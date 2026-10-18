// SPDX-License-Identifier: GPL-2.0-or-later
// Backend using the C++ module found through the QML import path
// (QML_IMPORT_PATH from ~/.config/plasma-workspace/env/kgnome-overview.sh,
// effective after the next login).
import QtQuick
import org.kgnome.overview as KG

QtObject {
    id: backend
    readonly property string kind: "module"
    property string searchText: ""
    property var favoriteIds: []

    readonly property KG.AppsModel apps: KG.AppsModel {}
    readonly property KG.AppsModel favorites: KG.AppsModel {
        favoritesOnly: true
        favoriteIds: backend.favoriteIds
    }
    readonly property KG.AppsModel searchApps: KG.AppsModel {
        filterString: backend.searchText
        limit: 12
    }

    function modelFor(which) {
        return which === "favorites" ? favorites : which === "search" ? searchApps : apps;
    }
    function launch(which, row) {
        return modelFor(which).launchRow(row);
    }
    function launchId(storageId) {
        return KG.Launcher.launch(storageId);
    }
}
