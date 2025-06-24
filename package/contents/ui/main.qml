import QtCore
import QtQml
import QtQuick 2.15
import QtQuick.Controls 6.5
import QtQuick.Controls.Fusion
import QtQuick.Layouts 1.1
import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid 2.0

PlasmoidItem {
    // if (Plasmoid.location === PlasmaCore.Types.Floating || Plasmoid.location === PlasmaCore.Types.Desktop)
    //     return cfg_viewMode === "Compact" ? compactRepresentation : fullRepresentation;
    // Liste der Geräte
    // Plugin-Instanz
    // Dein Logo
    // Image {
    //     source: Qt.resolvedUrl("../icons/kcast_icon_32x32.png")
    //     width: Kirigami.Units.iconSizes.sizeForLabels
    //     height: Kirigami.Units.iconSizes.sizeForLabels
    //     anchors.centerIn: parent
    //     fillMode: Image.PreserveAspectFit
    // }

    id: root

    implicitWidth: FullRepresentation.implicitWidth > 0 ? FullRepresentation.implicitWidth : 320
    implicitHeight: FullRepresentation.implicitHeight > 0 ? FullRepresentation.implicitHeight : 300
    Plasmoid.title: i18n("KCast")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: Plasmoid.title
    preferredRepresentation: {
        return compactRepresentation;
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
            // cursorShape: Qt.PointingHandCursor

            anchors.fill: parent
            // hoverEnabled: true
            onClicked: {
                console.log('before');
                expanded = !expanded;
                console.log('after');
            }
        }

    }

}