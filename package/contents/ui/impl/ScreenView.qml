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

    function focusSearch() {
        searchEntry.focusInput();
    }

    function handleKey(event) {
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
                searchResults.activateFirst();
                event.accepted = true;
            }
        } else if (searching && (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)) {
            searchResults.focusResults();
            event.accepted = true;
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

    // --- App folder dialog ---------------------------------------------------------
    FolderDialog {
        id: folderDialog
        z: 80
        anchors.fill: parent
        screenView: root
        grid: appGrid
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
