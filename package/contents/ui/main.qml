import QtCore
import QtQml
import QtQuick 2.15
import QtQuick.Controls 6.5
import QtQuick.Controls.Fusion
import QtQuick.Layouts 1.1
import de.agundur.kcast 1.0
import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid 2.0

PlasmoidItem {
    // if (Plasmoid.location === PlasmaCore.Types.Floating || Plasmoid.location === PlasmaCore.Types.Desktop)
    //     return cfg_viewMode === "Compact" ? compactRepresentation : fullRepresentation;

    id: root

    // Liste der Geräte
    property var devices: []
    property int selectedIndex: -1
    property bool canPlay: false
    property bool isPlaying: false
    property bool isPaused: false

    function refreshDevices() {
        console.log("refreashing");
        devices = kcast.scanDevicesWithCatt();
        if (devices.length > 0)
            selectedIndex = 0;
        else
            selectedIndex = -1;
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

    implicitWidth: fullRepresentation.implicitWidth > 0 ? fullRepresentation.implicitWidth : 320
    implicitHeight: fullRepresentation.implicitHeight > 0 ? fullRepresentation.implicitHeight : 300
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
    Plasmoid.title: i18n("KCast")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: Plasmoid.title
    preferredRepresentation: {
        return compactRepresentation;
    }

    // Plugin-Instanz
    KCastBridge {
        id: kcast
    }

    // Darstellungen binden das zentrale Modell
    fullRepresentation: FullRepresentation {
        id: full
    }

    compactRepresentation: Item {
        id: compact

        Component.onCompleted: {
            console.log('start');
        }
        // Wichtig für Panel-Integration
        Layout.minimumWidth: Kirigami.Units.iconSizes.sizeForLabels
        Layout.minimumHeight: Kirigami.Units.iconSizes.sizeForLabels

        // Klickfläche (auch für Panels!)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                console.log('before');
                expanded = !expanded;
                console.log('after');
            }
            cursorShape: Qt.PointingHandCursor
        }

        // Dein Logo
        Image {
            source: Qt.resolvedUrl("../icons/kcast_icon_32x32.png")
            width: Kirigami.Units.iconSizes.sizeForLabels
            height: Kirigami.Units.iconSizes.sizeForLabels
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit
        }

    }

}