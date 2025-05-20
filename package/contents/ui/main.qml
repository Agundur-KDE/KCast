import QtQuick 2.15
import QtQuick.Layouts 1.1
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid 2.0

PlasmoidItem {
    id: root

    property string runMode: ""
    property bool isSearching: false

    // Funktionen
    function listDevices() {
        isSearching = true;
        // Python-Funktion zum Suchen von Geräten aufrufen
        nativeInterface.listDevices();
        // Nach 5 Sekunden den Status zurücksetzen, falls es zu lange dauert
        searchTimer.restart();
    }

    function runCast(action, url) {
        // Python-Funktion zum Ausführen von Aktionen aufrufen
        nativeInterface.runCast(action, url);
    }

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
    Layout.minimumHeight: Kirigami.Units.gridUnit * 5
    implicitHeight: 280
    implicitWidth: 340
    // Beim Laden automatisch nach Geräten suchen
    Component.onCompleted: {
        listDevices();
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

        // Suchstatus
        PlasmaComponents.Label {
            id: statusLabel

            text: isSearching ? "Suche nach Chromecast-Geräten..." : (deviceSelector.count > 0 ? "Bitte Gerät auswählen" : "Keine Geräte gefunden")
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignCenter
            opacity: 0.7
        }

        // 1) Device-Liste (ComboBox)
        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents.ComboBox {
                id: deviceSelector

                model: nativeInterface.deviceList
                textRole: "name"
                Layout.fillWidth: true
                onActivated: {
                    nativeInterface.setSelectedDeviceIndex(currentIndex);
                }
                Component.onCompleted: {
                    if (count > 0) {
                        currentIndex = 0;
                        nativeInterface.setSelectedDeviceIndex(0);
                    }
                }
            }

            PlasmaComponents.Button {
                id: refreshButton

                icon.name: "view-refresh"
                text: ""
                onClicked: listDevices()
            }

        }

        // 2) URL/File-Eingabe
        PlasmaComponents.TextField {
            id: mediaUrl

            placeholderText: "http://... oder /pfad/zu/datei.mp4"
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
                onClicked: runCast("play", mediaUrl.text)
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

    // Timer für den Suchvorgang
    Timer {
        id: searchTimer

        interval: 5000
        running: false
        onTriggered: {
            isSearching = false;
        }
    }

    // Verbindungen zu Python-Signalen
    Connections {
        function onDevicesChanged() {
            isSearching = false;
            if (deviceSelector.count > 0) {
                deviceSelector.currentIndex = 0;
                nativeInterface.setSelectedDeviceIndex(0);
            }
        }

        function onDeviceConnected(name) {
            statusLabel.text = "Verbunden mit " + name;
        }

        function onDeviceDisconnected() {
            statusLabel.text = "Verbindung getrennt";
        }

        function onPlaybackStatusChanged(status) {
            statusLabel.text = "Status: " + status;
        }

        target: nativeInterface
    }

}