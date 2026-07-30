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
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid
import "playlistparser.js" as Parser

Item {
    id: fullRep

    property string defaultDevice: Plasmoid.configuration.DefaultDevice
    property var devices: []
    property bool scanning: false
    property int volumeStepBig: 5
    property int volumeStepSmall: 1
    property int currentVolume: 5
    property bool muted: false
    property string playState: "idle"   // "idle" | "playing" | "paused"
    property real mediaPosition: 0
    property real mediaDuration: 0
    property bool seekPending: false

    function formatTime(seconds) {
        var s = Math.max(0, Math.round(seconds));
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    readonly property bool deviceReady: !!(defaultDevice && defaultDevice.length > 0 && defaultDevice !== "-")
    readonly property bool controlsEnabled: !!(defaultDevice && defaultDevice.length > 0 && defaultDevice !== "-")
    readonly property bool hasMedia: typeof mediaUrl.text === "string" && mediaUrl.text.trim().length > 0
    property var deviceListModel: {
        var def = defaultDevice || "";
        var list = (def.length > 0 && def !== "-") ? [def] : [];
        for (var i = 0; i < devices.length; i++) {
            if (devices[i] !== def) list.push(devices[i]);
        }
        return list;
    }
    // Editing the URL / dropping something new no longer requires an
    // explicit Stop first — casting just replaces whatever the device
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

    function setDefaultDevice(name) {
        defaultDevice = name;
        Plasmoid.configuration.DefaultDevice = name;
        if (devices.indexOf(name) === -1)
            devices = devices.concat([name]);
    }

    // Quotes a path/argument for safe use inside a shell command string
    // (single quotes, embedded single quotes escaped the POSIX way).
    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    // Fire-and-forget catt invocation (cast/pause/play/stop/volume/mute)
    // via Plasma5Support's "executable" engine — no compiled C++ plugin
    // needed to spawn catt, see cattSource below.
    function catt(args) {
        cattSource.connectSource("catt " + args.map(shellQuote).join(" "));
    }

    function refreshDevices() {
        devices = [];
        scanning = true;
        // catt scan has its own ~5s discovery window and then exits on
        // its own (verified: `time catt scan` in this environment) — a
        // one-shot executable-engine call, no incremental/live discovery.
        scanSource.connectSource("catt scan -j");
    }

    function startScan() {
        refreshDevices();
    }

    // catt's own cast command wants a plain local path, not a file://
    // URL (matches the previous C++ normalizeUrlForCasting behavior).
    function normalizeUrlForCasting(input) {
        return input.replace(/^file:\/\//, "");
    }

    function castUrl(url) {
        if (!defaultDevice || defaultDevice === "-") {
            console.warn("[KCast] No device available for cast");
            return;
        }
        // `catt cast` on a local file blocks forever (it runs a local HTTP
        // server to serve the file) — switching tracks without tearing the
        // previous one down first is flaky (confirmed live: rapid re-cast
        // without a real device-level stop plays every other track,
        // silently no-ops the rest). Sequence: tell the device to stop
        // (clean teardown, not just killing our local process), kill any
        // leftover local server process for this device (pattern anchored
        // with ^ — unanchored also matches this very `sh -c "..."`
        // wrapper's own command line and kills itself), then a short
        // safety delay before the new cast so the receiver has time to
        // actually reset.
        var killAndCast = "catt -d " + shellQuote(defaultDevice) + " stop 2>/dev/null; pkill -f "
            + shellQuote("^catt -d " + defaultDevice + " cast") + " 2>/dev/null; sleep 1; catt "
            + ["-d", defaultDevice, "cast", normalizeUrlForCasting(url)].map(shellQuote).join(" ");
        cattSource.connectSource(killAndCast);
        playState = "playing";
        mediaPosition = 0;
        mediaDuration = 0;
    }

    function playPlaylistEntry(index) {
        if (index < 0 || index >= playlist.length) return;
        playlistIndex = index;
        mediaUrl.text = playlist[index].url;
        castUrl(playlist[index].url);
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
        cattCheckSource.connectSource("command -v catt");

        if (defaultDevice && defaultDevice.length > 0 && defaultDevice !== "-")
            setDefaultDevice(defaultDevice);

        loadVolumeForDevice(defaultDevice);

        if (!defaultDevice || defaultDevice.length === 0 || defaultDevice === "-")
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
            if (!defaultDevice) return;
            catt(["-d", defaultDevice, "volume", String(currentVolume)]);
            saveVolumeForDevice(defaultDevice, currentVolume);
        }
    }

    // Fire-and-forget catt commands (cast/pause/play/stop/volume/mute) —
    // see the catt() function above.
    Plasma5Support.DataSource {
        id: cattSource

        engine: "executable"
        onNewData: (sourceName, data) => disconnectSource(sourceName)
    }

    // Polls playback position/duration for the seek bar. `catt info -j`
    // is the only catt subcommand that reports current_time/duration —
    // no push/event API, so a 1s poll is the simplest thing that works.
    // Skipped while the slider is being dragged so the poll can't yank
    // the handle back mid-drag.
    Timer {
        interval: 1000
        running: playState !== "idle"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!defaultDevice || seekSlider.pressed || seekPending) return;
            infoSource.connectSource("catt -d " + shellQuote(defaultDevice) + " info -j");
        }
    }

    Plasma5Support.DataSource {
        id: infoSource

        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            // A poll started just before a seek was issued can still land
            // after seekPending flips true, carrying the pre-seek position
            // — applying it would yank the handle back before seekSource's
            // completion snaps it forward again. Drop it, next poll is fine.
            if (seekPending) return;
            try {
                var info = JSON.parse(data["stdout"] || "{}");
                mediaPosition = info.current_time || 0;
                mediaDuration = info.duration || 0;
                if (info.player_state === "PAUSED") playState = "paused";
                else if (info.player_state === "PLAYING" || info.player_state === "BUFFERING") playState = "playing";
            } catch (e) {}
        }
    }

    // catt's own seek completion signal — the process only exits once the
    // device has actually acknowledged the seek, so it's a reliable point
    // to resume trusting polled positions again.
    Plasma5Support.DataSource {
        id: seekSource

        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            seekPending = false;
        }
    }

    Plasma5Support.DataSource {
        id: cattCheckSource

        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if ((data["exit code"] || 0) !== 0)
                console.warn(i18n("You need to install 'catt' first!"));
        }
    }

    // `catt scan -j` prints one JSON object (keyed by device name) after
    // its own ~5s discovery window, then exits — no incremental/live
    // discovery like the old QProcess::readyReadStandardOutput did.
    Plasma5Support.DataSource {
        id: scanSource

        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            scanning = false;
            var found = [];
            try {
                found = Object.keys(JSON.parse(data["stdout"] || "{}"));
            } catch (e) {
                found = [];
            }
            devices = found;
            if ((!defaultDevice || defaultDevice.length === 0 || defaultDevice === "-") && found.length > 0)
                setDefaultDevice(found[0]);
        }
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
            text: scanning ? i18n("Searching devices…")
                : devices.length > 0 ? i18n("Select device:")
                : i18n("No device found")
            color: (!scanning && devices.length === 0) ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
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
                        setDefaultDevice(model[i]);
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
            id: seekControls

            Layout.fillWidth: true
            visible: playState !== "idle" && mediaDuration > 0
            spacing: 8

            PlasmaComponents.Label {
                text: formatTime(seekSlider.pressed ? seekSlider.value : mediaPosition)
            }

            PlasmaComponents.Slider {
                id: seekSlider

                Layout.fillWidth: true
                from: 0
                to: Math.max(mediaDuration, 1)
                value: mediaPosition
                live: true
                onPressedChanged: {
                    if (pressed) return;
                    var target = Math.round(value);
                    mediaPosition = target;
                    seekPending = true;
                    seekSource.connectSource("catt -d " + shellQuote(defaultDevice) + " seek " + shellQuote(String(target)));
                }
            }

            PlasmaComponents.Label {
                text: formatTime(mediaDuration)
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
                enabled: playlist.length > 1 && playState !== "idle"
                onClicked: playPrevious()
            }

            PlasmaComponents.Button {
                text: i18n("-10s")
                display: PlasmaComponents.Button.TextOnly
                enabled: controlsEnabled && playState !== "idle"
                onClicked: catt(["-d", defaultDevice, "rewind", "10"])
            }

            // Single toggle button, matching the near-universal media-player
            // convention (VLC/Spotify/YouTube): shows the icon/label for the
            // ACTION a click will perform, not the current state as text —
            // "Pause" while playing, "Play" while idle/paused, never
            // "Resume". Unlike VLC (icon-only, easy to misread at a glance),
            // checkable+checked gives it a sunken/pressed look while
            // playing, so the state itself is visible, not just the icon.
            PlasmaComponents.Button {
                text: playState === "playing" ? i18n("Pause") : i18n("Play")
                icon.name: playState === "playing" ? "media-playback-pause" : "media-playback-start"
                enabled: playState === "idle" ? canPlay : controlsEnabled
                checkable: true
                checked: playState === "playing"
                onClicked: {
                    if (playState === "playing") {
                        catt(["-d", defaultDevice, "pause"]);
                        playState = "paused";
                    } else if (playState === "paused") {
                        catt(["-d", defaultDevice, "play"]);
                        playState = "playing";
                    } else if (playlistIndex >= 0) {
                        playPlaylistEntry(playlistIndex);
                    } else {
                        var url = mediaUrl.text.replace(/^file:\/\//, "");
                        mediaUrl.text = url;
                        castUrl(url);
                    }
                }
            }

            PlasmaComponents.Button {
                text: i18n("+10s")
                display: PlasmaComponents.Button.TextOnly
                enabled: controlsEnabled && playState !== "idle"
                onClicked: catt(["-d", defaultDevice, "ffwd", "10"])
            }

            PlasmaComponents.Button {
                icon.name: "media-skip-forward"
                display: PlasmaComponents.Button.IconOnly
                visible: playlist.length > 0
                enabled: playlist.length > 1 && playState !== "idle"
                onClicked: playNext()
            }

            PlasmaComponents.Button {
                text: i18n("Stop")
                icon.name: "media-playback-stop"
                enabled: controlsEnabled && playState !== "idle"
                onClicked: {
                    catt(["-d", defaultDevice, "stop"]);
                    playState = "idle";
                    mediaPosition = 0;
                    mediaDuration = 0;
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
                    muted = muteBtn.checked;
                    catt(["-d", defaultDevice, "volumemute", muted ? "true" : "false"]);
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
                    if (!defaultDevice)
                        return ;

                    currentVolume = Math.round(value);
                    catt(["-d", defaultDevice, "volume", String(currentVolume)]);
                    saveVolumeForDevice(defaultDevice, currentVolume);
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
            playState: fullRep.playState
            onEntryActivated: (index) => playPlaylistEntry(index)
        }

        Item {
            Layout.fillHeight: true
        }

    }

}
