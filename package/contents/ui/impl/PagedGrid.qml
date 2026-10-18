// SPDX-License-Identifier: GPL-2.0-or-later
// Horizontally paged icon grid shared by the app grid and folder dialogs
// (GNOME's BaseAppView + IconGrid). Pointer handling lives in one MouseArea
// on top of the tiles, as in GNOME:
//  - press on an icon and move: drag the icon (drag and drop, see
//    ScreenView's icon drag manager); press and release: activate it;
//  - press on empty space and move: the pages follow the pointer and snap by
//    distance/velocity on release; click on empty space: emptyClicked();
//  - touchpad two-finger scroll always pages (follows the fingers, snaps when
//    they stop); the mouse wheel flips one page per notch.
// While an icon is dragged over the grid, the other icons make room for it
// after 200 ms, hovering an icon's centre targets it (folder), and resting at
// a page edge for 1 s flips the page.
import QtQuick
import org.kde.kirigami as Kirigami
import "Layout.js" as L

Item {
    id: grid

    property var entries: []           // [{kind: "app"|"folder", id, index, name, apps, appIds}]
    property QtObject backend: null
    property Item screenView: null     // owner of the icon drag manager
    property real s: 1
    property int fontPx: 15
    property real iconScale: 1
    property int preferredIconSize: 0  // > 0: custom grid (IconSize setting)
    property int columns: 0            // > 0: custom grid (Columns setting)
    property int rows: 0               // 0: automatic
    property var fixedMode: null       // {rows, columns}; overrides everything
    property var padding: ({h: 18, v: 24})
    property real spacing: 12
    property real maxSpacing: 36
    property int indicatorsHeight: Math.round(16 * s)
    property bool showArrows: true
    property real arrowAreaWidth: 0
    property real tileRadius: Math.round(24 * s)
    property bool folderDropEnabled: true
    property var runningWindows: ({})   // desktop file name -> [windows]
    function isRunning(storageId) {
        if (!storageId) {
            return false;
        }
        const id = storageId.endsWith(".desktop") ? storageId.slice(0, -8) : storageId;
        return (runningWindows[id] || []).length > 0;
    }

    signal entryActivated(var entry, int button, int modifiers)
    signal entryMenu(var entry, point screenPoint)
    signal emptyClicked()

    readonly property int pageWidth: Math.max(1, width)
    readonly property int pageHeight: Math.max(1, height - indicatorsHeight)
    readonly property int labelHeight: Math.round(fontPx * 1.4)
    function tileFor(size) {
        return size + Math.round(24 * s) + Math.round(6 * s) + labelHeight;
    }
    readonly property var geom: {
        if (fixedMode) {
            return L.gridGeometry(pageWidth, pageHeight, padding, fixedMode, spacing, maxSpacing, iconScale, tileFor,
                                  preferredIconSize > 0 ? preferredIconSize : 0);
        }
        if (columns > 0) {
            return L.customGridGeometry(pageWidth, pageHeight, padding, columns, rows,
                                        preferredIconSize > 0 ? preferredIconSize : Math.round(96 * iconScale),
                                        spacing, maxSpacing, tileFor);
        }
        const mode = L.bestGridMode(pageWidth - 2 * padding.h, pageHeight - 2 * padding.v);
        return L.gridGeometry(pageWidth, pageHeight, padding, mode, spacing, maxSpacing, iconScale, tileFor,
                              preferredIconSize > 0 ? preferredIconSize : 0);
    }
    // during a drag the grid can need one more slot (placeholder)
    readonly property int slotCount: entries.length + (placeholderSlot >= 0 && dragEntryIndex < 0 ? 1 : 0)
    readonly property int pageCount: Math.max(1, Math.ceil(slotCount / geom.perPage))
    property int currentPage: 0
    // fractional page position (GNOME: scroll adjustment value / page size)
    property real pagePos: 0
    property int hoverIndex: -1
    property int pressIndex: -1

    // --- drag and drop state (driven by ScreenView's icon drag manager) --------
    property int dragEntryIndex: -1   // entry of this grid being dragged (hidden)
    property int placeholderSlot: -1  // insert position (in the list without the dragged entry)
    property int folderTargetIndex: -1
    property bool dragOver: false
    readonly property bool animateSlots: dragEntryIndex >= 0 || placeholderSlot >= 0 || settleTimer.running

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
        dragEnd();
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

    // --- slots -----------------------------------------------------------------------
    // displayed slot of entry i (the dragged entry keeps its slot until a
    // placeholder is shown; then the others close up around the placeholder)
    function slotOf(i) {
        if (placeholderSlot < 0) {
            return i;
        }
        let k = i;
        if (dragEntryIndex >= 0) {
            if (i === dragEntryIndex) {
                return placeholderSlot;
            }
            if (i > dragEntryIndex) {
                k = i - 1;
            }
        }
        return k >= placeholderSlot ? k + 1 : k;
    }
    // entry index shown at a slot, or -1 (placeholder / empty)
    function entryAtSlot(slot) {
        for (let i = 0; i < entries.length; ++i) {
            if (i !== dragEntryIndex && slotOf(i) === slot) {
                return i;
            }
        }
        return -1;
    }
    // position in the list without the dragged entry for an entry index
    function reducedIndex(i) {
        return dragEntryIndex >= 0 && i > dragEntryIndex ? i - 1 : i;
    }
    readonly property int reducedCount: entries.length - (dragEntryIndex >= 0 ? 1 : 0)

    function slotRect(slot) {
        const g = geom;
        const page = Math.floor(slot / g.perPage);
        const k = slot % g.perPage;
        const col = k % g.columns, row = Math.floor(k / g.columns);
        return {
            x: page * pageWidth + Math.round(g.left + col * (g.tileSize + g.hSpacing)),
            y: Math.round(g.top + row * (g.tileSize + g.vSpacing)),
            width: g.tileSize, height: g.tileSize,
        };
    }

    // entry index under a point in grid coordinates, or -1
    function hitTest(x, y) {
        const g = geom;
        if (y < 0 || y > pageHeight) {
            return -1;
        }
        const page = Math.round(pagePos);
        const px = x + (pagePos - page) * pageWidth;
        const cx = px - g.left, cy = y - g.top;
        if (cx < 0 || cy < 0) {
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
        const i = entryAtSlot(page * g.perPage + row * g.columns + col);
        return i;
    }

    // --- drag over this grid ----------------------------------------------------
    // p in grid coordinates; draggedKind "app"/"folder". Returns
    // {type: "folder", index} | {type: "reorder", insertAt} | {type: "none"}
    property var pendingInsert: -1
    function dragHover(p, draggedKind) {
        dragOver = true;
        const g = geom;
        // page edge: flip after resting there for 1 s
        const edge = showArrows ? arrowAreaWidth : Math.round(48 * s);
        const side = p.x < edge ? -1 : p.x > pageWidth - edge ? 1 : 0;
        if (side !== edgeTimer.side) {
            edgeTimer.side = side;
            if (side !== 0) {
                edgeTimer.restart();
            } else {
                edgeTimer.stop();
            }
        }
        if (side !== 0 || p.y > pageHeight) {
            folderTargetIndex = -1;
            return {type: "reorder", insertAt: placeholderSlot >= 0 ? placeholderSlot : pendingOrCurrent()};
        }
        const page = currentPage;
        const px = p.x + (pagePos - page) * pageWidth;
        const col = L.clamp(Math.floor((px - g.left + g.hSpacing / 2) / (g.tileSize + g.hSpacing)), 0, g.columns - 1);
        const row = L.clamp(Math.floor((p.y - g.top + g.vSpacing / 2) / (g.tileSize + g.vSpacing)), 0, g.rows - 1);
        const slot = page * g.perPage + row * g.columns + col;
        const r = slotRect(slot);
        const lx = px + page * pageWidth - r.x, ly = p.y - r.y;
        const target = entryAtSlot(slot);
        // centre of another icon: folder target
        const inner = 0.25 * g.tileSize;
        if (target >= 0 && folderDropEnabled && draggedKind === "app"
                && lx > inner && lx < g.tileSize - inner && ly > inner * 0.6 && ly < g.tileSize - inner) {
            folderTargetIndex = target;
            insertTimer.stop();
            return {type: "folder", index: target};
        }
        folderTargetIndex = -1;
        // between icons: insert before/after the icon at that slot
        let insertAt;
        if (target < 0) {
            // the placeholder itself, or empty space after the last icon
            if (slot === placeholderSlot) {
                insertAt = placeholderSlot;
            } else if (placeholderSlot < 0 && slot === dragEntryIndex) {
                insertAt = dragEntryIndex;     // the dragged icon's own gap
            } else {
                insertAt = reducedCount;
            }
        } else {
            insertAt = reducedIndex(target) + (lx > g.tileSize / 2 ? 1 : 0);
        }
        insertAt = L.clamp(insertAt, 0, reducedCount);
        if (insertAt !== placeholderSlot && insertAt !== pendingInsert) {
            pendingInsert = insertAt;
            insertTimer.restart();
        } else if (insertAt === placeholderSlot) {
            pendingInsert = -1;
            insertTimer.stop();
        }
        return {type: "reorder", insertAt: insertAt};
    }
    function pendingOrCurrent() {
        return dragEntryIndex >= 0 ? reducedIndex(dragEntryIndex) : reducedCount;
    }
    function dragLeave() {
        dragOver = false;
        insertTimer.stop();
        edgeTimer.stop();
        edgeTimer.side = 0;
        pendingInsert = -1;
        folderTargetIndex = -1;
        if (dragEntryIndex < 0) {
            placeholderSlot = -1;
        }
    }
    function dragEnd() {
        dragLeave();
        if (dragEntryIndex >= 0 || placeholderSlot >= 0) {
            settleTimer.restart();
        }
        dragEntryIndex = -1;
        placeholderSlot = -1;
    }
    // insert position a drop would use right now
    function dropInsertAt() {
        if (placeholderSlot >= 0) {
            return placeholderSlot;
        }
        if (pendingInsert >= 0) {
            return pendingInsert;
        }
        return pendingOrCurrent();
    }

    Timer {
        id: insertTimer
        interval: 200          // GNOME: neighbours move after 200 ms
        onTriggered: {
            if (grid.pendingInsert >= 0) {
                grid.placeholderSlot = grid.pendingInsert;
                grid.pendingInsert = -1;
            }
        }
    }
    Timer {
        id: edgeTimer
        property int side: 0
        interval: 1000         // hover at the page edge for 1 s
        repeat: true
        onTriggered: {
            if (side > 0) {
                grid.nextPage();
            } else if (side < 0) {
                grid.previousPage();
            }
        }
    }
    Timer {
        id: settleTimer
        interval: 250
    }

    // --- tiles -----------------------------------------------------------------------
    Item {
        id: viewport
        width: grid.pageWidth
        height: grid.pageHeight
        clip: true

        Item {
            id: strip
            x: -grid.pagePos * grid.pageWidth
            height: parent.height

            Repeater {
                model: grid.entries.length
                delegate: Loader {
                    id: cellLoader
                    required property int index
                    readonly property var entry: index < grid.entries.length ? grid.entries[index] : null
                    readonly property int slot: grid.slotOf(index)
                    readonly property var rect: grid.slotRect(slot)
                    readonly property int page: Math.floor(slot / grid.geom.perPage)
                    x: rect.x
                    y: rect.y
                    width: rect.width
                    height: rect.height
                    Behavior on x { enabled: grid.animateSlots; NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    Behavior on y { enabled: grid.animateSlots; NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    visible: Math.abs(page - grid.pagePos) < 1 && index !== grid.dragEntryIndex
                    active: entry !== null && (visible || Math.abs(page - grid.pagePos) < 2)
                    sourceComponent: entry && entry.kind === "folder" ? folderTile : appTile
                    scale: grid.folderTargetIndex === index ? 1.1 : 1
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    Component {
                        id: appTile
                        AppIcon {
                            s: grid.s
                            fontPx: grid.fontPx
                            radius: grid.tileRadius
                            iconSize: grid.geom.iconSize
                            interactive: false
                            hoveredExternal: grid.hoverIndex === cellLoader.index || grid.folderTargetIndex === cellLoader.index
                            pressedExternal: grid.pressIndex === cellLoader.index
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
                            hovered: grid.hoverIndex === cellLoader.index || grid.folderTargetIndex === cellLoader.index
                            pressed: grid.pressIndex === cellLoader.index
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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        preventStealing: true

        property real pressX: 0
        property real pressY: 0
        property int pressEntry: -1
        property bool swiping: false
        property bool iconDragging: false
        property real lastX: 0
        property real lastT: 0
        property real velocity: 0     // px per ms

        function toScreen(mouse) {
            return mapToItem(grid.screenView, mouse.x, mouse.y);
        }

        onPressed: mouse => {
            pressX = mouse.x;
            pressY = mouse.y;
            lastX = mouse.x;
            lastT = Date.now();
            velocity = 0;
            swiping = false;
            iconDragging = false;
            pressEntry = grid.hitTest(mouse.x, mouse.y);
            grid.pressIndex = pressEntry;
        }
        onPositionChanged: mouse => {
            if (!pressed) {
                grid.hoverIndex = grid.hitTest(mouse.x, mouse.y);
                return;
            }
            if (iconDragging) {
                grid.screenView.iconDragMove(toScreen(mouse));
                return;
            }
            const dx = mouse.x - pressX, dy = mouse.y - pressY;
            if (!swiping && Math.hypot(dx, dy) > Qt.styleHints.startDragDistance) {
                grid.pressIndex = -1;
                grid.hoverIndex = -1;
                if (pressEntry >= 0 && grid.screenView && (pressedButtons & Qt.LeftButton)) {
                    // press on an icon: drag the icon
                    iconDragging = true;
                    grid.dragEntryIndex = pressEntry;
                    const r = mapToItem(grid.screenView, pressX, pressY);
                    grid.screenView.iconDragBegin(grid, grid.entries[pressEntry], r, toScreen(mouse), grid.geom.iconSize);
                    return;
                }
                swiping = true;
            }
            if (swiping) {
                const now = Date.now();
                const dt = Math.max(1, now - lastT);
                velocity = 0.6 * velocity + 0.4 * (mouse.x - lastX) / dt;
                lastX = mouse.x;
                lastT = now;
                grid.followUpdate(-dx / grid.pageWidth);
            }
        }
        onReleased: mouse => {
            if (iconDragging) {
                iconDragging = false;
                grid.screenView.iconDragEnd(toScreen(mouse));
                return;
            }
            if (swiping) {
                swiping = false;
                const dx = mouse.x - pressX;
                const fast = Math.abs(velocity) > 0.4;
                const far = Math.abs(dx) > grid.pageWidth * 0.2;
                grid.followEnd(fast || far, (fast ? -velocity : -dx) > 0 ? 1 : -1);
                grid.hoverIndex = grid.hitTest(mouse.x, mouse.y);
                return;
            }
            const index = grid.hitTest(mouse.x, mouse.y);
            grid.pressIndex = -1;
            if (mouse.button === Qt.RightButton) {
                if (index >= 0) {
                    grid.entryMenu(grid.entries[index], toScreen(mouse));
                }
                return;
            }
            if (index >= 0) {
                grid.entryActivated(grid.entries[index], mouse.button, mouse.modifiers);
            } else if (mouse.button === Qt.LeftButton) {
                grid.emptyClicked();
            }
        }
        onCanceled: {
            if (iconDragging) {
                iconDragging = false;
                grid.screenView.iconDragEnd(null);
            }
            if (swiping) {
                swiping = false;
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
            opacity: shown || (grid.dragOver && next) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
            // .page-navigation-hint while dragging
            Rectangle {
                anchors.fill: parent
                visible: grid.dragOver
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, next ? 0 : 0.05) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, next ? 0.05 : 0) }
                }
            }
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
