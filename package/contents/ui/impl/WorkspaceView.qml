// SPDX-License-Identifier: GPL-2.0-or-later
// One workspace of GNOME's WorkspacesView: the wallpaper with rounded
// corners (workspace-background, 30px) and the windows, which are spread out
// by KWin's ExpoLayout in the window picker (workspace mode 1) and sit at
// their natural positions in the app grid (workspace mode 0), exactly like
// WorkspacesView._updateWorkspacesState.
//
// The item is screen-sized and scaled into its box, so window coordinates are
// simply window.x - screen.x and the layout never has to be recomputed while
// the overview animates.
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import org.kde.kwin.private.effects
import "Layout.js" as L

Item {
    id: ws

    required property QtObject desktop
    required property int index
    required property Item screenView
    required property QtObject windowModel
    required property var box           // on-screen rect from ScreenView.workspaceRect()

    readonly property QtObject effect: screenView.effect
    readonly property QtObject targetScreen: screenView.targetScreen
    readonly property bool current: KWinComponents.Workspace.currentDesktop === desktop
    readonly property real cardScale: box.width / Math.max(1, width)
    readonly property real s: screenView.s
    // screen px -> local px
    function px(v) {
        return v / Math.max(0.05, cardScale);
    }
    // WorkspacesView: (1 - fitMode) * lerp(mode(initial), mode(final))
    readonly property real workspaceMode: screenView.pickerFactor * (1 - screenView.gridFactor)
    readonly property bool onScreen: box.x < screenView.width && box.x + box.width > 0
    readonly property alias windowCount: windowRepeater.count

    width: screenView.width
    height: screenView.height
    x: box.x
    y: box.y
    scale: cardScale
    transformOrigin: Item.TopLeft
    visible: onScreen && screenView.workspacesOpacity > 0
    opacity: screenView.workspacesOpacity

    // workspace-background: box-shadow 0 4px 16px 4px rgba(0,0,0,0.2)
    RectangularShadow {
        anchors.fill: background
        offset.y: ws.px(4 * ws.s)
        spread: ws.px(4 * ws.s)
        blur: ws.px(16 * ws.s)
        radius: background.radius
        color: Qt.rgba(0, 0, 0, 0.2 * ws.screenView.pickerFactor)
        visible: ws.screenView.pickerFactor > 0
    }
    Item {
        id: background
        anchors.fill: parent
        // BACKGROUND_CORNER_RADIUS_PIXELS, scaled with the workspace like in GNOME
        readonly property real radius: L.BACKGROUND_CORNER_RADIUS_PIXELS * ws.s * ws.screenView.pickerFactor
        layer.enabled: radius > 0
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }
        KWinComponents.DesktopBackground {
            anchors.fill: parent
            activity: KWinComponents.Workspace.currentActivity
            desktop: ws.desktop
            outputName: ws.targetScreen.name
        }
    }

    // Clicking the workspace (not a window): GNOME Workspace click action –
    // the active workspace leaves the overview, another one is activated.
    MouseArea {
        anchors.fill: parent
        enabled: ws.screenView.interactive
        onClicked: ws.effect.activateDesktop(ws.desktop)
    }

    ExpoLayout {
        id: expoLayout
        // window area inside the workspace (local px)
        x: Math.round(parent.width * 0.04)
        y: Math.round(parent.height * 0.04)
        width: parent.width - 2 * x
        height: parent.height - 2 * y
        placementMode: width >= height ? ExpoLayout.Rows : ExpoLayout.Columns
        // WINDOW_PREVIEW_MAXIMUM_SCALE, relative to the on-screen size
        maxScale: Math.min(1, L.WINDOW_PREVIEW_MAXIMUM_SCALE / Math.max(0.1, ws.screenView.pickerScale))

        Repeater {
            id: windowRepeater
            model: KWinComponents.WindowFilterModel {
                activity: KWinComponents.Workspace.currentActivity
                desktop: ws.desktop
                screenName: ws.targetScreen.name
                windowModel: ws.windowModel
                minimizedWindows: true
                windowType: ~KWinComponents.WindowFilterModel.Dock &
                            ~KWinComponents.WindowFilterModel.Desktop &
                            ~KWinComponents.WindowFilterModel.Notification &
                            ~KWinComponents.WindowFilterModel.CriticalNotification
            }

            delegate: ExpoCell {
                id: cell

                required property QtObject window
                required property int index

                readonly property real mode: ws.workspaceMode
                readonly property bool hovered: hover.hovered && ws.screenView.interactive && mode > 0.99
                // windowPreview.js ICON_SIZE 64, ICON_OVERLAP 0.7, in screen px
                readonly property real iconSize: ws.px(64 * ws.s)

                layout: expoLayout
                shouldLayout: !window.skipSwitcher
                partialActivationFactor: mode
                naturalX: window.x - ws.targetScreen.geometry.x
                naturalY: window.y - ws.targetScreen.geometry.y
                naturalWidth: window.width
                naturalHeight: window.height
                persistentKey: window.internalId
                bottomMargin: Math.round(iconSize * 0.3 + ws.px(6 * ws.s))

                contentItem: Item {
                    id: content
                    parent: windowLayer
                    visible: !cell.window.skipSwitcher && (!cell.window.minimized || cell.mode > 0)
                    // DRAGGING_WINDOW_OPACITY while it is being dragged
                    opacity: (cell.window.minimized ? cell.mode : 1) * (ws.screenView.dragWindow === cell.window ? 100 / 255 : 1)
                    z: cell.hovered ? 100000 : cell.window.stackingOrder

                    // windowPreview.js WINDOW_ACTIVE_SIZE_INC: grow a little on hover
                    KWinComponents.WindowThumbnail {
                        id: thumbnail
                        anchors.fill: parent
                        anchors.margins: cell.hovered ? -ws.px(5 * ws.s) : 0
                        Behavior on anchors.margins { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        wId: cell.window.internalId
                    }

                    // window-picker hover: rounded light border around the preview
                    Rectangle {
                        anchors.fill: thumbnail
                        anchors.margins: -ws.px(6 * ws.s)
                        radius: ws.px(12 * ws.s)
                        color: "transparent"
                        border.width: ws.px(4 * ws.s)
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                        opacity: cell.hovered ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    // App icon overlapping the bottom edge (70% below it)
                    Kirigami.Icon {
                        id: appIcon
                        width: cell.iconSize
                        height: cell.iconSize
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - cell.iconSize * (1 - 0.7)
                        source: cell.window.icon
                        opacity: cell.mode
                        visible: opacity > 0
                    }

                    // Title (window caption tooltip), shown on hover
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: appIcon.y + appIcon.height + ws.px(6 * ws.s)   // ICON_TITLE_SPACING
                        width: Math.min(titleLabel.implicitWidth + 2 * ws.px(12 * ws.s), Math.max(parent.width, ws.px(240 * ws.s)))
                        height: titleLabel.implicitHeight + 2 * ws.px(6 * ws.s)
                        radius: height / 2
                        color: L.SYSTEM_OVERLAY_BG_COLOR
                        opacity: cell.hovered ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Text {
                            id: titleLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 2 * ws.px(12 * ws.s))
                            text: cell.window.caption
                            color: L.SYSTEM_FG_COLOR
                            elide: Text.ElideMiddle
                            font.pixelSize: ws.px(ws.screenView.fontPx)
                        }
                    }

                    // .window-close: 32px circle (padding 3 + 24px icon), top-right corner
                    Rectangle {
                        id: closeButton
                        width: ws.px(30 * ws.s)
                        height: width
                        radius: width / 2
                        x: thumbnail.x + thumbnail.width - width / 2 - ws.px(4 * ws.s)
                        y: thumbnail.y - height / 2 + ws.px(4 * ws.s)
                        color: closeArea.containsMouse ? "#5a5a5f" : "#45454a"
                        opacity: cell.hovered && cell.window.closeable ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: ws.px(16 * ws.s)
                            height: width
                            source: "window-close-symbolic"
                            color: "white"
                            isMask: true
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: cell.window.closeWindow()
                        }
                    }

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        enabled: ws.screenView.interactive
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        preventStealing: true
                        // drag a window onto another workspace (peek, strip or thumbnail)
                        property point pressPos
                        property bool dragging: false
                        property bool dragged: false
                        onPressed: mouse => {
                            pressPos = mapToItem(ws.screenView, mouse.x, mouse.y);
                            dragging = false;
                            dragged = false;
                        }
                        onPositionChanged: mouse => {
                            if (!(pressedButtons & Qt.LeftButton)) {
                                return;
                            }
                            const p = mapToItem(ws.screenView, mouse.x, mouse.y);
                            if (!dragging && Math.hypot(p.x - pressPos.x, p.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                                dragging = true;
                                dragged = true;
                                ws.screenView.beginWindowDrag(cell.window, p);
                            }
                            if (dragging) {
                                ws.screenView.moveWindowDrag(p);
                            }
                        }
                        onReleased: mouse => {
                            if (dragging) {
                                dragging = false;
                                ws.screenView.endWindowDrag(mapToItem(ws.screenView, mouse.x, mouse.y));
                            }
                        }
                        onCanceled: {
                            if (dragging) {
                                dragging = false;
                                ws.screenView.endWindowDrag(null);
                            }
                        }
                        onClicked: mouse => {
                            if (dragged) {
                                return;
                            }
                            if (mouse.button === Qt.MiddleButton && cell.mode > 0.99) {
                                cell.window.closeWindow();
                            } else if (cell.mode < 0.99) {
                                // app grid strip: behaves like the workspace
                                ws.effect.activateDesktop(ws.desktop);
                            } else {
                                ws.effect.activateWindow(cell.window);
                            }
                        }
                    }
                }
            }
        }
    }

    // window content items live here (local, screen-sized coordinates)
    Item {
        id: windowLayer
        anchors.fill: parent
    }
}
