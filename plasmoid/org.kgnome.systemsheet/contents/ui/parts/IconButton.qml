// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .icon-button: round button with a symbolic icon.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Rectangle {
    id: button
    property string iconName
    property string toolTip
    property bool checked: false
    property real u: 1
    signal clicked()

    implicitWidth: (G.iconSize + 2 * G.iconButtonPadding) * u
    implicitHeight: implicitWidth
    radius: height / 2
    color: checked ? Kirigami.Theme.highlightColor
                   : mouse.pressed ? G.buttonActive : mouse.containsMouse ? G.buttonHover : G.buttonBg
    Accessible.role: Accessible.Button
    Accessible.name: toolTip
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    border.width: activeFocus ? 2 : 0
    border.color: Kirigami.Theme.highlightColor

    Kirigami.Icon {
        anchors.centerIn: parent
        width: G.iconSize * button.u
        height: width
        source: button.iconName
        color: G.fg
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
