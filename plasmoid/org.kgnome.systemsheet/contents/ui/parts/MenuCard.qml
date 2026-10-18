// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME .quick-toggle-menu: a card (radius 24, padding 12) with a header
// (24px icon in a circle, accent when the toggle is on; title_3 title;
// caption subtitle) and the toggle's own content below. Slides open.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Gnome.js" as G

Rectangle {
    id: card
    property bool open: false
    property string iconName
    property string title
    property string subtitle
    property bool active: false
    property Component content
    property real u: 1
    property var pal: G.palette(true)

    Layout.fillWidth: true
    Layout.preferredHeight: open ? body.implicitHeight + 2 * G.basePadding * 2 * u : 0
    visible: Layout.preferredHeight > 0
    clip: true
    radius: G.menuRadius * u
    color: pal.card
    Behavior on Layout.preferredHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: body
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: G.basePadding * 2 * card.u
        spacing: 0
        RowLayout {
            Layout.bottomMargin: G.basePadding * 2 * card.u
            spacing: G.basePadding * 2 * card.u
            Rectangle {
                Layout.preferredWidth: (G.iconSize * 1.5 + 2 * 1.5 * G.basePadding) * card.u
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: card.active ? card.pal.accent : card.pal.headerIcon
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: G.iconSize * 1.5 * card.u; height: width
                    source: card.iconName
                    color: card.active ? card.pal.accentFg : card.pal.fg
                    isMask: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: G.basePadding * 0.5 * card.u
                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: card.pal.fg
                    font.weight: Font.Bold
                    font.pixelSize: 15 * 4 / 3 * card.u
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.subtitle
                    color: card.pal.fg
                    font.weight: Font.Bold
                    font.pixelSize: G.captionPt * 4 / 3 * card.u
                    elide: Text.ElideRight
                }
            }
        }
        Loader {
            Layout.fillWidth: true
            active: card.open || card.visible
            sourceComponent: card.content
        }
    }
}
