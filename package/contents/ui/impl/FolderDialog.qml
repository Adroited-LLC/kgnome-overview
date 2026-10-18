// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's AppFolderDialog (_app-grid.scss .app-folder-dialog): at least
// 720px square (grown to fit three columns of the grid's icon size),
// border-radius 64px, $system_overlay_bg_color, title_1 folder name with
// 24px/36px padding (click it to rename, like the folder-name entry), a 3x3
// paged grid (FolderGrid), the overview shaded with DIALOG_SHADE_NORMAL
// (black, alpha 204) and a 200ms open/close animation. Clicking outside or
// Esc closes it; dragging an app out of the panel closes it and lets the app
// be dropped in the main grid (removing it from the folder).
import QtQuick
import org.kde.kirigami as Kirigami
import "Layout.js" as L

Item {
    id: dialog

    required property Item screenView
    required property Item appGrid     // AppGrid
    readonly property QtObject effect: screenView.effect
    readonly property real s: screenView.s
    readonly property bool open: effect.folderOpen.length > 0 && screenView.gridFactor > 0
    readonly property var folder: open && effect.appLayout ? effect.appLayout.folderNamed(effect.folderOpen) : null
    readonly property string folderName: folder ? folder.name : ""
    readonly property alias grid: paged
    property bool dragOut: false
    readonly property bool dragging: screenView.iconDrag !== null && screenView.iconDrag.source === paged

    // close when the folder disappeared (dissolved)
    onFolderChanged: if (open && !folder && !dragging) Qt.callLater(() => { if (!dialog.folder) dialog.effect.folderOpen = ""; })
    onOpenChanged: {
        if (open) {
            dragOut = false;
            paged.reset();
        }
        renaming = false;
    }

    function containsScreenPoint(p) {
        const q = panel.mapFromItem(screenView, p.x, p.y);
        return q.x >= 0 && q.y >= 0 && q.x <= panel.width && q.y <= panel.height;
    }

    visible: shade.opacity > 0 || dragging
    enabled: open

    readonly property real shown: open && !dragOut ? 1 : 0
    Rectangle {
        id: shade
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 204 / 255)
        opacity: dialog.shown
        Behavior on opacity { NumberAnimation { duration: L.FOLDER_DIALOG_ANIMATION_TIME; easing.type: Easing.OutQuad } }
        MouseArea {
            anchors.fill: parent
            enabled: dialog.shown > 0
            onClicked: dialog.effect.folderOpen = ""
            onWheel: wheel => wheel.accepted = true
        }
    }

    // sizes follow the main grid's icon size
    readonly property int iconSize: appGrid.iconSize
    readonly property int tile: paged.tileFor(iconSize)
    readonly property int titleHeight: Math.round(24 * s) + titleLabel.implicitHeight
    readonly property int side: Math.max(Math.round(L.APP_FOLDER_SIZE * s),
                                         3 * tile + 2 * Math.round(24 * s) + 2 * Math.round(36 * s),
                                         titleHeight + 3 * tile + 2 * Math.round(24 * s) + 2 * Math.round(12 * s)
                                             + paged.indicatorsHeight + Math.round(24 * s))

    Rectangle {
        id: panel
        width: dialog.side
        height: width
        anchors.centerIn: parent
        radius: Math.round(64 * dialog.s)
        color: L.SYSTEM_OVERLAY_BG_COLOR
        opacity: shade.opacity
        scale: L.lerp(0.9, 1, shade.opacity)

        MouseArea {
            // swallow clicks on the panel background; ends a rename
            anchors.fill: parent
            onClicked: dialog.finishRename(true)
        }

        Item {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(24 * dialog.s)
            width: parent.width - 2 * Math.round(36 * dialog.s)
            height: titleLabel.implicitHeight

            Text {
                id: titleLabel
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                visible: !dialog.renaming
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: L.SYSTEM_FG_COLOR
                text: dialog.folderName
                // %title_1: 20pt, weight 800
                font.pixelSize: Math.round(20 * 96 / 72 * dialog.s)
                font.weight: Font.ExtraBold
                Rectangle {
                    // hover hint that the name can be edited
                    anchors.fill: parent
                    anchors.margins: -Math.round(8 * dialog.s)
                    radius: Math.round(12 * dialog.s)
                    color: Qt.rgba(1, 1, 1, titleArea.containsMouse ? 0.08 : 0)
                    z: -1
                }
                MouseArea {
                    id: titleArea
                    anchors.fill: parent
                    anchors.margins: -Math.round(8 * dialog.s)
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: dialog.startRename()
                }
            }

            // .folder-name-entry: system entry, 12em
            Rectangle {
                anchors.centerIn: parent
                visible: dialog.renaming
                width: Math.round(12 * titleLabel.font.pixelSize)
                height: titleLabel.implicitHeight + Math.round(12 * dialog.s)
                radius: Math.round(12 * dialog.s)
                color: L.SYSTEM_BG_COLOR
                border.width: Math.round(2 * dialog.s)
                border.color: Kirigami.Theme.highlightColor
                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(12 * dialog.s)
                    anchors.rightMargin: Math.round(12 * dialog.s)
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    color: L.SYSTEM_FG_COLOR
                    selectionColor: Kirigami.Theme.highlightColor
                    font: titleLabel.font
                    clip: true
                    Keys.onReturnPressed: dialog.finishRename(true)
                    Keys.onEnterPressed: dialog.finishRename(true)
                    Keys.onEscapePressed: dialog.finishRename(false)
                    onActiveFocusChanged: if (!activeFocus && dialog.renaming) dialog.finishRename(true)
                }
            }
        }

        PagedGrid {
            id: paged
            anchors.top: title.bottom
            anchors.topMargin: Math.round(12 * dialog.s)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(24 * dialog.s)
            enabled: dialog.open && !dialog.renaming
            screenView: dialog.screenView
            entries: dialog.folder ? dialog.folder.apps.map((row, i) => ({kind: "app", index: row, id: dialog.folder.appIds[i], name: ""})) : []
            backend: dialog.effect.backend
            s: dialog.s
            fontPx: dialog.screenView.fontPx
            preferredIconSize: dialog.iconSize
            fixedMode: ({rows: 3, columns: 3})
            padding: ({h: Math.round(36 * dialog.s), v: Math.round(12 * dialog.s)})
            spacing: Math.round(12 * dialog.s)
            maxSpacing: Math.round(36 * dialog.s)
            showArrows: false
            folderDropEnabled: false
            runningWindows: dialog.effect.runningWindows
            onEntryActivated: (entry, button, modifiers) => {
                dialog.effect.launchApp("apps", entry.index, button, modifiers);
            }
            onEmptyClicked: dialog.finishRename(true)
        }
    }

    // --- rename -----------------------------------------------------------------
    property bool renaming: false
    function startRename() {
        if (!folder) {
            return;
        }
        nameInput.text = folderName;
        renaming = true;
        nameInput.forceActiveFocus();
        nameInput.selectAll();
    }
    function finishRename(accept) {
        if (!renaming) {
            return;
        }
        renaming = false;
        if (accept && effect.appLayout) {
            const newName = effect.appLayout.renameFolder(folderName, nameInput.text);
            effect.folderOpen = newName;
        }
        screenView.focusSearch();
    }
}
