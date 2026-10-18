// SPDX-License-Identifier: GPL-2.0-or-later
// Output volume (GNOME: OutputStreamSlider in status/volume.js). Uses
// plasma-pa's preferred sink, like Plasma's volume applet.
import QtQuick
import org.kde.plasma.private.volume as PA

QuickSlider {
    id: slider
    readonly property var sink: PA.PreferredDevice.sink
    readonly property int percent: sink ? Math.round(sink.volume / PA.PulseAudio.NormalVolume * 100) : 0
    available: !!sink
    toolTip: sink && sink.muted ? i18n("Unmute") : i18n("Mute")
    iconName: sink ? PA.AudioIcon.forVolume(percent, sink.muted, "") + "-symbolic" : "audio-volume-muted-symbolic"
    value: sink ? Math.min(1, sink.volume / PA.PulseAudio.NormalVolume) : 0
    onMoved: v => {
        if (!sink) return;
        sink.volume = Math.round(v * PA.PulseAudio.NormalVolume);
        sink.muted = v <= 0;
    }
    onIconClicked: if (sink) sink.muted = !sink.muted
}
