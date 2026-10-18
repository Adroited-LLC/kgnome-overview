// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .quick-toggle / .quick-toggle-has-menu: a pill (min-height 3 × icon,
// 12em wide) with icon, bold title and caption subtitle; checked uses the
// accent. With hasMenu the right end is a separate arrow button behind a 1px
// separator, like GNOME's Wi-Fi and Bluetooth toggles.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Item {
    id: toggle
    property string iconName
    property string title
    property string subtitle
    property bool checked: false
    property bool available: true
    property bool hasMenu: false
    property string menuToolTip
    property real u: Kirigami.Units.gridUnit / 18
    property var pal: G.palette(true)
    signal toggled()
    signal menuClicked()

    implicitWidth: G.toggleWidth * u
    implicitHeight: G.toggleHeight * u
    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.checked: checked
    activeFocusOnTab: true
    Keys.onReturnPressed: toggled()
    Keys.onSpacePressed: toggled()

    readonly property color baseColor: checked ? pal.accent : pal.button

    Rectangle {   // the whole pill; the main part and the arrow paint over it
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? (mainMouse.containsMouse ? Qt.lighter(toggle.pal.accent, 1.08) : toggle.pal.accent)
             : mainMouse.pressed ? toggle.pal.buttonActive : mainMouse.containsMouse ? toggle.pal.buttonHover : toggle.pal.button
        border.width: toggle.activeFocus ? 2 : 0
        border.color: G.rgba(toggle.pal.accent, 0.6)
        clip: true

        Rectangle {   // .quick-toggle-menu-button
            id: menuButton
            visible: toggle.hasMenu
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: (G.iconSize + 2 * G.menuButtonPadH) * toggle.u + parent.radius / 2
            color: toggle.checked
                   ? (menuMouse.containsMouse ? Qt.lighter(toggle.pal.menuButtonChecked, 1.06) : toggle.pal.menuButtonChecked)
                   : (menuMouse.containsMouse ? toggle.pal.buttonHover : toggle.pal.menuButton)
            radius: height / 2
            Rectangle {   // square off the left side
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: parent.radius
                color: parent.color
            }
            Rectangle {   // .quick-toggle-separator
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 1
                color: toggle.checked ? toggle.pal.separatorChecked : toggle.pal.separator
            }
            Chevron {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -pill.radius / 4
                u: toggle.u
                color: toggle.checked ? toggle.pal.accentFg : toggle.pal.fg
            }
            MouseArea {
                id: menuMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: toggle.menuClicked()
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: toggle.hasMenu ? undefined : parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: toggle.hasMenu ? menuButton.x : undefined
        anchors.leftMargin: G.basePadding * 2.5 * toggle.u
        anchors.rightMargin: (toggle.hasMenu ? G.basePadding * 1.5 : G.basePadding * 2) * toggle.u
        spacing: G.basePadding * 1.5 * toggle.u
        Kirigami.Icon {
            Layout.preferredWidth: G.iconSize * toggle.u
            Layout.preferredHeight: G.iconSize * toggle.u
            source: toggle.iconName
            color: toggle.checked ? toggle.pal.accentFg : toggle.pal.fg
            isMask: true
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: toggle.title
                color: toggle.checked ? toggle.pal.accentFg : toggle.pal.fg
                font.weight: Font.Bold
                font.pixelSize: G.titlePt * 4 / 3 * toggle.u
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: toggle.subtitle !== ""
                text: toggle.subtitle
                color: toggle.checked ? toggle.pal.accentFg : toggle.pal.fg
                font.pixelSize: G.captionPt * 4 / 3 * toggle.u
                elide: Text.ElideRight
            }
        }
    }
    MouseArea {
        id: mainMouse
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: toggle.hasMenu ? menuButton.x : parent.width
        hoverEnabled: true
        onClicked: toggle.toggled()
    }
}
