// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Power Mode (GNOME: status/powerProfiles.js) on PowerDevil's power
// profiles (power-profiles-daemon or tuned-ppd). Shown when profiles are
// available; on when the profile isn't Balanced; clicking goes back to
// Balanced, or to the last other profile; the arrow lists all profiles.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.batterymonitor as BM

QuickToggle {
    id: root
    BM.PowerProfilesControl { id: profiles; isSilent: true }
    property string lastProfile: "power-saver"
    readonly property var names: ({
        "performance": i18nc("Power profile", "Performance"),
        "balanced": i18nc("Power profile", "Balanced"),
        "power-saver": i18nc("Power profile", "Power Saver")
    })
    readonly property var icons: ({
        "performance": "power-profile-performance-symbolic",
        "balanced": "power-profile-balanced-symbolic",
        "power-saver": "power-profile-power-saver-symbolic"
    })
    readonly property string active: profiles.activeProfile
    onActiveChanged: if (active && active !== "balanced") lastProfile = active

    available: profiles.isPowerProfileDaemonInstalled && profiles.profiles.length > 0
    checked: active !== "" && active !== "balanced"
    iconName: icons[active] || "battery-profile-performance-symbolic"
    title: i18nc("Quick settings button title", "Power Mode")
    subtitle: names[active] || active
    onToggled: profiles.setProfile(checked ? "balanced" : lastProfile)
    menu: Component {
        ColumnLayout {
            spacing: 0
            Repeater {
                model: ["performance", "balanced", "power-saver"].filter(p => profiles.profiles.indexOf(p) >= 0)
                MenuItemRow {
                    required property string modelData
                    Layout.fillWidth: true
                    u: root.u
                    pal: root.pal
                    iconName: root.icons[modelData]
                    text: root.names[modelData]
                    checked: root.active === modelData
                    onTriggered: profiles.setProfile(modelData)
                }
            }
        }
    }
}
