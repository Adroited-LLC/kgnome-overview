// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Wired (GNOME: status/network.js NMWiredToggle), shown when there is an
// ethernet device. The pill connects/disconnects the first items profile,
// the arrow lists the items profiles.
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
            readonly property bool isWired: model.Type === PlasmaNM.Enums.Wired
            readonly property bool on: isWired && model.ConnectionState === PlasmaNM.Enums.Activated
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
    readonly property var firstItem: { root.rev; return find(it => it.isWired && it.connectionPath); }

    available: { root.rev; return find(it => it.isWired) !== null; }
    checked: activeItem !== null
    iconName: checked ? "network-items-symbolic" : "network-items-disconnected-symbolic"
    title: i18n("Wired")
    subtitle: checked ? activeItem.name : ""
    onToggled: {
        if (activeItem) handler.deactivateConnection(activeItem.connectionPath, activeItem.devicePath);
        else if (firstItem) handler.activateConnection(firstItem.connectionPath, firstItem.devicePath, firstItem.specificPath);
    }
    menu: Component {
        NetworkMenu {
            networkModel: networks
            handler: handler
            type: PlasmaNM.Enums.Wired
            u: root.u
            pal: root.pal
            settingsText: i18n("Wired Settings")
            onOpenSettings: root.openSettings()
        }
    }
}
