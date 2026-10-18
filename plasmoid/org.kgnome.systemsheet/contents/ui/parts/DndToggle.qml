// SPDX-License-Identifier: GPL-2.0-or-later
// Do Not Disturb (GNOME: status/doNotDisturb.js). Same settings writes as
// Plasma's Notifications applet: "until turned off" is one year ahead.
import QtQuick
import org.kde.notificationmanager as NotificationManager

QuickToggle {
    NotificationManager.Settings { id: settings }
    readonly property bool inhibited: {
        const until = settings.notificationsInhibitedUntil;
        return (!isNaN(until.getTime()) && Date.now() < until.getTime()) || settings.notificationsInhibitedByApplication;
    }
    available: true
    checked: inhibited
    iconName: checked ? "notifications-disabled-symbolic" : "notifications-symbolic"
    title: i18n("Do Not Disturb")
    onToggled: {
        if (inhibited) {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        } else {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            settings.notificationsInhibitedUntil = d;
        }
        settings.save();
    }
}
