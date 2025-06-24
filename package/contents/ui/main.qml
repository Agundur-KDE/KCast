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

    compactRepresentation: MouseArea {
        id: compact

        // Taken from DigitalClock to ensure uniform sizing when next to each other
        readonly property bool tooSmall: Plasmoid.formFactor === PlasmaCore.Types.Horizontal && Math.round(2 * (compactRoot.height / 5)) <= Kirigami.Theme.smallFont.pixelSize
        readonly property bool shouldHaveIcon: Plasmoid.formFactor === PlasmaCore.Types.Vertical || Plasmoid.icon !== ""
        readonly property bool shouldHaveLabel: Plasmoid.formFactor !== PlasmaCore.Types.Vertical && Plasmoid.configuration.menuLabel !== ""
        readonly property int iconSize: Kirigami.Units.iconSizes.large
        readonly property var sizing: {
            const displayedIcon = imageFallback.visible ? imageFallback : (buttonIcon.valid ? buttonIcon : buttonIconFallback);
            let impWidth = 0;
            if (shouldHaveIcon)
                impWidth += displayedIcon.width;

            if (shouldHaveLabel)
                impWidth += labelTextField.contentWidth + labelTextField.Layout.leftMargin + labelTextField.Layout.rightMargin;

            const impHeight = displayedIcon.height > 0 ? displayedIcon.height : iconSize;
            // at least square, but can be wider/taller
            if (kickoff.inPanel) {
                // horizontal

                if (kickoff.vertical)
                    return {
                    "preferredWidth": iconSize,
                    "preferredHeight": impHeight
                };
                else
                    return {
                    "preferredWidth": impWidth,
                    "preferredHeight": iconSize
                };
            } else {
                return {
                    "preferredWidth": impWidth,
                    "preferredHeight": Kirigami.Units.iconSizes.small
                };
            }
        }

        implicitWidth: iconSize
        implicitHeight: iconSize
        Layout.preferredWidth: sizing.preferredWidth
        Layout.preferredHeight: sizing.preferredHeight
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight
        hoverEnabled: true

        Image {
            source: Qt.resolvedUrl("../icons/kcast_icon_32x32.png")
            width: impWidth
            height: impHeight
            anchors.centerIn: parent
            fillMode: Image.PreserveAspectFit
        }

    }

}