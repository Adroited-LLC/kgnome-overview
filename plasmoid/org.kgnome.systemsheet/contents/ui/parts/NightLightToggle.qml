// SPDX-License-Identifier: GPL-2.0-or-later
// Night Light (GNOME: status/nightLight.js). When Night Light is configured
// the toggle suspends/resumes it the way Plasma's Brightness and Color applet
// does (NightLightInhibitor); when it is off in System Settings, the toggle
// opens that page.
import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.private.brightnesscontrolplugin as BC

QuickToggle {
    DBus.Properties {
        id: nl
        busType: DBus.BusType.Session
        service: "org.kde.KWin.NightLight"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"
    }
    readonly property bool nlAvailable: Boolean(nl.properties.available)
    readonly property bool nlEnabled: Boolean(nl.properties.enabled)
    readonly property bool inhibited: Boolean(nl.properties.inhibited)
    readonly property bool togglable: !inhibited || BC.NightLightInhibitor.inhibited

    signal openSettings()
    available: nlAvailable
    checked: nlEnabled && !inhibited
    iconName: "night-light-symbolic"
    title: i18n("Night Light")
    subtitle: !nlEnabled ? i18n("Set up in Settings") : !togglable ? i18n("Paused by another app") : ""
    onToggled: {
        if (!nlEnabled) {
            // Night Light is switched off in System Settings: open that page
            // instead of changing anything here
            openSettings();
            KCMUtils.KCMLauncher.openSystemSettings("kcm_nightlight");
        } else if (togglable) {
            BC.NightLightInhibitor.toggleInhibition();
        }
    }
}
