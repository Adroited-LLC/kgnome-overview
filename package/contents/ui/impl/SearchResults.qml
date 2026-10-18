// SPDX-License-Identifier: GPL-2.0-or-later
// Search results like GNOME's SearchResultsView: an app row first (our own
// model, ranked like GNOME's app search), then the other providers (KRunner,
// through Milou's ResultsModel) as a list grouped by category.
// Keyboard model (GNOME 50 searchController.js / search.js):
// - with the entry focused the first result is the default, drawn :selected,
//   and Enter activates it (SearchResultsView.activateDefault);
// - Down, Tab, Shift+Tab, and Right at the end of the text move keyboard focus
//   into the results (navigateFocus); there arrows/Tab move it and Enter
//   activates the focused result, which has GNOME's focus ring;
// - printable keys and Backspace go back to the entry and edit the text
//   (_onStageKeyPress -> startSearch), which resets the default to the first
//   result; Up from the top row / Tab past the end return to the entry.
// Qt keyboard focus physically stays in the TextInput (resultsFocused is the
// logical focus) so model resets in the KRunner list can never eat keys.
// SearchFocusReturnMs (default 250, 0 = off, not in GNOME): that long after
// the last arrow key the text cursor comes back to the entry while the
// highlighted result stays selected, so Enter still runs it.
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
    property bool userMoved: false        // selection is not the default one
    property bool resultsFocused: false   // logical key focus is on a result
    property bool pendingActivate: false
    property int lastAppIndex: 0
    readonly property int returnMs: effect.searchFocusReturnMs
    readonly property int appsPerRow: {
        const tile = appsRepeater.count > 0 && appsRepeater.itemAt(0) ? appsRepeater.itemAt(0).width : 1;
        return Math.max(1, Math.floor((appsRow.width + appsRow.spacing) / (tile + appsRow.spacing)));
    }

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
        if (selSection === "") {
            resultsFocused = false;
        }
        if (pendingActivate && (appCount > 0 || listCount > 0) && !krunner.querying) {
            pendingActivate = false;
            activateSelected();
        }
    }
    onAppCountChanged: Qt.callLater(fixSelection)
    onListCountChanged: Qt.callLater(fixSelection)
    onActiveChanged: {
        if (!active) {
            resultsFocused = false;
            returnTimer.stop();
        }
    }
    Connections {
        target: results.effect
        function onSearchTextChanged() {
            // typing always happens in the entry and resets to the default result
            results.pendingActivate = false;
            results.userMoved = false;
            results.resultsFocused = false;
            returnTimer.stop();
            Qt.callLater(results.fixSelection);
        }
    }

    // like GNOME's text 'key-focus-in' + startSearch: back to the entry; the
    // key itself is then handled by the TextInput
    function focusEntry() {
        resultsFocused = false;
        returnTimer.stop();
    }
    function backToEntry() {
        // Up from the top / Tab past the end (GNOME's FocusTrap)
        resultsFocused = false;
        returnTimer.stop();
        resetSelection();
    }

    Timer {
        id: returnTimer
        interval: Math.max(1, results.returnMs)
        onTriggered: results.resultsFocused = false
    }

    function select(section, index) {
        selSection = section;
        selIndex = index;
        userMoved = true;
        if (section === "apps") {
            lastAppIndex = index;
        } else {
            listView.positionViewAtIndex(index, ListView.Contain);
        }
    }

    // Arrow/Tab handling; returns true if the key was used.
    // key: Qt.Key_Up/Down/Left/Right/Tab/Backtab; cursorAtEnd: entry cursor at the end
    function navigate(key, cursorAtEnd) {
        if (appCount === 0 && listCount === 0) {
            return false;
        }
        if (selSection === "") {
            resetSelection();
        }
        const fromEntry = !resultsFocused;
        if (fromEntry) {
            // keys the entry keeps (GNOME: only Down, Tab, Shift+Tab and
            // Right at the end of the text leave the entry). After a timed
            // return Up keeps moving the kept highlight.
            if (key === Qt.Key_Left || (key === Qt.Key_Right && !cursorAtEnd)
                    || (key === Qt.Key_Up && !userMoved)) {
                return false;
            }
            if (key === Qt.Key_Backtab && !userMoved) {
                // Shift+Tab from the entry: the last result
                if (listCount > 0) {
                    select("list", listCount - 1);
                } else {
                    select("apps", appCount - 1);
                }
                focusResults();
                return true;
            }
        }
        const per = appsPerRow;
        if (selSection === "apps") {
            switch (key) {
            case Qt.Key_Left:
                select("apps", Math.max(0, selIndex - 1));
                break;
            case Qt.Key_Right:
                select("apps", Math.min(appCount - 1, selIndex + 1));
                break;
            case Qt.Key_Down:
                if (selIndex + per < appCount) {
                    select("apps", selIndex + per);
                } else if (listCount > 0) {
                    select("list", 0);
                }
                break;
            case Qt.Key_Up:
                if (selIndex - per >= 0) {
                    select("apps", selIndex - per);
                } else {
                    backToEntry();
                    return true;
                }
                break;
            case Qt.Key_Tab:
                if (selIndex + 1 < appCount) {
                    select("apps", selIndex + 1);
                } else if (listCount > 0) {
                    select("list", 0);
                } else {
                    backToEntry();
                    return true;
                }
                break;
            case Qt.Key_Backtab:
                if (selIndex > 0) {
                    select("apps", selIndex - 1);
                } else {
                    backToEntry();
                    return true;
                }
                break;
            }
        } else {
            switch (key) {
            case Qt.Key_Down:
                select("list", Math.min(listCount - 1, selIndex + 1));
                break;
            case Qt.Key_Tab:
                if (selIndex + 1 < listCount) {
                    select("list", selIndex + 1);
                } else {
                    backToEntry();
                    return true;
                }
                break;
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                if (selIndex > 0) {
                    select("list", selIndex - 1);
                } else if (appCount > 0) {
                    select("apps", key === Qt.Key_Up ? Math.min(lastAppIndex, appCount - 1) : appCount - 1);
                } else {
                    backToEntry();
                    return true;
                }
                break;
            default:
                // Left/Right inside the list: nothing to move to
                break;
            }
        }
        focusResults();
        return true;
    }
    function focusResults() {
        resultsFocused = true;
        if (returnMs > 0) {
            returnTimer.restart();
        }
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
                    id: appsRepeater
                    delegate: AppIcon {
                        required property int index
                        readonly property int tileSize: Math.round(64 * results.s) + 2 * Math.round(12 * results.s)
                        width: Math.round(tileSize * 1.25)
                        height: implicitHeight
                        s: results.s
                        fontPx: results.screenView.fontPx
                        iconSize: Math.round(64 * results.s)
                        selected: results.selSection === "apps" && results.selIndex === index
                        focusRing: selected && results.resultsFocused
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
                        // GNOME :focus = 2px inset accent ring; :selected (default) = fill only
                        border.width: row.selected && results.resultsFocused ? Math.round(2 * results.s) : 0
                        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.7)

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
