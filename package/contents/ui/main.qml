// SPDX-License-Identifier: GPL-2.0-or-later
// kgnome-overview bootstrap. Keep this file tiny and stable.
//
// KWin compiles every declarative effect in one shared QQmlEngine that lives
// for the whole session and caches compiled QML by URL, so a reinstalled
// effect would keep running the old code until the next login. All real code
// therefore lives in contents/ui/<ImplDir>/, where install.sh gives each
// install a fresh directory name and records it in kwinrc
// [Effect-kgnomeoverview] ImplDir.
import QtQuick
import org.kde.kwin as KWinComponents

KWinComponents.SceneEffect {
    id: sceneEffect

    property QtObject controller: null
    property string implDir: "impl"

    function implUrl(file) {
        return Qt.resolvedUrl(implDir + "/" + file);
    }

    delegate: Loader {
        // stable API for the views
        readonly property QtObject sceneScreen: KWinComponents.SceneView.screen
        readonly property QtObject sceneEffect: KWinComponents.SceneView.effect
        focus: true
        source: sceneEffect.controller ? sceneEffect.implUrl("ScreenView.qml") : ""
    }

    Component.onCompleted: {
        const configured = configuration && configuration.ImplDir ? String(configuration.ImplDir) : "";
        for (const dir of configured.length > 0 ? [configured, "impl"] : ["impl"]) {
            implDir = dir;
            const component = Qt.createComponent(implUrl("Controller.qml"));
            if (component.status === Component.Ready) {
                controller = component.createObject(sceneEffect, {sceneEffect: sceneEffect});
                if (controller) {
                    return;
                }
            }
            console.warn("kgnome-overview: cannot load", implUrl("Controller.qml"), component.errorString());
        }
    }
}
