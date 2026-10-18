// SPDX-License-Identifier: GPL-2.0-or-later
// Panel button: a single power/battery icon, or GNOME's status icons
// (network, volume, battery/power) in a row.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact
    property string powerIcon
    property bool statusIcons: false

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var icons: {
        const list = [];
        if (statusIcons && status.item) {
            if (status.item.networkIcon) list.push(status.item.networkIcon);
            if (status.item.volumeIcon) list.push(status.item.volumeIcon);
        }
        list.push(powerIcon);
        return list;
    }
    readonly property real iconSize: Math.min(vertical ? width : height, Kirigami.Units.iconSizes.medium)

    hoverEnabled: true
    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : (iconSize * icons.length + spacingTotal)
    Layout.minimumHeight: vertical ? (iconSize * icons.length + spacingTotal) : Kirigami.Units.iconSizes.small
    readonly property real spacingTotal: Kirigami.Units.smallSpacing * (icons.length - 1)

    Loader {
        id: status
        active: compact.statusIcons
        source: "parts/StatusIcons.qml"
    }

    GridLayout {
        anchors.centerIn: parent
        flow: compact.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.smallSpacing
        Repeater {
            model: compact.icons
            Kirigami.Icon {
                required property string modelData
                Layout.preferredWidth: compact.iconSize
                Layout.preferredHeight: compact.iconSize
                source: modelData
                active: compact.containsMouse
            }
        }
    }
}
