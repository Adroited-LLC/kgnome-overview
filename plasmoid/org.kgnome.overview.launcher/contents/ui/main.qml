// SPDX-License-Identifier: GPL-2.0-or-later
// Panel button that opens the kgnome-overview app grid (or window picker)
// through KWin's global shortcut component, like GNOME's "Show Apps".
// Provides org.kde.plasma.launchermenu, so plasmashell's "Activate
// Application Launcher" shortcut (Alt+F1) triggers it too.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

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

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }

    Plasmoid.icon: Plasmoid.configuration.icon || "view-app-grid-symbolic"
    Plasmoid.title: i18n("Applications")
    toolTipMainText: i18n("Show Applications")
    toolTipSubText: ""
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    Plasmoid.onActivated: root.open()

    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.open()
        Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal ? height : Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? width : Kirigami.Units.iconSizes.small

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: button.containsMouse
        }
    }
}
