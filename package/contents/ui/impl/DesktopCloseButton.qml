// SPDX-License-Identifier: GPL-2.0-or-later
// Hover "x" on workspace thumbnails, side peeks and the app grid's strip:
// closes the desktop. Not in GNOME (its workspaces only go away when empty);
// windows are never closed, DynamicWorkspaces.closeDesktop moves them to the
// neighbouring desktop. Hidden when the desktop can't be closed (the last one,
// or the trailing empty one with dynamic workspaces). Looks like GNOME's
// .window-close button.
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: button

    required property QtObject effect
    required property QtObject desktop
    property bool shown: false
    property real size: 22

    readonly property QtObject dyn: effect ? effect.dyn : null
    readonly property bool closable: dyn !== null && dyn.revision >= 0 && effect.desktopCount > 1 && dyn.canClose(desktop)

    width: size
    height: size
    radius: size / 2
    color: closeArea.containsMouse ? "#5a5a5f" : "#45454a"
    border.width: Math.max(1, Math.round(size / 22))
    border.color: Qt.rgba(1, 1, 1, 0.12)
    opacity: (shown || closeArea.containsMouse) && closable ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.round(button.size * 0.55)
        height: width
        source: "window-close-symbolic"
        color: "white"
        isMask: true
    }
    MouseArea {
        id: closeArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.dyn.closeDesktop(button.desktop)
    }
}
