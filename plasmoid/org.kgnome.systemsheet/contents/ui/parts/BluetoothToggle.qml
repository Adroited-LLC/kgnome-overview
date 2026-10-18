// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Bluetooth (GNOME: status/bluetooth.js) through BluezQt, the same calls
// Plasma's Bluetooth applet makes: the pill powers the adapters, the arrow
// lists paired devices (click to connect/disconnect).
import QtQuick
import QtQuick.Layouts
import org.kde.bluezqt as BluezQt
import org.kde.kcmutils as KCMUtils

QuickToggle {
    id: root
    signal openSettings()
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
    menu: Component {
        ColumnLayout {
            spacing: 0
            Repeater {
                model: root.manager.devices.filter(d => d.paired)
                MenuItemRow {
                    required property var modelData
                    Layout.fillWidth: true
                    u: root.u
                    pal: root.pal
                    enabled: root.checked
                    opacity: enabled ? 1 : 0.5
                    iconName: (modelData.icon || "bluetooth") + "-symbolic"
                    text: modelData.name
                    checked: modelData.connected
                    onTriggered: modelData.connected ? modelData.disconnectFromDevice() : modelData.connectToDevice()
                }
            }
            MenuSeparator { u: root.u; pal: root.pal }
            MenuItemRow {
                Layout.fillWidth: true
                u: root.u
                pal: root.pal
                text: i18n("Bluetooth Settings")
                onTriggered: { root.openSettings(); KCMUtils.KCMLauncher.openSystemSettings("kcm_bluetooth"); }
            }
        }
    }
}
