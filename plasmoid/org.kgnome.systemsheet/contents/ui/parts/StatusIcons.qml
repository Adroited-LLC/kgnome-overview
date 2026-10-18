// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's panel status area icons: network and volume (the power/battery
// icon is added by the caller).
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.volume as PA

QtObject {
    property PlasmaNM.NetworkStatus status: PlasmaNM.NetworkStatus {}
    property PlasmaNM.ConnectionIcon connection: PlasmaNM.ConnectionIcon { connectivity: status.connectivity }
    readonly property var sink: PA.PreferredDevice.sink
    readonly property string networkIcon: connection.connectionIcon ? connection.connectionIcon + "-symbolic" : ""
    readonly property string volumeIcon: sink
        ? PA.AudioIcon.forVolume(Math.round(sink.volume / PA.PulseAudio.NormalVolume * 100), sink.muted, "") + "-symbolic" : ""
}
