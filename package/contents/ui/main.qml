import QtQuick 6.5
import QtQuick.Controls 6.7
import QtQuick.Layouts
import org.kde.activities as Activities
import org.kde.kirigami as Kirigami
import org.kde.plasma.activityswitcher as ActivitySwitcher
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
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

        // Own instance: the compact representation is a separate QML tree
        // from FullRepresentation.qml and can't reach into its volume
        // state — reads/writes the same persisted config directly instead
        // of sharing an object, so the two stay roughly in sync without
        // any coupling between them.
        property int volume: 50

        Component.onCompleted: {
            var device = Plasmoid.configuration.DefaultDevice;
            try {
                var vols = JSON.parse(Plasmoid.configuration.deviceVolumes || "{}");
                if (device && device in vols)
                    compact.volume = vols[device];
            } catch (e) {}
        }

        function adjustVolume(delta) {
            var device = Plasmoid.configuration.DefaultDevice;
            if (!device || device === "-") return;
            compact.volume = Math.max(0, Math.min(100, compact.volume + delta));
            volumeDebounce.restart();
        }

        Timer {
            id: volumeDebounce

            interval: 90
            repeat: false
            onTriggered: {
                var device = Plasmoid.configuration.DefaultDevice;
                if (!device || device === "-") return;
                cattSource.connectSource("catt -d '" + device.replace(/'/g, "'\\''") + "' volume " + compact.volume);
                try {
                    var vols = JSON.parse(Plasmoid.configuration.deviceVolumes || "{}");
                    vols[device] = compact.volume;
                    Plasmoid.configuration.deviceVolumes = JSON.stringify(vols);
                } catch (e) {}
            }
        }

        Plasma5Support.DataSource {
            id: cattSource

            engine: "executable"
            onNewData: (sourceName, data) => disconnectSource(sourceName)
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (ev) => {
                compact.adjustVolume(ev.angleDelta.y > 0 ? 1 : -1);
                ev.accepted = true;
            }
        }

        // Quotes a path/argument for safe use inside a shell command string.
        function shellQuote(s) {
            return "'" + s.replace(/'/g, "'\\''") + "'";
        }

        DropArea {
            id: compactDrop

            z: 1
            anchors.fill: parent
            onEntered: (drag) => {
                if (drag.hasUrls) {
                    drag.accept(Qt.CopyAction);
                    if (!expanded)
                        expanded = true;
                }
            }
            onPositionChanged: (drag) => {
                if (drag.hasUrls)
                    drag.accept(Qt.CopyAction);
            }
            // The drag typically ends up released here, not inside the
            // popup that onEntered just opened — the cursor doesn't
            // automatically move into the new popup.
            //
            // full (FullRepresentation's id) is NOT reachable from here:
            // `fullRepresentation` is a QQmlComponent-typed property, so
            // `FullRepresentation { id: full }` gets implicitly wrapped in
            // a Component and full's id is scoped inside it, invisible to
            // this file. Route through the same incoming-queue file the
            // Dolphin service menu already uses instead — FullRepresentation
            // polls it every 800ms once instantiated (which the expanded
            // change above just triggered).
            onDropped: (drop) => {
                var urls = drop.hasUrls ? drop.urls : (drop.hasText ? [drop.text] : []);
                if (urls.length === 0) return;
                var script = "mkdir -p \"$HOME/.cache/kcast\"";
                for (var i = 0; i < urls.length; i++)
                    script += " && echo " + compact.shellQuote(urls[i]) + " >> \"$HOME/.cache/kcast/incoming\"";
                dropQueueSource.connectSource("sh -c " + compact.shellQuote(script));
            }
        }

        Plasma5Support.DataSource {
            id: dropQueueSource

            engine: "executable"
            onNewData: (sourceName, data) => disconnectSource(sourceName)
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                expanded = !expanded;
            }
        }

        Image {
            // Plain Image, not Kirigami.Icon: Kirigami.Icon's automatic
            // isMask heuristic (guessMonochrome(), based on the
            // rasterized image's color saturation/brightness) misjudges
            // this multi-color logo as symbolic/monochrome and renders
            // it as a solid-color mask instead of its real colors. Image
            // has no such masking logic — same approach already used
            // successfully for this icon in FullRepresentation.qml.
            //
            // Plasmoid.icon can be metadata.json's package-relative
            // "/icons/foo.svg" notation (leading slash = relative to
            // contents/) — resolve it manually since Image doesn't
            // understand that notation either (verified against KDE bug
            // 509896: only some Plasma-native surfaces resolve it
            // themselves).
            source: Plasmoid.icon.startsWith("/") ? Qt.resolvedUrl(".." + Plasmoid.icon) : Plasmoid.icon
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

    }

}