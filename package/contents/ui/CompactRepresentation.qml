import QtQuick 2.15
import QtQuick.Controls 6.5
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Item {
    id: compactView

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
