// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME-style app tile (_app-grid.scss .overview-tile): icon with the label
// underneath (6px spacing), 12px padding, rounded hover highlight.
// With interactive: false the tile has no MouseArea of its own; the parent
// (AppGrid) does hit testing and sets hovered/pressed, so drags can start on
// top of icons.
import QtQuick
import org.kde.kirigami as Kirigami
import "Layout.js" as L

Item {
    id: tile

    property var app: null          // {name, iconName, iconPath, icon, storageId}
    property int iconSize: 96
    property real s: 1
    property int fontPx: Math.round(15 * s)
    property bool showLabel: true
    property bool selected: false
    property bool focusRing: false     // GNOME :focus (keyboard focus) ring
    property bool running: false
    property string tooltip: ""
    property bool interactive: true
    property bool hoveredExternal: false
    property bool pressedExternal: false
    property real radius: Math.round(24 * s)
    property real dotBottomMargin: Math.round(1 * s)
    property int tilePadding: Math.round(12 * s)
    readonly property bool hovered: interactive ? area.containsMouse : hoveredExternal
    readonly property bool pressed: interactive ? area.pressed : pressedExternal
    readonly property int padding: tilePadding
    readonly property int labelHeight: showLabel ? Math.round(fontPx * 1.4) : 0

    // right-click emits menuRequested instead of activated (search results)
    property bool menuEnabled: false

    signal activated(int button, int modifiers)
    signal menuRequested()

    implicitWidth: iconSize + 2 * padding
    implicitHeight: iconSize + 2 * padding + (showLabel ? Math.round(6 * s) + labelHeight : 0)

    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: Qt.rgba(1, 1, 1, tile.pressed ? 0.15 : (tile.selected || tile.hovered) ? 0.1 : 0)
        border.width: tile.focusRing ? Math.round(2 * tile.s) : 0
        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.7)
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    AsyncIcon {
        id: iconItem
        anchors.horizontalCenter: parent.horizontalCenter
        y: tile.padding
        size: tile.iconSize
        iconPath: tile.app ? tile.app.iconPath : ""
        fallback: tile.app ? tile.app.icon : ""
    }

    Text {
        id: label
        visible: tile.showLabel
        anchors.top: iconItem.bottom
        anchors.topMargin: Math.round(6 * tile.s)
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Math.round(4 * tile.s)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: L.SYSTEM_FG_COLOR
        font.pixelSize: tile.fontPx
        text: tile.app ? tile.app.name : ""
    }

    // .app-grid-running-dot: 5px
    Rectangle {
        visible: tile.running
        width: Math.round(5 * tile.s)
        height: width
        radius: width / 2
        color: L.SYSTEM_FG_COLOR
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: tile.dotBottomMargin
    }

    // name tooltip for label-less tiles (dash): .dash-label
    Rectangle {
        visible: !tile.showLabel && tile.hovered && tile.app !== null
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Math.round(14 * tile.s)
        width: tipLabel.implicitWidth + Math.round(24 * tile.s)
        height: tipLabel.implicitHeight + Math.round(12 * tile.s)
        radius: height / 2
        color: L.SYSTEM_OVERLAY_BG_COLOR
        Text {
            id: tipLabel
            anchors.centerIn: parent
            color: L.SYSTEM_FG_COLOR
            font.pixelSize: tile.fontPx
            text: tile.tooltip.length > 0 ? tile.tooltip : (tile.app ? tile.app.name : "")
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: tile.interactive
        visible: tile.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | (tile.menuEnabled ? Qt.RightButton : Qt.NoButton)
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                tile.menuRequested();
            } else {
                tile.activated(mouse.button, mouse.modifiers);
            }
        }
    }
}
