// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Panel button that opens the kgnome-overview app grid (or window picker)
// through KWin's global shortcut component, like GNOME's "Show Apps".
// Provides org.kde.plasma.launchermenu, so plasmashell's "Activate
// Application Launcher" shortcut (Alt+F1) triggers it too.
// Structure follows Plasma's Show Desktop applet (a full representation that
// is just an icon button).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "Commands.js" as Commands

PlasmoidItem {
    id: root

    readonly property string shortcutName: Plasmoid.configuration.target === "overview"
                                           ? "Toggle GNOME Overview" : "Toggle GNOME App Grid"

    function open() {
        // qdbus6 on some distributions, qdbus on Fedora
        const cmd = "q=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus); "
                  + "\"$q\" org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut '"
                  + shortcutName + "'";
        executable.connectSource(cmd);
    }

    function openSettings() {
        executable.connectSource(Commands.effectSettings);
    }

    // right-click menu: next to Plasma's own "Configure Show Applications…"
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Overview Settings…")
            icon.name: "configure"
            onTriggered: root.openSettings()
        }
    ]

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.icon: Plasmoid.configuration.icon || "view-app-grid-symbolic"
    Plasmoid.title: i18n("Applications")
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.onActivated: root.open()
    toolTipMainText: i18n("Show Applications")
    toolTipSubText: ""

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : height
    Layout.minimumHeight: vertical ? width : Kirigami.Units.iconSizes.small
    Layout.preferredWidth: Layout.minimumWidth
    Layout.preferredHeight: Layout.minimumHeight

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.open()

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: mouseArea.containsMouse
        }
    }
}
