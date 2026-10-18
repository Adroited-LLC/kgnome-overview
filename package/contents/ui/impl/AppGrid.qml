// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's AppDisplay: apps and folders on horizontally swiped pages, in the
// saved arrangement (AppLayoutModel; alphabetical until the first change).
// IconGrid sizing (_app-grid.scss .icon-grid): row/column spacing 12px
// (max 36px), page padding 24px top/bottom and 18px left/right plus the space
// for the navigation arrows (PAGE_PREVIEW_RATIO 0.20 of the width, split over
// both sides), horizontal page indicators under the grid. Columns, rows and
// icon size come from the Columns / Rows / IconSize settings; with Columns=0
// GNOME's 8x3 / 6x4 / 4x6 / 3x8 modes and 96..16px icons are used.
import QtQuick
import "Layout.js" as L

Item {
    id: appGrid

    required property Item screenView
    readonly property QtObject effect: screenView.effect
    readonly property QtObject backend: effect.backend
    readonly property real s: screenView.s

    readonly property real indicatorsWidth: Math.max(width * L.PAGE_PREVIEW_RATIO / 2, Math.round(72 * s))
    readonly property alias pageCount: paged.pageCount
    readonly property alias paged: paged
    readonly property int iconSize: paged.geom.iconSize
    readonly property var entries: effect.appLayout ? effect.appLayout.entries : []

    function nextPage() { paged.nextPage(); }
    function previousPage() { paged.previousPage(); }
    function goToPage(p) { paged.goToPage(p); }

    Connections {
        target: appGrid.effect
        function onVisibleChanged() {
            if (!appGrid.effect.visible) {
                paged.reset();
            }
        }
        function onPageGesture(delta, finished, commit) {
            if (finished) {
                paged.followEnd(commit, delta > 0 ? 1 : -1);
            } else {
                paged.followUpdate(delta);
            }
        }
    }

    PagedGrid {
        id: paged
        anchors.fill: parent
        enabled: appGrid.enabled
        screenView: appGrid.screenView
        entries: appGrid.entries
        backend: appGrid.backend
        s: appGrid.s
        fontPx: appGrid.screenView.fontPx
        iconScale: appGrid.effect.iconScale
        preferredIconSize: appGrid.effect.gridIconSize > 0 ? Math.round(appGrid.effect.gridIconSize * appGrid.s) : 0
        columns: appGrid.effect.gridColumns
        rows: appGrid.effect.gridRows
        padding: ({h: Math.round(18 * appGrid.s + appGrid.indicatorsWidth), v: Math.round(24 * appGrid.s)})
        spacing: Math.round(12 * appGrid.s)
        maxSpacing: Math.round(36 * appGrid.s)
        arrowAreaWidth: appGrid.indicatorsWidth
        runningWindows: appGrid.effect.runningWindows

        onEntryActivated: (entry, button, modifiers) => {
            if (entry.kind === "folder") {
                appGrid.effect.folderOpen = entry.name;
            } else {
                appGrid.effect.launchApp("apps", entry.index, button, modifiers);
            }
        }
        onEmptyClicked: appGrid.effect.setState(appGrid.effect.stateWindowPicker)
    }
}
