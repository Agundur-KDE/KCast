/*
 * SPDX-FileCopyrightText: 2026 Agundur <info@agundur.de>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 *
 * Collapsible playlist section: search (plain substring, falls back
 * gracefully if the pattern isn't valid regex), loop mode (off/all/one),
 * shuffle, click-to-jump. Visual polish (thumbnails, ambient colors) is a
 * separate follow-up — this is the interaction/structure proposal.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    id: root

    // entries: [{url, title, duration}]
    property var entries: []
    property int currentIndex: -1
    property string loopMode: "off" // "off" | "all" | "one"
    property bool shuffle: false
    property bool expanded: entries.length > 0

    signal entryActivated(int index)

    readonly property var filteredIndices: {
        if (searchField.text.length === 0)
            return entries.map((_, i) => i);

        var pattern = searchField.text;
        var re = null;
        try {
            re = new RegExp(pattern, "i");
        } catch (e) {
            re = null; // invalid regex: fall back to plain substring below
        }

        var out = [];
        for (var i = 0; i < entries.length; i++) {
            var title = entries[i].title || "";
            var matches = re ? re.test(title) : title.toLowerCase().includes(pattern.toLowerCase());
            if (matches)
                out.push(i);
        }
        return out;
    }

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents.ToolButton {
            icon.name: root.expanded ? "arrow-up" : "arrow-down"
            display: QQC.AbstractButton.IconOnly
            enabled: root.entries.length > 0
            onClicked: root.expanded = !root.expanded
        }

        PlasmaComponents.Label {
            text: i18n("Playlist (%1)", root.entries.length)
            Layout.fillWidth: true
        }

        PlasmaComponents.ToolButton {
            icon.name: "media-playlist-shuffle"
            checkable: true
            checked: root.shuffle
            QQC.ToolTip.text: i18n("Shuffle")
            QQC.ToolTip.visible: hovered
            onToggled: root.shuffle = checked
        }

        PlasmaComponents.ToolButton {
            icon.name: root.loopMode === "one" ? "media-playlist-repeat-one" : "media-playlist-repeat"
            checkable: true
            checked: root.loopMode !== "off"
            QQC.ToolTip.text: root.loopMode === "off" ? i18n("Repeat: off")
                        : root.loopMode === "all" ? i18n("Repeat: all")
                        : i18n("Repeat: one")
            QQC.ToolTip.visible: hovered
            // cycles off -> all -> one -> off, one click at a time
            onClicked: root.loopMode = root.loopMode === "off" ? "all"
                     : root.loopMode === "all" ? "one" : "off"
        }
    }

    PlasmaComponents.TextField {
        id: searchField

        Layout.fillWidth: true
        visible: root.expanded
        placeholderText: i18n("Search (supports regex)…")
        clearButtonShown: true
    }

    PlasmaComponents.ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(root.entries.length, 6) * Kirigami.Units.gridUnit * 1.6
        visible: root.expanded

        ListView {
            id: listView

            model: root.filteredIndices
            clip: true

            delegate: PlasmaComponents.ItemDelegate {
                id: delegateRoot

                required property int modelData
                width: listView.width
                highlighted: delegateRoot.modelData === root.currentIndex

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: delegateRoot.modelData === root.currentIndex ? "media-playback-start" : "audio-x-generic"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    PlasmaComponents.Label {
                        text: root.entries[delegateRoot.modelData].title
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: root.entries[delegateRoot.modelData].duration || ""
                        opacity: 0.7
                    }
                }

                onClicked: root.entryActivated(delegateRoot.modelData)
            }
        }
    }
}
