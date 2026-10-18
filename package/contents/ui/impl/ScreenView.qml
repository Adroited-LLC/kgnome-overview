// SPDX-License-Identifier: GPL-2.0-or-later
// One overview per screen. Geometry follows GNOME's ControlsManagerLayout:
// every region has a box per state and is blended by effect.stateValue.
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
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

    // UI scale: GNOME sizes are in logical px; follow the Plasma font size.
    readonly property real s: Kirigami.Units.gridUnit / 18

    // --- GNOME ControlsManagerLayout metrics --------------------------------
    readonly property int spacing: Math.round(height * L.VERTICAL_SPACING_RATIO)
    readonly property int searchTop: Math.round(spacing * 0.75)
    readonly property int searchHeight: searchTop + searchEntry.height
    readonly property int dashHeight: Math.min(dash.implicitHeight, Math.round(height * L.DASH_MAX_HEIGHT_RATIO))
    readonly property int thumbnailsHeight: Math.round(height * L.MAX_THUMBNAIL_SCALE)
    readonly property var metrics: ({
        width: width, height: height, startY: 0,
        spacing: spacing, searchHeight: searchHeight, dashHeight: dashHeight,
        thumbnailsHeight: thumbnailsHeight, expandFraction: 1,
    })

    readonly property var pickerCard: L.fitAspect(L.workspacesBox(1, metrics), screenAspect)
    readonly property var gridCard: L.fitAspect(L.workspacesBox(2, metrics), screenAspect)
    // Workspace card: full screen when hidden, shrinking with the state.
    readonly property var workspaceCard: sv <= 1
        ? L.lerpRect(L.rect(0, 0, width, height), pickerCard, pickerFactor)
        : L.lerpRect(pickerCard, gridCard, gridFactor)
    // Window layout area: fixed during HIDDEN<->PICKER (ExpoCell interpolates
    // from the natural window geometry), shrinking towards the grid strip.
    readonly property var layoutArea: {
        const card = sv <= 1 ? pickerCard : L.lerpRect(pickerCard, gridCard, gridFactor);
        const pad = Math.round(L.lerp(spacing * 0.75, spacing * 0.15, gridFactor));
        return L.inset(card, pad, pad);
    }
    readonly property var appDisplayBox: L.blend(L.appDisplayBox, sv, metrics)
    readonly property var searchBox: L.searchBox(metrics)
    readonly property real cardRadius: Math.round(L.lerp(0, 18 * s, pickerFactor) * L.lerp(1, 0.6, gridFactor))

    function focusSearch() {
        searchEntry.focusInput();
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (searching) {
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
        } else if (!searching && effect.targetState === effect.stateAppGrid) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) {
                appGrid.previousPage();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) {
                appGrid.nextPage();
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                appGrid.currentPage = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                appGrid.currentPage = appGrid.pageCount - 1;
                event.accepted = true;
            }
        }
    }
    Keys.onPressed: event => handleKey(event)

    KWinComponents.WindowModel {
        id: stackModel
    }

    // --- Background -----------------------------------------------------------
    KWinComponents.DesktopBackground {
        id: wallpaper
        anchors.fill: parent
        activity: KWinComponents.Workspace.currentActivity
        desktop: KWinComponents.Workspace.currentDesktop
        outputName: root.targetScreen.name
        visible: !effect.blurBackground
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
        // dark translucent shade, a bit darker for the app grid
        anchors.fill: parent
        color: "#000000"
        opacity: 0.45 * root.pickerFactor + 0.15 * root.gridFactor
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        onClicked: effect.hide()
    }

    // --- Workspace card (current desktop) --------------------------------------
    Item {
        id: card
        x: root.workspaceCard.x
        y: root.workspaceCard.y
        width: root.workspaceCard.width
        height: root.workspaceCard.height
        z: 1
        visible: !root.searching || opacity > 0
        opacity: root.searching ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: effect.animationDuration; easing.type: Easing.OutQuad } }

        KWinComponents.DesktopBackground {
            id: cardBackground
            anchors.fill: parent
            activity: KWinComponents.Workspace.currentActivity
            desktop: KWinComponents.Workspace.currentDesktop
            outputName: root.targetScreen.name
            layer.enabled: root.cardRadius > 0
            layer.effect: GE.OpacityMask {
                maskSource: Rectangle {
                    width: cardBackground.width
                    height: cardBackground.height
                    radius: root.cardRadius
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            onClicked: {
                if (effect.targetState === effect.stateAppGrid) {
                    effect.setState(effect.stateWindowPicker);
                } else {
                    effect.hide();
                }
            }
        }
    }
    // soft shadow under the card
    RectangularShadow {
        x: card.x; y: card.y; width: card.width; height: card.height
        z: 0.5
        radius: root.cardRadius
        blur: 24 * root.s
        color: Qt.rgba(0, 0, 0, 0.45 * root.pickerFactor)
        visible: root.pickerFactor > 0 && card.opacity > 0
        opacity: card.opacity
    }

    // --- Windows --------------------------------------------------------------
    WindowPicker {
        id: windowPicker
        z: 2
        x: root.layoutArea.x
        y: root.layoutArea.y
        width: root.layoutArea.width
        height: root.layoutArea.height
        contentParent: windowLayer
        screenView: root
        windowModel: stackModel
        opacity: card.opacity
    }
    Item {
        // thumbnails' content items live here, in screen coordinates
        id: windowLayer
        anchors.fill: parent
        z: 3
        opacity: card.opacity
        visible: opacity > 0
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
    WorkspaceThumbnails {
        id: thumbnails
        z: 40
        x: 0
        y: root.searchHeight + Math.round(root.spacing * L.THUMBNAILS_SPACING_ADJUSTMENT_TOP)
        width: root.width
        height: root.thumbnailsHeight
        screenView: root
        windowModel: stackModel
        opacity: root.pickerFactor * (1 - root.gridFactor) * (root.searching ? 0 : 1)
        visible: opacity > 0
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

    // Shown only if no backend could be created at all.
    Text {
        z: 100
        visible: !effect.backend && effect.backendError.length > 0
        anchors.centerIn: parent
        color: "white"
        text: "kgnome-overview: no app backend\n" + effect.backendError
    }
}
