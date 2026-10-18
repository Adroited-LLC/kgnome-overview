// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
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

    // Typed as QtObject on purpose: Plasma's kicker plugin also has a C++
    // class called AppsModel, which confuses QML's type check if both are loaded.
    readonly property QtObject apps: KG.AppsModel {}
    readonly property QtObject favorites: KG.AppsModel {
        favoritesOnly: true
        favoriteIds: backend.favoriteIds
    }
    readonly property QtObject searchApps: KG.AppsModel {
        filterString: backend.searchText
        limit: 12
    }

    // Bumped whenever any model's content changes, so JS lookups re-evaluate.
    property int revision: 0
    readonly property list<Connections> _watchers: [
        Connections { target: backend.apps; function onModelReset() { backend.revision++ } function onCountChanged() { backend.revision++ } },
        Connections { target: backend.favorites; function onModelReset() { backend.revision++ } function onCountChanged() { backend.revision++ } },
        Connections { target: backend.searchApps; function onModelReset() { backend.revision++ } function onCountChanged() { backend.revision++ } }
    ]

    function count(which) {
        return modelFor(which).count;
    }
    // Normalised entry: {name, iconName, iconPath, icon, storageId}
    function appAt(which, row) {
        const e = modelFor(which).get(row);
        if (!e || e.storageId === undefined) {
            return null;
        }
        return {name: e.name, iconName: e.iconName, iconPath: e.iconPath || "", icon: e.iconName, storageId: e.storageId};
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
