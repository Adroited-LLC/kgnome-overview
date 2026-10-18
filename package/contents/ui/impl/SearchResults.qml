// SPDX-License-Identifier: GPL-2.0-or-later
// Search results: an "Applications" row first (our own model, ranked like
// GNOME's app search), then everything else from KRunner via Milou.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

Item {
    id: results

    required property Item screenView
    property bool active: false

    readonly property QtObject effect: screenView.effect
    readonly property QtObject backend: effect.backend
    readonly property real s: screenView.s
    readonly property int appCount: backend && active ? (backend.revision, backend.count("search")) : 0
    readonly property int panelWidth: Math.min(width - 2 * screenView.spacing, Math.round(900 * s))

    function activateFirst() {
        if (appCount > 0) {
            effect.launch("search", 0);
        } else if (milouLoader.item) {
            milouLoader.item.runCurrentIndex(null);
        }
    }
    function focusResults() {
        if (milouLoader.item && milouLoader.item.count > 0) {
            milouLoader.item.forceActiveFocus();
        }
    }

    onActiveChanged: if (!active) screenView.focusSearch()

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        width: results.panelWidth
        spacing: Math.round(12 * results.s)

        // Applications
        Rectangle {
            width: parent.width
            height: appsRow.height + 2 * Math.round(12 * results.s)
            visible: results.appCount > 0
            radius: Math.round(18 * results.s)
            color: Qt.rgba(0.17, 0.17, 0.17, 0.85)

            Flow {
                id: appsRow
                anchors.centerIn: parent
                width: parent.width - 2 * Math.round(12 * results.s)
                spacing: Math.round(4 * results.s)
                Repeater {
                    model: Math.min(results.appCount, 12)
                    delegate: AppIcon {
                        required property int index
                        readonly property int tileSize: Math.round(64 * results.s) + 2 * Math.round(12 * results.s)
                        width: Math.round(tileSize * 1.25)
                        height: implicitHeight
                        s: results.s
                        iconSize: Math.round(64 * results.s)
                        selected: index === 0
                        app: results.backend ? (results.backend.revision, results.backend.appAt("search", index)) : null
                        onActivated: results.effect.launch("search", index)
                    }
                }
            }
        }

        // Everything else (KRunner)
        Rectangle {
            width: parent.width
            height: Math.max(0, Math.min(results.height - y - Math.round(12 * results.s),
                                         (milouLoader.item ? milouLoader.item.contentHeight : 0) + 2 * Math.round(10 * results.s)))
            visible: milouLoader.item && milouLoader.item.count > 0
            radius: Math.round(18 * results.s)
            color: Qt.rgba(0.17, 0.17, 0.17, 0.85)
            clip: true

            Loader {
                id: milouLoader
                anchors.fill: parent
                anchors.margins: Math.round(10 * results.s)
                active: results.active
                sourceComponent: Milou.ResultsView {
                    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                    Kirigami.Theme.inherit: false
                    queryString: results.effect.searchText
                    limit: 15
                    onActivated: results.effect.hide()
                    Keys.onEscapePressed: event => {
                        results.effect.searchText = "";
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
