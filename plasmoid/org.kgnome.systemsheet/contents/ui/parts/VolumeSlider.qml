// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Output volume (GNOME: OutputStreamSlider in status/volume.js) on
// plasma-pa's preferred sink, like Plasma's volume applet. The icon mutes;
// with more than one output device an arrow opens GNOME's inline
// "Sound Output" menu to pick the default device.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.volume as PA
import "Gnome.js" as G

ColumnLayout {
    id: volume
    property real u: Kirigami.Units.gridUnit / 18
    property var pal: G.palette(true)
    property bool menuOpen: false
    readonly property var sink: PA.PreferredDevice.sink
    readonly property int percent: sink ? Math.round(sink.volume / PA.PulseAudio.NormalVolume * 100) : 0
    readonly property bool available: !!sink
    spacing: 0

    PA.SinkModel { id: sinks }

    QuickSlider {
        Layout.fillWidth: true
        u: volume.u
        pal: volume.pal
        toolTip: volume.sink && volume.sink.muted ? i18n("Unmute") : i18n("Mute")
        iconName: volume.sink ? PA.AudioIcon.forVolume(volume.percent, volume.sink.muted, "") + "-symbolic" : "audio-volume-muted-symbolic"
        value: volume.sink ? Math.min(1, volume.sink.volume / PA.PulseAudio.NormalVolume) : 0
        hasMenu: deviceRepeater.count > 1
        menuOpen: volume.menuOpen
        onMoved: v => {
            if (!volume.sink) return;
            volume.sink.volume = Math.round(v * PA.PulseAudio.NormalVolume);
            volume.sink.muted = v <= 0;
        }
        onIconClicked: if (volume.sink) volume.sink.muted = !volume.sink.muted
        onMenuClicked: volume.menuOpen = !volume.menuOpen
    }
    Rectangle {   // .quick-toggle-menu card
        Layout.fillWidth: true
        Layout.topMargin: volume.menuOpen ? G.menuMargin * volume.u : 0
        Layout.preferredHeight: volume.menuOpen ? devices.implicitHeight + 2 * G.basePadding * 2 * volume.u : 0
        visible: Layout.preferredHeight > 0
        clip: true
        radius: G.menuRadius * volume.u
        color: volume.pal.card
        Behavior on Layout.preferredHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        ColumnLayout {
            id: devices
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: G.basePadding * 2 * volume.u
            spacing: 0
            RowLayout {   // .header
                Layout.bottomMargin: G.basePadding * 2 * volume.u
                spacing: G.basePadding * 2 * volume.u
                Rectangle {
                    Layout.preferredWidth: (G.iconSize * 1.5 + 2 * 1.5 * G.basePadding) * volume.u
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: volume.pal.headerIcon
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: G.iconSize * 1.5 * volume.u; height: width
                        source: "audio-headphones-symbolic"
                        color: volume.pal.fg; isMask: true
                    }
                }
                Text {
                    text: i18n("Sound Output")
                    color: volume.pal.fg
                    font.weight: Font.Bold
                    font.pixelSize: 15 * 4 / 3 * volume.u
                }
            }
            Repeater {
                id: deviceRepeater
                model: sinks
                MenuItemRow {
                    required property var model
                    Layout.fillWidth: true
                    u: volume.u
                    pal: volume.pal
                    text: model.Description || model.Name || ""
                    checked: !!model.PulseObject && model.PulseObject.default
                    onTriggered: if (model.PulseObject) model.PulseObject.default = true
                }
            }
        }
    }
}
