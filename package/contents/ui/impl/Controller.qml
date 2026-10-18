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

    function setState(s) {
        if (s !== stateHidden) {
            sceneEffect.visible = true;
        }
        if (s === targetState && stateAnim.running === false && stateValue === s) {
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
        }
    }

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
        KWinComponents.ScreenEdgeHandler {
            enabled: effect.cfg ? effect.cfg.TopRightCorner === true : false
            edge: KWinComponents.ScreenEdgeHandler.TopRightEdge
            onActivated: effect.toggleOverview()
        }
    ]

    Component.onCompleted: {
        console.info("kgnome-overview: controller loaded from", Qt.resolvedUrl("."));
        createBackend();
    }
}
