// SPDX-License-Identifier: GPL-2.0-or-later
// Bluetooth on/off (GNOME: status/bluetooth.js) through BluezQt, the same
// calls Plasma's Bluetooth applet makes.
import QtQuick
import org.kde.bluezqt as BluezQt

QuickToggle {
    readonly property var manager: BluezQt.Manager
    available: manager.bluetoothBlocked || manager.adapters.length > 0
    checked: manager.bluetoothOperational
    iconName: checked ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic"
    title: i18n("Bluetooth")
    subtitle: {
        const c = manager.connectedDevices;
        if (!checked || c.length === 0) return "";
        return c.length === 1 ? c[0].name : i18np("%1 connected", "%1 connected", c.length);
    }
    onToggled: {
        const enable = !checked;
        manager.bluetoothBlocked = !enable;
        manager.adapters.forEach(adapter => { adapter.powered = enable; });
    }
}
