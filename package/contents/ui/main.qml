import QtQuick 6.5
import QtQuick.Controls 6.7
import QtQuick.Layouts
import de.agundur.kcast 1.0
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

        // Own instance: the compact representation is a separate QML tree
        // from FullRepresentation.qml (which has its own "kcast" id) and
        // can't reach into it. Both ultimately just shell out to catt using
        // the same persisted default device, so two instances don't cause
        // any state-sync issue for a volumeUp/volumeDown-only use here.
        KCastBridge {
            id: kcast
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                const d = ev.angleDelta.y > 0 ? 1 : -1;
                if (d > 0)
                    kcast.volumeUp(1);

                if (d < 0)
                    kcast.volumeDown(1);

                ev.accepted = true;
            }
        }

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
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                expanded = !expanded;
            }
        }

        Kirigami.Icon {
            source: Plasmoid.icon
            anchors.fill: parent
        }

    }

}