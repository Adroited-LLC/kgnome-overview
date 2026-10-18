// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Screen brightness (GNOME: status/brightness.js), one slider per display
// that PowerDevil can control (laptop backlight or DDC/CI monitors).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.brightnesscontrolplugin as BC
import "Gnome.js" as G

ColumnLayout {
    id: column
    property real u: Kirigami.Units.gridUnit / 18
    property var pal: G.palette(true)
    readonly property bool available: control.isBrightnessAvailable && repeater.count > 0
    spacing: 0

    BC.ScreenBrightnessControl {
        id: control
        isSilent: true
    }
    Repeater {
        id: repeater
        model: control.displays
        QuickSlider {
            required property string displayName
            required property string label
            required property int brightness
            required property int maxBrightness
            Layout.fillWidth: true
            u: column.u
            pal: column.pal
            iconName: "display-brightness-symbolic"
            toolTip: repeater.count > 1 ? label : i18n("Brightness")
            value: maxBrightness > 0 ? brightness / maxBrightness : 0
            onMoved: v => control.setBrightness(displayName, Math.max(1, Math.round(v * maxBrightness)))
        }
    }
}
