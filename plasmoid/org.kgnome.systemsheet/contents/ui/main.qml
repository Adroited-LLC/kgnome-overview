// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME Shell 50-style system menu (Quick Settings) for Plasma 6.
// Structure follows gnome-shell js/ui/panel.js QuickSettings._setupIndicators
// and js/ui/status/system.js; session actions go through Plasma's
// SessionManagement, so KDE's own confirmation screen is used.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions as Sessions
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property bool inTray: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentDrawsPlasmoidHeading) !== 0
    readonly property bool useStatusIcons: Plasmoid.configuration.compactStyle === "icons" && !inTray

    Sessions.SessionManagement { id: sm }

    function run(cmd) { executable.connectSource(cmd); }
    // close the menu first, then act (screenshots shouldn't show the menu)
    function closeThen(fn, delay) {
        root.expanded = false;
        actionTimer.fn = fn;
        actionTimer.interval = delay || 1;
        actionTimer.restart();
    }
    Timer {
        id: actionTimer
        property var fn
        onTriggered: if (fn) { const f = fn; fn = null; f(); }
    }
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }

    // Developer hook: a Plasma script can open the menu by bumping
    // General/expandRequest (used for screenshots; see README)
    property int expandRequest: Plasmoid.configuration.expandRequest
    onExpandRequestChanged: root.expanded = true

    // keep the battery state for the panel icon
    Loader {
        id: batteryState
        active: true
        visible: false
        source: "parts/BatteryItem.qml"
    }
    readonly property bool hasBattery: batteryState.status === Loader.Ready && batteryState.item.available
    readonly property string powerIcon: hasBattery ? batteryState.item.iconName : "system-shutdown-symbolic"

    Plasmoid.icon: powerIcon
    Plasmoid.title: i18n("System Menu")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: i18n("System Menu")
    toolTipSubText: hasBattery ? i18n("Battery at %1%", batteryState.item.percent)
                               : i18n("Volume, settings, lock, log out and power off")

    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10

    compactRepresentation: CompactRepresentation {
        powerIcon: root.powerIcon
        statusIcons: root.useStatusIcons
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: Sheet {
        sessions: sm
        showUserHeader: Plasmoid.configuration.showUserHeader
        showToggles: Plasmoid.configuration.showToggles
        showDarkStyle: Plasmoid.configuration.showDarkStyle
        styleVariant: Plasmoid.configuration.styleVariant
        accentSource: Plasmoid.configuration.accentSource
        sheetRadius: Plasmoid.configuration.sheetRadius
        drawBackground: !root.inTray
        isOpen: root.expanded
        onScreenshot: root.closeThen(() => root.run("spectacle -r"), 300)
        onOpenSettings: root.closeThen(() => root.run("systemsettings"))
        onLock: root.closeThen(() => sm.lock())
        onSuspend: root.closeThen(() => sm.suspend())
        onReboot: root.closeThen(() => sm.requestReboot(Sessions.SessionManagement.ConfirmationMode.ForcePrompt))
        onPowerOff: root.closeThen(() => sm.requestShutdown(Sessions.SessionManagement.ConfirmationMode.ForcePrompt))
        onLogOut: root.closeThen(() => sm.requestLogout(Sessions.SessionManagement.ConfirmationMode.ForcePrompt))
        onSwitchUser: root.closeThen(() => sm.switchUser())
        onCloseRequested: root.expanded = false
    }
}
