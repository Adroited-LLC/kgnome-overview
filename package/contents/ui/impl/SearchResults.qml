// SPDX-License-Identifier: GPL-2.0-or-later
// Search results like GNOME's SearchResultsView: an app row first (our own
// model, ranked like GNOME's app search), then the other providers (KRunner,
// through Milou's ResultsModel) as a list grouped by category.
// Keyboard focus never leaves the search entry: the entry forwards the arrow
// keys here, which move a highlighted selection (app row, then the list);
// Enter activates it (the first result by default). KRunner's application
// matches that are already in the app row are filtered out.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou
import org.kde.kitemmodels as KItemModels
import "Layout.js" as L

Item {
    id: results

    required property Item screenView
    property bool active: false

    readonly property QtObject effect: screenView.effect
    readonly property QtObject backend: effect.backend
    readonly property real s: screenView.s
    readonly property int maxApps: 12
    readonly property int appCount: backend && active ? Math.min(maxApps, (backend.revision, backend.count("search"))) : 0
    readonly property int listCount: listView.count
    readonly property int panelWidth: Math.min(width - 2 * screenView.spacing, Math.round(1000 * s))
    readonly property int panelPadding: Math.round(12 * s)

    // --- selection ---------------------------------------------------------------
    property string selSection: ""   // "apps" | "list" | ""
    property int selIndex: -1
    property bool userMoved: false
    property bool pendingActivate: false

    function resetSelection() {
        userMoved = false;
        if (appCount > 0) {
            selSection = "apps";
            selIndex = 0;
        } else if (listCount > 0) {
            selSection = "list";
            selIndex = 0;
        } else {
            selSection = "";
            selIndex = -1;
        }
    }
    function fixSelection() {
        if (!userMoved) {
            resetSelection();
        } else if (selSection === "apps" && selIndex >= appCount) {
            resetSelection();
        } else if (selSection === "list" && selIndex >= listCount) {
            resetSelection();
        }
        if (pendingActivate && (appCount > 0 || listCount > 0) && !krunner.querying) {
            pendingActivate = false;
            activateSelected();
        }
    }
    onAppCountChanged: Qt.callLater(fixSelection)
    onListCountChanged: Qt.callLater(fixSelection)
    Connections {
        target: results.effect
        function onSearchTextChanged() {
            results.pendingActivate = false;
            results.userMoved = false;
            Qt.callLater(results.fixSelection);
        }
    }

    // key: Qt.Key_Up/Down/Left/Right/Tab; returns true if handled
    function moveSelection(key) {
        if (appCount === 0 && listCount === 0) {
            return false;
        }
        if (selSection === "") {
            resetSelection();
            return true;
        }
        userMoved = true;
        const forward = key === Qt.Key_Down || key === Qt.Key_Right || key === Qt.Key_Tab;
        if (selSection === "apps") {
            if (key === Qt.Key_Left) {
                selIndex = Math.max(0, selIndex - 1);
            } else if (key === Qt.Key_Right) {
                if (selIndex < appCount - 1) {
                    selIndex++;
                } else if (listCount > 0) {
                    selSection = "list";
                    selIndex = 0;
                }
            } else if (forward && listCount > 0) {
                selSection = "list";
                selIndex = 0;
            }
        } else {
            if (forward) {
                selIndex = Math.min(listCount - 1, selIndex + 1);
            } else if (selIndex > 0) {
                selIndex--;
            } else if (appCount > 0) {
                selSection = "apps";
                selIndex = 0;
            }
            listView.positionViewAtIndex(selIndex, ListView.Contain);
        }
        return true;
    }

    function activateSelected() {
        if (selSection === "apps" && selIndex >= 0) {
            effect.launch("search", selIndex);
        } else if (selSection === "list" && selIndex >= 0) {
            runListRow(selIndex);
        } else if (krunner.querying || effect.searchText.length > 0) {
            // results not there yet: run the first one when it arrives
            pendingActivate = true;
        }
    }
    // kept for ScreenView
    function activateFirst() {
        activateSelected();
    }

    function runListRow(row) {
        const src = filtered.mapToSource(filtered.index(row, 0));
        if (krunner.run(src)) {
            effect.hide();
        }
    }

    // --- KRunner results, minus apps that are already in the app row ------------
    readonly property var appNames: {
        const names = {};
        for (let i = 0; i < appCount; ++i) {
            const a = backend.appAt("search", i);
            if (a && a.name) {
                names[a.name.toLowerCase()] = true;
            }
        }
        return names;
    }
    onAppNamesChanged: filtered.invalidateFilter()

    Milou.ResultsModel {
        id: krunner
        queryString: results.active ? results.effect.searchText : ""
        limit: 15
    }
    KItemModels.KSortFilterProxyModel {
        id: filtered
        sourceModel: krunner
        filterRowCallback: (row, parent) => {
            const idx = krunner.index(row, 0, parent);
            const category = String(krunner.data(idx, Milou.ResultsModel.CategoryRole) || "");
            const name = String(krunner.data(idx, Qt.DisplayRole) || "").toLowerCase();
            return !(category === "Applications" && results.appNames[name] === true);
        }
    }

    // --- view ------------------------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        width: results.panelWidth
        spacing: Math.round(12 * results.s)

        // Applications
        Rectangle {
            width: parent.width
            height: appsRow.height + 2 * results.panelPadding
            visible: results.appCount > 0
            radius: Math.round(24 * results.s)
            color: L.SYSTEM_OVERLAY_BG_COLOR

            Flow {
                id: appsRow
                anchors.centerIn: parent
                width: parent.width - 2 * results.panelPadding
                spacing: Math.round(4 * results.s)
                Repeater {
                    model: results.appCount
                    delegate: AppIcon {
                        required property int index
                        readonly property int tileSize: Math.round(64 * results.s) + 2 * Math.round(12 * results.s)
                        width: Math.round(tileSize * 1.25)
                        height: implicitHeight
                        s: results.s
                        fontPx: results.screenView.fontPx
                        iconSize: Math.round(64 * results.s)
                        selected: results.selSection === "apps" && results.selIndex === index
                        app: results.backend ? (results.backend.revision, results.backend.appAt("search", index)) : null
                        onActivated: results.effect.launch("search", index)
                    }
                }
            }
        }

        // Everything else (KRunner), grouped by category like GNOME's providers
        Rectangle {
            width: parent.width
            height: Math.max(0, Math.min(results.height - y - Math.round(12 * results.s),
                                         listView.contentHeight + 2 * results.panelPadding))
            visible: results.listCount > 0
            radius: Math.round(24 * results.s)
            color: L.SYSTEM_OVERLAY_BG_COLOR
            clip: true

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: results.panelPadding
                model: results.active ? filtered : null
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: results.selSection === "list" ? results.selIndex : -1
                highlightMoveDuration: 0
                section.property: "category"
                section.criteria: ViewSection.FullString

                delegate: Item {
                    id: row
                    required property int index
                    required property var model
                    readonly property bool firstInSection: ListView.section !== ListView.previousSection
                    readonly property bool selected: results.selSection === "list" && results.selIndex === index
                    width: ListView.view.width
                    height: Math.round(48 * results.s) + (firstInSection && index > 0 ? Math.round(8 * results.s) : 0)

                    // provider name (GNOME: provider icon + name on the left)
                    Text {
                        visible: row.firstInSection
                        x: 0
                        width: Math.round(180 * results.s)
                        anchors.bottom: parent.bottom
                        height: Math.round(48 * results.s)
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        color: Qt.rgba(0.98, 0.98, 0.98, 0.7)
                        font.pixelSize: results.screenView.fontPx
                        font.weight: Font.DemiBold
                        text: row.model.category || ""
                    }

                    Rectangle {
                        id: item
                        x: Math.round(196 * results.s)
                        width: parent.width - x
                        height: Math.round(48 * results.s)
                        anchors.bottom: parent.bottom
                        radius: Math.round(12 * results.s)
                        color: Qt.rgba(1, 1, 1, row.selected ? 0.12 : rowArea.containsMouse ? 0.07 : 0)

                        Kirigami.Icon {
                            id: rowIcon
                            x: Math.round(12 * results.s)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(32 * results.s)
                            height: width
                            source: row.model.decoration
                        }
                        Text {
                            id: rowTitle
                            anchors.left: rowIcon.right
                            anchors.leftMargin: Math.round(12 * results.s)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.5)
                            elide: Text.ElideRight
                            color: L.SYSTEM_FG_COLOR
                            font.pixelSize: results.screenView.fontPx
                            textFormat: Text.PlainText
                            text: row.model.display || ""
                        }
                        Text {
                            anchors.left: rowTitle.right
                            anchors.leftMargin: Math.round(12 * results.s)
                            anchors.right: parent.right
                            anchors.rightMargin: Math.round(12 * results.s)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            color: Qt.rgba(0.98, 0.98, 0.98, 0.55)
                            font.pixelSize: results.screenView.fontPx
                            textFormat: Text.PlainText
                            text: row.model.subtext || ""
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: results.runListRow(row.index)
                        }
                    }
                }
            }
        }
    }
}
