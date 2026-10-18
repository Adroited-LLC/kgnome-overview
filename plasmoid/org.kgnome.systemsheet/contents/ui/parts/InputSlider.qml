// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Microphone volume (GNOME: InputStreamSlider in status/volume.js). Like
// GNOME it only shows while an application is recording (a non-virtual
// source output exists, e.g. not plasma-pa's own level monitors).
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.volume as PA
import "Gnome.js" as G

QuickSlider {
    id: slider
    readonly property var source: PA.PreferredDevice.source
    property int recording: 0
    PA.SourceOutputModel { id: outputs }
    Repeater {
        model: outputs
        delegate: Item {
            required property var model
            readonly property bool real: !model.VirtualStream
            Component.onCompleted: if (real) slider.recording++
            Component.onDestruction: if (real) slider.recording--
        }
    }
    available: !!source && recording > 0
    toolTip: source && source.muted ? i18n("Unmute") : i18n("Mute")
    iconName: source && !source.muted
              ? (source.volume / PA.PulseAudio.NormalVolume > 0.66 ? "microphone-sensitivity-high-symbolic"
                 : source.volume / PA.PulseAudio.NormalVolume > 0.33 ? "microphone-sensitivity-medium-symbolic"
                 : "microphone-sensitivity-low-symbolic")
              : "microphone-sensitivity-muted-symbolic"
    value: source ? Math.min(1, source.volume / PA.PulseAudio.NormalVolume) : 0
    onMoved: v => {
        if (!source) return;
        source.volume = Math.round(v * PA.PulseAudio.NormalVolume);
        source.muted = v <= 0;
    }
    onIconClicked: if (source) source.muted = !source.muted
}
