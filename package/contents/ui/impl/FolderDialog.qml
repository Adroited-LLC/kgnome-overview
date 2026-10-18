// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's AppFolderDialog (_app-grid.scss .app-folder-dialog): 720px square,
// border-radius 64px, $system_overlay_bg_color, title_1 folder name with
// 24px/36px padding, a 3x3 paged grid (FolderGrid), the overview shaded with
// DIALOG_SHADE_NORMAL (black, alpha 204) and a 200ms open/close animation.
// Clicking outside or Esc closes it.
import QtQuick
import "Layout.js" as L

Item {
    id: dialog

    required property Item screenView
    required property Item grid      // AppGrid
    readonly property QtObject effect: screenView.effect
    readonly property real s: screenView.s
    readonly property bool open: effect.folderOpen.length > 0 && screenView.gridFactor > 0
    property var folder: null

    onOpenChanged: {
        if (open) {
            folder = grid.folderNamed(effect.folderOpen);
            paged.reset();
        }
    }

    visible: shade.opacity > 0
    enabled: open

    Rectangle {
        id: shade
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 204 / 255)
        opacity: dialog.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: L.FOLDER_DIALOG_ANIMATION_TIME; easing.type: Easing.OutQuad } }
        MouseArea {
            anchors.fill: parent
            onClicked: dialog.effect.folderOpen = ""
            onWheel: wheel => wheel.accepted = true
        }
    }

    Rectangle {
        id: panel
        width: Math.round(L.APP_FOLDER_SIZE * dialog.s)
        height: width
        anchors.centerIn: parent
        radius: Math.round(64 * dialog.s)
        color: L.SYSTEM_OVERLAY_BG_COLOR
        opacity: shade.opacity
        scale: L.lerp(0.9, 1, shade.opacity)

        MouseArea {
            // swallow clicks on the panel background
            anchors.fill: parent
        }

        Text {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(24 * dialog.s)
            width: parent.width - 2 * Math.round(36 * dialog.s)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: L.SYSTEM_FG_COLOR
            text: dialog.folder ? dialog.folder.name : ""
            // %title_1: 20pt, weight 800
            font.pixelSize: Math.round(20 * 96 / 72 * dialog.s)
            font.weight: Font.ExtraBold
        }

        PagedGrid {
            id: paged
            anchors.top: title.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(24 * dialog.s)
            enabled: dialog.open
            entries: dialog.folder ? dialog.folder.apps.map(i => ({kind: "app", index: i, name: ""})) : []
            backend: dialog.effect.backend
            s: dialog.s
            fontPx: dialog.screenView.fontPx
            iconScale: dialog.effect.iconScale
            fixedMode: ({rows: 3, columns: 3})
            padding: ({h: Math.round(36 * dialog.s), v: Math.round(12 * dialog.s)})
            spacing: Math.round(12 * dialog.s)
            maxSpacing: Math.round(36 * dialog.s)
            showArrows: false
            runningWindows: dialog.effect.runningWindows
            onEntryActivated: (entry, button, modifiers) => {
                dialog.effect.launchApp("apps", entry.index, button, modifiers);
            }
            onEmptyClicked: {}
        }
    }
}
