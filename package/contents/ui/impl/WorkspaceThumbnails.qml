// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's ThumbnailsBox: a centred row of workspace previews under the search
// entry, at most MAX_THUMBNAIL_SCALE (5%) of the screen height.
// Dropping a window or app between two thumbnails creates a workspace there
// (dynamic workspaces only), like GNOME's drop placeholder.
// _workspace-thumbnails.scss: .workspace-thumbnails spacing 6px, padding 6px;
// .workspace-thumbnail border-radius 4px; .workspace-thumbnail-indicator
// 3px accent border, radius 8px.
import QtQuick
import Qt5Compat.GraphicalEffects as GE
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents

Item {
    id: box

    required property Item screenView
    required property QtObject windowModel

    readonly property QtObject targetScreen: screenView.targetScreen
    readonly property real boxPadding: Math.round(6 * screenView.s)
    readonly property real thumbHeight: Math.max(1, height - 2 * boxPadding)
    readonly property real thumbWidth: Math.round(thumbHeight * targetScreen.geometry.width / targetScreen.geometry.height)
    readonly property real thumbSpacing: Math.round(6 * screenView.s)
    readonly property real thumbScale: thumbHeight / targetScreen.geometry.height

    // --- drop targets, GNOME ThumbnailsBox.handleDragOver (workspaceThumbnail.js) --
    // WORKSPACE_CUT_SIZE: a "cut" into the sides of each thumbnail so the
    // placeholder between two thumbnails is easy to hit.
    readonly property real cutSize: Math.round(10 * screenView.s)
    // .placeholder width: 18px
    readonly property real placeholderWidth: Math.round(18 * screenView.s)
    // index a new workspace would be inserted at (placeholder shown), or -1
    property int placeholderPos: -1
    readonly property int count: thumbRepeater.count
    readonly property real gapWidth: placeholderPos >= 0 ? placeholderWidth + thumbSpacing : 0
    readonly property real contentWidth: count * thumbWidth + Math.max(0, count - 1) * thumbSpacing + gapWidth
    function thumbX(i) {
        return Math.round((width - contentWidth) / 2 + i * (thumbWidth + thumbSpacing)
                          + (placeholderPos >= 0 && i >= placeholderPos ? gapWidth : 0));
    }

    // What a drop at (x, y) (this item's coordinates) would hit:
    // {desktop} for a thumbnail, {insertAt} for the gap before thumbnail
    // insertAt (only if canCreate, like GNOME's dynamic-workspaces check), or
    // null. Zones as in _getPlaceholderTarget/_withinWorkspace.
    function dropAt(x, y, canCreate) {
        if (y < 0 || y > height) {
            return null;
        }
        for (let i = 0; i < count; ++i) {
            const t = thumbRepeater.itemAt(i);
            if (!t) {
                continue;
            }
            const tx = thumbX(i);
            if (canCreate) {
                let x1 = tx - thumbSpacing - cutSize;
                const x2 = tx + cutSize;
                if (i === 0) {
                    x1 += thumbSpacing + cutSize;
                }
                if (i === placeholderPos) {
                    x1 -= placeholderWidth + thumbSpacing;
                }
                if (x > x1 && x <= x2) {
                    return {insertAt: i};
                }
            }
            const w1 = tx + cutSize;
            const w2 = tx + thumbWidth - cutSize + (i === count - 1 ? cutSize : 0);
            if (x > w1 && x <= w2) {
                return {desktop: t.desktop};
            }
        }
        return null;
    }
    // compatibility: desktop under a point, or null
    function desktopAt(x, y) {
        const t = dropAt(x, y, false);
        return t ? t.desktop : null;
    }

    // drop placeholder: a vertical bar in the gap that opens between thumbnails
    Rectangle {
        z: 5
        visible: box.placeholderPos >= 0
        readonly property real gapX: box.placeholderPos >= 0 ? box.thumbX(box.placeholderPos) - box.thumbSpacing - box.placeholderWidth : 0
        x: gapX + (box.placeholderWidth - width) / 2
        y: box.boxPadding
        width: Math.max(2, Math.round(4 * box.screenView.s))
        height: box.thumbHeight
        radius: width / 2
        color: Kirigami.Theme.highlightColor
    }

    Item {
        id: row
        y: box.boxPadding
        width: box.width
        height: box.thumbHeight

        Repeater {
            id: thumbRepeater
            model: KWinComponents.VirtualDesktopModel {}

            delegate: Item {
                id: thumb
                required property QtObject desktop
                required property int index
                readonly property bool current: KWinComponents.Workspace.currentDesktop === desktop

                x: box.thumbX(index)
                width: box.thumbWidth
                height: box.thumbHeight
                // SLIDE_ANIMATION_TIME: thumbnails slide aside for the placeholder
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                Item {
                    id: preview
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: preview.width
                            height: preview.height
                            radius: Math.round(4 * box.screenView.s)
                        }
                    }

                    KWinComponents.DesktopBackground {
                        anchors.fill: parent
                        activity: KWinComponents.Workspace.currentActivity
                        desktop: thumb.desktop
                        outputName: box.targetScreen.name
                    }

                    Item {
                        // windows at screen size, scaled down
                        width: box.targetScreen.geometry.width
                        height: box.targetScreen.geometry.height
                        scale: box.thumbScale
                        transformOrigin: Item.TopLeft

                        Repeater {
                            model: KWinComponents.WindowFilterModel {
                                activity: KWinComponents.Workspace.currentActivity
                                desktop: thumb.desktop
                                screenName: box.targetScreen.name
                                windowModel: box.windowModel
                                windowType: ~KWinComponents.WindowFilterModel.Dock &
                                            ~KWinComponents.WindowFilterModel.Desktop &
                                            ~KWinComponents.WindowFilterModel.Notification &
                                            ~KWinComponents.WindowFilterModel.CriticalNotification
                            }
                            KWinComponents.WindowThumbnail {
                                required property QtObject window
                                wId: window.internalId
                                x: window.x - box.targetScreen.geometry.x
                                y: window.y - box.targetScreen.geometry.y
                                z: window.stackingOrder
                                width: window.width
                                height: window.height
                                visible: !window.minimized
                            }
                        }
                    }
                }

                // Active workspace indicator (slides between thumbnails in GNOME)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Math.round(3 * box.screenView.s)
                    radius: Math.round(8 * box.screenView.s)
                    color: "transparent"
                    border.width: Math.round(3 * box.screenView.s)
                    border.color: thumb.current || box.screenView.dropDesktop === thumb.desktop ? Kirigami.Theme.highlightColor
                                                : Qt.rgba(1, 1, 1, area.containsMouse ? 0.3 : 0)
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: KWinComponents.Workspace.currentDesktop = thumb.desktop
                }

                HoverHandler {
                    id: thumbHover
                }

                // hover x: close this desktop, its windows move next door
                DesktopCloseButton {
                    z: 10
                    x: thumb.width - width / 2 - Math.round(4 * box.screenView.s)
                    y: -height / 2 + Math.round(4 * box.screenView.s)
                    size: Math.round(22 * box.screenView.s)
                    effect: box.screenView.effect
                    desktop: thumb.desktop
                    shown: (thumbHover.hovered || box.screenView.devShowCloseButtons) && box.screenView.dragWindow === null && box.screenView.iconDrag === null
                }
            }
        }
    }
}
