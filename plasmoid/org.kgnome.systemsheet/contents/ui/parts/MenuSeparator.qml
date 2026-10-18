// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import "Gnome.js" as G

Rectangle {
    property real u: 1
    property var pal: G.palette(true)
    Layout.fillWidth: true
    Layout.topMargin: G.basePadding * u
    Layout.bottomMargin: G.basePadding * u
    Layout.leftMargin: G.basePadding * 2 * u
    Layout.rightMargin: G.basePadding * 2 * u
    implicitHeight: 1
    color: pal.menuSeparator
}
