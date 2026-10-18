// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property string cfg_compactStyle
    property alias cfg_showUserHeader: userHeader.checked
    property alias cfg_showToggles: toggles.checked
    property alias cfg_showDarkStyle: darkStyle.checked
    property int cfg_expandRequest
    // set by plasmashell's config dialog for every key; declared so it doesn't warn
    property string cfg_compactStyleDefault
    property bool cfg_showUserHeaderDefault
    property bool cfg_showTogglesDefault
    property bool cfg_showDarkStyleDefault
    property int cfg_expandRequestDefault

    Kirigami.FormLayout {
        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("Panel icon:")
            text: i18n("Single power icon (battery icon on laptops)")
            checked: cfg_compactStyle !== "icons"
            onToggled: if (checked) cfg_compactStyle = "single"
        }
        QQC2.RadioButton {
            text: i18n("GNOME status icons (network, volume, battery/power)")
            checked: cfg_compactStyle === "icons"
            onToggled: if (checked) cfg_compactStyle = "icons"
        }
        QQC2.Label {
            text: i18n("Inside the system tray only the single icon is shown.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.CheckBox {
            id: userHeader
            Kirigami.FormData.label: i18n("Menu:")
            text: i18n("Show user name and picture (not in GNOME 50)")
        }
        QQC2.CheckBox {
            id: toggles
            text: i18n("Show quick toggles (Wi-Fi, Bluetooth, Night Light…)")
        }
        QQC2.CheckBox {
            id: darkStyle
            enabled: toggles.checked
            text: i18n("Include the Dark Style toggle (switches the Global Theme)")
        }
    }
}
