// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .quick-slider: flat icon button, slider (4px trough, 16px handle,
// accent fill) and, with hasMenu, a flat arrow button for a submenu (the
// output volume slider shows one when there is more than one device).
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
    property var pal: G.palette(true)
    property bool available: true
    property bool hasMenu: false
    property bool menuOpen: false
    signal moved(real value)
    signal iconClicked()
    signal menuClicked()

    spacing: G.basePadding * u
    Accessible.role: Accessible.Slider
    Accessible.name: toolTip

    IconButton {
        u: row.u
        pal: row.pal
        flat: true
        iconName: row.iconName
        toolTip: row.toolTip
        implicitWidth: (G.iconSize + 2 * G.basePadding) * row.u
        onClicked: row.iconClicked()
    }
    Item {
        id: slider
        Layout.fillWidth: true
        implicitHeight: (G.iconSize + 2 * G.basePadding) * row.u
        readonly property real knob: G.sliderHandle * row.u
        readonly property real track: width - knob
        activeFocusOnTab: true
        Keys.onLeftPressed: row.moved(Math.max(0, row.value - 0.05))
        Keys.onRightPressed: row.moved(Math.min(1, row.value + 0.05))

        Rectangle {   // trough
            x: slider.knob / 2; width: slider.track
            anchors.verticalCenter: parent.verticalCenter
            height: G.sliderTrough * row.u; radius: height / 2
            color: row.pal.trough
        }
        Rectangle {   // fill
            x: slider.knob / 2; width: slider.track * row.value
            anchors.verticalCenter: parent.verticalCenter
            height: G.sliderTrough * row.u; radius: height / 2
            color: row.pal.accent
        }
        Rectangle {   // handle
            x: slider.track * row.value
            anchors.verticalCenter: parent.verticalCenter
            width: slider.knob; height: width; radius: width / 2
            color: sliderMouse.containsMouse || sliderMouse.pressed ? (row.pal.dark ? "#ffffff" : Qt.lighter(row.pal.handle, 1.3)) : row.pal.handle
            border.width: slider.activeFocus ? 2 : 0
            border.color: G.rgba(row.pal.accent, 0.6)
        }
        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            function update(mx) { row.moved(Math.max(0, Math.min(1, (mx - slider.knob / 2) / slider.track))); }
            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => { if (pressed) update(mouse.x); }
            onWheel: wheel => row.moved(Math.max(0, Math.min(1, row.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    IconButton {
        visible: row.hasMenu
        u: row.u
        pal: row.pal
        flat: !row.menuOpen
        checked: row.menuOpen
        toolTip: i18n("Select output device")
        implicitWidth: (G.iconSize + 2 * G.basePadding) * row.u
        onClicked: row.menuClicked()
        Chevron {
            anchors.centerIn: parent
            u: row.u
            color: row.menuOpen ? row.pal.accentFg : row.pal.fg
            rotation: row.menuOpen ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 150 } }
        }
    }
}
