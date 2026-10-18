// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's Dash: favourites plus a "Show Apps" button at the bottom, at most
// DASH_MAX_HEIGHT_RATIO of the screen height; icon size is the largest of the
// dash sizes (64 down to 16) for which all items fit.
// _dash.scss: .dash-background $system_overlay_bg_color, radius 28px
// ($modal_radius + 12), padding 12px top/bottom and 10px left/right,
// margin-bottom 12px; items margin 0 2px with 6px tile padding and 16px
// radius; separator 1px with 4px margins; running dot in the bottom padding.
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
    readonly property int itemMargin: Math.round(2 * s)
    readonly property int bgPadding: Math.round(12 * s)
    readonly property int bgPaddingH: Math.round(10 * s)
    readonly property int bottomMargin: Math.round(12 * s)
    readonly property int separatorWidth: favCount > 0 ? Math.round((1 + 2 * 4) * s) : 0
    readonly property int iconSize: {
        const n = favCount + 1;
        for (const base of L.DASH_ICON_SIZES) {
            const size = Math.round(base * effect.iconScale);
            const item = size + 2 * itemPadding;
            const w = n * (item + 2 * itemMargin) + separatorWidth + 2 * bgPaddingH;
            const h = item + 2 * bgPadding + bottomMargin;
            if (w <= maxWidth && h <= maxHeight) {
                return size;
            }
        }
        return 16;
    }
    readonly property int itemSize: iconSize + 2 * itemPadding

    function windowsFor(storageId) {
        return effect.windowsFor(storageId);
    }

    implicitWidth: background.width
    implicitHeight: itemSize + 2 * bgPadding + bottomMargin
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: background
        anchors.horizontalCenter: parent.horizontalCenter
        width: row.width + 2 * dash.bgPaddingH
        height: dash.itemSize + 2 * dash.bgPadding
        radius: Math.round(28 * dash.s)
        color: L.SYSTEM_OVERLAY_BG_COLOR

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 2 * dash.itemMargin
            leftPadding: dash.itemMargin
            rightPadding: dash.itemMargin

            Repeater {
                model: dash.favCount
                delegate: AppIcon {
                    required property int index
                    readonly property var wins: app ? (dash.effect.runningWindows, dash.windowsFor(app.storageId)) : []
                    width: dash.itemSize
                    height: dash.itemSize
                    s: dash.s
                    tilePadding: dash.itemPadding
                    radius: Math.round(16 * dash.s)
                    fontPx: dash.screenView.fontPx
                    dotBottomMargin: -Math.round(dash.bgPadding / 2 + 2.5 * dash.s)
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
                    height: dash.iconSize
                    color: Qt.rgba(1, 1, 1, 0.1)   // $system_borders_color
                }
            }

            // "Show Apps" toggle
            Item {
                width: dash.itemSize
                height: dash.itemSize
                readonly property bool checked: dash.effect.targetState === dash.effect.stateAppGrid
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 0
                    radius: Math.round(16 * dash.s)
                    color: Qt.rgba(1, 1, 1, showAppsArea.pressed ? 0.15 : parent.checked ? 0.12 : showAppsArea.containsMouse ? 0.1 : 0)
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(dash.iconSize * 0.6)
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
