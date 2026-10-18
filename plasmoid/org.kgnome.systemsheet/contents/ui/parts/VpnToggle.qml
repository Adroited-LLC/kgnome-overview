// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// VPN (GNOME: status/network.js NMVpnToggle), shown when VPN connections
// are configured. The pill connects/disconnects the first VPN, the arrow
// lists them.
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

QuickToggle {
    id: root
    signal openSettings()
    property int rev: 0
    PlasmaNM.Handler { id: handler }
    PlasmaNM.NetworkModel { id: networks }

    Repeater {
        id: items
        model: networks
        delegate: Item {
            required property var model
            readonly property bool isVpn: model.Type === PlasmaNM.Enums.Vpn
            readonly property bool on: isVpn && model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property string name: model.ItemUniqueName
            readonly property string connectionPath: model.ConnectionPath
            readonly property string devicePath: model.DevicePath
            readonly property string specificPath: model.SpecificPath
            onOnChanged: root.rev++
            Component.onCompleted: root.rev++
            Component.onDestruction: root.rev++
        }
    }
    function find(pred) {
        for (let i = 0; i < items.count; i++) {
            const it = items.itemAt(i);
            if (it && pred(it)) return it;
        }
        return null;
    }
    readonly property var activeItem: { root.rev; return find(it => it.on); }
    readonly property var firstItem: { root.rev; return find(it => it.isVpn && it.connectionPath); }

    available: { root.rev; return find(it => it.isVpn) !== null; }
    checked: activeItem !== null
    iconName: checked ? "network-vpn-symbolic" : "network-vpn-disconnected-symbolic"
    title: i18n("VPN")
    subtitle: checked ? activeItem.name : ""
    onToggled: {
        if (activeItem) handler.deactivateConnection(activeItem.connectionPath, activeItem.devicePath);
        else if (firstItem) handler.activateConnection(firstItem.connectionPath, firstItem.devicePath, firstItem.specificPath);
    }
    menu: Component {
        NetworkMenu {
            networkModel: networks
            handler: handler
            type: PlasmaNM.Enums.Vpn
            u: root.u
            pal: root.pal
            settingsText: i18n("VPN Settings")
            onOpenSettings: root.openSettings()
        }
    }
}
