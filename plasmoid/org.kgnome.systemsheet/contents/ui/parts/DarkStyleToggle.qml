// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Dark Style (GNOME: status/darkMode.js). Plasma's equivalent switches between
// the default light and dark Global Themes (DarkModeControl runs
// plasma-apply-lookandfeel), which also resets colours/icons of that theme.
import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin as BC

QuickToggle {
    available: true
    checked: BC.DarkModeControl.darkMode
    iconName: "contrast-symbolic"
    title: i18n("Dark Style")
    onToggled: BC.DarkModeControl.darkMode = !checked
}
