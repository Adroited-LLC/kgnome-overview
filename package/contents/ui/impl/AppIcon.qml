// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME-style app tile: icon with a label underneath, rounded hover highlight.
import QtQuick

Item {
    id: tile

    property var app: null          // {name, iconName, iconPath, icon, storageId}
    property int iconSize: 96
    property real s: 1
    property bool showLabel: true
    property bool selected: false
    property bool running: false
    property string tooltip: ""
    readonly property alias hovered: area.containsMouse
    readonly property int padding: Math.round(12 * s)
    readonly property int labelHeight: showLabel ? Math.round(label.font.pixelSize * 1.4) : 0

    signal activated(int button, int modifiers)

    implicitWidth: iconSize + 2 * padding
    implicitHeight: iconSize + 2 * padding + (showLabel ? Math.round(6 * s) + labelHeight : 0)

    Rectangle {
        anchors.fill: parent
        radius: Math.round(16 * tile.s)
        color: Qt.rgba(1, 1, 1, area.pressed ? 0.2 : (tile.selected || area.containsMouse) ? 0.12 : 0)
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    AsyncIcon {
        id: iconItem
        anchors.horizontalCenter: parent.horizontalCenter
        y: tile.padding
        size: tile.iconSize
        iconPath: tile.app ? tile.app.iconPath : ""
        fallback: tile.app ? tile.app.icon : ""
        scale: area.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
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
        color: "white"
        font.pixelSize: Math.round(13 * tile.s)
        text: tile.app ? tile.app.name : ""
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.4)
    }

    // running indicator (dash)
    Rectangle {
        visible: tile.running
        width: Math.round(5 * tile.s)
        height: width
        radius: width / 2
        color: "white"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(3 * tile.s)
    }

    // name tooltip for label-less tiles (dash)
    Rectangle {
        visible: !tile.showLabel && area.containsMouse && tile.app !== null
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Math.round(8 * tile.s)
        width: tipLabel.implicitWidth + Math.round(20 * tile.s)
        height: tipLabel.implicitHeight + Math.round(10 * tile.s)
        radius: height / 2
        color: Qt.rgba(0.12, 0.12, 0.12, 0.92)
        Text {
            id: tipLabel
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: Math.round(13 * tile.s)
            text: tile.tooltip.length > 0 ? tile.tooltip : (tile.app ? tile.app.name : "")
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => tile.activated(mouse.button, mouse.modifiers)
    }
}
