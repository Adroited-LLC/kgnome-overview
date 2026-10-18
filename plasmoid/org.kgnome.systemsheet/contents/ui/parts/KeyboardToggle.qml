// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Keyboard backlight (GNOME: status/backlight.js KeyboardBrightnessToggle),
// shown only when PowerDevil finds a keyboard backlight. The pill switches it
// off / back on, the arrow opens a brightness slider.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.brightnesscontrolplugin as BC

QuickToggle {
    id: root
    BC.KeyboardBrightnessControl { id: kbd; isSilent: true }
    property int lastOn: 0
    available: kbd.isBrightnessAvailable && kbd.brightnessMax > 0
    checked: kbd.brightness > 0
    iconName: "input-keyboard-brightness-symbolic"
    title: i18n("Keyboard")
    onToggled: {
        if (kbd.brightness > 0) { lastOn = kbd.brightness; kbd.brightness = 0; }
        else kbd.brightness = lastOn > 0 ? lastOn : kbd.brightnessMax;
    }
    menu: Component {
        QuickSlider {
            u: root.u
            pal: root.pal
            iconName: "input-keyboard-brightness-symbolic"
            toolTip: i18n("Keyboard brightness")
            value: kbd.brightnessMax > 0 ? kbd.brightness / kbd.brightnessMax : 0
            onMoved: v => kbd.brightness = Math.round(v * kbd.brightnessMax)
        }
    }
}
