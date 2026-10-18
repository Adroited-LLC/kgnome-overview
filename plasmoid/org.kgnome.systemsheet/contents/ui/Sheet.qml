// SPDX-License-Identifier: GPL-2.0-or-later
// The Quick Settings sheet. Layout, top to bottom, as in GNOME 50
// (js/ui/panel.js QuickSettings._setupIndicators, N_QUICK_SETTINGS_COLUMNS 2):
//   system row (battery | screenshot, settings | lock, power ▸ submenu)
//   output volume slider, brightness slider
//   two-column toggles: network, bluetooth, night light, dark style, DND
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import "parts"
import "parts/Gnome.js" as G

Rectangle {
    id: sheet
    property var sessions
    property bool showUserHeader: false
    property bool showToggles: true
    property bool showDarkStyle: true
    property bool drawBackground: true
    property bool isOpen: false
    property bool powerMenuOpen: false
    readonly property real u: Kirigami.Units.gridUnit / 18

    signal screenshot()
    signal openSettings()
    signal lock()
    signal suspend()
    signal reboot()
    signal powerOff()
    signal logOut()
    signal switchUser()
    signal closeRequested()

    onIsOpenChanged: if (!isOpen) powerMenuOpen = false

    readonly property real contentWidth: (2 * G.toggleWidth + G.gridSpacing) * u
    Layout.preferredWidth: contentWidth + 2 * G.sheetPadding * u
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    Layout.preferredHeight: column.implicitHeight + 2 * G.sheetPadding * u
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    color: drawBackground ? G.sheetBg : "transparent"
    radius: G.sheetRadius * u
    focus: true
    Keys.onEscapePressed: powerMenuOpen ? (powerMenuOpen = false) : closeRequested()

    KCoreAddons.KUser { id: kuser }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: G.sheetPadding * sheet.u
        spacing: G.gridSpacing * sheet.u

        // Optional (GNOME 50 doesn't show the user in this menu)
        RowLayout {
            visible: sheet.showUserHeader
            spacing: G.gridSpacing * sheet.u
            Rectangle {   // avatar: ~/.face.icon / AccountsService picture, else an icon
                Layout.preferredWidth: 40 * sheet.u
                Layout.preferredHeight: 40 * sheet.u
                radius: width / 2
                color: G.buttonBg
                clip: true
                Image {
                    id: face
                    anchors.fill: parent
                    source: kuser.faceIconUrl
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    visible: false
                }
                Kirigami.ShadowedTexture {
                    anchors.fill: parent
                    visible: face.status === Image.Ready
                    radius: width / 2
                    source: face
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 24 * sheet.u; height: width
                    visible: face.status !== Image.Ready
                    source: "user-symbolic"
                    fallback: "user-identity"
                    color: G.fg
                    isMask: true
                }
            }
            Text {
                Layout.fillWidth: true
                text: kuser.fullName || kuser.loginName
                color: G.fg
                font.weight: Font.Bold
                font.pixelSize: 14.67 * sheet.u * 1.05
                elide: Text.ElideRight
            }
        }

        // System row (status/system.js SystemItem)
        RowLayout {
            Layout.fillWidth: true
            spacing: G.basePadding * 1.5 * sheet.u
            Loader {
                id: battery
                source: "parts/BatteryItem.qml"
                visible: status === Loader.Ready && item.available
                onLoaded: item.u = Qt.binding(() => sheet.u)
                Connections {
                    target: battery.item
                    function onActivated() { sheet.closeRequested(); }
                }
            }
            Item { Layout.fillWidth: true; visible: battery.visible }   // laptop spacer
            IconButton {
                u: sheet.u
                iconName: "camera-photo-symbolic"
                toolTip: i18n("Take Screenshot")
                onClicked: sheet.screenshot()
            }
            IconButton {
                u: sheet.u
                iconName: "configure-symbolic"
                toolTip: i18n("Settings")
                onClicked: sheet.openSettings()
            }
            Item { Layout.fillWidth: true; visible: !battery.visible }  // desktop spacer
            IconButton {
                u: sheet.u
                visible: sheet.sessions.canLock
                iconName: "system-lock-screen-symbolic"
                toolTip: i18n("Lock Screen")
                onClicked: sheet.lock()
            }
            IconButton {
                u: sheet.u
                iconName: "system-shutdown-symbolic"
                toolTip: i18n("Power Off / Log Out")
                checked: sheet.powerMenuOpen
                onClicked: sheet.powerMenuOpen = !sheet.powerMenuOpen
            }
        }

        // Power submenu (ShutdownItem menu, header "Power Off")
        // slides open inline, pushing the sliders and toggles down
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: sheet.powerMenuOpen ? menuColumn.implicitHeight + 2 * G.basePadding * sheet.u : 0
            Layout.topMargin: visible ? 0 : -column.spacing
            visible: Layout.preferredHeight > 0
            opacity: sheet.powerMenuOpen ? 1 : 0
            clip: true
            radius: G.menuRadius * sheet.u
            color: G.menuBg
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            ColumnLayout {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: G.basePadding * sheet.u
                spacing: 0

                RowLayout {   // .quick-toggle-menu .header
                    Layout.margins: G.basePadding * sheet.u
                    spacing: G.gridSpacing * sheet.u
                    Rectangle {
                        Layout.preferredWidth: 32 * sheet.u
                        Layout.preferredHeight: 32 * sheet.u
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: G.iconSize * sheet.u; height: width
                            source: "system-shutdown-symbolic"
                            color: G.fg
                            isMask: true
                        }
                    }
                    Text {
                        text: i18n("Power Off")
                        color: G.fg
                        font.weight: Font.Bold
                        font.pixelSize: 14.67 * sheet.u * 1.1
                    }
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u
                    visible: sheet.sessions.canSuspend
                    text: i18n("Suspend")
                    onTriggered: sheet.suspend()
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u
                    visible: sheet.sessions.canReboot
                    text: i18n("Restart…")
                    onTriggered: sheet.reboot()
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u
                    visible: sheet.sessions.canShutdown
                    text: i18n("Power Off…")
                    onTriggered: sheet.powerOff()
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.margins: G.basePadding * sheet.u
                    implicitHeight: 1
                    color: G.separator
                    visible: sheet.sessions.canLogout || sheet.sessions.canSwitchUser
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u
                    visible: sheet.sessions.canLogout
                    text: i18n("Log Out…")
                    onTriggered: sheet.logOut()
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u
                    visible: sheet.sessions.canSwitchUser
                    text: i18n("Switch User…")
                    onTriggered: sheet.switchUser()
                }
            }
        }

        // Sliders (colspan 2)
        Loader {
            id: volume
            Layout.fillWidth: true
            source: "parts/VolumeSlider.qml"
            visible: status === Loader.Ready && item.available
        }
        Loader {
            id: brightness
            Layout.fillWidth: true
            source: "parts/BrightnessSliders.qml"
            visible: status === Loader.Ready && item.available
        }

        // Toggles (1 column each, N_QUICK_SETTINGS_COLUMNS = 2), GNOME order
        GridLayout {
            Layout.fillWidth: true
            visible: sheet.showToggles
            columns: 2
            rowSpacing: G.gridSpacing * sheet.u
            columnSpacing: G.gridSpacing * sheet.u
            Repeater {
                model: ["WifiToggle", "BluetoothToggle", "NightLightToggle", "DarkStyleToggle", "DndToggle"]
                Loader {
                    id: toggleLoader
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: G.toggleWidth * sheet.u
                    active: modelData !== "DarkStyleToggle" || sheet.showDarkStyle
                    source: "parts/" + modelData + ".qml"
                    visible: status === Loader.Ready && item.available
                    Connections {
                        target: toggleLoader.item
                        ignoreUnknownSignals: true
                        function onOpenSettings() { sheet.closeRequested(); }
                    }
                }
            }
        }
    }
}
