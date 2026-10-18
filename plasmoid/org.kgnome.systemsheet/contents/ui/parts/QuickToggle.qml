// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .quick-toggle: a pill with icon, title and optional subtitle; the
// checked state uses the accent colour.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Rectangle {
    id: toggle
    property string iconName
    property string title
    property string subtitle
    property bool checked: false
    property bool available: true
    property real u: Kirigami.Units.gridUnit / 18
    signal toggled()

    implicitWidth: G.toggleWidth * u
    implicitHeight: G.toggleHeight * u
    radius: height / 2
    color: checked ? (mouse.containsMouse ? Qt.lighter(Kirigami.Theme.highlightColor, 1.1) : Kirigami.Theme.highlightColor)
                   : mouse.pressed ? G.buttonActive : mouse.containsMouse ? G.buttonHover : G.buttonBg
    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.checked: checked
    activeFocusOnTab: true
    Keys.onReturnPressed: toggled()
    Keys.onSpacePressed: toggled()
    border.width: activeFocus ? 2 : 0
    border.color: Qt.lighter(Kirigami.Theme.highlightColor, 1.3)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: G.basePadding * 2.5 * toggle.u
        anchors.rightMargin: G.basePadding * 2 * toggle.u
        spacing: G.basePadding * 1.5 * toggle.u
        Kirigami.Icon {
            Layout.preferredWidth: G.iconSize * toggle.u
            Layout.preferredHeight: G.iconSize * toggle.u
            source: toggle.iconName
            color: G.fg
            isMask: true
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: toggle.title
                color: G.fg
                font.weight: Font.Bold
                font.pixelSize: 14.67 * toggle.u * 0.95
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: toggle.subtitle !== ""
                text: toggle.subtitle
                color: G.fg
                opacity: 0.85
                font.pixelSize: 14.67 * toggle.u * 0.8
                elide: Text.ElideRight
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: toggle.toggled()
    }
}
