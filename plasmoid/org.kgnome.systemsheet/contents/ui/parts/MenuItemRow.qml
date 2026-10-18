// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .popup-menu-item inside a .quick-toggle-menu.
import QtQuick
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Rectangle {
    id: item
    property string text
    property real u: 1
    signal triggered()

    implicitHeight: 36 * u
    radius: 10 * u
    color: mouse.pressed ? G.buttonActive : (mouse.containsMouse || activeFocus) ? G.buttonHover : "transparent"
    Accessible.role: Accessible.MenuItem
    Accessible.name: text
    activeFocusOnTab: true
    Keys.onReturnPressed: triggered()
    Keys.onSpacePressed: triggered()

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12 * item.u
        text: item.text
        color: G.fg
        font.pixelSize: 14.67 * item.u * 0.95
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: item.triggered()
    }
}
