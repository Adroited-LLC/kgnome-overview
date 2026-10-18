// SPDX-License-Identifier: GPL-2.0-or-later
// App icon that decodes asynchronously: the C++ module resolves the icon
// theme path, and Image { asynchronous: true } loads it on a worker thread.
// Falls back to Kirigami.Icon (synchronous QIcon lookup) when there is no path.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: icon

    property string iconPath: ""
    property var fallback: ""      // icon name or QIcon
    property int size: 48

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image
        anchors.fill: parent
        source: icon.iconPath.length > 0 ? "file://" + icon.iconPath : ""
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(icon.size, icon.size)
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Loader {
        anchors.fill: parent
        active: icon.iconPath.length === 0 || image.status === Image.Error
        asynchronous: true
        sourceComponent: Kirigami.Icon {
            source: icon.fallback || "application-x-executable"
        }
    }
}
