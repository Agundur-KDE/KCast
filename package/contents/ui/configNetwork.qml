/*
 * SPDX-FileCopyrightText: 2025 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 */

import QtCore
import QtQuick 2.15
import QtQuick.Controls 2.15 as QtControls
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts 1.15
import org.kde.kcmutils as KCM
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kquickcontrols 2.0 as KQC
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    property string cfg_DefaultDevice
    property var availableDevices: [cfg_DefaultDevice]
    property string selectedDevice: cfg_DefaultDevice

    Kirigami.FormLayout {
        QtControls.Button {
            Kirigami.FormData.label: i18n("Search") + " :"
            icon.name: "view-refresh"
            text: i18n("Devices")
            onClicked: scanSource.connectSource("catt scan -j")
        }

        QtControls.ComboBox {
            // Optional: auf "keine Auswahl" setzen

            id: deviceCombo

            Kirigami.FormData.label: i18n("Default") + " :"
            Layout.fillWidth: true
            model: availableDevices
            // Editierbar, damit ein Gerät auch manuell per Name oder IP
            // eingetragen werden kann, wenn `catt scan` es nicht findet
            // (z.B. bekannter catt-Discovery-Bug, siehe KCast#23) —
            // `catt -d` akzeptiert beides.
            editable: true
            Component.onCompleted: {
                const idx = availableDevices.indexOf(cfg_DefaultDevice);
                if (idx !== -1)
                    deviceCombo.currentIndex = idx;
                else
                    deviceCombo.currentIndex = -1;
                deviceCombo.editText = cfg_DefaultDevice;
            }
            // Wenn Auswahl geändert wird, speichere neuen Wert in kcfg_ → "Anwenden" wird aktiv
            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    cfg_DefaultDevice = availableDevices[currentIndex];

            }
            // Manuell eingetippter Name/IP, der nicht (mehr) in der
            // gescannten Liste steht — z.B. weil die Discovery leer blieb.
            onEditTextChanged: {
                if (currentIndex < 0)
                    cfg_DefaultDevice = editText;
            }
        }

    }

    Plasma5Support.DataSource {
        id: scanSource

        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            var list = [];
            try {
                list = Object.keys(JSON.parse(data["stdout"] || "{}"));
            } catch (e) {}
            if (list.length === 0)
                return;

            availableDevices = list;
            // Fallback wenn aktuelles Gerät nicht dabei ist
            if (!availableDevices.includes(selectedDevice)) {
                selectedDevice = availableDevices[0];
                cfg_DefaultDevice = selectedDevice;
            }
        }
    }

}
