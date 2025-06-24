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
    id: root

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

    compactRepresentation: MouseArea {
        id: compact

        readonly property int preferredWidth: compact.inPanel ? Kirigami.Units.iconSizes.sizeForLabels : Kirigami.Units.iconSizes.huge
        readonly property int preferredHeight: compact.inPanel ? Kirigami.Units.iconSizes.sizeForLabels : Kirigami.Units.iconSizes.huge

        implicitWidth: preferredWidth
        implicitHeight: preferredHeight
        Layout.preferredWidth: preferredWidth
        Layout.preferredHeight: preferredHeight
        hoverEnabled: true

        MouseArea {
            // cursorShape: Qt.PointingHandCursor

            anchors.fill: parent
            onClicked: {
                expanded = !expanded;
            }
        }

        Image {
            source: Qt.resolvedUrl("../icons/kcast_icon_64x64.png")
            width: preferredWidth
            height: preferredHeight
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit
        }

    }

}