// SPDX-License-Identifier: GPL-2.0-or-later
// One overview per screen. Geometry follows GNOME 50's ControlsManagerLayout
// (js/ui/overviewControls.js) and WorkspacesView (js/ui/workspacesView.js):
// every region has a box per state and is blended by effect.stateValue.
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import "Layout.js" as L

FocusScope {
    id: root
    focus: true

    // Provided by the bootstrap Loader in main.qml
    readonly property QtObject effect: parent ? parent.sceneEffect.controller : null
    readonly property QtObject targetScreen: parent ? parent.sceneScreen : null
    readonly property QtObject backend: effect.backend

    readonly property real sv: effect.stateValue
    readonly property real pickerFactor: Math.min(sv, 1)   // HIDDEN -> WINDOW_PICKER
    readonly property real gridFactor: Math.max(sv - 1, 0)  // WINDOW_PICKER -> APP_GRID
    readonly property bool searching: effect.searchText.length > 0
    readonly property bool interactive: effect.active
    readonly property real screenAspect: width / Math.max(1, height)

    // UI scale: GNOME sizes are logical px at an 11pt base font; follow the
    // Plasma font size (gridUnit 18 at the default 10pt font).
    readonly property real s: Kirigami.Units.gridUnit / 18
    readonly property int fontPx: Math.round(11 * 96 / 72 * s)

    // --- GNOME ControlsManagerLayout metrics --------------------------------
    readonly property int spacing: Math.round(height * L.VERTICAL_SPACING_RATIO)
    readonly property int searchTop: Math.round(12 * s)      // .search-entry margin-top
    readonly property int searchHeight: searchTop + searchEntry.height + Math.round(6 * s)
    readonly property int dashHeight: Math.min(dash.implicitHeight, Math.round(height * L.DASH_MAX_HEIGHT_RATIO))
    // ThumbnailsBox is only shown with more than one workspace
    readonly property bool thumbnailsShown: effect.desktopCount > 1
    readonly property int thumbnailsHeight: thumbnailsShown ? Math.round(height * L.MAX_THUMBNAIL_SCALE) : 0
    readonly property var metrics: ({
        width: width, height: height, startY: 0,
        spacing: spacing, searchHeight: searchHeight, dashHeight: dashHeight,
        thumbnailsHeight: thumbnailsHeight, expandFraction: thumbnailsShown ? 1 : 0,
    })
    readonly property var fullBox: L.rect(0, 0, width, height)
    readonly property var pickerBox: L.workspacesBox(1, metrics)
    readonly property var gridBox: L.workspacesBox(2, metrics)
    readonly property real pickerScale: L.fitAspect(pickerBox, screenAspect).width / Math.max(1, width)
    readonly property var appDisplayBox: L.blend(L.appDisplayBox, sv, metrics)
    readonly property var searchBox: L.searchBox(metrics)

    // workspaces fade out while searching (SearchController)
    property real workspacesOpacity: searching ? 0 : 1
    Behavior on workspacesOpacity { NumberAnimation { duration: effect.animationDuration; easing.type: Easing.OutQuad } }

    // WorkspacesView.vfunc_allocate: FitMode.SINGLE (hidden, window picker)
    // interpolated to FitMode.ALL (app grid), inactive workspaces at 94%.
    function workspaceRect(index) {
        const pos = effect.workspacePos;
        let r;
        if (sv <= 1) {
            r = L.fitSingleRect(L.lerpRect(fullBox, pickerBox, pickerFactor), screenAspect, index, pos, s);
        } else {
            r = L.lerpRect(L.fitSingleRect(pickerBox, screenAspect, index, pos, s),
                           L.fitAllRect(gridBox, screenAspect, index, Math.max(1, effect.desktopCount), s),
                           gridFactor);
        }
        const distance = L.clamp(Math.abs(pos - index), 0, 1);
        return L.scaleRect(r, L.lerp(L.WORKSPACE_INACTIVE_SCALE, 1, 1 - distance));
    }

    // --- Window drag and drop to another workspace -------------------------------
    property QtObject dragWindow: null
    property point dragPoint
    function beginWindowDrag(window, p) {
        dragWindow = window;
        dragPoint = p;
    }
    function moveWindowDrag(p) {
        dragPoint = p;
        showDropTarget(dropTargetAt(p));
    }

    // --- Drop targets for windows and apps --------------------------------------
    // {type: "desktop", desktop} or {type: "newDesktop", index, where} or null.
    // New workspaces (GNOME: only with dynamic workspaces) come from the gap
    // between two workspace thumbnails (drop placeholder) or, in the app grid,
    // between two workspaces of the strip at the top.
    readonly property bool canCreateDesktops: effect.dyn !== null && effect.dyn.enabled && !effect.dyn.suspended
    readonly property real cutSize: Math.round(10 * s)        // WORKSPACE_CUT_SIZE
    property var dropNew: ({where: "", index: -1})
    function stripGapAt(p) {
        // gaps between the app grid's workspace strip previews
        const n = effect.desktopCount;
        for (let i = 0; i < n; ++i) {
            const r = workspaceRect(i);
            if (p.y < r.y || p.y > r.y + r.height) {
                continue;
            }
            const prev = i > 0 ? workspaceRect(i - 1) : null;
            const x1 = (prev ? prev.x + prev.width : r.x) - cutSize;
            const x2 = r.x + cutSize;
            if (p.x > x1 && p.x <= x2) {
                return i;
            }
        }
        return -1;
    }
    function dropTargetAt(p) {
        if (thumbnails.visible) {
            const tp = mapToItem(thumbnails, p.x, p.y);
            const t = thumbnails.dropAt(tp.x, tp.y, canCreateDesktops);
            if (t) {
                return t.desktop ? {type: "desktop", desktop: t.desktop} : {type: "newDesktop", index: t.insertAt, where: "thumbnails"};
            }
        }
        if (canCreateDesktops && gridFactor > 0.99 && !searching) {
            const i = stripGapAt(p);
            if (i >= 0) {
                return {type: "newDesktop", index: i, where: "strip"};
            }
        }
        const d = desktopAtPoint(p);
        return d ? {type: "desktop", desktop: d} : null;
    }
    function showDropTarget(t) {
        dropDesktop = t && t.type === "desktop" ? t.desktop : null;
        const n = t && t.type === "newDesktop" ? {where: t.where, index: t.index} : {where: "", index: -1};
        if (n.where !== dropNew.where || n.index !== dropNew.index) {
            dropNew = n;
        }
    }
    // GNOME ThumbnailsBox.acceptDrop with a placeholder: insertWorkspace, then
    // move the window there / launch the app there.
    function dropWindowOnNewDesktop(window, index) {
        const d = effect.dyn ? effect.dyn.insertDesktop(index) : null;
        if (d) {
            window.desktops = [d];
        }
    }

    function desktopAtPoint(p) {
        if (thumbnails.visible) {
            const tp = mapToItem(thumbnails, p.x, p.y);
            const d = thumbnails.desktopAt(tp.x, tp.y);
            if (d) {
                return d;
            }
        }
        const desktops = effect.desktops;
        for (let i = 0; i < desktops.length; ++i) {
            const r = workspaceRect(i);
            if (p.x >= r.x && p.x <= r.x + r.width && p.y >= r.y && p.y <= r.y + r.height) {
                return desktops[i];
            }
        }
        return null;
    }
    function endWindowDrag(p) {
        const window = dragWindow;
        dragWindow = null;
        showDropTarget(null);
        if (!window || !p) {
            return;
        }
        const t = dropTargetAt(p);
        if (t && t.type === "newDesktop") {
            dropWindowOnNewDesktop(window, t.index);
            return;
        }
        const desktop = t ? t.desktop : null;
        if (desktop && !(window.desktops.length === 1 && window.desktops[0] === desktop)) {
            window.desktops = [desktop];
        }
    }

    // --- App icon drag and drop (GNOME's DND for app icons) -----------------------
    // Sources: the app grid and folder dialog grids (PagedGrid). Targets:
    // another icon's centre (create folder / add to folder), between icons
    // (reorder), the dash (favourite), a workspace (launch there).
    property var iconDrag: null        // {source: PagedGrid, entry, fromFolder}
    property point iconDragPoint
    property point iconDragOffset
    property int iconDragSize: 96
    property var iconDropTarget: ({type: "none"})
    property QtObject dropDesktop: null
    property bool dashDropHover: false

    function pointIn(item, p) {
        if (!item || !item.visible) {
            return false;
        }
        const q = item.mapFromItem(root, p.x, p.y);
        return q.x >= 0 && q.y >= 0 && q.x <= item.width && q.y <= item.height;
    }
    function iconDragBegin(sourceGrid, entry, pressPoint, p, iconSize) {
        iconDrag = {source: sourceGrid, entry: entry,
                    fromFolder: sourceGrid === folderDialog.grid ? folderDialog.folderName : ""};
        iconDragSize = iconSize;
        iconDragOffset = Qt.point(0, 0);
        iconDragMove(p);
    }
    function iconDragMove(p) {
        if (!iconDrag) {
            return;
        }
        iconDragPoint = p;
        const kind = iconDrag.entry.kind;
        const fromFolder = iconDrag.fromFolder.length > 0;
        let target = {type: "none"};
        if (fromFolder && !folderDialog.dragOut) {
            if (folderDialog.containsScreenPoint(p)) {
                const g = folderDialog.grid;
                target = g.dragHover(g.mapFromItem(root, p.x, p.y), kind);
                target.grid = g;
            } else {
                // dragged out of the folder: close it, continue in the main grid
                folderDialog.dragOut = true;
                folderDialog.grid.dragLeave();
                folderDialog.grid.placeholderSlot = -1;
            }
        }
        if (target.type === "none" && (!fromFolder || folderDialog.dragOut)) {
            const g = appGrid.paged;
            if (gridFactor > 0.99 && !searching && pointIn(g, p) && g.mapFromItem(root, p.x, p.y).y <= g.pageHeight) {
                target = g.dragHover(g.mapFromItem(root, p.x, p.y), kind);
                target.grid = g;
            } else {
                g.dragLeave();
            }
        }
        if (target.type === "none" && kind === "app" && pointIn(dash, p)) {
            target = dash.dragHover(dash.mapFromItem(root, p.x, p.y), iconDrag.entry.id);
        } else {
            dash.dragLeave();
        }
        if (target.type === "none" && kind === "app") {
            const t = dropTargetAt(p);
            if (t) {
                target = t;
            }
        }
        dashDropHover = target.type === "dash";
        showDropTarget(target.type === "desktop" || target.type === "newDesktop" ? target : null);
        iconDropTarget = target;
    }
    function iconDragEnd(p) {
        const drag = iconDrag;
        const target = iconDropTarget;
        // read the grid's drop position before resetting the grids
        const insertAt = target && target.grid ? target.grid.dropInsertAt() : -1;
        const targetEntry = target && target.type === "folder" ? target.grid.entries[target.index] : null;
        const sourceIndex = drag ? drag.source.dragEntryIndex : -1;
        const fromDash = drag !== null && drag.source === dash;
        const wasOut = folderDialog.dragOut;
        iconDrag = null;
        iconDropTarget = {type: "none"};
        dashDropHover = false;
        showDropTarget(null);
        appGrid.paged.dragEnd();
        folderDialog.grid.dragEnd();
        dash.dragEnd();
        folderDialog.dragOut = false;
        if (!drag || !p) {
            return;
        }
        const e = drag.entry;
        const model = effect.appLayout;
        const fromFolder = drag.fromFolder;
        // GNOME AppDisplay.acceptDrop: a favourite dropped on the grid is unpinned
        const unpinOnGridDrop = fromDash && effect.isFavorite(e.id);
        if (wasOut) {
            effect.folderOpen = "";
        }
        switch (target.type) {
        case "folder":
            if (!model) {
                break;
            }
            if (targetEntry.kind === "folder") {
                model.addToFolder(e.id, targetEntry.name);
            } else {
                const name = effect.sharedCategory([e.id, targetEntry.id]) || "Unnamed Folder";
                model.createFolder(e.id, targetEntry.id, name);
            }
            if (unpinOnGridDrop) {
                effect.removeFavorite(e.id);
            }
            break;
        case "reorder":
            if (!model) {
                break;
            }
            if (target.grid === appGrid.paged) {
                if (fromDash || fromFolder || insertAt !== sourceIndex) {
                    model.moveTo(e.id, insertAt);
                }
                if (unpinOnGridDrop) {
                    effect.removeFavorite(e.id);
                }
            } else if (target.grid === folderDialog.grid && fromFolder) {
                if (insertAt !== sourceIndex) {
                    model.moveInFolder(fromFolder, e.id, insertAt);
                }
            }
            break;
        case "dash":
            // Dash.acceptDrop: addFavoriteAtPos / moveFavoriteToPos
            if (target.pos >= 0) {
                effect.addFavorite(e.id, target.pos);
            }
            break;
        case "unpin":
            effect.removeFavorite(e.id);
            break;
        case "desktop":
            effect.launchOnDesktop(e.id, target.desktop);
            break;
        case "newDesktop":
            effect.launchOnNewDesktop(e.id, target.index);
            break;
        default:
            if (fromDash) {
                // dragged well off the dash and dropped elsewhere: unpin
                if (effect.isFavorite(e.id) && dash.mapFromItem(root, p.x, p.y).y < -dash.itemSize) {
                    effect.removeFavorite(e.id);
                }
            } else if (fromFolder && wasOut && model) {
                // dropped outside any target after leaving the folder: take it out
                model.moveTo(e.id, appGrid.entries.length);
            }
            break;
        }
    }

    // --- app context menu (GNOME AppMenu) --------------------------------------------
    property string appMenuFor: ""      // app id (no .desktop) or ""
    function openAppMenu(id, p, above) {
        appMenu.open(id, p, above);
    }

    readonly property bool searchResultsFocused: searchResults.resultsFocused
    function focusSearch() {
        searchEntry.focusInput();
    }

    function handleKey(event) {
        if (appMenuFor.length > 0) {
            if (event.key === Qt.Key_Escape) {
                appMenu.close();
                event.accepted = true;
                return;
            }
            appMenu.close();
        }
        if (event.key === Qt.Key_Escape) {
            if (effect.folderOpen.length > 0) {
                effect.folderOpen = "";
            } else if (searching) {
                effect.searchText = "";
            } else if (effect.targetState === effect.stateAppGrid) {
                effect.setState(effect.stateWindowPicker);
            } else {
                effect.hide();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (searching) {
                searchResults.activateSelected();
                event.accepted = true;
            }
        } else if (searching && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                   && (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                       || event.key === Qt.Key_Backtab
                       || ((event.key === Qt.Key_Left || event.key === Qt.Key_Right)
                           && !(event.modifiers & Qt.ShiftModifier)))) {
            // GNOME's navigateFocus; keys the entry keeps fall through to it
            if (searchResults.navigate(event.key, searchEntry.cursorAtEnd)) {
                event.accepted = true;
            }
        } else if (searching && searchResults.resultsFocused) {
            // GNOME _onStageKeyPress -> startSearch: text keys return to the entry
            // (not accepted, so the TextInput applies them); other keys stay
            if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 || event.key === Qt.Key_Backspace
                    || event.key === Qt.Key_Delete) {
                searchResults.focusEntry();
            } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                searchResults.focusEntry();
            }
        } else if (!searching && effect.folderOpen.length === 0 && effect.targetState === effect.stateAppGrid) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) {
                appGrid.previousPage();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) {
                appGrid.nextPage();
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                appGrid.goToPage(0);
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                appGrid.goToPage(appGrid.pageCount - 1);
                event.accepted = true;
            }
        } else if (!searching && effect.targetState === effect.stateWindowPicker
                   && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.AltModifier)) {
            // GNOME: Ctrl+Alt+Left/Right switch workspaces in the overview
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                effect.switchDesktop(event.key === Qt.Key_Left ? -1 : 1);
                event.accepted = true;
            }
        }
    }
    Keys.onPressed: event => handleKey(event)

    KWinComponents.WindowModel {
        id: stackModel
    }

    // --- Background: #overviewGroup is $system_base_color -----------------------
    Item {
        anchors.fill: parent
        opacity: root.pickerFactor
        visible: opacity > 0
        KWinComponents.DesktopBackground {
            id: wallpaper
            anchors.fill: parent
            activity: KWinComponents.Workspace.currentActivity
            desktop: KWinComponents.Workspace.currentDesktop
            outputName: root.targetScreen.name
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            visible: effect.blurBackground
            source: wallpaper
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            saturation: -0.2
        }
        Rectangle {
            // solid GNOME background, or a GNOME-coloured tint over the blur
            anchors.fill: parent
            color: L.SYSTEM_BASE_COLOR
            opacity: effect.blurBackground ? 0.88 : 1
        }
    }

    // Empty space: the window picker closes, the app grid goes back to the picker.
    // Scrolling over the window picker switches workspaces.
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        onClicked: {
            if (effect.targetState === effect.stateAppGrid && !root.searching) {
                effect.setState(effect.stateWindowPicker);
            } else {
                effect.hide();
            }
        }
        property real pixelAccum: 0
        onWheel: wheel => {
            if (effect.targetState !== effect.stateWindowPicker || root.searching) {
                return;
            }
            const px = Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y) ? -wheel.pixelDelta.x : -wheel.pixelDelta.y;
            if (px !== 0) {
                // touchpad: the workspaces follow the fingers, snap when they stop
                pixelAccum += px;
                effect.wsGestureUpdate(pixelAccum / (root.width * 0.5));
                wheelSnap.restart();
                return;
            }
            if (wheelLock.running) {
                return;
            }
            const delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? -wheel.angleDelta.x : -wheel.angleDelta.y;
            if (delta !== 0 && effect.switchDesktop(delta > 0 ? 1 : -1)) {
                wheelLock.restart();
            }
        }
        Timer {
            id: wheelLock
            interval: 150
        }
        Timer {
            id: wheelSnap
            interval: 120
            onTriggered: {
                const p = parent.pixelAccum / (root.width * 0.5);
                parent.pixelAccum = 0;
                effect.wsGestureEnd(Math.abs(p) > 0.25, p > 0 ? 1 : -1);
            }
        }
    }

    // --- Workspaces ---------------------------------------------------------------
    Item {
        id: workspaces
        anchors.fill: parent
        z: 2
        Repeater {
            model: KWinComponents.VirtualDesktopModel {}
            delegate: WorkspaceView {
                screenView: root
                windowModel: stackModel
                box: root.workspaceRect(index)
                z: index === effect.currentIndex ? 2 : 1
            }
        }
    }

    // Panels/docks fade out like in KWin's overview.
    Repeater {
        model: KWinComponents.WindowFilterModel {
            activity: KWinComponents.Workspace.currentActivity
            desktop: KWinComponents.Workspace.currentDesktop
            screenName: root.targetScreen.name
            windowModel: stackModel
            windowType: KWinComponents.WindowFilterModel.Dock
        }
        KWinComponents.WindowThumbnail {
            required property QtObject window
            wId: window.internalId
            x: window.x - root.targetScreen.geometry.x
            y: window.y - root.targetScreen.geometry.y
            z: 30
            width: window.width
            height: window.height
            opacity: 1 - root.pickerFactor
            visible: !window.hidden && opacity > 0
        }
    }

    // --- Workspace thumbnails ---------------------------------------------------
    // _getThumbnailsBoxParams: APP_GRID -> opacity 0, scale 0.5, translationY h/2
    WorkspaceThumbnails {
        id: thumbnails
        z: 40
        x: 0
        y: root.searchHeight + Math.round(root.spacing * L.THUMBNAILS_SPACING_ADJUSTMENT_TOP)
        width: root.width
        height: root.thumbnailsHeight
        screenView: root
        windowModel: stackModel
        opacity: root.pickerFactor * (1 - root.gridFactor) * root.workspacesOpacity
        scale: L.lerp(1, 0.5, root.gridFactor)
        transform: Translate { y: root.gridFactor * thumbnails.height / 2 }
        visible: root.thumbnailsShown && opacity > 0
        enabled: root.interactive && effect.targetState === effect.stateWindowPicker
        placeholderPos: root.dropNew.where === "thumbnails" ? root.dropNew.index : -1
    }

    // drop placeholder between two workspaces of the app grid's strip
    Rectangle {
        z: 41
        readonly property int index: root.dropNew.where === "strip" ? root.dropNew.index : -1
        readonly property var r: index >= 0 ? root.workspaceRect(index) : null
        readonly property var prev: index > 0 ? root.workspaceRect(index - 1) : null
        visible: r !== null
        width: Math.max(2, Math.round(4 * root.s))
        height: r ? r.height : 0
        radius: width / 2
        x: r ? (prev ? (prev.x + prev.width + r.x) / 2 : r.x - root.cutSize) - width / 2 : 0
        y: r ? r.y : 0
        color: Kirigami.Theme.highlightColor
    }

    // --- App grid ---------------------------------------------------------------
    AppGrid {
        id: appGrid
        z: 45
        x: root.appDisplayBox.x
        y: root.appDisplayBox.y
        width: root.appDisplayBox.width
        height: root.appDisplayBox.height
        screenView: root
        opacity: root.gridFactor * (root.searching ? 0 : 1)
        visible: opacity > 0
        enabled: root.interactive && effect.targetState === effect.stateAppGrid && !root.searching
    }

    // --- Search -----------------------------------------------------------------
    SearchEntry {
        id: searchEntry
        z: 70
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.searchTop
        screenView: root
        focus: true
        opacity: root.pickerFactor
    }

    SearchResults {
        id: searchResults
        z: 65
        x: root.searchBox.x
        y: root.searchBox.y
        width: root.searchBox.width
        height: root.searchBox.height
        screenView: root
        active: root.searching
        opacity: root.searching ? root.pickerFactor : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // --- Dash -------------------------------------------------------------------
    Dash {
        id: dash
        z: 60
        anchors.horizontalCenter: parent.horizontalCenter
        maxWidth: root.width - 2 * root.spacing
        maxHeight: Math.round(root.height * L.DASH_MAX_HEIGHT_RATIO)
        screenView: root
        windowModel: stackModel
        // slide in from the bottom edge
        y: root.height - root.dashHeight * root.pickerFactor
        opacity: root.pickerFactor
        enabled: root.interactive
    }

    // drag proxy (windowPreview.js WINDOW_DND_SIZE 256)
    KWinComponents.WindowThumbnail {
        id: dragProxy
        z: 90
        visible: root.dragWindow !== null
        wId: root.dragWindow ? root.dragWindow.internalId : ""
        readonly property real f: root.dragWindow ? Math.min(1, 256 * root.s / Math.max(root.dragWindow.width, root.dragWindow.height)) : 1
        width: root.dragWindow ? root.dragWindow.width * f : 0
        height: root.dragWindow ? root.dragWindow.height * f : 0
        x: root.dragPoint.x - width / 2
        y: root.dragPoint.y - height / 2
    }

    // --- App folder dialog ---------------------------------------------------------
    FolderDialog {
        id: folderDialog
        z: 80
        anchors.fill: parent
        screenView: root
        appGrid: appGrid
    }

    // dragged app icon / folder
    Item {
        id: iconDragProxy
        z: 95
        visible: root.iconDrag !== null
        width: root.iconDragSize
        height: root.iconDragSize
        x: root.iconDragPoint.x - width / 2
        y: root.iconDragPoint.y - height / 2
        readonly property var entry: root.iconDrag ? root.iconDrag.entry : null
        AsyncIcon {
            anchors.fill: parent
            visible: parent.entry !== null && parent.entry.kind === "app"
            readonly property var app: !visible ? null : parent.entry.app ? parent.entry.app
                                       : effect.backend ? effect.backend.appAt("apps", parent.entry.index) : null
            size: root.iconDragSize
            iconPath: app ? app.iconPath : ""
            fallback: app ? app.icon : ""
        }
        FolderIcon {
            visible: parent.entry !== null && parent.entry.kind === "folder"
            anchors.centerIn: parent
            width: root.iconDragSize + Math.round(24 * root.s)
            height: width
            iconSize: root.iconDragSize
            s: root.s
            showLabel: false
            backend: effect.backend
            folder: visible ? parent.entry : null
        }
    }

    AppMenu {
        id: appMenu
        z: 98
        anchors.fill: parent
        screenView: root
    }

    // Shown only if no backend could be created at all.
    Text {
        z: 100
        visible: !effect.backend && effect.backendError.length > 0
        anchors.centerIn: parent
        color: "white"
        text: "kgnome-overview: no app backend\n" + effect.backendError
    }
}
