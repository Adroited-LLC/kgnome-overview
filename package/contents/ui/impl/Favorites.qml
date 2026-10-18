// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Reads a Plasma launcher's KActivities favourites (Plasma's private
// KAStatsFavoritesModel for the launcher's client id, e.g. Kickoff's). Only
// used once, to seed the dash's own list (FavoriteApps) in the same order;
// the order is the launcher's "ordering" in kactivitymanagerd-statsrc.
import QtQuick
import org.kde.plasma.private.kicker as Kicker

QtObject {
    id: favs

    required property string client
    // desktop file ids ("org.kde.dolphin.desktop"), in dash order
    property var ids: []
    property bool ready: false

    readonly property Kicker.KAStatsFavoritesModel model: Kicker.KAStatsFavoritesModel {}

    readonly property list<Connections> _watchers: [
        Connections {
            target: favs.model
            function onFavoritesChanged() { Qt.callLater(favs.refresh) }
            function onCountChanged() { Qt.callLater(favs.refresh) }
            function onModelReset() { Qt.callLater(favs.refresh) }
            function onRowsMoved() { Qt.callLater(favs.refresh) }
            function onRowsInserted() { Qt.callLater(favs.refresh) }
            function onRowsRemoved() { Qt.callLater(favs.refresh) }
        }
    ]

    function normalize(id) {
        id = String(id || "");
        if (id.startsWith("applications:")) {
            id = id.substring(13);
        }
        return id;
    }
    // ids of the model's rows (resolved: preferred://browser -> the browser)
    function rowIds() {
        const out = [];
        for (let i = 0; i < model.count; ++i) {
            const idx = model.index(i, 0);
            // Kicker's FavoriteIdRole, then the URL role as a fallback
            let id = normalize(model.data(idx, Qt.UserRole + 3));
            if (!id.endsWith(".desktop")) {
                const url = String(model.data(idx, Qt.UserRole + 10) || "");
                id = url.endsWith(".desktop") ? url.substring(url.lastIndexOf("/") + 1) : id;
            }
            out.push(id);
        }
        return out;
    }
    function refresh() {
        const next = rowIds().filter(x => x.endsWith(".desktop"));
        if (next.join(",") !== ids.join(",")) {
            console.info("kgnome-overview: favourites (" + client + "):", next.length);
        }
        ids = next;
        ready = true;
    }
    function full(id) {
        return "applications:" + (id.endsWith(".desktop") ? id : id + ".desktop");
    }
    function indexOf(id) {
        const d = id.endsWith(".desktop") ? id : id + ".desktop";
        return rowIds().indexOf(d);
    }

    function add(id, position) {
        const i = indexOf(id);
        if (i >= 0) {
            move(id, position);
            return;
        }
        if (position >= 0 && position < model.count) {
            model.addFavorite(full(id), position);
        } else {
            model.addFavorite(full(id));
        }
    }
    function remove(id) {
        model.removeFavorite(full(id));
    }
    // position counted in the list without the moved item (GNOME's moveFavoriteToPos)
    function move(id, position) {
        const from = indexOf(id);
        if (from < 0) {
            return;
        }
        const to = Math.max(0, Math.min(model.count - 1, position));
        if (to !== from) {
            model.moveRow(from, to);
        }
    }

    Component.onCompleted: {
        model.initForClient(client);
        refresh();
    }
}
