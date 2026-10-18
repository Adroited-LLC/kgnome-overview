// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's ThumbnailsBox: a centred row of workspace previews under the search
// entry, at most MAX_THUMBNAIL_SCALE (5%) of the screen height.
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

    // desktop under a point in this item's coordinates, or null
    function desktopAt(x, y) {
        if (y < 0 || y > height) {
            return null;
        }
        const p = mapToItem(row, x, y);
        for (let i = 0; i < thumbRepeater.count; ++i) {
            const t = thumbRepeater.itemAt(i);
            if (t && p.x >= t.x - thumbSpacing / 2 && p.x <= t.x + t.width + thumbSpacing / 2) {
                return t.desktop;
            }
        }
        return null;
    }

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        y: box.boxPadding
        height: box.thumbHeight
        spacing: box.thumbSpacing

        Repeater {
            id: thumbRepeater
            model: KWinComponents.VirtualDesktopModel {}

            delegate: Item {
                id: thumb
                required property QtObject desktop
                required property int index
                readonly property bool current: KWinComponents.Workspace.currentDesktop === desktop

                width: box.thumbWidth
                height: box.thumbHeight

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
            }
        }
    }
}
