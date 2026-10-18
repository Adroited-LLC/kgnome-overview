// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .quick-settings .icon-button: circular, padding $base_padding*1.75
// around a 16px symbolic icon; checked uses the accent (default button).
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Rectangle {
    id: button
    property string iconName
    property string toolTip
    property bool checked: false
    property bool flat: false
    property real u: 1
    property var pal: G.palette(true)
    signal clicked()

    implicitWidth: (G.iconSize + 2 * G.iconButtonPadding) * u
    implicitHeight: implicitWidth
    radius: height / 2
    color: checked ? (mouse.containsMouse ? Qt.lighter(pal.accent, 1.08) : pal.accent)
         : mouse.pressed ? pal.buttonActive : mouse.containsMouse ? pal.buttonHover
         : flat ? "transparent" : pal.button
    Accessible.role: Accessible.Button
    Accessible.name: toolTip
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    border.width: activeFocus ? 2 : 0
    border.color: G.rgba(pal.accent, 0.6)

    Kirigami.Icon {
        anchors.centerIn: parent
        width: G.iconSize * button.u
        height: width
        visible: button.iconName !== ""
        source: button.iconName
        color: button.checked ? button.pal.accentFg : button.pal.fg
        isMask: true
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }
    QQC2.ToolTip.text: toolTip
    QQC2.ToolTip.visible: toolTip !== "" && mouse.containsMouse
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
}
