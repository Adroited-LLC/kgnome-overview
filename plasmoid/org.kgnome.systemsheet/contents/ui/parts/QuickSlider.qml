// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .quick-slider: icon button + slider spanning both grid columns.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

RowLayout {
    id: row
    property string iconName
    property string toolTip
    property real value: 0          // 0..1
    property real u: Kirigami.Units.gridUnit / 18
    property bool available: true
    signal moved(real value)
    signal iconClicked()

    spacing: G.basePadding * u
    Accessible.role: Accessible.Slider
    Accessible.name: toolTip

    IconButton {
        u: row.u
        iconName: row.iconName
        toolTip: row.toolTip
        color: "transparent"
        implicitWidth: (G.iconSize + 2 * G.basePadding) * row.u
        onClicked: row.iconClicked()
    }
    Item {
        id: slider
        Layout.fillWidth: true
        implicitHeight: (G.iconSize + 2 * G.basePadding) * row.u
        readonly property real knob: 20 * row.u
        readonly property real track: width - knob
        activeFocusOnTab: true
        Keys.onLeftPressed: row.moved(Math.max(0, row.value - 0.05))
        Keys.onRightPressed: row.moved(Math.min(1, row.value + 0.05))

        Rectangle {   // trough
            x: slider.knob / 2; width: slider.track
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * row.u; radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.2)
        }
        Rectangle {   // fill
            x: slider.knob / 2; width: slider.track * row.value
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * row.u; radius: height / 2
            color: Kirigami.Theme.highlightColor
        }
        Rectangle {   // handle
            x: slider.track * row.value
            anchors.verticalCenter: parent.verticalCenter
            width: slider.knob; height: width; radius: width / 2
            color: "#ffffff"
            border.width: slider.activeFocus ? 2 : 0
            border.color: Kirigami.Theme.highlightColor
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            function update(mx) { row.moved(Math.max(0, Math.min(1, (mx - slider.knob / 2) / slider.track))); }
            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => { if (pressed) update(mouse.x); }
            onWheel: wheel => row.moved(Math.max(0, Math.min(1, row.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
}
