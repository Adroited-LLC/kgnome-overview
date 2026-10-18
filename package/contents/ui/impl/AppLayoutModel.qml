// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// The app grid's arrangement, like GNOME's org.gnome.shell app-picker-layout
// and app-folders settings: the order of apps and folders, and the folders'
// contents. Persisted in kwinrc [Effect-kgnomeoverview] as AppLayout
// (ids, folders as "folder:<name>") and AppFolders ("Name=id;id;...").
// Until the first change the grid is alphabetical; apps that are not in the
// saved layout (newly installed) are appended alphabetically.
import QtQuick
import "Folders.js" as F

QtObject {
    id: model

    required property QtObject effect
    readonly property QtObject backend: effect.backend
    readonly property var cfg: effect.cfg

    readonly property var savedLayout: (cfg && cfg.AppLayout) ? cfg.AppLayout.filter(s => s.length > 0) : []
    readonly property var folders: F.parse((cfg && cfg.AppFolders) ? cfg.AppFolders.filter(s => s.length > 0) : [])

    // installed apps: id -> {row, name}
    readonly property var installed: {
        const map = {};
        if (!backend) {
            return map;
        }
        backend.revision;
        const n = backend.count("apps");
        for (let i = 0; i < n; ++i) {
            const app = backend.appAt("apps", i);
            if (app) {
                map[F.normalizeId(app.storageId)] = {row: i, name: app.name};
            }
        }
        return map;
    }

    // GNOME (appDisplay.js _loadApps): favourites are not in the grid or folders
    readonly property var hidden: {
        const set = {};
        if (effect.hideFavoritesInGrid) {
            for (const id of effect.favoriteIds) {
                set[F.normalizeId(id)] = true;
            }
        }
        return set;
    }

    function appEntry(id) {
        if (hidden[id]) {
            return null;
        }
        const a = installed[id];
        return a ? {kind: "app", id: id, index: a.row, name: a.name} : null;
    }
    function folderEntry(folder) {
        const apps = [], appIds = [];
        for (const id of folder.ids) {
            const a = hidden[id] ? null : installed[id];
            if (a) {
                apps.push(a.row);
                appIds.push(id);
            }
        }
        return apps.length > 0 ? {kind: "folder", id: "folder:" + folder.name, index: -1, name: folder.name, apps: apps, appIds: appIds} : null;
    }

    // [{kind: "app"|"folder", id, index (app row), name, apps, appIds}]
    readonly property var entries: {
        const inFolder = {};
        const folderById = {};
        for (const f of folders) {
            for (const id of f.ids) {
                inFolder[id] = true;
            }
            folderById["folder:" + f.name] = f;
        }
        const used = {};
        const list = [];
        for (const key of savedLayout) {
            if (used[key]) {
                continue;
            }
            let e = null;
            if (folderById[key]) {
                e = folderEntry(folderById[key]);
            } else if (!inFolder[key]) {
                e = appEntry(key);
            }
            if (e) {
                used[key] = true;
                list.push(e);
            }
        }
        const rest = [];
        for (const f of folders) {
            const key = "folder:" + f.name;
            if (!used[key]) {
                const e = folderEntry(f);
                if (e) {
                    rest.push(e);
                }
            }
        }
        for (const id in installed) {
            if (!used[id] && !inFolder[id] && !hidden[id]) {
                rest.push(appEntry(id));
            }
        }
        rest.sort((a, b) => a.name.localeCompare(b.name));
        return list.concat(rest);
    }

    function folderNamed(name) {
        for (const e of entries) {
            if (e.kind === "folder" && e.name === name) {
                return e;
            }
        }
        return null;
    }

    // --- mutations -----------------------------------------------------------
    function save(layoutIds, newFolders) {
        // drop folders that ended up with fewer than two apps (GNOME dissolves them)
        const kept = [];
        for (const f of newFolders) {
            const present = f.ids.filter(id => installed[id] !== undefined);
            if (present.length >= 2) {
                kept.push(f);
            } else if (present.length === 1) {
                const pos = layoutIds.indexOf("folder:" + f.name);
                if (pos >= 0) {
                    layoutIds.splice(pos, 1, present[0]);
                } else {
                    layoutIds.push(present[0]);
                }
            }
        }
        // keep hidden favourites at their old places, for when they are unpinned
        savedLayout.forEach((k, i) => {
            if (hidden[k] && layoutIds.indexOf(k) < 0) {
                layoutIds.splice(Math.min(i, layoutIds.length), 0, k);
            }
        });
        const keptNames = kept.map(f => "folder:" + f.name);
        layoutIds = layoutIds.filter(k => !k.startsWith("folder:") || keptNames.indexOf(k) >= 0);
        effect.writeConfig("AppFolders", F.serialize(kept));
        effect.writeConfig("AppLayout", layoutIds);
    }
    function currentIds() {
        return entries.map(e => e.id);
    }
    function cloneFolders() {
        return folders.map(f => ({name: f.name, ids: f.ids.slice()}));
    }
    function removeFromFolders(fs, id) {
        for (const f of fs) {
            const i = f.ids.indexOf(id);
            if (i >= 0) {
                f.ids.splice(i, 1);
            }
        }
    }

    // move an app or folder (by id) to position `insertAt` of the main grid,
    // counted in the list without the moved item; takes apps out of folders
    function moveTo(id, insertAt) {
        const ids = currentIds().filter(k => k !== id);
        const fs = cloneFolders();
        removeFromFolders(fs, id);
        ids.splice(Math.max(0, Math.min(ids.length, insertAt)), 0, id);
        save(ids, fs);
    }
    // drop app `id` onto the app `targetId`: new folder at the target's place
    function createFolder(id, targetId, name) {
        const fs = cloneFolders();
        removeFromFolders(fs, id);
        removeFromFolders(fs, targetId);
        const folderName = F.uniqueName(fs, name || "Unnamed Folder");
        fs.push({name: folderName, ids: [targetId, id]});
        const ids = currentIds().filter(k => k !== id);
        const pos = ids.indexOf(targetId);
        ids.splice(pos >= 0 ? pos : ids.length, pos >= 0 ? 1 : 0, "folder:" + folderName);
        save(ids, fs);
        return folderName;
    }
    function addToFolder(id, folderName) {
        const fs = cloneFolders();
        removeFromFolders(fs, id);
        const f = fs.find(x => x.name === folderName);
        if (!f) {
            return;
        }
        f.ids.push(id);
        save(currentIds().filter(k => k !== id), fs);
    }
    // reorder inside a folder (insertAt counted without the moved app)
    function moveInFolder(folderName, id, insertAt) {
        const fs = cloneFolders();
        const f = fs.find(x => x.name === folderName);
        if (!f) {
            return;
        }
        const present = f.ids.filter(x => installed[x] !== undefined && !hidden[x] && x !== id);
        const absent = f.ids.filter(x => (installed[x] === undefined || hidden[x]) && x !== id);
        present.splice(Math.max(0, Math.min(present.length, insertAt)), 0, id);
        f.ids = present.concat(absent);
        save(currentIds(), fs);
    }
    function renameFolder(oldName, newName) {
        newName = newName.trim();
        if (newName.length === 0 || newName === oldName) {
            return oldName;
        }
        const fs = cloneFolders();
        const f = fs.find(x => x.name === oldName);
        if (!f) {
            return oldName;
        }
        f.name = F.uniqueName(fs, newName, oldName);
        const ids = currentIds().map(k => k === "folder:" + oldName ? "folder:" + f.name : k);
        save(ids, fs);
        return f.name;
    }
}
