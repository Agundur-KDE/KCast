import QtQuick
import QtQuick.Controls 6.7
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    preferredRepresentation: {
        const edge = Plasmoid.location;
        if (edge === PlasmaCore.Types.TopEdge || edge === PlasmaCore.Types.BottomEdge || edge === PlasmaCore.Types.LeftEdge || edge === PlasmaCore.Types.RightEdge)
            return compactRepresentation;

        return compactRepresentation;
    }
    Plasmoid.title: i18n("KCast")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: Plasmoid.title

    // Darstellungen binden das zentrale Modell
    fullRepresentation: FullRepresentation {
        id: full

        implicitWidth: FullRepresentation.implicitWidth > 0 ? FullRepresentation.implicitWidth : 320
        implicitHeight: FullRepresentation.implicitHeight > 0 ? FullRepresentation.implicitHeight : 300
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