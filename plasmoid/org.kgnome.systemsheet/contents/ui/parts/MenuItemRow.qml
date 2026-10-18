// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .popup-menu-item inside a .quick-toggle-menu card.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Rectangle {
    id: item
    property string text
    property string iconName
    property bool checked: false     // shows a check mark (device lists)
    property real u: 1
    property var pal: G.palette(true)
    signal triggered()

    implicitHeight: 36 * u
    radius: G.basePadding * 1.5 * u
    color: mouse.pressed ? G.rgba(pal.fg, 0.16) : (mouse.containsMouse || activeFocus) ? pal.itemHover : "transparent"
    Accessible.role: Accessible.MenuItem
    Accessible.name: text
    activeFocusOnTab: true
    Keys.onReturnPressed: triggered()
    Keys.onSpacePressed: triggered()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12 * item.u
        anchors.rightMargin: 12 * item.u
        spacing: G.basePadding * 2 * item.u
        Kirigami.Icon {
            visible: item.iconName !== ""
            Layout.preferredWidth: G.iconSize * item.u
            Layout.preferredHeight: G.iconSize * item.u
            source: item.iconName
            color: item.pal.fg
            isMask: true
        }
        Text {
            Layout.fillWidth: true
            text: item.text
            color: item.pal.fg
            font.pixelSize: G.titlePt * 4 / 3 * item.u * 0.95
            elide: Text.ElideRight
        }
        Kirigami.Icon {
            visible: item.checked
            Layout.preferredWidth: G.iconSize * item.u
            Layout.preferredHeight: G.iconSize * item.u
            source: "object-select-symbolic"
            color: item.pal.fg
            isMask: true
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: item.triggered()
    }
}
