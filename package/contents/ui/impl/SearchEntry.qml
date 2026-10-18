// SPDX-License-Identifier: GPL-2.0-or-later
// Adwaita-ish search pill. Always holds keyboard focus, so typing anywhere in
// the overview starts a search (like GNOME).
import QtQuick
import org.kde.kirigami as Kirigami

FocusScope {
    id: entry

    required property Item screenView
    readonly property QtObject effect: screenView.effect
    readonly property real s: screenView.s
    readonly property alias text: input.text

    width: Math.round(320 * s)
    height: Math.round(36 * s)

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: input.activeFocus && entry.effect.searchText.length > 0 ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.1)
        border.width: input.activeFocus ? Math.round(2 * entry.s) : 0
        border.color: input.activeFocus ? Qt.rgba(0.47, 0.68, 0.93, 0.8) : "transparent"   // Adwaita focus ring
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Kirigami.Icon {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: Math.round(12 * entry.s)
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
        font.pixelSize: Math.round(15 * entry.s)
        clip: true
        horizontalAlignment: TextInput.AlignLeft
        onTextEdited: entry.effect.searchText = text
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => entry.screenView.handleKey(event)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: "Type to search"
            color: Qt.rgba(1, 1, 1, 0.5)
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
