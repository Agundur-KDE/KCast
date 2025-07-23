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
import de.agundur.kcast 1.0
import org.kde.kcmutils as KCM
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kquickcontrols 2.0 as KQC

KCM.SimpleKCM {
    property string cfg_DefaultDevice
    property var availableDevices: []
    property string selectedDevice: cfg_DefaultDevice

    Kirigami.FormLayout {
        QtControls.Button {
            Kirigami.FormData.label: i18n("Search") + " :"
            icon.name: "view-refresh"
            text: i18n("Devices")
            onClicked: {
                pressed:
                true;
                var result = kcast.scanDevicesWithCatt();
                pressed:
                false;
                if (result && result.length > 0) {
                    availableDevices = result;
                    // Fallback wenn aktuelles Gerät nicht dabei ist
                    if (!availableDevices.includes(selectedDevice)) {
                        selectedDevice = availableDevices[0];
                        cfg_DefaultDevice = selectedDevice;
                    }
                }
            }
        }

        QtControls.ComboBox {
            id: deviceCombo

            Kirigami.FormData.label: i18n("Default") + " :"
            Layout.fillWidth: true
            model: availableDevices
            onCurrentIndexChanged: {
                selectedDevice = deviceCombo.currentText;
                cfg_DefaultDevice = selectedDevice; // nur wenn alias korrekt
            }
            Component.onCompleted: {
                deviceCombo.currentIndex = availableDevices.indexOf(selectedDevice);
            }
        }

    }

    KCastBridge {
        id: kcast
    }

}
