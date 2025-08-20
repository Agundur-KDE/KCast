/*
 * SPDX-FileCopyrightText: 2025 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 */

import Qt.labs.platform as Platform
import QtQuick 6.5
import QtQuick.Controls 6.7
import QtQuick.Layouts
import de.agundur.kcast 1.0
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {
    property string defaultDevice: Plasmoid.configuration.DefaultDevice
    property bool isPaused: false
    property int selectedIndex: -1
    property var devices: []
    readonly property bool canPlay: devices.length > 0 && typeof mediaUrl.text === "string" && mediaUrl.text.length > 0
    property bool isPlaying: false
    property int volumeStepBig: 5
    property int volumeStepSmall: 1
    property int currentVolume: 50
    property bool muted: false
    property bool userInteracting: false
    property int volumeIgnoreMs: 500
    property double lastUserTs: 0

    function refreshDevices() {
        console.log(i18n("refreashing"));
        devices = kcast.scanDevicesAsync();
    }

    function _play() {
        console.log(mediaUrl.text);
        kcast.playMedia(deviceSelector.currentText, mediaUrl.text);
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

    function markUserAction() {
        lastUserTs = Date.now();
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
        if (defaultDevice)
            devices = [defaultDevice];
        else
            refreshDevices();
        console.log("[KCast] DBus registration started");
        const ok = kcast.registerDBus();
        if (!ok)
            console.warn("[KCast] DBus registration failed");

        if (Plasmoid.configuration.defaultDevice && Plasmoid.configuration.defaultDevice.length > 0)
            setDefaultDevice(Plasmoid.configuration.defaultDevice);

    }
    Layout.minimumWidth: deviceList.implicitWidth + 100
    Layout.minimumHeight: logoWrapper.implicitHeight + deviceList.implicitHeight + mediaUrl.implicitHeight + mediaControls.implicitHeight + 200
    implicitWidth: FullRepresentation.implicitWidth > 0 ? FullRepresentation.implicitWidth : 320
    implicitHeight: FullRepresentation.implicitHeight > 0 ? FullRepresentation.implicitHeight : 300

    Timer {
        id: volumeDebounce

        interval: 80
        repeat: false
        onTriggered: {
            if (kcast && kcast.setVolume)
                kcast.setVolume(currentVolume);

        }
    }

    KCastBridge {
        id: kcast
    }

    DropArea {
        // Optional: Timeout oder sofort schließen

        anchors.fill: parent
        onDropped: function(drop) {
            var url = "";
            if (drop.hasUrls && drop.urls.length > 0)
                url = drop.urls[0];
            else if (drop.hasText)
                url = drop.text;
            if (url !== "") {
                console.log(i18n("URL detected: %1").arg(url));
                mediaUrl.text = url;
            } else {
                console.log(i18n("Not a valid url"));
                drop.accept(Qt.IgnoreAction);
            }
        }
        onExited: {
            if (root.keepOpenDuringDrop)
                Qt.callLater(() => {
                root.plasmoidItem.expanded = false;
            });

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

            Component.onCompleted: {
                if (devices.length > 0)
                    selectedIndex = 0;
                else
                    selectedIndex = -1;
            }
            Layout.fillWidth: true

            PlasmaComponents.ComboBox {
                id: deviceSelector

                Layout.fillWidth: true
                model: devices
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
                onTextEdited: kcast.setMediaUrl(text)

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

        }

        RowLayout {
            id: mediaControls

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            PlasmaComponents.Button {
                id: playBtn

                text: i18n("Play")
                icon.name: "media-playback-start"
                enabled: !isPlaying && canPlay
                checkable: true
                checked: kcast.playing
                onClicked: {
                    var raw = mediaUrl.text;
                    var cleaned = raw;
                    if (raw.startsWith("file://")) {
                        cleaned = raw.replace(/^file:\/\//, "");
                        mediaUrl.text = cleaned;
                    }
                    _play();
                    isPlaying = true;
                    isPaused = false;
                }
            }

            PlasmaComponents.Button {
                id: pauseButton

                property bool isPaused: false

                text: isPaused ? i18n("Resume") : i18n("Pause")
                icon.name: "media-playback-pause"
                enabled: isPlaying || kcast.playing
                onClicked: {
                    if (isPaused) {
                        text:
                        "Resume";
                        _resume();
                        isPaused = false;
                        pauseButton.icon.name = "media-playback-pause";
                    } else {
                        text:
                        "Pause";
                        _pause();
                        isPaused = true;
                        pauseButton.icon.name = "media-playback-start";
                    }
                }
            }

            PlasmaComponents.Button {
                text: "Stop"
                enabled: isPlaying || kcast.playing
                icon.name: "media-playback-stop"
                onClicked: {
                    _stop();
                    isPlaying = false;
                    isPaused = false;
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

                checkable: true
                checked: muted
                icon.name: muted ? "audio-volume-muted" : "audio-volume-high"
                // text: muted ? i18n("Unmute") : i18n("Mute")
                Accessible.name: checked ? "Unmute" : "Mute"
                onClicked: {
                    if (!kcast || !kcast.setMuted)
                        return ;

                    muted = checked;
                    kcast.setMuted(muted);
                }
            }

            PlasmaComponents.Button {
                // icon.name: "media-volume-down"
                text: i18n("-")
                onClicked: {
                    currentVolume = Math.max(0, currentVolume - volumeStepBig);
                    markUserAction();
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
                        markUserAction();
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
                onClicked: {
                    currentVolume = Math.min(100, currentVolume + volumeStepBig); // sofort im UI
                    markUserAction();
                    volumeDebounce.restart(); // nach kurzer Zeit >= setVolume()
                }
            }

        }

        Platform.FileDialog {
            id: fileDialog

            title: i18n("Open file")
            nameFilters: ["Media (*.mp4 *.mkv *.webm *.mp3)", "Alle Dateien (*)"]
            onAccepted: {
                mediaUrl.text = file;
            }
        }

        Item {
            Layout.fillHeight: true
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

    }

}
