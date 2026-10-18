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
    readonly property var favoriteIds: (cfg && cfg.FavoriteApps) ? cfg.FavoriteApps.filter(s => s.length > 0) : []
    readonly property int gestureFingers: (cfg && cfg.GestureFingers !== undefined) ? cfg.GestureFingers : 3
    readonly property var folderSpecs: (cfg && cfg.AppFolders) ? cfg.AppFolders.filter(s => s.length > 0) : []

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
        Instantiator {
            model: effect.gestureFingers > 0 && effect.visible ? 2 : 0
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
        KWinComponents.ScreenEdgeHandler {
            enabled: effect.cfg ? effect.cfg.TopRightCorner === true : false
            edge: KWinComponents.ScreenEdgeHandler.TopRightEdge
            onActivated: effect.toggleOverview()
        }
    ]

    Component.onCompleted: {
        console.info("kgnome-overview: controller loaded from", Qt.resolvedUrl("."));
        createBackend();
        rebuildRunning();
    }
}
