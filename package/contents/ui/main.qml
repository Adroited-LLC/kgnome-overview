// SPDX-License-Identifier: GPL-2.0-or-later
// Phase 0 spike: prove the effect loads and can reach the app backend.
import QtQuick
import org.kde.kwin as KWinComponents

KWinComponents.SceneEffect {
    id: effect

    property QtObject backend: null

    function createBackend() {
        const order = ["BackendModule.qml", "BackendLocal.qml", "BackendKicker.qml"];
        for (const file of order) {
            const component = Qt.createComponent(Qt.resolvedUrl(file));
            if (component.status === Component.Ready) {
                const obj = component.createObject(effect);
                if (obj) {
                    backend = obj;
                    console.info("kgnome-overview: using backend", obj.kind, "from", file);
                    return;
                }
            }
            console.info("kgnome-overview: backend", file, "unavailable:", component.errorString());
        }
        console.warn("kgnome-overview: no backend could be loaded");
    }

    delegate: Rectangle {
        color: "#e0202020"
        Column {
            anchors.centerIn: parent
            spacing: 20
            Text {
                color: "white"
                font.pixelSize: 48
                text: "kgnome-overview spike on " + KWinComponents.SceneView.screen.name
            }
            Text {
                color: "white"
                font.pixelSize: 32
                text: effect.backend ? ("backend: " + effect.backend.kind + ", apps: " + (effect.backend.apps ? effect.backend.apps.count : 0)
                                        + ", favourites: " + effect.backend.favorites.count) : "no backend"
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: effect.visible = false
        }
        focus: true
        Keys.onEscapePressed: effect.visible = false
    }

    KWinComponents.ShortcutHandler {
        name: "Toggle GNOME Overview"
        text: "Toggle GNOME Overview"
        sequence: "Meta+O"
        onActivated: effect.visible = !effect.visible
    }

    Component.onCompleted: createBackend()
}
