// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's go-next-symbolic chevron (icon themes such as Breeze draw an arrow
// for that name), drawn as two rounded strokes.
import QtQuick

Item {
    id: chevron
    property color color: "black"
    property real u: 1
    implicitWidth: 16 * u
    implicitHeight: 16 * u
    readonly property real stroke: 2 * u
    readonly property real arm: 6 * u
    Repeater {
        model: [45, -45]
        Rectangle {
            required property real modelData
            width: chevron.arm + chevron.stroke
            height: chevron.stroke
            radius: height / 2
            color: chevron.color
            antialiasing: true
            x: chevron.width / 2 - width / 2 + 0.5 * chevron.u
            y: chevron.height / 2 - height / 2 + (modelData > 0 ? -1 : 1) * chevron.arm * 0.3535
            transformOrigin: Item.Right
            rotation: modelData
        }
    }
}
