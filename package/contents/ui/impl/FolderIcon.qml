// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME app folder tile (.app-folder: raised tile button): a 2x2 preview of
// the first apps (FOLDER_SUBICON_FRACTION 0.4 of the icon size) and the name.
import QtQuick
import "Layout.js" as L

Item {
    id: tile

    property var folder: null        // {name, apps: [app rows]}
    property QtObject backend: null
    property int iconSize: 96
    property real s: 1
    property int fontPx: Math.round(15 * s)
    property real radius: Math.round(24 * s)
    property bool hovered: false
    property bool pressed: false
    property bool showLabel: true
    readonly property int padding: Math.round(12 * s)
    readonly property int subSize: Math.floor(L.FOLDER_SUBICON_FRACTION * iconSize)

    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        // tile_button($system_base_color, raised) on the overview background
        color: Qt.rgba(1, 1, 1, tile.pressed ? 0.16 : tile.hovered ? 0.12 : 0.07)
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Grid {
        id: preview
        anchors.horizontalCenter: parent.horizontalCenter
        y: tile.padding + (tile.iconSize - height) / 2
        columns: 2
        spacing: Math.round((tile.iconSize - 2 * tile.subSize) / 3)
        Repeater {
            model: tile.folder ? Math.min(4, tile.folder.apps.length) : 0
            delegate: AsyncIcon {
                required property int index
                readonly property var app: tile.backend ? (tile.backend.revision, tile.backend.appAt("apps", tile.folder.apps[index])) : null
                size: tile.subSize
                iconPath: app ? app.iconPath : ""
                fallback: app ? app.icon : ""
            }
        }
    }

    Text {
        visible: tile.showLabel
        anchors.top: parent.top
        anchors.topMargin: tile.padding + tile.iconSize + Math.round(6 * tile.s)
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Math.round(4 * tile.s)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: L.SYSTEM_FG_COLOR
        font.pixelSize: tile.fontPx
        text: tile.folder ? tile.folder.name : ""
    }
}
