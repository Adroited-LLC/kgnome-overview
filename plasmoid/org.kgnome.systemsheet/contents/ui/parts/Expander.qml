// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Shared expand/collapse for the inline menus (toggle menu card, Power Off,
// Sound Output), like GNOME's QuickToggleMenu: one animated progress (0..1)
// drives the card's height, the gap above it and the content's opacity, so
// the rows below move continuously in both directions:
// - height = progress × fullHeight, nothing else animates on its own;
// - the gap above (topMargin) grows with progress, so the last frame of a
//   collapse equals the hidden state (no end-of-animation jump). Put it in
//   a layout without spacing of its own: Qt Quick Layouts ignore negative
//   margins, so a parent's spacing next to it can't be cancelled and would
//   appear/disappear in one step when the card is shown/hidden;
// - the card stays visible (and its content loaded) until progress is 0.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Rectangle {
    id: expander
    property bool open: false
    property real u: 1
    property var pal: G.palette(true)
    // natural height when open (content plus padding)
    property real fullHeight: 0
    // space above the card when open (GNOME .quick-toggle-menu margin-top)
    property real gap: G.menuMargin * u
    default property alias expanderData: inner.data

    property real progress: open ? 1 : 0
    Behavior on progress {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuad }   // GNOME: EASE_OUT_QUAD
    }
    readonly property bool shown: progress > 0

    Layout.fillWidth: true
    Layout.preferredHeight: progress * fullHeight
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight
    Layout.topMargin: progress * gap
    visible: shown
    clip: true
    radius: G.menuRadius * u
    color: pal.card

    Item {
        id: inner
        anchors.fill: parent
        opacity: expander.progress
    }
}
