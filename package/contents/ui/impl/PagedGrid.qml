// SPDX-License-Identifier: GPL-2.0-or-later
// Horizontally paged icon grid shared by the app grid and folder dialogs
// (GNOME's BaseAppView + IconGrid). Pointer handling lives in one MouseArea
// on top of the tiles, so a press on an icon can turn into a swipe:
//  - drag (mouse or touchpad click-drag): pages follow the pointer and snap
//    by distance/velocity on release; a press without movement is a click,
//    hit-tested to the tile under the pointer (or "empty space");
//  - touchpad two-finger scroll: pages follow the fingers, snap when they stop;
//  - mouse wheel: one page per notch (SCROLL_TIMEOUT_TIME 150 ms in GNOME).
import QtQuick
import org.kde.kirigami as Kirigami
import "Layout.js" as L

Item {
    id: grid

    property var entries: []           // [{kind: "app"|"folder", index, name, apps}]
    property QtObject backend: null
    property real s: 1
    property int fontPx: 15
    property real iconScale: 1
    property var fixedMode: null       // {rows, columns}; null = IconGrid best mode
    property var padding: ({h: 18, v: 24})
    property real spacing: 12
    property real maxSpacing: 36
    property int indicatorsHeight: Math.round(16 * s)
    property bool showArrows: true
    property real arrowAreaWidth: 0
    property real tileRadius: Math.round(24 * s)
    property var runningWindows: ({})   // desktop file name -> [windows]
    function isRunning(storageId) {
        if (!storageId) {
            return false;
        }
        const id = storageId.endsWith(".desktop") ? storageId.slice(0, -8) : storageId;
        return (runningWindows[id] || []).length > 0;
    }

    signal entryActivated(var entry, int button, int modifiers)
    signal emptyClicked()

    readonly property int pageWidth: Math.max(1, width)
    readonly property int pageHeight: Math.max(1, height - indicatorsHeight)
    readonly property int labelHeight: Math.round(fontPx * 1.4)
    readonly property var mode: fixedMode ? fixedMode
                                          : L.bestGridMode(pageWidth - 2 * padding.h, pageHeight - 2 * padding.v)
    readonly property var geom: L.gridGeometry(pageWidth, pageHeight, padding, mode, spacing, maxSpacing, iconScale,
                                               size => size + Math.round(24 * s) + Math.round(6 * s) + labelHeight)
    readonly property int pageCount: Math.max(1, Math.ceil(entries.length / geom.perPage))
    property int currentPage: 0
    // fractional page position (GNOME: scroll adjustment value / page size)
    property real pagePos: 0
    property int hoverIndex: -1
    property int pressIndex: -1

    onPageCountChanged: if (currentPage >= pageCount) goToPage(pageCount - 1, false)

    function goToPage(p, animate) {
        p = Math.max(0, Math.min(pageCount - 1, p));
        currentPage = p;
        pageAnim.stop();
        if (animate === false) {
            pagePos = p;
            return;
        }
        pageAnim.from = pagePos;
        pageAnim.to = p;
        pageAnim.start();
    }
    function nextPage() {
        goToPage(currentPage + 1);
    }
    function previousPage() {
        goToPage(currentPage - 1);
    }
    function reset() {
        goToPage(0, false);
        hoverIndex = -1;
        pressIndex = -1;
    }

    // follow-the-finger helpers (drag, touchpad scroll, swipe gesture)
    property int followFrom: 0
    property bool following: false
    function followUpdate(deltaPages) {
        if (!following) {
            pageAnim.stop();
            following = true;
            followFrom = currentPage;
            hoverIndex = -1;
        }
        let p = followFrom + deltaPages;
        // rubber band at the ends
        if (p < 0) {
            p = p * 0.3;
        } else if (p > pageCount - 1) {
            p = pageCount - 1 + (p - pageCount + 1) * 0.3;
        }
        pagePos = p;
    }
    function followEnd(commit, direction) {
        if (!following) {
            return;
        }
        following = false;
        goToPage(followFrom + (commit ? direction : 0));
    }

    NumberAnimation {
        id: pageAnim
        target: grid
        property: "pagePos"
        duration: L.PAGE_SWITCH_TIME
        easing.type: Easing.OutCubic
    }

    // entry index under a point in grid coordinates, or -1
    function hitTest(x, y) {
        const g = geom;
        const page = Math.round(pagePos);
        const px = x - (page - pagePos) * pageWidth;
        const cx = px - g.left, cy = y - g.top;
        if (cx < 0 || cy < 0 || y > pageHeight) {
            return -1;
        }
        const col = Math.floor(cx / (g.tileSize + g.hSpacing));
        const row = Math.floor(cy / (g.tileSize + g.vSpacing));
        if (col >= g.columns || row >= g.rows) {
            return -1;
        }
        if (cx - col * (g.tileSize + g.hSpacing) > g.tileSize || cy - row * (g.tileSize + g.vSpacing) > g.tileSize) {
            return -1;
        }
        const index = page * g.perPage + row * g.columns + col;
        return index < entries.length ? index : -1;
    }

    // --- pages -------------------------------------------------------------------
    Item {
        id: viewport
        width: grid.pageWidth
        height: grid.pageHeight
        clip: true

        Repeater {
            model: grid.pageCount
            delegate: Item {
                id: page
                required property int index
                x: (index - grid.pagePos) * grid.pageWidth
                width: grid.pageWidth
                height: grid.pageHeight
                visible: Math.abs(index - grid.pagePos) < 1

                Repeater {
                    model: page.visible ? grid.geom.perPage : 0
                    delegate: Loader {
                        id: cellLoader
                        required property int index
                        readonly property int entryIndex: page.index * grid.geom.perPage + index
                        readonly property var entry: entryIndex < grid.entries.length ? grid.entries[entryIndex] : null
                        readonly property int col: index % grid.geom.columns
                        readonly property int row: Math.floor(index / grid.geom.columns)
                        x: Math.round(grid.geom.left + col * (grid.geom.tileSize + grid.geom.hSpacing))
                        y: Math.round(grid.geom.top + row * (grid.geom.tileSize + grid.geom.vSpacing))
                        width: grid.geom.tileSize
                        height: grid.geom.tileSize
                        active: entry !== null
                        sourceComponent: entry && entry.kind === "folder" ? folderTile : appTile

                        Component {
                            id: appTile
                            AppIcon {
                                s: grid.s
                                fontPx: grid.fontPx
                                radius: grid.tileRadius
                                iconSize: grid.geom.iconSize
                                interactive: false
                                hoveredExternal: grid.hoverIndex === cellLoader.entryIndex
                                pressedExternal: grid.pressIndex === cellLoader.entryIndex
                                app: grid.backend && cellLoader.entry ? (grid.backend.revision, grid.backend.appAt("apps", cellLoader.entry.index)) : null
                                running: app !== null && grid.isRunning(app.storageId)
                            }
                        }
                        Component {
                            id: folderTile
                            FolderIcon {
                                s: grid.s
                                fontPx: grid.fontPx
                                radius: grid.tileRadius
                                iconSize: grid.geom.iconSize
                                backend: grid.backend
                                folder: cellLoader.entry
                                hovered: grid.hoverIndex === cellLoader.entryIndex
                                pressed: grid.pressIndex === cellLoader.entryIndex
                            }
                        }
                    }
                }
            }
        }
    }

    // --- pointer handling ------------------------------------------------------------
    MouseArea {
        id: pointer
        width: grid.pageWidth
        height: grid.pageHeight
        enabled: grid.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true

        property real pressX: 0
        property bool dragging: false
        property real lastX: 0
        property real lastT: 0
        property real velocity: 0     // px per ms

        onPressed: mouse => {
            pressX = mouse.x;
            lastX = mouse.x;
            lastT = Date.now();
            velocity = 0;
            dragging = false;
            grid.pressIndex = grid.hitTest(mouse.x, mouse.y);
        }
        onPositionChanged: mouse => {
            if (!pressed) {
                grid.hoverIndex = grid.hitTest(mouse.x, mouse.y);
                return;
            }
            const dx = mouse.x - pressX;
            if (!dragging && Math.abs(dx) > Qt.styleHints.startDragDistance) {
                dragging = true;
                grid.pressIndex = -1;
            }
            if (dragging) {
                const now = Date.now();
                const dt = Math.max(1, now - lastT);
                velocity = 0.6 * velocity + 0.4 * (mouse.x - lastX) / dt;
                lastX = mouse.x;
                lastT = now;
                grid.followUpdate(-dx / grid.pageWidth);
            }
        }
        onReleased: mouse => {
            if (dragging) {
                dragging = false;
                const dx = mouse.x - pressX;
                const fast = Math.abs(velocity) > 0.4;
                const far = Math.abs(dx) > grid.pageWidth * 0.2;
                grid.followEnd(fast || far, (fast ? -velocity : -dx) > 0 ? 1 : -1);
                grid.hoverIndex = grid.hitTest(mouse.x, mouse.y);
                return;
            }
            const index = grid.hitTest(mouse.x, mouse.y);
            grid.pressIndex = -1;
            if (index >= 0) {
                grid.entryActivated(grid.entries[index], mouse.button, mouse.modifiers);
            } else if (mouse.button === Qt.LeftButton) {
                grid.emptyClicked();
            }
        }
        onCanceled: {
            if (dragging) {
                dragging = false;
                grid.followEnd(false, 0);
            }
            grid.pressIndex = -1;
        }
        onExited: grid.hoverIndex = -1

        property real scrollAccum: 0
        onWheel: wheel => {
            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                || Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y);
            const px = horizontal ? -wheel.pixelDelta.x : -wheel.pixelDelta.y;
            if (px !== 0) {
                scrollAccum += px;
                grid.followUpdate(scrollAccum / grid.pageWidth * (horizontal ? 1 : 2));
                scrollSnap.restart();
                return;
            }
            if (scrollLock.running) {
                return;
            }
            const delta = horizontal ? -wheel.angleDelta.x : -wheel.angleDelta.y;
            if (delta > 0) {
                grid.nextPage();
            } else if (delta < 0) {
                grid.previousPage();
            }
            scrollLock.restart();
        }
        Timer {
            id: scrollLock
            interval: 150
        }
        Timer {
            id: scrollSnap
            interval: 120
            onTriggered: {
                const p = grid.pagePos - grid.followFrom;
                pointer.scrollAccum = 0;
                grid.followEnd(Math.abs(p) > 0.15, p > 0 ? 1 : -1);
            }
        }
    }

    // --- page navigation arrows (.page-navigation-arrow) -----------------------------
    Repeater {
        model: grid.showArrows ? 2 : 0
        delegate: Item {
            required property int index
            readonly property bool next: index === 1
            readonly property bool shown: next ? grid.currentPage < grid.pageCount - 1 : grid.currentPage > 0
            width: grid.arrowAreaWidth
            height: grid.pageHeight
            x: next ? grid.pageWidth - width : 0
            opacity: shown ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(60 * grid.s)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, arrowArea.pressed ? 0.15 : arrowArea.containsMouse ? 0.1 : 0)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(24 * grid.s)
                    height: width
                    source: next ? "go-next-symbolic" : "go-previous-symbolic"
                    color: L.SYSTEM_FG_COLOR
                    isMask: true
                }
                MouseArea {
                    id: arrowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: next ? grid.nextPage() : grid.previousPage()
                }
            }
        }
    }

    // --- page indicators (pageIndicators.js, horizontal, 10px dots) ------------------
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: grid.indicatorsHeight
        visible: grid.pageCount > 1
        Repeater {
            model: grid.pageCount
            delegate: Item {
                required property int index
                readonly property real progress: 1 - L.clamp(Math.abs(grid.pagePos - index), 0, 1)
                // .page-indicator padding: 6px 12px 0
                width: Math.round((10 + 24) * grid.s)
                height: grid.indicatorsHeight
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(6 * grid.s)
                    width: Math.round(10 * grid.s)
                    height: width
                    radius: width / 2
                    color: L.SYSTEM_FG_COLOR
                    scale: L.lerp(dotArea.pressed ? 0.5 : L.INDICATOR_INACTIVE_SCALE, 1, progress)
                    opacity: L.lerp(dotArea.containsMouse ? 1 : L.INDICATOR_INACTIVE_OPACITY, 1, progress)
                }
                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: grid.goToPage(index)
                }
            }
        }
    }
}
