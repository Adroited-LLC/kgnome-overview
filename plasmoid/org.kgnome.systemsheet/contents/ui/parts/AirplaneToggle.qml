// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Airplane Mode (GNOME: status/rfkill.js), shown when there is a Wi-Fi or
// mobile broadband device, same calls as plasma-nm's toolbar.
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

QuickToggle {
    PlasmaNM.Handler { id: handler }
    PlasmaNM.AvailableDevices { id: devices }
    available: devices.wirelessDeviceAvailable || devices.modemDeviceAvailable
    checked: PlasmaNM.Configuration.airplaneModeEnabled
    iconName: "airplane-mode-symbolic"
    title: i18n("Airplane Mode")
    onToggled: {
        const enable = !checked;
        handler.enableAirplaneMode(enable);
        PlasmaNM.Configuration.airplaneModeEnabled = enable;
    }
}
