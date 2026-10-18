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
import org.kde.ksvg as KSvg
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
    // "auto" follows the Plasma theme (light or dark GNOME palette)
    property string styleVariant: "auto"
    // "gnome": GNOME's default blue #3584e4; "plasma": the KDE accent colour
    property string accentSource: "gnome"
    readonly property real u: Kirigami.Units.gridUnit / 18
    readonly property var pal: G.palette(styleVariant === "dark" || (styleVariant !== "light" && G.isDark(Kirigami.Theme.backgroundColor)),
                                         accentSource === "plasma" ? Kirigami.Theme.highlightColor : G.gnomeAccent)

    signal screenshot()
    signal openSettings()
    signal lock()
    signal suspend()
    signal reboot()
    signal powerOff()
    signal logOut()
    signal switchUser()
    signal closeRequested()

    onIsOpenChanged: {
        if (!isOpen) {
            powerMenuOpen = false;
            if (volume.item) volume.item.menuOpen = false;
        } else {
            bumpTimer.restart();
        }
    }
    // Plasma restores the popup's last size from the applet config before it
    // reads our Layout hints, and only re-applies Layout.minimumHeight when it
    // changes; nudge it each time the sheet opens so the popup always fits.
    property int minBump: 0
    Timer { id: bumpTimer; interval: 1; onTriggered: { sheet.minBump = 1; Qt.callLater(() => { sheet.minBump = 0; }); } }

    readonly property real contentWidth: (2 * G.toggleWidth + G.gridSpacing) * u
    Layout.preferredWidth: contentWidth + 2 * G.sheetPadding * u
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    readonly property real wantedHeight: column.implicitHeight + 2 * G.sheetPadding * u
    readonly property real screenLimit: (Screen.desktopAvailableHeight > 0 ? Screen.desktopAvailableHeight * 0.9 : 100000)
    Layout.preferredHeight: Math.min(wantedHeight, screenLimit)
    Layout.minimumHeight: Layout.preferredHeight + minBump
    Layout.maximumHeight: Layout.preferredHeight + minBump

    color: "transparent"
    focus: true

    // Plasma always draws its own popup frame (CompactApplet.qml sets
    // StandardBackground/SolidBackground), so the GNOME card is stretched
    // over the frame's padding to cover it, leaving only its outer edge.
    KSvg.FrameSvgItem {
        id: frameRef
        visible: false
        imagePath: "dialogs/background"
    }
    Rectangle {
        id: card
        visible: sheet.drawBackground
        anchors.fill: parent
        anchors.leftMargin: -frameRef.margins.left
        anchors.rightMargin: -frameRef.margins.right
        anchors.topMargin: -frameRef.margins.top
        anchors.bottomMargin: -frameRef.margins.bottom
        color: sheet.pal.sheetBg
        radius: G.sheetRadius * sheet.u
        border.width: 1
        border.color: sheet.pal.sheetBorder
    }
    Keys.onEscapePressed: powerMenuOpen ? (powerMenuOpen = false) : closeRequested()

    KCoreAddons.KUser { id: kuser }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: G.sheetPadding * sheet.u
        contentWidth: width
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive

    ColumnLayout {
        id: column
        width: flick.width
        spacing: G.gridSpacing * sheet.u

        // Optional (GNOME 50 doesn't show the user in this menu)
        RowLayout {
            visible: sheet.showUserHeader
            spacing: G.gridSpacing * sheet.u
            Rectangle {   // avatar: ~/.face.icon / AccountsService picture, else an icon
                Layout.preferredWidth: 40 * sheet.u
                Layout.preferredHeight: 40 * sheet.u
                radius: width / 2
                color: sheet.pal.button
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
                    color: sheet.pal.fg
                    isMask: true
                }
            }
            Text {
                Layout.fillWidth: true
                text: kuser.fullName || kuser.loginName
                color: sheet.pal.fg
                font.weight: Font.Bold
                font.pixelSize: G.titlePt * 4 / 3 * sheet.u * 1.1
                elide: Text.ElideRight
            }
        }

        // System row (status/system.js SystemItem)
        RowLayout {
            Layout.fillWidth: true
            spacing: G.systemRowSpacing * sheet.u
            Loader {
                id: battery
                source: "parts/BatteryItem.qml"
                visible: status === Loader.Ready && item.available
                onLoaded: { item.u = Qt.binding(() => sheet.u); item.pal = Qt.binding(() => sheet.pal); }
                Connections {
                    target: battery.item
                    function onActivated() { sheet.closeRequested(); }
                }
            }
            Item { Layout.fillWidth: true; visible: battery.visible }   // laptop spacer
            IconButton {
                u: sheet.u
                pal: sheet.pal
                iconName: "camera-photo-symbolic"
                toolTip: i18n("Take Screenshot")
                onClicked: sheet.screenshot()
            }
            IconButton {
                u: sheet.u
                pal: sheet.pal
                iconName: "configure-symbolic"
                toolTip: i18n("Settings")
                onClicked: sheet.openSettings()
            }
            Item { Layout.fillWidth: true; visible: !battery.visible }  // desktop spacer
            IconButton {
                u: sheet.u
                pal: sheet.pal
                visible: sheet.sessions.canLock
                iconName: "system-lock-screen-symbolic"
                toolTip: i18n("Lock Screen")
                onClicked: sheet.lock()
            }
            IconButton {
                u: sheet.u
                pal: sheet.pal
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
            // .quick-toggle-menu: card, radius 24, margin-top 12, padding 12
            Layout.preferredHeight: sheet.powerMenuOpen ? menuColumn.implicitHeight + 2 * G.basePadding * 2 * sheet.u : 0
            Layout.topMargin: visible ? G.menuMargin * sheet.u - column.spacing : -column.spacing
            visible: Layout.preferredHeight > 0
            opacity: sheet.powerMenuOpen ? 1 : 0
            clip: true
            radius: G.menuRadius * sheet.u
            color: sheet.pal.card
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            ColumnLayout {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: G.basePadding * 2 * sheet.u
                spacing: 0

                RowLayout {   // .quick-toggle-menu .header
                    Layout.bottomMargin: G.basePadding * 2 * sheet.u
                    spacing: G.basePadding * 2 * sheet.u
                    Rectangle {   // .header .icon: 24px icon, padding 9, fg 20%
                        Layout.preferredWidth: (G.iconSize * 1.5 + 2 * 1.5 * G.basePadding) * sheet.u
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: width / 2
                        color: sheet.pal.headerIcon
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: G.iconSize * 1.5 * sheet.u; height: width
                            source: "system-shutdown-symbolic"
                            color: sheet.pal.fg
                            isMask: true
                        }
                    }
                    Text {
                        text: i18n("Power Off")
                        color: sheet.pal.fg
                        font.weight: Font.Bold
                        font.pixelSize: 15 * 4 / 3 * sheet.u   // %title_3
                    }
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u; pal: sheet.pal
                    visible: sheet.sessions.canSuspend
                    text: i18n("Suspend")
                    onTriggered: sheet.suspend()
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u; pal: sheet.pal
                    visible: sheet.sessions.canReboot
                    text: i18n("Restart…")
                    onTriggered: sheet.reboot()
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u; pal: sheet.pal
                    visible: sheet.sessions.canShutdown
                    text: i18n("Power Off…")
                    onTriggered: sheet.powerOff()
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.margins: G.basePadding * sheet.u
                    implicitHeight: 1
                    color: sheet.pal.menuSeparator
                    visible: sheet.sessions.canLogout || sheet.sessions.canSwitchUser
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u; pal: sheet.pal
                    visible: sheet.sessions.canLogout
                    text: i18n("Log Out…")
                    onTriggered: sheet.logOut()
                }
                MenuItemRow {
                    Layout.fillWidth: true; u: sheet.u; pal: sheet.pal
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
            onLoaded: item.pal = Qt.binding(() => sheet.pal)
        }
        Loader {
            id: brightness
            Layout.fillWidth: true
            source: "parts/BrightnessSliders.qml"
            visible: status === Loader.Ready && item.available
            onLoaded: item.pal = Qt.binding(() => sheet.pal)
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
                    onLoaded: item.pal = Qt.binding(() => sheet.pal)
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
}
