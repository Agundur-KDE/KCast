import QtQuick
import QtQuick.Controls 6.7
import QtQuick.Layouts
import org.kde.draganddrop 2.0 as DragDrop
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

        return fullRepresentation;
    }
    Plasmoid.title: i18n("KCast")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: Plasmoid.title

    // Darstellungen binden das zentrale Modell
    fullRepresentation: FullRepresentation {
        id: full
    }

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool inPanel: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge].includes(Plasmoid.location)
        readonly property int preferredWidth: inPanel ? Kirigami.Units.iconSizes.sizeForLabels : Kirigami.Units.iconSizes.huge
        readonly property int preferredHeight: inPanel ? Kirigami.Units.iconSizes.sizeForLabels : Kirigami.Units.iconSizes.huge

        implicitWidth: preferredWidth
        implicitHeight: preferredHeight
        Layout.preferredWidth: preferredWidth
        Layout.preferredHeight: preferredHeight
        hoverEnabled: true

        DropArea {
            id: compactDrop

            z: 1
            anchors.fill: parent
            onEntered: {
                console.log("🟢 Drag detected – öffne FullView");
                expanded = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            onClicked: {
                expanded = !expanded;
                cursorShape:
                Qt.PointingHandCursor;
            }
        }

        Kirigami.Icon {
            // source: "kcast-symbolic"
            source: Plasmoid.icon
            width: preferredWidth
            height: preferredHeight
            anchors.centerIn: parent
        }

    }

}