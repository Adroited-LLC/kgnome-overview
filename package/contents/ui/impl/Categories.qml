// SPDX-License-Identifier: GPL-2.0-or-later
// Menu categories (from Plasma's Kicker models) to name a new folder after
// the category two apps share, like GNOME's _findBestFolderName.
import QtQuick
import org.kde.plasma.private.kicker as Kicker

QtObject {
    id: cats

    readonly property QtObject _applet: QtObject {}
    readonly property Kicker.RootModel _root: Kicker.RootModel {
        appletInterface: cats._applet
        flat: false
        sorted: true
        showSeparators: false
        showAllApps: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        autoPopulate: true
    }

    function normalize(id) {
        id = String(id || "");
        if (id.startsWith("applications:")) {
            id = id.substring(13);
        }
        return id.endsWith(".desktop") ? id.slice(0, -8) : id;
    }

    // id -> [category names], most specific (sub-category) first
    function collect(model, names, out, depth) {
        for (let j = 0; model && j < model.count && depth < 3; ++j) {
            const idx = model.index(j, 0);
            const id = normalize(model.data(idx, Qt.UserRole + 3)); // FavoriteIdRole
            if (id) {
                (out[id] = out[id] || []).push(...names);
            } else if (model.modelForRow) {
                const sub = model.modelForRow(j);
                const subName = model.data(idx, Qt.DisplayRole);
                if (sub && subName) {
                    collect(sub, [subName].concat(names), out, depth + 1);
                }
            }
        }
    }
    function map() {
        const out = {};
        for (let i = 0; i < _root.count; ++i) {
            const name = _root.data(_root.index(i, 0), Qt.DisplayRole);
            if (name) {
                collect(_root.modelForRow(i), [name], out, 0);
            }
        }
        return out;
    }

    function sharedCategory(ids) {
        const m = map();
        let common = null;
        for (const id of ids) {
            const c = m[normalize(id)] || [];
            common = common === null ? c.slice() : common.filter(x => c.indexOf(x) >= 0);
        }
        return common && common.length > 0 ? common[0] : "";
    }
}
