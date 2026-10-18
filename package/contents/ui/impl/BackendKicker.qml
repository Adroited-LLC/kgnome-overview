// SPDX-License-Identifier: GPL-2.0-or-later
// Pure-QML fallback backend using Plasma's private Kicker models, for when the
// C++ module cannot be loaded at all. Icons load synchronously here, and the
// dash only knows favourites from the effect configuration / defaults.
import QtQuick
import org.kde.plasma.private.kicker as Kicker
import org.kde.kitemmodels as KItemModels

QtObject {
    id: backend
    readonly property string kind: "kicker"
    property string searchText: ""
    property var favoriteIds: []

    readonly property var defaultFavorites: ["org.mozilla.firefox.desktop", "firefox.desktop",
        "org.kde.dolphin.desktop", "org.kde.konsole.desktop", "org.kde.kate.desktop",
        "org.kde.discover.desktop", "systemsettings.desktop"]

    // Kicker's AppsModel refuses to populate as a root model without an
    // applet interface; an empty object is enough (no hidden-apps config).
    readonly property QtObject _applet: QtObject {}

    readonly property Kicker.RootModel _root: Kicker.RootModel {
        appletInterface: backend._applet
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        autoPopulate: true
    }

    readonly property var apps: _root.count > 0 ? _root.modelForRow(0) : null

    readonly property Kicker.SimpleFavoritesModel favorites: Kicker.SimpleFavoritesModel {
        favorites: backend.favoriteIds.length > 0 ? backend.favoriteIds : backend.defaultFavorites
    }

    readonly property KItemModels.KSortFilterProxyModel searchApps: KItemModels.KSortFilterProxyModel {
        sourceModel: backend.apps
        filterRoleName: "display"
        filterString: backend.searchText
        filterCaseSensitivity: Qt.CaseInsensitive
    }

    property int revision: 0
    readonly property list<Connections> _watchers: [
        Connections { target: backend.apps; function onModelReset() { backend.revision++ } function onCountChanged() { backend.revision++ } },
        Connections { target: backend.favorites; function onModelReset() { backend.revision++ } function onCountChanged() { backend.revision++ } },
        Connections { target: backend.searchApps; function onModelReset() { backend.revision++ } function onCountChanged() { backend.revision++ } function onRowsInserted() { backend.revision++ } function onRowsRemoved() { backend.revision++ } }
    ]

    function modelFor(which) {
        return which === "favorites" ? favorites : which === "search" ? searchApps : apps;
    }
    function count(which) {
        const m = modelFor(which);
        return m ? m.count : 0;
    }
    function appAt(which, row) {
        const m = modelFor(which);
        if (!m || row < 0 || row >= m.count) {
            return null;
        }
        const idx = m.index(row, 0);
        let id = m.data(idx, Qt.UserRole + 3) || ""; // Kicker FavoriteIdRole
        if (id.startsWith("applications:")) {
            id = id.substring(13);
        }
        return {name: m.data(idx, Qt.DisplayRole), iconName: "", iconPath: "", icon: m.data(idx, Qt.DecorationRole), storageId: id};
    }

    function launch(which, row) {
        if (which === "favorites") {
            return favorites.trigger(row, "", null);
        }
        if (which === "search") {
            const src = searchApps.mapToSource(searchApps.index(row, 0)).row;
            return apps ? apps.trigger(src, "", null) : false;
        }
        return apps ? apps.trigger(row, "", null) : false;
    }
    function launchId(storageId) {
        if (!apps) {
            return false;
        }
        for (let i = 0; i < apps.count; ++i) {
            const fav = apps.data(apps.index(i, 0), Qt.UserRole + 3); // FavoriteIdRole
            if (fav === storageId || fav === "applications:" + storageId) {
                return apps.trigger(i, "", null);
            }
        }
        return false;
    }
}
