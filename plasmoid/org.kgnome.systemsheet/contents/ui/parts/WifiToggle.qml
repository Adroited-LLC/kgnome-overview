// SPDX-License-Identifier: GPL-2.0-or-later
// Wi-Fi on/off (GNOME: status/network.js NMWirelessToggle) through plasma-nm.
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

QuickToggle {
    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.Handler { id: handler }
    PlasmaNM.NetworkStatus { id: status }

    available: enabled.wirelessHwEnabled
    checked: enabled.wirelessEnabled
    iconName: checked ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"
    title: i18n("Wi-Fi")
    // NetworkStatus.activeConnections is "Wired: Name\nWi-Fi: SSID…"; keep the Wi-Fi part
    subtitle: {
        if (!checked) return "";
        const lines = (status.activeConnections || "").split("\n").filter(l => /wi-?fi|wireless/i.test(l));
        return lines.length ? lines[0].replace(/^[^:]*:\s*/, "").replace(/<[^>]*>/g, "") : "";
    }
    onToggled: handler.enableWireless(!checked)
}
