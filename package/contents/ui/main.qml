import QtCore
import QtQml
import QtQuick 2.15
import QtQuick.Layouts 1.1
import de.agundur.kcast 1.0
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

    function refreshDevices() {
        console.log("refreashing");
        if (!kcast) {
            console.warn("❌ Plugin not available!");
            return ;
        }
        devices = kcast.deviceList();
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
        kcast.play(mediaUrl.text);
    }

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
    Layout.minimumHeight: Kirigami.Units.gridUnit * 5
    implicitHeight: 280
    implicitWidth: 340
    Component.onCompleted: {
        backend.startBackend();
        refreshDevices();
    }

    // Plugin-Instanz
    KCastBridge {
        id: kcast
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
                onActivated: {
                    selectedIndex = currentIndex;
                    if (kcast)
                        kcast.setSelectedDeviceIndex(currentIndex);

                }
            }

            PlasmaComponents.Button {
                text: "🔄 Geräte aktualisieren"
                icon.name: "view-refresh"
                Layout.alignment: Qt.AlignRight
                onClicked: refreshDevices()
            }

        }

        PlasmaComponents.TextField {
            id: mediaUrl

            placeholderText: "http://... oder /path/to/file.mp4"
            Layout.fillWidth: true
        }
        // 3) Buttons für die Steuerung

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            PlasmaComponents.Button {
                text: "Play"
                icon.name: "media-playback-start"
                enabled: deviceSelector.currentIndex >= 0 && mediaUrl.text.length > 0
                onClicked: _play()
            }

            PlasmaComponents.Button {
                text: "Pause"
                icon.name: "media-playback-pause"
                enabled: deviceSelector.currentIndex >= 0
                onClicked: runCast("pause", "")
            }

            PlasmaComponents.Button {
                text: "Stop"
                icon.name: "media-playback-stop"
                enabled: deviceSelector.currentIndex >= 0
                onClicked: runCast("stop", "")
            }

        }
        // Platzhalter

        Item {
            Layout.fillHeight: true
        }

    }

}
