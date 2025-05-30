import QtCore
import QtQml
import QtQuick 2.15
import QtQuick.Layouts 1.1
import de.agundur.kcast 1.0
import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid 2.0

PlasmoidItem {
    id: root

    // Liste der Geräte
    property var devices: []
    property int selectedIndex: -1
    property bool canPlay: false
    property bool isPlaying: false
    property bool isPaused: false

    function refreshDevices() {
        console.log("refreashing");
        if (!kcast) {
            console.warn("❌ Plugin not available!");
            return ;
        }
        devices = kcast.scanDevicesWithCatt();
        console.log("📡 Gefundene Geräte:", devices);
        if (devices.length > 0) {
            selectedIndex = 0;
            kcast.setSelectedDeviceIndex(0);
        } else {
            selectedIndex = -1;
        }
    }

    function _play() {
        console.log(mediaUrl.text);
        if (!kcast) {
            console.warn("❌ Plugin not available!");
            return ;
        }
        kcast.playMedia(deviceSelector.currentText, mediaUrl.text);
    }

    function _pause() {
        if (!kcast) {
            console.warn("❌ Plugin not available!");
            return ;
        }
        kcast.pauseMedia();
    }

    function _stop() {
        if (!kcast) {
            console.warn("❌ Plugin not available!");
            return ;
        }
        kcast.stopMedia();
    }

    Component.onCompleted: {
        refreshDevices();
    }
    Plasmoid.title: i18n("KCast")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
    Layout.minimumHeight: Kirigami.Units.gridUnit * 5
    implicitHeight: 280
    implicitWidth: 340

    // Plugin-Instanz
    KCastBridge {
        id: kcast
    }

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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Titel
            Kirigami.Heading {
                text: "KCast"
                level: 2
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: devices.length > 0 ? "Select device:" : "No device found"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            // 1) Device-Liste (ComboBox)
            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents.ComboBox {
                    id: deviceSelector

                    Layout.fillWidth: true
                    model: devices
                    currentIndex: selectedIndex
                    onCurrentIndexChanged: {
                        selectedIndex = currentIndex;
                        if (typeof kcast !== "undefined")
                            kcast.setSelectedDeviceIndex(currentIndex);

                    }
                }

                PlasmaComponents.Button {
                    text: "search devices"
                    icon.name: "view-refresh"
                    Layout.alignment: Qt.AlignRight
                    onClicked: kcast.scanDevicesWithCatt()
                }

            }

            PlasmaComponents.TextField {
                id: mediaUrl

                Layout.fillWidth: true
                placeholderText: "http://... or /path/to/file.mp4"
                onTextChanged: {
                    const valid = text.length > 5 && text.endsWith(".mp4");
                    canPlay = valid;
                    if (!valid) {
                        isPlaying = false;
                        isPaused = false;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                PlasmaComponents.Button {
                    text: "Play"
                    icon.name: "media-playback-start"
                    enabled: canPlay && !isPlaying
                    onClicked: {
                        _play();
                        isPlaying = true;
                        isPaused = false;
                    }
                }

                PlasmaComponents.Button {
                    property bool isPaused: false

                    text: isPaused ? "⏵ Resume" : "⏸ Pause"
                    icon.name: "media-playback-pause"
                    enabled: isPlaying
                    onClicked: {
                        if (isPaused) {
                            text:
                            "⏵ Resume";
                            _pause();
                            isPaused = false;
                        } else {
                            text:
                            "⏸ Pause";
                            _pause();
                            isPaused = true;
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

}
