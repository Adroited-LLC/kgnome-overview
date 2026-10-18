// SPDX-License-Identifier: GPL-2.0-or-later
// Paged, alphabetical app grid with GNOME's IconGrid sizing:
// best mode among 8x3 / 6x4 / 4x6 / 3x8 (rows x columns) by aspect ratio,
// icons up to 96 px, FILL spacing capped at max-row/column-spacing.
import QtQuick
import "Layout.js" as L

Item {
    id: grid

    required property Item screenView
    readonly property QtObject effect: screenView.effect
    readonly property QtObject backend: effect.backend
    readonly property real s: screenView.s

    readonly property int indicatorsHeight: Math.round(32 * s)
    readonly property int pageWidth: Math.max(1, width)
    readonly property int pageHeight: Math.max(1, height - indicatorsHeight)
    readonly property var padding: ({h: Math.round(64 * s), v: Math.round(12 * s)})
    readonly property int labelHeight: Math.round(Math.round(13 * s) * 1.4)
    readonly property var mode: L.bestGridMode(pageWidth - 2 * padding.h, pageHeight - 2 * padding.v)
    readonly property var geom: L.gridGeometry(pageWidth, pageHeight, padding, mode,
                                               Math.round(24 * s), Math.round(72 * s), effect.iconScale,
                                               size => size + Math.round(24 * s) + Math.round(6 * s) + labelHeight)
    readonly property int appCount: backend ? (backend.revision, backend.count("apps")) : 0
    readonly property int pageCount: Math.max(1, Math.ceil(appCount / geom.perPage))
    property int currentPage: 0

    onPageCountChanged: if (currentPage >= pageCount) currentPage = pageCount - 1

    function nextPage() {
        currentPage = Math.min(pageCount - 1, currentPage + 1);
    }
    function previousPage() {
        currentPage = Math.max(0, currentPage - 1);
    }

    ListView {
        id: pages
        x: 0
        y: 0
        width: grid.pageWidth
        height: grid.pageHeight
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: L.PAGE_SWITCH_TIME
        highlightMoveVelocity: -1
        boundsBehavior: Flickable.StopAtBounds
        interactive: grid.enabled
        clip: true
        cacheBuffer: width   // keep the neighbouring pages ready
        model: grid.pageCount
        currentIndex: grid.currentPage
        onCurrentIndexChanged: if (grid.currentPage !== currentIndex) grid.currentPage = currentIndex

        delegate: Item {
            id: page
            required property int index
            width: pages.width
            height: pages.height

            Repeater {
                model: grid.geom.perPage
                delegate: AppIcon {
                    required property int index
                    readonly property int appIndex: page.index * grid.geom.perPage + index
                    readonly property int col: index % grid.geom.columns
                    readonly property int row: Math.floor(index / grid.geom.columns)

                    x: Math.round(grid.geom.left + col * (grid.geom.tileSize + grid.geom.hSpacing))
                    y: Math.round(grid.geom.top + row * (grid.geom.tileSize + grid.geom.vSpacing))
                    width: grid.geom.tileSize
                    height: grid.geom.tileSize
                    s: grid.s
                    iconSize: grid.geom.iconSize
                    app: grid.backend && appIndex < grid.appCount ? (grid.backend.revision, grid.backend.appAt("apps", appIndex)) : null
                    visible: app !== null
                    onActivated: grid.effect.launch("apps", appIndex)
                }
            }
        }
    }

    // Mouse wheel / touchpad scrolling flips pages (GNOME: SCROLL_TIMEOUT_TIME).
    WheelHandler {
        target: null
        enabled: grid.enabled
        property real accumulated: 0
        onWheel: event => {
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y;
            if (scrollLock.running) {
                return;
            }
            accumulated += delta;
            if (accumulated <= -60) {
                grid.nextPage();
                accumulated = 0;
                scrollLock.restart();
            } else if (accumulated >= 60) {
                grid.previousPage();
                accumulated = 0;
                scrollLock.restart();
            }
        }
    }
    Timer {
        id: scrollLock
        interval: 150
    }

    // Page indicators
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: grid.indicatorsHeight
        spacing: Math.round(4 * grid.s)
        visible: grid.pageCount > 1
        Repeater {
            model: grid.pageCount
            delegate: Item {
                required property int index
                width: Math.round(24 * grid.s)
                height: grid.indicatorsHeight
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round((index === grid.currentPage ? 10 : 8) * grid.s)
                    height: width
                    radius: width / 2
                    color: "white"
                    opacity: index === grid.currentPage ? 1 : (dotArea.containsMouse ? 0.6 : 0.35)
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: grid.currentPage = index
                }
            }
        }
    }
}
