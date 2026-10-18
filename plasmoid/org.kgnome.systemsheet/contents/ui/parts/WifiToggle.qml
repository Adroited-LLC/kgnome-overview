// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Wi-Fi (GNOME: status/network.js NMWirelessToggle) through plasma-nm:
// the pill switches Wi-Fi on/off, the arrow opens the network list.
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

QuickToggle {
    id: root
    signal openSettings()
    property int rev: 0
    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.Handler { id: handler }
    PlasmaNM.NetworkModel { id: networks }

    readonly property string activeSsid: {
        rev;
        for (let i = 0; i < networksList.count; i++) {
            const it = networksList.itemAt(i);
            if (it && it.on) return it.name;
        }
        return "";
    }
    Repeater {   // watch the model for the connected network's name
        id: networksList
        model: networks
        delegate: Item {
            required property var model
            readonly property bool on: model.Type === PlasmaNM.Enums.Wireless && model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property string name: model.ItemUniqueName
            onOnChanged: root.rev++
            Component.onCompleted: root.rev++
            Component.onDestruction: root.rev++
        }
    }

    available: enabled.wirelessHwEnabled
    checked: enabled.wirelessEnabled
    iconName: checked ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"
    title: i18n("Wi-Fi")
    subtitle: checked ? activeSsid : ""
    menuTitle: i18n("Wi-Fi")
    menuSubtitle: ""
    onToggled: handler.enableWireless(!checked)
    onMenuOpenChanged: if (menuOpen && checked) handler.requestScan()
    menu: Component {
        NetworkMenu {
            networkModel: networks
            handler: handler
            type: PlasmaNM.Enums.Wireless
            u: root.u
            pal: root.pal
            settingsText: i18n("All Networks")
            emptyText: root.checked ? i18n("No networks found") : i18n("Wi-Fi is off")
            onOpenSettings: root.openSettings()
        }
    }
}
