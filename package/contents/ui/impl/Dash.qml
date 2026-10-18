// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME 50's Dash (js/ui/dash.js, _dash.scss): favourites, then running apps
// that are not favourites after a separator, then "Show Apps". Icon size is
// the largest of DashIconSize (GNOME 64) and GNOME's smaller sizes
// (48..16) for which everything fits.
// Drag and drop like Dash.handleDragOver/acceptDrop: a placeholder opens at
// floor(x / item width), never past the favourites and not next to the
// dragged favourite itself; while a favourite is dragged the Show Apps
// button becomes the "Unpin" target (ShowAppsIcon.setDragApp).
// _dash.scss: .dash-background $system_overlay_bg_color, radius 28px,
// padding 12px top/bottom and 10px left/right, margin-bottom 12px; items
// margin 0 2px with 6px tile padding and 16px radius; separator 1px with 4px
// margins; running dot in the bottom padding.
import QtQuick
import org.kde.kirigami as Kirigami
import "Layout.js" as L

Item {
    id: dash

    required property Item screenView
    required property QtObject windowModel
    property real maxWidth: 1000
    property real maxHeight: 200

    readonly property QtObject effect: screenView.effect
    readonly property QtObject backend: effect.backend
    readonly property real s: screenView.s

    // --- items -------------------------------------------------------------------
    // [{id, storageId, app, fav, row}]  (id without ".desktop")
    readonly property var items: {
        const out = [];
        if (!backend) {
            return out;
        }
        backend.revision;
        const seen = {};
        const n = backend.count("favorites");
        for (let i = 0; i < n; ++i) {
            const a = backend.appAt("favorites", i);
            if (!a || !a.storageId) {
                continue;
            }
            const id = a.storageId.replace(/\.desktop$/, "");
            seen[id] = true;
            out.push({id: id, storageId: a.storageId, app: a, fav: true});
        }
        const installed = effect.appLayout ? effect.appLayout.installed : {};
        for (const id of effect.runningIds) {
            const inst = installed[id];
            if (seen[id] || inst === undefined) {
                continue;
            }
            seen[id] = true;
            const a = backend.appAt("apps", inst.row);
            if (a) {
                out.push({id: id, storageId: a.storageId, app: a, fav: false});
            }
        }
        return out;
    }
    readonly property int favCount: {
        let n = 0;
        for (const it of items) {
            n += it.fav ? 1 : 0;
        }
        return n;
    }
    readonly property int runCount: items.length - favCount

    // --- metrics -------------------------------------------------------------------
    readonly property int itemPadding: Math.round(6 * s)
    readonly property int itemMargin: Math.round(2 * s)
    readonly property int bgPadding: Math.round(12 * s)
    readonly property int bgPaddingH: Math.round(10 * s)
    readonly property int bottomMargin: Math.round(12 * s)
    readonly property bool separatorShown: favCount > 0 && runCount > 0
    readonly property int separatorWidth: separatorShown ? Math.round((1 + 2 * 4) * s) : 0
    readonly property int iconSize: {
        const n = items.length + 1;
        const sizes = [effect.dashIconSize].concat(L.DASH_ICON_SIZES.filter(x => x < effect.dashIconSize));
        for (const size of sizes) {
            const item = size + 2 * itemPadding;
            const w = n * (item + 2 * itemMargin) + separatorWidth + 2 * bgPaddingH;
            const h = item + 2 * bgPadding + bottomMargin;
            if (w <= maxWidth && h <= maxHeight) {
                return size;
            }
        }
        return 16;
    }
    readonly property int itemSize: iconSize + 2 * itemPadding
    readonly property int stride: itemSize + 2 * itemMargin

    // --- drag state (driven by ScreenView's icon drag manager) ------------------------
    property int dragEntryIndex: -1      // dash item being dragged
    property int dropPos: -1             // placeholder position among the favourites
    property bool dragOverDash: false
    property bool unpinHover: false
    readonly property bool draggingFavorite: screenView.iconDrag !== null && screenView.iconDrag.source === dash
                                             && dragEntryIndex >= 0 && dragEntryIndex < items.length && items[dragEntryIndex].fav
    readonly property int placeholderWidth: dropPos >= 0 ? stride : 0

    function slotX(i) {
        let x = bgPaddingH + i * stride;
        if (dropPos >= 0 && i >= dropPos) {
            x += placeholderWidth;
        }
        if (i >= favCount) {
            x += separatorWidth;
        }
        return x + itemMargin;
    }
    readonly property real contentWidth: 2 * bgPaddingH + (items.length + 1) * stride + separatorWidth + placeholderWidth

    // p in dash coordinates; returns the drop target for ScreenView
    function dragHover(p, entryId) {
        dragOverDash = true;
        const own = dragEntryIndex >= 0 ? dragEntryIndex : -1;
        // Show Apps = Unpin target for a favourite dragged from the dash
        if (draggingFavorite && p.x - background.x >= showApps.x - itemMargin) {
            unpinHover = true;
            dropPos = -1;
            return {type: "unpin"};
        }
        unpinHover = false;
        const favPos = items.findIndex(it => it.fav && it.id === entryId);
        let pos = Math.floor((p.x - background.x - bgPaddingH) / stride);
        if (favCount === 0) {
            pos = 0;
        }
        pos = L.clamp(pos, 0, favCount);
        // Don't allow positioning before or after self
        if (favPos >= 0 && (pos === favPos || pos === favPos + 1)) {
            dropPos = -1;
            return {type: "dash", pos: -1};
        }
        dropPos = pos;
        // position among the favourites without the dragged app (moveFavoriteToPos)
        return {type: "dash", pos: favPos >= 0 && favPos < pos ? pos - 1 : pos};
    }
    function dragLeave() {
        dragOverDash = false;
        unpinHover = false;
        dropPos = -1;
    }
    function dragEnd() {
        dragLeave();
        dragEntryIndex = -1;
    }

    implicitWidth: contentWidth
    implicitHeight: itemSize + 2 * bgPadding + bottomMargin
    width: implicitWidth
    height: implicitHeight
    Behavior on width { enabled: dash.dragOverDash; NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

    Rectangle {
        id: background
        anchors.horizontalCenter: parent.horizontalCenter
        width: dash.contentWidth
        height: dash.itemSize + 2 * dash.bgPadding
        radius: Math.round(28 * dash.s)
        color: L.SYSTEM_OVERLAY_BG_COLOR
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        // placeholder: GNOME's .placeholder has no image any more, just space

        Repeater {
            model: dash.items.length
            delegate: AppIcon {
                id: dashIcon
                required property int index
                readonly property var item: dash.items[index] || null
                readonly property var wins: item ? (dash.effect.runningWindows, dash.effect.windowsFor(item.storageId)) : []
                x: dash.slotX(index)
                y: dash.bgPadding
                Behavior on x { enabled: dash.dragOverDash || dash.dragEntryIndex >= 0; NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                width: dash.itemSize
                height: dash.itemSize
                s: dash.s
                interactive: false
                hoveredExternal: iconArea.containsMouse && !iconArea.dragging
                pressedExternal: iconArea.pressed && !iconArea.dragging
                opacity: iconArea.dragging ? 0.4 : 1
                tilePadding: dash.itemPadding
                radius: Math.round(16 * dash.s)
                fontPx: dash.screenView.fontPx
                dotBottomMargin: -Math.round(dash.bgPadding / 2 + 2.5 * dash.s)
                showLabel: false
                iconSize: dash.iconSize
                app: item ? item.app : null
                running: wins.length > 0
                focusRing: dash.screenView.appMenuFor === (item ? item.id : "") && item !== null

                MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    property point pressPos
                    property bool dragging: false
                    function toScreen(mouse) {
                        return mapToItem(dash.screenView, mouse.x, mouse.y);
                    }
                    onPressed: mouse => {
                        pressPos = Qt.point(mouse.x, mouse.y);
                        dragging = false;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || !(pressedButtons & Qt.LeftButton) || !dashIcon.item) {
                            return;
                        }
                        if (dragging) {
                            dash.screenView.iconDragMove(toScreen(mouse));
                        } else if (Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                            dragging = true;
                            dash.dragEntryIndex = dashIcon.index;
                            const it = dashIcon.item;
                            const inst = dash.effect.appLayout ? dash.effect.appLayout.installed[it.id] : undefined;
                            const entry = {kind: "app", id: it.id, index: inst ? inst.row : -1, name: it.app.name, app: it.app};
                            dash.screenView.iconDragBegin(dash, entry, mapToItem(dash.screenView, pressPos.x, pressPos.y),
                                                          toScreen(mouse), dash.iconSize);
                        }
                    }
                    onReleased: mouse => {
                        if (dragging) {
                            dragging = false;
                            dash.screenView.iconDragEnd(toScreen(mouse));
                            return;
                        }
                        const it = dashIcon.item;
                        if (!it || !containsMouse) {
                            return;
                        }
                        if (mouse.button === Qt.RightButton) {
                            dash.screenView.openAppMenu(it.id, mapToItem(dash.screenView, width / 2, 0), true);
                            return;
                        }
                        // GNOME: click focuses a running app, middle/Ctrl-click opens a new window
                        if (dashIcon.wins.length > 0 && mouse.button === Qt.LeftButton && !(mouse.modifiers & Qt.ControlModifier)) {
                            dash.effect.activateWindow(dashIcon.wins[dashIcon.wins.length - 1]);
                        } else {
                            dash.effect.newWindow(it.storageId);
                        }
                    }
                    onCanceled: {
                        if (dragging) {
                            dragging = false;
                            dash.screenView.iconDragEnd(null);
                        }
                    }
                }
            }
        }

        // separator between pinned and running apps
        Rectangle {
            visible: dash.separatorShown
            x: dash.slotX(dash.favCount) - dash.itemMargin - dash.separatorWidth + Math.round((dash.separatorWidth - width) / 2)
            Behavior on x { enabled: dash.dragOverDash; NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, Math.round(1 * dash.s))
            height: dash.iconSize
            color: Qt.rgba(1, 1, 1, 0.1)   // $system_borders_color
        }

        // "Show Apps" toggle; Unpin target while a favourite is dragged
        Item {
            id: showApps
            x: dash.slotX(dash.items.length)
            y: dash.bgPadding
            Behavior on x { enabled: dash.dragOverDash; NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            width: dash.itemSize
            height: dash.itemSize
            readonly property bool checked: dash.effect.targetState === dash.effect.stateAppGrid
            readonly property bool unpinMode: dash.draggingFavorite
            Rectangle {
                anchors.fill: parent
                radius: Math.round(16 * dash.s)
                color: Qt.rgba(1, 1, 1, showAppsArea.pressed ? 0.15 : (dash.unpinHover || (!showApps.unpinMode && (showApps.checked || showAppsArea.containsMouse))) ? 0.12 : 0)
                border.width: dash.unpinHover ? Math.round(2 * dash.s) : 0
                border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.8)
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(dash.iconSize * 0.6)
                height: width
                source: showApps.unpinMode ? "user-trash-symbolic" : "view-app-grid-symbolic"
                fallback: "view-grid-symbolic"
                color: "white"
                isMask: true
            }
            // .dash-label
            Rectangle {
                visible: showApps.unpinMode || showAppsArea.containsMouse
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(14 * dash.s) + dash.bgPadding
                width: showAppsLabel.implicitWidth + Math.round(24 * dash.s)
                height: showAppsLabel.implicitHeight + Math.round(12 * dash.s)
                radius: height / 2
                color: L.SYSTEM_OVERLAY_BG_COLOR
                Text {
                    id: showAppsLabel
                    anchors.centerIn: parent
                    color: L.SYSTEM_FG_COLOR
                    font.pixelSize: dash.screenView.fontPx
                    text: showApps.unpinMode ? "Unpin" : "Show Apps"
                }
            }
            MouseArea {
                id: showAppsArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: dash.effect.setState(parent.checked ? dash.effect.stateWindowPicker : dash.effect.stateAppGrid)
            }
        }
    }
}
