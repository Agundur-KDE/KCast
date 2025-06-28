/*
 * SPDX-FileCopyrightText: 2025 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 */

import QtQuick
import QtQuick.Controls 6.7
import QtQuick.Layouts
import de.agundur.kcast 1.0
import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

DropArea {
    property bool isPaused: false
    property int selectedIndex: -1
    property var devices: []
    readonly property bool canPlay: devices.length > 0 && typeof mediaUrl.text === "string" && mediaUrl.text.length > 0
    property bool isPlaying: false

    function refreshDevices() {
        console.log("refreashing");
        devices = kcast.scanDevicesWithCatt();
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

    Component.onCompleted: {
        if (!kcast) {
            console.warn("❌ Plugin not available!");
            return ;
        }
        if (!kcast.isCattInstalled()) {
            console.warn("⚠ Bitte installiere 'catt' zuerst!");
            return ;
        }
        refreshDevices();
    }
    Layout.minimumWidth: deviceList.implicitWidth + 100
    Layout.minimumHeight: logoWrapper.implicitHeight + deviceList.implicitHeight + mediaUrl.implicitHeight + mediaControls.implicitHeight + 200
    implicitWidth: FullRepresentation.implicitWidth > 0 ? FullRepresentation.implicitWidth : 320
    implicitHeight: FullRepresentation.implicitHeight > 0 ? FullRepresentation.implicitHeight : 300

    DragDrop.DropArea {
        anchors.fill: parent
        preventStealing: true
        onDrop: (event) => {
            var url = "";
            if (event.mimeData.hasUrls && event.mimeData.urls.length > 0)
                url = event.mimeData.urls[0];
            else if (event.mimeData.hasText)
                url = event.mimeData.text;
            if (url !== "") {
                console.log("📥 URL erkannt:", url);
                mediaUrl.text = url;
            } else {
                console.log("⚠️ Keine gültige URL im Drop enthalten.");
                event.accept(Qt.IgnoreAction);
            }
        }
    }

    KCastBridge {
        id: kcast
    }

    ColumnLayout {
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
                text: "KCast"
                level: 2
                Layout.fillWidth: true
            }

        }

        PlasmaComponents.Label {
            text: devices.length > 0 ? "Select device:" : "No device found"
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
                text: "search devices"
                icon.name: "view-refresh"
                Layout.alignment: Qt.AlignRight
                onClicked: {
                    refreshDevices();
                }
            }

        }

        TextField {
            id: mediaUrl

            Layout.fillWidth: true
            placeholderText: "http://... or /path/to/file.mp4"
            onTextChanged: {
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
                        text: "copy"
                        enabled: mediaUrl.selectedText.length > 0
                        onTriggered: mediaUrl.copy()
                    }

                    MenuItem {
                        text: "paste"
                        // enabled: Qt.application.clipboard.hasText
                        onTriggered: mediaUrl.paste()
                    }

                    MenuItem {
                        text: "cut"
                        enabled: mediaUrl.selectedText.length > 0
                        onTriggered: mediaUrl.cut()
                    }

                    MenuItem {
                        text: "select all"
                        onTriggered: mediaUrl.selectAll()
                    }

                }

            }

        }

        RowLayout {
            id: mediaControls

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            PlasmaComponents.Button {
                text: "Play"
                icon.name: "media-playback-start"
                enabled: !isPlaying && canPlay
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

                text: isPaused ? "Resume" : "Pause"
                icon.name: "media-playback-pause"
                enabled: isPlaying
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
                enabled: isPlaying
                icon.name: "media-playback-stop"
                onClicked: {
                    _stop();
                    isPlaying = false;
                    isPaused = false;
                }
            }

        }
        // Platzhalter

        Item {
            Layout.fillHeight: true
        }

    }

}
