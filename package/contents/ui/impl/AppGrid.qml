// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's AppDisplay: alphabetical apps and folders on horizontally swiped
// pages. IconGrid sizing (_app-grid.scss .icon-grid): row/column spacing 12px
// (max 36px), page padding 24px top/bottom and 18px left/right plus the space
// for the navigation arrows (PAGE_PREVIEW_RATIO 0.20 of the width, split over
// both sides), best mode among 8x3 / 6x4 / 4x6 / 3x8 (rows x columns),
// icons up to 96px, horizontal page indicators under the grid.
import QtQuick
import "Layout.js" as L
import "Folders.js" as F

Item {
    id: appGrid

    required property Item screenView
    readonly property QtObject effect: screenView.effect
    readonly property QtObject backend: effect.backend
    readonly property real s: screenView.s

    readonly property real indicatorsWidth: Math.max(width * L.PAGE_PREVIEW_RATIO / 2, Math.round(72 * s))
    readonly property alias pageCount: paged.pageCount

    function nextPage() { paged.nextPage(); }
    function previousPage() { paged.previousPage(); }
    function goToPage(p) { paged.goToPage(p); }

    // apps + folders, sorted by name like GNOME's default (alphabetical) order
    readonly property var entries: {
        if (!backend) {
            return [];
        }
        backend.revision;
        const folders = F.parse(effect.folderSpecs);
        const folderApps = folders.map(() => []);
        const list = [];
        const n = backend.count("apps");
        for (let i = 0; i < n; ++i) {
            const app = backend.appAt("apps", i);
            const id = F.normalizeId(app.storageId);
            const f = folders.findIndex(folder => folder.ids[id] === true);
            if (f >= 0) {
                folderApps[f].push(i);
            } else {
                list.push({kind: "app", index: i, name: app.name});
            }
        }
        for (let f = 0; f < folders.length; ++f) {
            if (folderApps[f].length > 0) {
                list.push({kind: "folder", index: -1, name: folders[f].name, apps: folderApps[f]});
            }
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list;
    }

    function folderNamed(name) {
        for (const e of entries) {
            if (e.kind === "folder" && e.name === name) {
                return e;
            }
        }
        return null;
    }

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
        entries: appGrid.entries
        backend: appGrid.backend
        s: appGrid.s
        fontPx: appGrid.screenView.fontPx
        iconScale: appGrid.effect.iconScale
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
