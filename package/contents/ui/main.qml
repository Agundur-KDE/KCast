import QtQuick 6.5
import QtQuick.Controls 6.7
import QtQuick.Layouts
import org.kde.activities as Activities
import org.kde.kirigami as Kirigami
import org.kde.plasma.activityswitcher as ActivitySwitcher
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property bool keepOpenDuringDrop: false

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

        DropArea {
            id: compactDrop

            z: 1
            anchors.fill: parent
            onEntered: (drag) => {
                if (drag.hasUrls) {
                    root.keepOpenDuringDrop = true;
                    expanded = !expanded;
                }
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
            source: Plasmoid.icon
            anchors.fill: parent
        }

    }

}