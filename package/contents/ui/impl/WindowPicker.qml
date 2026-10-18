// SPDX-License-Identifier: GPL-2.0-or-later
// Window picker: KWin's ExpoLayout (the algorithm behind KWin's overview)
// with our own GNOME-like window previews. Cells interpolate from the
// natural window geometry to the organised layout via partialActivationFactor.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import org.kde.kwin.private.effects

Item {
    id: picker

    required property Item contentParent
    required property Item screenView
    required property QtObject windowModel

    readonly property QtObject effect: screenView.effect
    readonly property QtObject targetScreen: screenView.targetScreen
    readonly property alias count: windowRepeater.count

    ExpoLayout {
        id: expoLayout
        anchors.fill: parent
        placementMode: width >= height ? ExpoLayout.Rows : ExpoLayout.Columns

        Repeater {
            id: windowRepeater
            model: KWinComponents.WindowFilterModel {
                activity: KWinComponents.Workspace.currentActivity
                desktop: KWinComponents.Workspace.currentDesktop
                screenName: picker.targetScreen.name
                windowModel: picker.windowModel
                minimizedWindows: true
                windowType: ~KWinComponents.WindowFilterModel.Dock &
                            ~KWinComponents.WindowFilterModel.Desktop &
                            ~KWinComponents.WindowFilterModel.Notification &
                            ~KWinComponents.WindowFilterModel.CriticalNotification
            }

            delegate: ExpoCell {
                id: cell

                required property QtObject window
                required property int index

                readonly property real factor: picker.screenView.pickerFactor
                readonly property real gridFactor: picker.screenView.gridFactor
                readonly property real s: picker.screenView.s
                readonly property int iconSize: Math.round(48 * s * (1 - 0.5 * gridFactor))
                readonly property bool hovered: hover.hovered && picker.screenView.interactive

                layout: expoLayout
                shouldLayout: !window.skipSwitcher
                partialActivationFactor: factor
                naturalX: window.x - picker.targetScreen.geometry.x
                naturalY: window.y - picker.targetScreen.geometry.y
                naturalWidth: window.width
                naturalHeight: window.height
                persistentKey: window.internalId
                bottomMargin: Math.round(iconSize / 2 + 8 * s)

                contentItem: Item {
                    id: content
                    parent: picker.contentParent
                    visible: !cell.window.skipSwitcher && (!cell.window.minimized || cell.factor > 0)
                    opacity: cell.window.minimized ? cell.factor : 1
                    z: cell.hovered ? 100000 : cell.window.stackingOrder

                    KWinComponents.WindowThumbnail {
                        id: thumbnail
                        anchors.fill: parent
                        wId: cell.window.internalId
                    }

                    // GNOME-style hover outline
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -Math.round(6 * cell.s)
                        radius: Math.round(12 * cell.s)
                        color: "transparent"
                        border.width: Math.round(4 * cell.s)
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                        opacity: cell.hovered ? cell.factor * (1 - cell.gridFactor) : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    // App icon overlapping the bottom edge
                    Kirigami.Icon {
                        id: appIcon
                        width: cell.iconSize
                        height: cell.iconSize
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.bottom
                        source: cell.window.icon
                        opacity: cell.factor * (1 - cell.gridFactor)
                        visible: opacity > 0
                    }

                    // Title, shown on hover
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: appIcon.bottom
                        anchors.topMargin: Math.round(4 * cell.s)
                        width: Math.min(titleLabel.implicitWidth + 2 * Math.round(10 * cell.s), Math.max(parent.width, 200 * cell.s))
                        height: titleLabel.implicitHeight + 2 * Math.round(4 * cell.s)
                        radius: height / 2
                        color: Qt.rgba(0.12, 0.12, 0.12, 0.85)
                        opacity: cell.hovered ? cell.factor * (1 - cell.gridFactor) : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Text {
                            id: titleLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 2 * Math.round(10 * cell.s))
                            text: cell.window.caption
                            color: "white"
                            elide: Text.ElideMiddle
                            font.pixelSize: Math.round(13 * cell.s)
                        }
                    }

                    // Close button (top-right), shown on hover
                    Rectangle {
                        id: closeButton
                        width: Math.round(28 * cell.s)
                        height: width
                        radius: width / 2
                        anchors.horizontalCenter: parent.right
                        anchors.verticalCenter: parent.top
                        color: closeArea.containsMouse ? "#5a5a5a" : "#3a3a3a"
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        visible: cell.hovered && cell.gridFactor === 0 && cell.factor === 1 && cell.window.closeable
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(16 * cell.s)
                            height: width
                            source: "window-close-symbolic"
                            color: "white"
                            isMask: true
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: cell.window.closeWindow()
                        }
                    }

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        enabled: picker.screenView.interactive
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                cell.window.closeWindow();
                            } else if (picker.effect.targetState === picker.effect.stateAppGrid) {
                                picker.effect.setState(picker.effect.stateWindowPicker);
                            } else {
                                picker.effect.activateWindow(cell.window);
                            }
                        }
                    }
                }
            }
        }
    }
}
