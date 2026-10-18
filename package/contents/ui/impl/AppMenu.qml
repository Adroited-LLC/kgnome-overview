// SPDX-License-Identifier: GPL-2.0-or-later
// App context menu like GNOME 50's AppMenu (js/ui/appMenu.js), kept simple:
// New Window, Pin to Dash / Unpin, Quit (only while running). GNOME's
// "App Details" (GNOME Software) and per-window entries are left out.
// Styled after .popup-menu-content: dark rounded box, 12px radius items.
import QtQuick
import "Layout.js" as L

Item {
    id: menu

    required property Item screenView
    readonly property QtObject effect: screenView.effect
    readonly property real s: screenView.s
    readonly property string appId: screenView.appMenuFor
    readonly property bool shown: appId.length > 0
    property point anchorPoint
    property bool above: true

    visible: shown
    enabled: shown

    function open(id, p, placeAbove) {
        anchorPoint = p;
        above = placeAbove !== false;
        screenView.appMenuFor = id;
    }
    function close() {
        screenView.appMenuFor = "";
    }
    Connections {
        target: menu.effect
        function onVisibleChanged() { menu.close() }
        function onTargetStateChanged() { menu.close() }
    }

    readonly property bool running: shown && (effect.runningWindows, effect.windowsFor(appId).length > 0)
    readonly property bool favorite: shown && (effect.favoriteIds, effect.isFavorite(appId))
    readonly property var actions: {
        if (!shown) {
            return [];
        }
        const list = [{text: "New Window", run: () => effect.newWindow(appId)}, {separator: true},
                      {text: favorite ? "Unpin" : "Pin to Dash",
                       run: () => favorite ? effect.removeFavorite(appId) : effect.addFavorite(appId, -1)}];
        if (running) {
            list.push({separator: true});
            list.push({text: "Quit", run: () => effect.quitApp(appId)});
        }
        return list;
    }

    // click outside closes
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menu.close()
        onWheel: menu.close()
    }

    Rectangle {
        id: box
        readonly property int pad: Math.round(6 * menu.s)
        width: Math.max(Math.round(180 * menu.s), column.implicitWidth) + 2 * pad
        height: column.implicitHeight + 2 * pad
        x: L.clamp(menu.anchorPoint.x - width / 2, Math.round(8 * menu.s), menu.width - width - Math.round(8 * menu.s))
        y: menu.above ? menu.anchorPoint.y - height - Math.round(12 * menu.s) : menu.anchorPoint.y + Math.round(12 * menu.s)
        radius: Math.round(18 * menu.s)
        color: Qt.rgba(0.16, 0.16, 0.18, 0.98)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        MouseArea {
            anchors.fill: parent   // keep clicks inside from closing
        }

        Column {
            id: column
            x: box.pad
            y: box.pad
            width: box.width - 2 * box.pad
            Repeater {
                model: menu.actions.length
                delegate: Item {
                    required property int index
                    readonly property var action: menu.actions[index]
                    width: column.width
                    implicitWidth: label.implicitWidth + Math.round(24 * menu.s)
                    height: action.separator ? Math.round(9 * menu.s) : Math.round(36 * menu.s)
                    Rectangle {
                        visible: !!parent.action.separator
                        anchors.centerIn: parent
                        width: parent.width - Math.round(24 * menu.s)
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.1)
                    }
                    Rectangle {
                        visible: !parent.action.separator
                        anchors.fill: parent
                        radius: Math.round(12 * menu.s)
                        color: Qt.rgba(1, 1, 1, itemArea.pressed ? 0.15 : itemArea.containsMouse ? 0.1 : 0)
                    }
                    Text {
                        id: label
                        visible: !parent.action.separator
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(12 * menu.s)
                        color: L.SYSTEM_FG_COLOR
                        font.pixelSize: menu.screenView.fontPx
                        text: parent.action.text || ""
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        enabled: !parent.action.separator
                        hoverEnabled: true
                        onClicked: {
                            const run = parent.action.run;
                            menu.close();
                            run();
                        }
                    }
                }
            }
        }
    }
}
