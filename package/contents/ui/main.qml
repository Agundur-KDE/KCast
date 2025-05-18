import Qt.labs.platform 1.1
import QtQml.Models 2.15
import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0

PlasmoidItem {
    property string runMode: ""

    function listDevices() {
        runMode = "list";
        caster.program = "python3";
        caster.arguments = [plasmoid.location + "/../scripts/cast.py", "--list"];
        caster.start();
    }

    function runCast(action) {
        runMode = "action";
        var dev = deviceSelector.currentText;
        var url = mediaUrl.text;
        caster.program = "python3";
        caster.arguments = [plasmoid.location + "/../scripts/cast.py", "--device", dev, "--" + action, "--url", url];
        caster.start();
    }

    width: 300
    height: 200
    Component.onCompleted: listDevices()

    Column {
        spacing: 8
        anchors.centerIn: parent

        // 1) Device-Liste (ComboBox)
        ComboBox {
            id: deviceSelector

            model: devicesModel
            textRole: "name"
        }

        // 2) URL/File-Eingabe
        TextField {
            id: mediaUrl

            placeholderText: "http://… oder /pfad/zu/datei.mp4"
            width: parent.width
        }

        // 3) Buttons
        Row {
            spacing: 8

            Button {
                text: "Play"
                onClicked: runCast("play")
            }

            Button {
                text: "Pause"
                onClicked: runCast("pause")
            }

            Button {
                text: "Stop"
                onClicked: runCast("stop")
            }

        }

    }

    // Model, das Python-Script aufruft und Liste liefert
    ListModel {
        id: devicesModel
    }

}
