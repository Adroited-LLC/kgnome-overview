// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Connection list for the network toggles' menus (GNOME: network.js
// NMWirelessToggle / NMWiredToggle / NMVpnToggle menus), on plasma-nm's
// NetworkModel. Activation follows plasma-nm's ConnectionItem.qml: saved
// connections are activated, open networks added, and for protected new
// networks a password row appears inline.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kcmutils as KCMUtils
import "Gnome.js" as G

ColumnLayout {
    id: menu
    property var networkModel          // PlasmaNM.NetworkModel
    property var handler               // PlasmaNM.Handler
    property int type                  // PlasmaNM.Enums.Wireless / Wired / Vpn
    property string settingsText
    property string emptyText
    property real u: 1
    property var pal: G.palette(true)
    property string askPasswordFor: ""
    signal openSettings()
    spacing: 0

    PlasmaNM.AppletProxyModel {
        id: sorted
        sourceModel: menu.networkModel
    }
    property int shown: 0

    Repeater {
        model: sorted
        delegate: ColumnLayout {
            id: entry
            required property var model
            required property int index
            readonly property bool connected: model.ConnectionState === PlasmaNM.Enums.Activated
            readonly property bool busy: model.ConnectionState === PlasmaNM.Enums.Activating
            readonly property bool needsPassword: !model.Uuid && model.Type === PlasmaNM.Enums.Wireless
                && (model.SecurityType === PlasmaNM.Enums.StaticWep || model.SecurityType === PlasmaNM.Enums.WpaPsk
                    || model.SecurityType === PlasmaNM.Enums.Wpa2Psk || model.SecurityType === PlasmaNM.Enums.SAE)
            readonly property bool matches: model.Type === menu.type
            visible: matches
            onMatchesChanged: menu.shown += matches ? 1 : -1
            Component.onCompleted: if (matches) menu.shown++
            Component.onDestruction: if (matches) menu.shown--
            Layout.fillWidth: true
            spacing: 0

            MenuItemRow {
                Layout.fillWidth: true
                u: menu.u
                pal: menu.pal
                iconName: entry.model.ConnectionIcon || ""
                text: entry.model.ItemUniqueName + (entry.busy ? " …" : "")
                checked: entry.connected
                onTriggered: {
                    const m = entry.model;
                    if (m.ConnectionState !== PlasmaNM.Enums.Deactivated) {
                        menu.handler.deactivateConnection(m.ConnectionPath, m.DevicePath);
                    } else if (m.Uuid) {
                        menu.handler.activateConnection(m.ConnectionPath, m.DevicePath, m.SpecificPath);
                    } else if (entry.needsPassword) {
                        menu.askPasswordFor = menu.askPasswordFor === m.ItemUniqueName ? "" : m.ItemUniqueName;
                    } else {
                        menu.handler.addAndActivateConnection(m.DevicePath, m.SpecificPath);
                    }
                }
            }
            RowLayout {   // inline password entry for a new protected network
                visible: menu.askPasswordFor === entry.model.ItemUniqueName
                Layout.fillWidth: true
                Layout.leftMargin: 12 * menu.u
                Layout.rightMargin: 12 * menu.u
                Layout.bottomMargin: G.basePadding * menu.u
                spacing: G.basePadding * menu.u
                QQC2.TextField {
                    id: password
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: i18n("Password")
                    onVisibleChanged: if (visible) forceActiveFocus()
                    onAccepted: connectButton.clicked()
                }
                QQC2.Button {
                    id: connectButton
                    text: i18n("Connect")
                    enabled: password.text.length >= 8 || entry.model.SecurityType === PlasmaNM.Enums.StaticWep
                    onClicked: {
                        menu.handler.addAndActivateConnection(entry.model.DevicePath, entry.model.SpecificPath, password.text);
                        password.text = "";
                        menu.askPasswordFor = "";
                    }
                }
            }
        }
    }
    Text {
        visible: menu.shown <= 0 && menu.emptyText !== ""
        Layout.fillWidth: true
        Layout.margins: 12 * menu.u
        text: menu.emptyText
        color: menu.pal.fg
        opacity: 0.7
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: G.titlePt * 4 / 3 * menu.u * 0.95
    }
    MenuSeparator { u: menu.u; pal: menu.pal; visible: menu.settingsText !== "" }
    MenuItemRow {
        visible: menu.settingsText !== ""
        Layout.fillWidth: true
        u: menu.u
        pal: menu.pal
        text: menu.settingsText
        onTriggered: {
            menu.openSettings();
            KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement");
        }
    }
}
