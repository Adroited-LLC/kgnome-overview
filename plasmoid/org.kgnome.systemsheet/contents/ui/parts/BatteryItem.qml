// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's PowerToggle (status/system.js): battery icon and percentage in the
// top row, only when the machine has a battery; opens the power settings.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.private.battery as Battery
import "Gnome.js" as G

Rectangle {
    id: item
    property real u: Kirigami.Units.gridUnit / 18
    readonly property bool available: battery.hasCumulative
    readonly property bool charging: battery.state === Battery.BatteryControlModel.Charging
    readonly property string iconName: "battery-" + String(Math.round(battery.percent / 10) * 10).padStart(3, "0")
                                        + (charging ? "-charging" : "") + "-symbolic"
    readonly property int percent: battery.percent
    property var pal: G.palette(true)
    signal activated()

    Battery.BatteryControlModel { id: battery }

    implicitHeight: (G.iconSize + 2 * G.iconButtonPadding) * u
    implicitWidth: label.implicitWidth + (G.iconSize + 4 * G.iconButtonPadding) * u
    radius: height / 2
    color: mouse.pressed ? pal.buttonActive : mouse.containsMouse ? pal.buttonHover : pal.button
    Accessible.role: Accessible.Button
    Accessible.name: i18n("Power settings, battery at %1%", percent)

    RowLayout {
        anchors.centerIn: parent
        spacing: G.basePadding * item.u
        Kirigami.Icon {
            Layout.preferredWidth: G.iconSize * item.u
            Layout.preferredHeight: G.iconSize * item.u
            source: item.iconName
            fallback: "battery-symbolic"
            color: item.pal.fg
            isMask: true
        }
        Text {
            id: label
            text: i18nc("battery percentage", "%1%", item.percent)
            color: item.pal.fg
            font.pixelSize: G.titlePt * 4 / 3 * item.u
            font.weight: Font.Bold
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            item.activated();
            KCMUtils.KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig");
        }
    }
}
