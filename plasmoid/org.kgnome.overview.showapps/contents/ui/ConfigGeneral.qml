// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support
import "Commands.js" as Commands

KCM.SimpleKCM {
    property string cfg_icon
    property string cfg_target
    // set by plasmashell's config dialog for every key; declared so it
    // doesn't warn
    property string cfg_iconDefault
    property string cfg_targetDefault
    property var cfg_expanding
    property var cfg_length

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }

    Kirigami.FormLayout {
        QQC2.Button {
            Kirigami.FormData.label: i18n("Icon:")
            implicitWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.largeSpacing * 2
            implicitHeight: implicitWidth
            icon.name: cfg_icon
            icon.width: Kirigami.Units.iconSizes.large
            icon.height: Kirigami.Units.iconSizes.large
            onClicked: iconDialog.open()
            KIconThemes.IconDialog {
                id: iconDialog
                onIconNameChanged: name => { if (name) { cfg_icon = name; } }
            }
        }
        QQC2.Button {
            text: i18n("Default (app grid dots)")
            onClicked: cfg_icon = "view-app-grid-symbolic"
        }
        QQC2.Button {
            text: i18n("Distribution logo")
            onClicked: cfg_icon = "start-here-kde-symbolic"
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Click opens:")
            model: [i18n("App grid"), i18n("Window picker")]
            currentIndex: cfg_target === "overview" ? 1 : 0
            onActivated: index => cfg_target = index === 1 ? "overview" : "appgrid"
        }
        Item {
            Kirigami.FormData.isSection: true
        }
        QQC2.Button {
            Kirigami.FormData.label: i18n("Overview:")
            text: i18n("Overview Settings…")
            icon.name: "configure"
            onClicked: executable.connectSource(Commands.effectSettings)
        }
    }
}
