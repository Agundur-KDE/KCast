/*
 * SPDX-FileCopyrightText: 2025 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 */

import Qt.labs.platform as Platform
import QtCore
import QtQuick 6.5
import QtQuick.Controls 6.7
import QtQuick.Layouts
import de.agundur.kcast 1.0
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid
import "playlistparser.js" as Parser

Item {
    property string defaultDevice: Plasmoid.configuration.DefaultDevice
    property var devices: []
    property int volumeStepBig: 5
    property int volumeStepSmall: 1
    property int currentVolume: 5
    property bool muted: false
    property string playState: "idle"   // "idle" | "playing" | "paused"
    readonly property bool deviceReady: !!(kcast && kcast.defaultDevice && kcast.defaultDevice.length > 0)
    readonly property bool controlsEnabled: !!(kcast.defaultDevice && kcast.defaultDevice.length > 0)
    readonly property bool hasMedia: typeof mediaUrl.text === "string" && mediaUrl.text.trim().length > 0
    property var deviceListModel: {
        var def = kcast.defaultDevice || defaultDevice || "";
        var found = (kcast && kcast.devices) ? kcast.devices : [];
        var list = (def.length > 0 && def !== "-") ? [def] : [];
        for (var i = 0; i < found.length; i++) {
            if (found[i] !== def) list.push(found[i]);
        }
        return list;
    }
    // Editing the URL / dropping something new no longer requires an
    // explicit Stop first — CastFile() just replaces whatever the device
    // is currently playing, so Play can stay enabled regardless of playState.
    readonly property bool canPlay: controlsEnabled && hasMedia

    property var playlist: []
    property int playlistIndex: -1
    // loop/shuffle state lives on playlistView itself (single source of
    // truth) — read via playlistView.loopMode / playlistView.shuffle below

    function loadVolumeForDevice(name) {
        if (!name || name.length === 0) return;
        try {
            var vols = JSON.parse(Plasmoid.configuration.deviceVolumes || "{}");
            if (name in vols)
                currentVolume = vols[name];
        } catch(e) {}
    }

    function saveVolumeForDevice(name, vol) {
        if (!name || name.length === 0) return;
        try {
            var vols = JSON.parse(Plasmoid.configuration.deviceVolumes || "{}");
            vols[name] = vol;
            Plasmoid.configuration.deviceVolumes = JSON.stringify(vols);
        } catch(e) {}
    }

    function refreshDevices() {
        console.log(i18n("refreshing"));
        // scanDevicesAsync() is void — the real update comes from the
        // onDevicesScanned Connections handler below once the scan
        // finishes. Assigning its return value here just clobbered
        // devices with undefined for the brief window until then.
        kcast.scanDevicesAsync();
    }

    function devs() {
        return (kcast && kcast.devices) ? kcast.devices : [];
    }

    function startScan() {
        devices = [];
        kcast.scanDevicesAsync();
    }

    function _play() {
        let url = mediaUrl.text || "";
        if (url.startsWith("file://"))
            url = url.replace(/^file:\/\//, "");

        kcast.CastFile(url);
    }

    function _pause() {
        kcast.pauseMedia(deviceSelector.currentText);
    }

    function _resume() {
        kcast.resumeMedia(deviceSelector.currentText);
    }

    function _stop() {
        kcast.stopMedia(deviceSelector.currentText);
    }

    function playPlaylistEntry(index) {
        if (index < 0 || index >= playlist.length) return;
        playlistIndex = index;
        var url = playlist[index].url.replace(/^file:\/\//, "");
        mediaUrl.text = playlist[index].url;
        kcast.mediaUrl = playlist[index].url;
        kcast.CastFile(url);
        playState = "playing";
    }

    function nextTrackIndex() {
        if (playlist.length === 0) return -1;
        var loopMode = playlistView.loopMode;
        if (playlistView.shuffle) {
            if (playlist.length === 1) return loopMode === "off" ? -1 : 0;
            var next;
            do {
                next = Math.floor(Math.random() * playlist.length);
            } while (next === playlistIndex);
            return next;
        }
        var i = playlistIndex + 1;
        if (i >= playlist.length)
            return loopMode === "all" ? 0 : -1;
        return i;
    }

    function playNext() {
        var i = playlistView.loopMode === "one" ? playlistIndex : nextTrackIndex();
        if (i >= 0) playPlaylistEntry(i);
    }

    function playPrevious() {
        if (playlist.length === 0) return;
        var i = playlistIndex - 1;
        if (i < 0) i = playlistView.loopMode === "all" ? playlist.length - 1 : 0;
        playPlaylistEntry(i);
    }

    // Quotes a path for safe use inside a shell command string (single
    // quotes, with embedded single quotes escaped the POSIX way).
    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    // Builds an ad-hoc playlist from a multi-file drop, or parses a
    // dropped .m3u/.m3u8 file — which, confusingly, can also be an HLS
    // *stream* manifest rather than a playlist (see playlistparser.js).
    //
    // Reads the file via Plasma5Support's "executable" engine (`cat`),
    // not XMLHttpRequest — verified in this environment that a local
    // file:// XHR GET (sync AND async) simply never completes under
    // Qt 6.11's QML engine, while the executable DataSource works fine
    // and is the same mechanism already used for icon-path resolution
    // in KHoneycomb.
    function loadPlaylistFromM3U(fileUrl) {
        var localPath = fileUrl.replace(/^file:\/\//, "");
        m3uReadSource.pendingUrl = fileUrl;
        m3uReadSource.connectSource("cat " + shellQuote(localPath));
    }

    function loadPlaylistFromUrls(urls) {
        playlist = urls.map((u) => ({
            url: u,
            title: Parser.baseName(u),
            duration: ""
        }));
        playPlaylistEntry(0);
    }



    Component.onCompleted: {
        mediaUrl.text = kcast.mediaUrl;
        if (!kcast) {
            console.warn(i18n("Plugin not available!"));
            return ;
        }
        if (!kcast.isCattInstalled()) {
            console.warn(i18n("You need to install 'catt' first!"));
            return ;
        }
        console.log("[KCast] DBus registration started");
        const ok = kcast.registerDBus();
        if (!ok)
            console.warn("[KCast] DBus registration failed");

        if (defaultDevice && defaultDevice.length > 0 && defaultDevice !== "-")
            kcast.setDefaultDevice(defaultDevice);

        loadVolumeForDevice(defaultDevice || kcast.defaultDevice);

        if (!kcast.defaultDevice || kcast.defaultDevice.length === 0)
            startScan();

    }
    Layout.minimumWidth: deviceList.implicitWidth + 100
    Layout.minimumHeight: logoWrapper.implicitHeight + deviceList.implicitHeight + mediaUrl.implicitHeight + mediaControls.implicitHeight + volumeControls.implicitHeight + playlistView.implicitHeight + 150
    implicitWidth: FullRepresentation.implicitWidth > 0 ? FullRepresentation.implicitWidth : 320
    implicitHeight: FullRepresentation.implicitHeight > 0 ? FullRepresentation.implicitHeight : 300

    Timer {
        id: volumeDebounce

        interval: 80
        repeat: false
        onTriggered: {
            if (kcast && kcast.setVolume) {
                kcast.setVolume(currentVolume);
                saveVolumeForDevice(kcast.defaultDevice, currentVolume);
            }
        }
    }

    KCastBridge {
        id: kcast
    }

    DropArea {
        // Optional: Timeout oder sofort schließen

        anchors.fill: parent
        onDropped: function(drop) {
            if (drop.hasUrls && drop.urls.length > 1) {
                loadPlaylistFromUrls(drop.urls);
                return;
            }

            var url = "";
            if (drop.hasUrls && drop.urls.length > 0)
                url = drop.urls[0];
            else if (drop.hasText)
                url = drop.text;

            if (url === "") {
                console.log(i18n("Not a valid url"));
                drop.accept(Qt.IgnoreAction);
                return;
            }

            // Single item could be a plain file or a folder — resolve it
            // (folder → its media files become the playlist).
            resolveAndHandlePath(url);
        }
        onExited: {
            if (root.keepOpenDuringDrop)
                Qt.callLater(() => {
                root.plasmoidItem.expanded = false;
            });

        }
    }

    // Resolves a dropped/opened path that might be a folder: lists its
    // media files (non-recursive) and loads them as a playlist. A plain
    // file just passes through to handleIncomingUrl unchanged. Uses the
    // same executable DataSource as everything else (see below) — `find`
    // for the directory case, `echo` as the single-file fallback, so both
    // cases come back through the one onNewData handler.
    function resolveAndHandlePath(path) {
        var localPath = path.replace(/^file:\/\//, "");
        var mediaExts = ["mp4", "mkv", "webm", "avi", "m4v", "mp3", "flac", "wav", "ogg"];
        var findExpr = mediaExts.map((ext) => "-iname " + shellQuote("*." + ext)).join(" -o ");
        var script = "if [ -d \"$1\" ]; then find \"$1\" -maxdepth 1 -type f \\( " + findExpr + " \\) | sort; else echo \"$1\"; fi";
        pathResolveSource.connectSource("sh -c " + shellQuote(script) + " _ " + shellQuote(localPath));
    }

    // Shared by drag&drop and the Dolphin service-menu file handoff below.
    function handleIncomingUrl(url) {
        console.log(i18n("URL detected: %1").arg(url));

        if (/\.m3u8?$/i.test(url)) {
            loadPlaylistFromM3U(url);
            return;
        }

        playlist = [];
        playlistIndex = -1;
        mediaUrl.text = url;
        // setting .text directly doesn't fire onTextEdited (that's
        // only for user-driven edits), so the bridge's mediaUrl
        // property — read by the Dolphin service menu's file handoff
        // (see dolphinHandoffTimer below) — would otherwise stay stale.
        kcast.mediaUrl = url;
    }

    // Replaces the old D-Bus self-registration: the Dolphin service menu
    // (servicemenus/kcast_stream.desktop) now appends the dropped file's
    // URL as one line to ~/.cache/kcast/incoming instead of calling
    // de.agundur.kcast/CastFile over D-Bus. This is the only thing that
    // used the D-Bus interface (verified: grepped the repo, nothing else
    // calls it) — no compiled plugin needed just for that anymore.
    property string incomingQueuePath: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "") + "/.cache/kcast/incoming"
    // ponytail: append-only queue file, never truncated — fine at drop-menu
    // volume (a handful of lines ever), revisit if it ever grows large.
    property int incomingConsumedLength: 0

    Plasma5Support.DataSource {
        id: m3uReadSource

        engine: "executable"
        property string pendingUrl: ""

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            var fileUrl = pendingUrl;
            pendingUrl = "";
            var result = Parser.parseM3U(data["stdout"] || "");
            if (result.kind === "playlist") {
                playlist = result.entries;
                playPlaylistEntry(0);
            } else {
                // "hls" or "empty": not a queue, cast the manifest URL directly
                mediaUrl.text = fileUrl;
                kcast.mediaUrl = fileUrl;
            }
        }
    }

    Plasma5Support.DataSource {
        id: dolphinPollSource

        engine: "executable"

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            var text = data["stdout"] || "";
            if (text.length <= incomingConsumedLength)
                return;

            var newPart = text.substring(incomingConsumedLength);
            incomingConsumedLength = text.length;
            newPart.split(/\r?\n/).forEach((line) => {
                var url = line.trim();
                if (url.length > 0)
                    resolveAndHandlePath(url);
            });
        }
    }

    Timer {
        id: dolphinHandoffTimer

        interval: 800
        running: true
        repeat: true
        onTriggered: dolphinPollSource.connectSource("cat " + shellQuote(incomingQueuePath))
    }

    Plasma5Support.DataSource {
        id: pathResolveSource

        engine: "executable"

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            var lines = (data["stdout"] || "").split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0);
            if (lines.length > 1)
                loadPlaylistFromUrls(lines);
            else if (lines.length === 1)
                handleIncomingUrl(lines[0]);
        }
    }

    ColumnLayout {
        // Platzhalter

        anchors.fill: parent
        spacing: 12
        anchors.margins: Kirigami.Units.largeSpacing

        RowLayout {
            Item {
                id: logoWrapper

                width: 64
                height: 64
                // ToolTip.visible: kcastIcon.containsMouse
                ToolTip.delay: 500
                ToolTip.text: "KCast"

                Image {
                    id: kcastIcon

                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("../icons/kcast_icon_64x64.png")
                    width: 64
                    height: 64
                    fillMode: Image.PreserveAspectFit
                }

            }

            Kirigami.Heading {
                text: i18n("KCast")
                level: 2
                Layout.fillWidth: true
            }

        }

        PlasmaComponents.Label {
            text: devices.length > 0 ? i18n("Select device:") : i18n("No device found")
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        // 1) Device-Liste (ComboBox)
        RowLayout {
            id: deviceList

            Layout.fillWidth: true

            PlasmaComponents.ComboBox {
                id: deviceSelector

                Layout.fillWidth: true
                model: deviceListModel
                onActivated: (i) => {
                    if (i >= 0 && i < model.length) {
                        kcast.setDefaultDevice(model[i]);
                        loadVolumeForDevice(model[i]);
                    }
                }
            }

            PlasmaComponents.Button {
                text: i18n("search devices")
                icon.name: "view-refresh"
                Layout.alignment: Qt.AlignRight
                onClicked: {
                    refreshDevices();
                }
            }

        }

        RowLayout {
            TextField {
                id: mediaUrl

                Layout.fillWidth: true
                placeholderText: i18n("http://... or /path/to/file.mp4")
                // 1) UI initial mit Bridge befüllen
                Component.onCompleted: mediaUrl.text = kcast.mediaUrl
                // 3) Wenn der Nutzer tippt → zurück in die Bridge spiegeln
                onTextEdited: kcast.mediaUrl = text

                // 2) Wenn die Bridge (z.B. via D-Bus) mediaUrl ändert → UI nachziehen
                Connections {
                    function onMediaUrlChanged() {
                        mediaUrl.text = kcast.mediaUrl;
                    }

                    target: kcast
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onPressed: {
                        if (mouse.button === Qt.RightButton)
                            menu.popup();

                    }

                    Menu {
                        id: menu

                        MenuItem {
                            text: i18n("copy")
                            enabled: mediaUrl.selectedText.length > 0
                            onTriggered: mediaUrl.copy()
                        }

                        MenuItem {
                            text: i18n("paste")
                            onTriggered: mediaUrl.paste()
                        }

                        MenuItem {
                            text: i18n("cut")
                            enabled: mediaUrl.selectedText.length > 0
                            onTriggered: mediaUrl.cut()
                        }

                        MenuItem {
                            text: i18n("select all")
                            onTriggered: mediaUrl.selectAll()
                        }

                    }

                }

            }

            PlasmaComponents.Button {
                text: i18n("open")
                icon.name: "folder-video"
                Layout.alignment: Qt.AlignRight
                onClicked: {
                    fileDialog.open();
                }
            }

            PlasmaComponents.Button {
                icon.name: "folder-open"
                display: PlasmaComponents.Button.IconOnly
                Layout.alignment: Qt.AlignRight
                ToolTip.text: i18n("Open folder as playlist")
                ToolTip.visible: hovered
                onClicked: {
                    folderDialog.open();
                }
            }

        }

        RowLayout {
            id: mediaControls

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            PlasmaComponents.Button {
                icon.name: "media-skip-backward"
                display: PlasmaComponents.Button.IconOnly
                visible: playlist.length > 0
                enabled: playlist.length > 1
                onClicked: playPrevious()
            }

            PlasmaComponents.Button {
                text: i18n("Play")
                icon.name: "media-playback-start"
                enabled: canPlay
                onClicked: {
                    if (playlistIndex >= 0) {
                        playPlaylistEntry(playlistIndex);
                        return;
                    }
                    var url = mediaUrl.text.replace(/^file:\/\//, "");
                    mediaUrl.text = url;
                    kcast.CastFile(url);
                    playState = "playing";
                }
            }

            PlasmaComponents.Button {
                icon.name: "media-skip-forward"
                display: PlasmaComponents.Button.IconOnly
                visible: playlist.length > 0
                enabled: playlist.length > 1
                onClicked: playNext()
            }

            PlasmaComponents.Button {
                text: playState === "playing" ? i18n("Pause") : i18n("Resume")
                icon.name: playState === "playing" ? "media-playback-pause" : "media-playback-start"
                enabled: controlsEnabled && playState !== "idle"
                onClicked: {
                    if (playState === "playing") {
                        kcast.pauseMedia(kcast.defaultDevice);
                        playState = "paused";
                    } else if (playState === "paused") {
                        kcast.resumeMedia(kcast.defaultDevice);
                        playState = "playing";
                    }
                }
            }

            PlasmaComponents.Button {
                text: i18n("Stop")
                icon.name: "media-playback-stop"
                enabled: controlsEnabled && playState !== "idle"
                onClicked: {
                    kcast.stopMedia(kcast.defaultDevice);
                    playState = "idle";
                }
            }

        }

        RowLayout {
            id: volumeControls

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            PlasmaComponents.Button {
                id: muteBtn

                enabled: controlsEnabled
                checkable: true
                checked: muted
                icon.name: muted ? "audio-volume-muted" : "audio-volume-high"
                // text: muted ? i18n("Unmute") : i18n("Mute")
                Accessible.name: checked ? "Unmute" : "Mute"
                onClicked: {
                    kcast.setMuted(muteBtn.checked);
                }
            }

            PlasmaComponents.Button {
                // icon.name: "media-volume-down"
                text: i18n("-")
                enabled: deviceReady
                onClicked: {
                    currentVolume = Math.max(0, currentVolume - volumeStepBig);
                    
                    volumeDebounce.restart();
                }
            }

            PlasmaComponents.Slider {
                id: volumeSlider

                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: volumeStepSmall
                live: true
                value: currentVolume
                enabled: deviceReady
                // Beim Ziehen: nur throttled (Debounce) senden
                onValueChanged: {
                    if (!pressed)
                        return ;

                    // nur wenn der User wirklich schiebt
                    currentVolume = Math.round(value);
                    volumeDebounce.restart();
                }
                // „Loslassen“-Moment: final commit (ersetzt onReleased)
                onPressedChanged: {
                    if (pressed)
                        return ;

                    // wird false => Finger/Maus losgelassen
                    if (!kcast || !kcast.setVolume)
                        return ;

                    currentVolume = Math.round(value);
                    kcast.setVolume(currentVolume);
                    saveVolumeForDevice(kcast.defaultDevice, currentVolume);
                }
                Keys.onPressed: (ev) => {
                    if (ev.key === Qt.Key_Left) {
                        currentVolume = Math.max(0, currentVolume - volumeStepSmall);
                        volumeDebounce.restart();
                        ev.accepted = true;
                    }
                    if (ev.key === Qt.Key_Right) {
                        currentVolume = Math.min(100, currentVolume + volumeStepSmall);
                        volumeDebounce.restart();
                        ev.accepted = true;
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (ev) => {
                        const d = ev.angleDelta.y > 0 ? volumeStepSmall : -volumeStepSmall;
                        currentVolume = Math.max(0, Math.min(100, currentVolume + d));
                        
                        volumeDebounce.restart();
                        ev.accepted = true;
                    }
                }

            }

            PlasmaComponents.Label {
                // minimumWidth: implicitWidth

                text: currentVolume + "%"
                Accessible.name: i18n("Volume in %")
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents.Button {
                // icon.name: "media-volume-up"
                text: i18n("+")
                enabled: deviceReady
                onClicked: {
                    currentVolume = Math.min(100, currentVolume + volumeStepBig); // sofort im UI
                    
                    volumeDebounce.restart(); // nach kurzer Zeit >= setVolume()
                }
            }

        }

        Platform.FileDialog {
            id: fileDialog

            title: i18n("Open file")
            nameFilters: ["Media (*.mp4 *.mkv *.webm *.mp3)", "Alle Dateien (*)"]
            onAccepted: {
                playlist = [];
                playlistIndex = -1;
                mediaUrl.text = file;
                kcast.mediaUrl = file;
            }
        }

        Platform.FolderDialog {
            id: folderDialog

            title: i18n("Open folder as playlist")
            onAccepted: resolveAndHandlePath(String(folder))
        }

        PlaylistView {
            id: playlistView

            Layout.fillWidth: true
            entries: playlist
            currentIndex: playlistIndex
            onEntryActivated: (index) => playPlaylistEntry(index)
        }

        Item {
            Layout.fillHeight: true
        }

        Connections {
            target: kcast
            function onPlayingChanged() {
                if (!kcast.playing && playState === "playing") {
                    playState = "idle";
                    // Track ended on the device: auto-advance if a
                    // playlist is active and loop/shuffle says to continue.
                    if (playlist.length > 0)
                        playNext();
                }
            }
        }

        Connections {
            function onVolumeCommandSent(command, value) {
                if (command === "set")
                    currentVolume = value;

                if (command === "up")
                    currentVolume = Math.max(0, Math.min(100, currentVolume + value));

                if (command === "down")
                    currentVolume = Math.max(0, Math.min(100, currentVolume - value));

            }

            function onMuteCommandSent(on) {
                muted = on;
            }

            target: kcast
        }

        Connections {
            // erstes gefundenes nehmen
            // z.B. eine Fehlermeldung sichtbar schalten

            function onDeviceFound(name) {
                if (devices.indexOf(name) === -1)
                    devices = devices.concat([name]);

                // trigger Bindings
                if (!kcast.defaultDevice || kcast.defaultDevice.length === 0)
                    kcast.setDefaultDevice(name);

            }

            function onDevicesScanned(list) {
                devices = Array.isArray(list) ? list : [];
            }

            target: kcast
        }

    }

}
