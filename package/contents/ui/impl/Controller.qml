// SPDX-License-Identifier: GPL-2.0-or-later
// kgnome-overview: a GNOME Shell style overview for KWin (Plasma 6).
import QtQuick
import org.kde.kwin as KWinComponents
import "Layout.js" as L

// State machine, shortcuts and app backend. Views reach it as
// SceneView.effect.controller and call it "effect".
QtObject {
    id: effect

    required property QtObject sceneEffect
    readonly property bool visible: sceneEffect.visible

    // GNOME's OverviewControls.ControlsState
    readonly property int stateHidden: 0
    readonly property int stateWindowPicker: 1
    readonly property int stateAppGrid: 2

    readonly property int animationDuration: L.SIDE_CONTROLS_ANIMATION_TIME

    // Single animated state value 0..2, like GNOME's _stateAdjustment.
    property real stateValue: 0
    property int targetState: stateHidden
    property string searchText: ""
    property QtObject backend: null
    property string backendError: ""

    readonly property bool active: visible && targetState !== stateHidden
    readonly property var cfg: sceneEffect.configuration
    readonly property real iconScale: (cfg && cfg.IconScale > 0) ? cfg.IconScale : 1.0
    readonly property bool blurBackground: cfg ? cfg.BlurBackground !== false : true
    readonly property var configFavoriteIds: (cfg && cfg.FavoriteApps) ? cfg.FavoriteApps.filter(s => s.length > 0) : []
    // dash favourites: shared with Kickoff (Favorites.qml) or FavoriteApps
    readonly property string favoritesClient: (cfg && cfg.FavoritesClient) ? String(cfg.FavoritesClient) : ""
    property QtObject sharedFavorites: null
    readonly property bool favoritesShared: sharedFavorites !== null && sharedFavorites.ready
    readonly property var favoriteIds: favoritesShared ? sharedFavorites.ids : configFavoriteIds
    readonly property bool hideFavoritesInGrid: cfg ? cfg.HideFavoritesInGrid !== false : true
    readonly property int dashIconSize: (cfg && cfg.DashIconSize > 0) ? cfg.DashIconSize : 64
    readonly property int searchFocusReturnMs: (cfg && cfg.SearchFocusReturnMs !== undefined) ? cfg.SearchFocusReturnMs : 250
    onFavoritesClientChanged: createSharedFavorites()
    function createSharedFavorites() {
        if (sharedFavorites && sharedFavorites.client === favoritesClient) {
            return;
        }
        if (sharedFavorites) {
            sharedFavorites.destroy();
            sharedFavorites = null;
        }
        if (favoritesClient.length === 0) {
            return;
        }
        const c = Qt.createComponent(Qt.resolvedUrl("Favorites.qml"));
        sharedFavorites = c.status === Component.Ready ? c.createObject(effect, {client: favoritesClient}) : null;
        console.info("kgnome-overview: favourites", sharedFavorites ? "shared with " + favoritesClient : "from FavoriteApps (" + c.errorString().trim() + ")");
    }
    readonly property int hotCorner: (cfg && cfg.HotCorner !== undefined) ? cfg.HotCorner : 1
    // GNOME dynamic workspaces (DynamicWorkspaces.qml)
    readonly property bool dynamicWorkspaces: cfg ? cfg.DynamicWorkspaces !== false : true
    property QtObject dyn: null
    readonly property int gestureFingers: (cfg && cfg.GestureFingers !== undefined) ? cfg.GestureFingers : 4
    // App grid size: IconSize px (0 = GNOME's automatic 96..16), Columns
    // (0 = GNOME's 8x3/6x4/4x6/3x8 modes), Rows (0 = automatic)
    readonly property int gridIconSize: (cfg && cfg.IconSize !== undefined) ? cfg.IconSize : 112
    readonly property int gridColumns: (cfg && cfg.Columns !== undefined) ? cfg.Columns : 10
    readonly property int gridRows: (cfg && cfg.Rows !== undefined) ? cfg.Rows : 0

    // Persist a setting (KConfigPropertyMap autosaves to kwinrc).
    function writeConfig(key, value) {
        if (cfg) {
            cfg[key] = value;
            cfg.writeConfig();
        }
    }

    // Grid arrangement and folders (AppLayoutModel.qml)
    property QtObject appLayout: null
    property QtObject categories: null
    function ensureCategories() {
        if (!categories) {
            const c = Qt.createComponent(Qt.resolvedUrl("Categories.qml"));
            categories = c.status === Component.Ready ? c.createObject(effect) : null;
            if (!categories) {
                console.info("kgnome-overview: categories unavailable:", c.errorString());
            }
        }
    }
    function sharedCategory(ids) {
        ensureCategories();
        try {
            return categories ? categories.sharedCategory(ids) : "";
        } catch (e) {
            return "";
        }
    }

    // Favourites (GNOME AppFavorites: addFavoriteAtPos, moveFavoriteToPos,
    // removeFavorite). Without a shared launcher list the current dash is
    // copied into FavoriteApps on the first change.
    function normalizedFavorite(storageId) {
        return storageId.endsWith(".desktop") ? storageId : storageId + ".desktop";
    }
    function isFavorite(storageId) {
        return favoriteIds.indexOf(normalizedFavorite(storageId)) >= 0;
    }
    function currentFavoriteList() {
        let ids = configFavoriteIds.slice();
        if (ids.length === 0 && backend) {
            for (let i = 0; i < backend.count("favorites"); ++i) {
                const a = backend.appAt("favorites", i);
                if (a && a.storageId) {
                    ids.push(a.storageId);
                }
            }
        }
        return ids;
    }
    // position: index in the favourites without the app itself (-1 = end)
    function addFavorite(storageId, position) {
        const id = normalizedFavorite(storageId);
        if (favoritesShared) {
            sharedFavorites.add(id, position);
            return;
        }
        let ids = currentFavoriteList().filter(x => x !== id);
        ids.splice(position >= 0 ? Math.min(position, ids.length) : ids.length, 0, id);
        writeConfig("FavoriteApps", ids);
    }
    function removeFavorite(storageId) {
        const id = normalizedFavorite(storageId);
        if (favoritesShared) {
            sharedFavorites.remove(id);
            return;
        }
        const ids = currentFavoriteList().filter(x => x !== id);
        // an empty list means "launcher favourites"; keep one placeholder entry
        writeConfig("FavoriteApps", ids.length > 0 ? ids : ["none.desktop"]);
    }
    // GNOME AppMenu "Quit": close every window of the app
    function quitApp(storageId) {
        const wins = windowsFor(storageId).slice();
        for (const w of wins) {
            w.closeWindow();
        }
    }
    function newWindow(storageId) {
        if (backend && backend.launchId(normalizedFavorite(storageId))) {
            hide();
        }
    }
    function launchOnDesktop(storageId, desktop) {
        if (desktop && KWinComponents.Workspace.currentDesktop !== desktop) {
            KWinComponents.Workspace.currentDesktop = desktop;
        }
        if (backend && backend.launchId(storageId.endsWith(".desktop") ? storageId : storageId + ".desktop")) {
            hide();
        }
    }

    // --- Workspaces (GNOME's _scrollAdjustment) -----------------------------
    readonly property var desktops: KWinComponents.Workspace.desktops
    readonly property int desktopCount: desktops.length
    readonly property int currentIndex: Math.max(0, desktops.indexOf(KWinComponents.Workspace.currentDesktop))
    // fractional index of the workspace shown in the middle; animated
    property real workspacePos: currentIndex
    property bool workspaceDragging: false
    onCurrentIndexChanged: {
        if (workspaceDragging) {
            return;
        }
        if (!visible) {
            workspacePos = currentIndex;
            return;
        }
        animateWorkspacePos(currentIndex);
    }
    function animateWorkspacePos(to) {
        wsAnim.stop();
        wsAnim.from = workspacePos;
        wsAnim.to = to;
        wsAnim.start();
    }
    function switchDesktop(delta) {
        const i = Math.max(0, Math.min(desktopCount - 1, currentIndex + delta));
        if (i !== currentIndex) {
            KWinComponents.Workspace.currentDesktop = desktops[i];
            return true;
        }
        return false;
    }
    function activateDesktop(desktop) {
        if (KWinComponents.Workspace.currentDesktop === desktop) {
            hide();
        } else {
            KWinComponents.Workspace.currentDesktop = desktop;
        }
    }

    // --- Gestures: the state follows the finger, like GNOME's swipe tracker --
    property real gestureFrom: 0
    property bool gestureActive: false
    function gestureBegin() {
        if (gestureActive) {
            return;
        }
        stateAnim.stop();
        gestureFrom = visible ? Math.round(stateValue) : stateHidden;
        gestureActive = true;
    }
    function gestureUpdate(delta) {    // delta in states, + towards the app grid
        if (!gestureActive) {
            gestureBegin();
        }
        const v = Math.max(0, Math.min(2, gestureFrom + delta));
        if (v > 0 && !visible) {
            sceneEffect.visible = true;
        }
        targetState = Math.round(v);
        stateValue = v;
    }
    function gestureEnd(commit, direction) {
        if (!gestureActive) {
            return;
        }
        gestureActive = false;
        const to = commit ? Math.max(0, Math.min(2, gestureFrom + direction)) : gestureFrom;
        if (to === stateHidden && !visible) {
            return;
        }
        targetState = -1; // force setState to animate
        setState(to);
    }

    function wsGestureUpdate(delta) {   // delta in workspaces, + towards the next one
        if (!workspaceDragging) {
            wsAnim.stop();
            workspaceDragging = true;
            wsGestureFrom = currentIndex;
        }
        workspacePos = Math.max(-0.15, Math.min(desktopCount - 0.85, wsGestureFrom + delta));
    }
    property int wsGestureFrom: 0
    function wsGestureEnd(commit, direction) {
        if (!workspaceDragging) {
            return;
        }
        workspaceDragging = false;
        const target = Math.max(0, Math.min(desktopCount - 1, wsGestureFrom + (commit ? direction : 0)));
        animateWorkspacePos(target);
        if (target !== currentIndex) {
            KWinComponents.Workspace.currentDesktop = desktops[target];
        }
    }

    function setState(s) {
        if (s !== stateHidden) {
            sceneEffect.visible = true;
        }
        if (s === targetState && !stateAnim.running && stateValue === s) {
            return;
        }
        targetState = s;
        stateAnim.stop();
        stateAnim.from = stateValue;
        stateAnim.to = s;
        stateAnim.start();
    }
    function hide() {
        setState(stateHidden);
    }
    function toggleOverview() {
        if (active) {
            hide();
        } else {
            setState(stateWindowPicker);
        }
    }
    function toggleAppGrid() {
        if (active && targetState === stateAppGrid) {
            hide();
        } else {
            setState(stateAppGrid);
        }
    }

    function activateWindow(window) {
        KWinComponents.Workspace.activeWindow = window;
        hide();
    }
    function launch(which, row) {
        if (backend && backend.launch(which, row)) {
            hide();
        }
    }

    // GNOME AppIcon activation: a running app is focused (most recent window),
    // middle- or Ctrl-click opens a new window.
    function launchApp(which, row, button, modifiers) {
        const app = backend ? backend.appAt(which, row) : null;
        const wins = app ? windowsFor(app.storageId) : [];
        if (wins.length > 0 && button === Qt.LeftButton && !(modifiers & Qt.ControlModifier)) {
            activateWindow(wins[wins.length - 1]);
        } else {
            launch(which, row);
        }
    }

    function createBackend() {
        const choice = cfg && cfg.Backend ? String(cfg.Backend) : "auto";
        const all = {module: "BackendModule.qml", local: "BackendLocal.qml", kicker: "BackendKicker.qml"};
        const order = all[choice] ? [all[choice]] : [all.module, all.local, all.kicker];
        let errors = [];
        for (const file of order) {
            const component = Qt.createComponent(Qt.resolvedUrl(file));
            if (component.status === Component.Ready) {
                const obj = component.createObject(effect, {searchText: Qt.binding(() => effect.searchText),
                                                            favoriteIds: Qt.binding(() => effect.favoriteIds)});
                if (obj) {
                    backend = obj;
                    console.info("kgnome-overview: using backend", obj.kind, "from", file);
                    return;
                }
            }
            errors.push(file + ": " + component.errorString().trim());
            console.info("kgnome-overview: backend", file, "unavailable:", component.errorString().trim());
        }
        backendError = errors.join("\n");
        console.warn("kgnome-overview: no backend could be loaded");
    }

    onVisibleChanged: {
        if (!visible) {
            stateAnim.stop();
            stateValue = 0;
            targetState = stateHidden;
            searchText = "";
            gestureActive = false;
            workspaceDragging = false;
            wsAnim.stop();
            workspacePos = currentIndex;
            folderOpen = "";
        }
    }

    // Running apps by desktop file name (dash and grid running dots).
    // Workspace.stackingOrder has no change signal, so rebuild on window events.
    property var runningWindows: ({})
    // running apps in the order they started (GNOME's dash keeps running
    // non-favourites after the separator)
    property var runningIds: []
    function rebuildRunning() {
        const map = {};
        const order = KWinComponents.Workspace.stackingOrder;
        for (let i = 0; i < order.length; ++i) {
            const w = order[i];
            if (!w || !w.normalWindow || w.skipTaskbar || !w.desktopFileName) {
                continue;
            }
            (map[w.desktopFileName] = map[w.desktopFileName] || []).push(w);
        }
        runningWindows = map;
        const ids = runningIds.filter(id => map[id] !== undefined);
        for (const id in map) {
            if (ids.indexOf(id) < 0) {
                ids.push(id);
            }
        }
        if (ids.join(",") !== runningIds.join(",")) {
            runningIds = ids;
        }
    }
    function windowsFor(storageId) {
        if (!storageId) {
            return [];
        }
        const id = storageId.endsWith(".desktop") ? storageId.slice(0, -8) : storageId;
        return runningWindows[id] || [];
    }

    // Horizontal touchpad swipes in the app grid page the grid (AppGrid listens).
    signal pageGesture(real delta, bool finished, bool commit)

    // name of the open app folder ("" = none)
    property string folderOpen: ""

    readonly property list<QtObject> _objects: [
        NumberAnimation {
            id: stateAnim
            target: effect
            property: "stateValue"
            duration: effect.animationDuration
            easing.type: Easing.OutQuad
            onFinished: {
                if (effect.targetState === effect.stateHidden) {
                    effect.sceneEffect.visible = false;
                }
            }
        },
        Connections {
            target: KWinComponents.Workspace
            function onWindowAdded() { Qt.callLater(effect.rebuildRunning) }
            function onWindowRemoved() { Qt.callLater(effect.rebuildRunning) }
            function onWindowActivated() { Qt.callLater(effect.rebuildRunning) }
        },
        NumberAnimation {
            id: wsAnim
            target: effect
            property: "workspacePos"
            duration: L.WORKSPACE_SWITCH_TIME
            easing.type: Easing.OutCubic
        },
        KWinComponents.ShortcutHandler {
            name: "Toggle GNOME Overview"
            text: "Toggle GNOME Overview"
            sequence: "Meta+O"
            onActivated: effect.toggleOverview()
        },
        KWinComponents.ShortcutHandler {
            name: "Toggle GNOME App Grid"
            text: "Toggle GNOME App Grid"
            sequence: "Meta+Shift+O"
            onActivated: effect.toggleAppGrid()
        },
        // Vertical swipes: up = hidden -> picker -> app grid, down = back.
        Instantiator {
            model: effect.gestureFingers > 0 ? 1 : 0
            delegate: KWinComponents.SwipeGestureHandler {
                direction: KWinComponents.SwipeGestureHandler.Direction.Up
                fingerCount: effect.gestureFingers
                deviceType: KWinComponents.SwipeGestureHandler.Device.Touchpad
                property real last: 0
                onProgressChanged: if (progress > 0) { last = progress; effect.gestureUpdate(progress); }
                onActivated: { effect.gestureEnd(true, 1); last = 0; }
                onCancelled: { effect.gestureEnd(last > 0.5, 1); last = 0; }
            }
        },
        // The other directions only exist while the overview is shown, so
        // they never steal gestures from apps.
        Instantiator {
            model: effect.gestureFingers > 0 && effect.visible ? 1 : 0
            delegate: KWinComponents.SwipeGestureHandler {
                direction: KWinComponents.SwipeGestureHandler.Direction.Down
                fingerCount: effect.gestureFingers
                deviceType: KWinComponents.SwipeGestureHandler.Device.Touchpad
                property real last: 0
                onProgressChanged: if (progress > 0) { last = progress; effect.gestureUpdate(-progress); }
                onActivated: { effect.gestureEnd(true, -1); last = 0; }
                onCancelled: { effect.gestureEnd(last > 0.5, -1); last = 0; }
            }
        },
        // Left/right: KWin itself switches desktops with 3 and 4 fingers
        // (VirtualDesktopManager), and the overview follows the current
        // desktop, so only other finger counts get our own handlers.
        Instantiator {
            model: effect.gestureFingers > 0 && effect.gestureFingers !== 3 && effect.gestureFingers !== 4
                   && effect.visible ? 2 : 0
            // index 0: fingers move left -> next workspace / page; 1: right -> previous
            delegate: KWinComponents.SwipeGestureHandler {
                required property int index
                readonly property int sign: index === 0 ? 1 : -1
                direction: index === 0 ? KWinComponents.SwipeGestureHandler.Direction.Left
                                       : KWinComponents.SwipeGestureHandler.Direction.Right
                fingerCount: effect.gestureFingers
                deviceType: KWinComponents.SwipeGestureHandler.Device.Touchpad
                property real last: 0
                function update(p, finished, commit) {
                    if (effect.targetState === effect.stateAppGrid) {
                        effect.pageGesture(sign * p, finished, commit);
                    } else if (finished) {
                        effect.wsGestureEnd(commit, sign);
                    } else {
                        effect.wsGestureUpdate(sign * p);
                    }
                }
                onProgressChanged: if (progress > 0) { last = progress; update(progress, false, false); }
                onActivated: { update(last, true, true); last = 0; }
                onCancelled: { update(last, true, last > 0.5); last = 0; }
            }
        },
        // GNOME's hot corner (top left by default, HotCorner setting)
        KWinComponents.ScreenEdgeHandler {
            enabled: effect.hotCorner > 0
            edge: [KWinComponents.ScreenEdgeHandler.NoEdge, KWinComponents.ScreenEdgeHandler.TopLeftEdge,
                   KWinComponents.ScreenEdgeHandler.TopRightEdge, KWinComponents.ScreenEdgeHandler.BottomLeftEdge,
                   KWinComponents.ScreenEdgeHandler.BottomRightEdge][Math.max(0, Math.min(4, effect.hotCorner))]
            onActivated: effect.toggleOverview()
        }
    ]

    Component.onCompleted: {
        console.info("kgnome-overview: controller loaded from", Qt.resolvedUrl("."));
        createSharedFavorites();
        createBackend();
        rebuildRunning();
        const dc = Qt.createComponent(Qt.resolvedUrl("DynamicWorkspaces.qml"));
        dyn = dc.status === Component.Ready ? dc.createObject(effect, {enabled: Qt.binding(() => effect.dynamicWorkspaces)}) : null;
        if (!dyn) {
            console.warn("kgnome-overview: DynamicWorkspaces:", dc.errorString());
        }
        const lc = Qt.createComponent(Qt.resolvedUrl("AppLayoutModel.qml"));
        appLayout = lc.createObject(effect, {effect: effect});
        // Kicker's category models populate asynchronously; create them early
        Qt.callLater(ensureCategories);
        if (!appLayout) {
            console.warn("kgnome-overview: AppLayoutModel:", lc.errorString());
        }
    }
}
