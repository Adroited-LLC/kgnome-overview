// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's Dash: favourites plus a "Show Apps" button at the bottom, at most
// DASH_MAX_HEIGHT_RATIO of the screen height; icon size is the largest of the
// dash sizes for which all items fit.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import "Layout.js" as L

Item {
    id: dash

    required property Item screenView
    required property QtObject windowModel
    property real maxWidth: 1000
    property real maxHeight: 200

    readonly property QtObject effect: screenView.effect
    readonly property QtObject backend: effect.backend
    readonly property real s: screenView.s
    readonly property int favCount: backend ? (backend.revision, backend.count("favorites")) : 0
    readonly property int itemPadding: Math.round(6 * s)
    readonly property int bgPadding: Math.round(6 * s)
    readonly property int bottomMargin: Math.round(screenView.spacing / 2)
    readonly property int separatorWidth: favCount > 0 ? Math.round(13 * s) : 0
    readonly property int iconSize: {
        const n = favCount + 1;
        for (const base of L.DASH_ICON_SIZES) {
            const size = Math.round(base * effect.iconScale);
            const item = size + 2 * itemPadding;
            const w = n * item + separatorWidth + 2 * bgPadding;
            const h = item + 2 * bgPadding + bottomMargin;
            if (w <= maxWidth && h <= maxHeight) {
                return size;
            }
        }
        return 16;
    }
    readonly property int itemSize: iconSize + 2 * itemPadding

    // Running apps, matched by desktop file name (for the indicator dots).
    // Workspace.stackingOrder has no change signal, so rebuild on window events.
    property var runningWindows: ({})
    function rebuildRunning() {
        const map = {};
        const order = KWinComponents.Workspace.stackingOrder;
        for (let i = 0; i < order.length; ++i) {
            const w = order[i];
            if (!w || !w.normalWindow || w.skipTaskbar || !w.desktopFileName) {
                continue;
            }
            (map[w.desktopFileName] = map[w.desktopFileName] || []).push(w);
        }
        runningWindows = map;
    }
    Connections {
        target: KWinComponents.Workspace
        function onWindowAdded() { Qt.callLater(dash.rebuildRunning) }
        function onWindowRemoved() { Qt.callLater(dash.rebuildRunning) }
        function onWindowActivated() { Qt.callLater(dash.rebuildRunning) }
    }
    Component.onCompleted: rebuildRunning()

    function windowsFor(storageId) {
        if (!storageId) {
            return [];
        }
        const id = storageId.endsWith(".desktop") ? storageId.slice(0, -8) : storageId;
        return runningWindows[id] || [];
    }

    implicitWidth: background.width
    implicitHeight: itemSize + 2 * bgPadding + bottomMargin
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: background
        anchors.horizontalCenter: parent.horizontalCenter
        width: row.width + 2 * dash.bgPadding
        height: dash.itemSize + 2 * dash.bgPadding
        radius: Math.round(dash.itemSize * 0.3)
        color: Qt.rgba(0.2, 0.2, 0.2, 0.7)
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Row {
            id: row
            anchors.centerIn: parent

            Repeater {
                model: dash.favCount
                delegate: AppIcon {
                    required property int index
                    readonly property var wins: app ? dash.windowsFor(app.storageId) : []
                    width: dash.itemSize
                    height: dash.itemSize
                    s: dash.s
                    showLabel: false
                    iconSize: dash.iconSize
                    app: dash.backend ? (dash.backend.revision, dash.backend.appAt("favorites", index)) : null
                    running: wins.length > 0
                    onActivated: (button, modifiers) => {
                        // GNOME: click focuses a running app, middle/Ctrl-click opens a new window
                        if (wins.length > 0 && button === Qt.LeftButton && !(modifiers & Qt.ControlModifier)) {
                            dash.effect.activateWindow(wins[wins.length - 1]);
                        } else {
                            dash.effect.launch("favorites", index);
                        }
                    }
                }
            }

            Item {
                width: dash.separatorWidth
                height: dash.itemSize
                visible: dash.favCount > 0
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(1, Math.round(1 * dash.s))
                    height: Math.round(dash.itemSize * 0.6)
                    color: Qt.rgba(1, 1, 1, 0.25)
                }
            }

            // "Show Apps" toggle
            Item {
                width: dash.itemSize
                height: dash.itemSize
                readonly property bool checked: dash.effect.targetState === dash.effect.stateAppGrid
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(2 * dash.s)
                    radius: Math.round(14 * dash.s)
                    color: Qt.rgba(1, 1, 1, showAppsArea.pressed ? 0.25 : parent.checked ? 0.18 : showAppsArea.containsMouse ? 0.12 : 0)
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(dash.iconSize * 0.75)
                    height: width
                    source: "view-app-grid-symbolic"
                    fallback: "view-grid-symbolic"
                    color: "white"
                    isMask: true
                }
                MouseArea {
                    id: showAppsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: dash.effect.setState(parent.checked ? dash.effect.stateWindowPicker : dash.effect.stateAppGrid)
                }
            }
        }
    }
}
