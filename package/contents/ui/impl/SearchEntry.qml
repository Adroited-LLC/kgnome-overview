// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's .search-entry (gnome-shell-sass/widgets/_search-entry.scss):
// width 24em, circular, padding 9px, $system_bg_color, 16px icon with
// 0 4px padding, accent focus ring. Always holds keyboard focus, so typing
// anywhere in the overview starts a search (like GNOME).
import QtQuick
import org.kde.kirigami as Kirigami
import "Layout.js" as L

FocusScope {
    id: entry

    required property Item screenView
    readonly property QtObject effect: screenView.effect
    readonly property real s: screenView.s
    readonly property alias text: input.text

    // 24em at GNOME's 11pt base font
    width: Math.round(24 * screenView.fontPx)
    height: Math.round(input.font.pixelSize * 1.3 + 2 * 9 * s)

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Qt.lighter(L.SYSTEM_BG_COLOR, hoverArea.hovered ? 1.15 : 1.0)
        // the focus ring only shows once there is something typed, like GNOME's
        // overview where the entry always has key focus
        border.width: entry.effect.searchText.length > 0 ? Math.round(2 * entry.s) : 0
        border.color: Kirigami.Theme.highlightColor
        HoverHandler {
            id: hoverArea
        }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Kirigami.Icon {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: Math.round((9 + 4) * entry.s)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(16 * entry.s)
        height: width
        source: "edit-find-symbolic"
        color: Qt.rgba(1, 1, 1, 0.7)
        isMask: true
    }

    TextInput {
        id: input
        focus: true
        anchors.left: searchIcon.right
        anchors.leftMargin: Math.round(8 * entry.s)
        anchors.right: clearButton.visible ? clearButton.left : parent.right
        anchors.rightMargin: Math.round(12 * entry.s)
        anchors.verticalCenter: parent.verticalCenter
        color: "white"
        selectionColor: Qt.rgba(0.21, 0.52, 0.89, 1)
        selectedTextColor: "white"
        font.pixelSize: entry.screenView.fontPx
        clip: true
        horizontalAlignment: TextInput.AlignLeft
        onTextEdited: entry.effect.searchText = text
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => entry.screenView.handleKey(event)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: "Type to search"
            color: Qt.rgba(0.98, 0.98, 0.98, 0.7)
            font: input.font
        }
    }

    Kirigami.Icon {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: Math.round(10 * entry.s)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(16 * entry.s)
        height: width
        visible: input.text.length > 0
        source: "edit-clear-symbolic"
        color: Qt.rgba(1, 1, 1, 0.7)
        isMask: true
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Math.round(6 * entry.s)
            onClicked: entry.effect.searchText = ""
        }
    }

    Connections {
        target: entry.effect
        function onSearchTextChanged() {
            if (input.text !== entry.effect.searchText) {
                input.text = entry.effect.searchText;
            }
        }
        function onVisibleChanged() {
            if (entry.effect.visible) {
                input.forceActiveFocus();
            }
        }
    }
    Component.onCompleted: {
        input.text = entry.effect.searchText;
        input.forceActiveFocus();
    }

    function focusInput() {
        input.forceActiveFocus();
    }
}
