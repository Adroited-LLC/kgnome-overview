// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Measures the System Menu's expand/collapse animations frame by frame
// (dev/sheet-anim.sh): loads Sheet.qml outside plasmashell, opens and
// closes each expandable menu and prints, per frame, the sheet height and
// the y of every row below the system row (content coordinates). A smooth
// animation has no frame where something jumps.
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 520
    height: 1600
    visible: true
    function i18n(s, ...a) { let r = String(s); a.forEach((v, i) => { r = r.replace("%" + (i + 1), v); }); return r; }
    function i18nc(c, s, ...a) { return i18n(s, ...a); }
    function i18np(s, p, n, ...a) { return i18n(n === 1 ? s : p, n, ...a); }

    QtObject {
        id: sessions
        property bool canLock: true
        property bool canSuspend: true
        property bool canReboot: true
        property bool canShutdown: true
        property bool canLogout: true
        property bool canSwitchUser: true
    }
    Loader {
        id: loader
        width: 480
        source: Qt.resolvedUrl("../plasmoid/org.kgnome.systemsheet/contents/ui/Sheet.qml")
        onLoaded: { item.sessions = sessions; item.isOpen = true; }
        height: 1400
    }
    readonly property var sheet: loader.item
    function walk(it, pred, out) {
        if (!it) return out;
        if (pred(it)) out.push(it);
        for (const c of (it.children || [])) walk(c, pred, out);
        return out;
    }
    function rows() {
        // direct children of the sheet's column and of the toggle grid
        const col = walk(sheet, o => o.toString().startsWith("QQuickColumnLayout") && o.parent && o.parent.toString().startsWith("QQuickItem") && o.parent.parent && o.parent.parent.toString().startsWith("QQuickFlickable"), [])[0];
        const out = [];
        if (!col) return out;
        for (const c of col.children) {
            if (!c.visible) continue;
            if (c.toString().startsWith("QQuickGridLayout")) {
                for (const g of c.children) if (g.visible) out.push({n: (g.modelData || (g.title !== undefined ? "card" : "?")), y: Math.round(c.y + g.y), h: Math.round(g.height)});
            } else {
                out.push({n: c.toString().split("(")[0].replace("QQuick", "").substring(0, 10), y: Math.round(c.y), h: Math.round(c.height)});
            }
        }
        return out;
    }
    property string phase: "idle"
    property real t0: 0
    FrameAnimation {
        running: win.sheet !== null
        onTriggered: {
            const r = win.rows();
            console.log("F", Date.now() - win.t0, win.phase, Math.round(win.sheet.wantedHeight),
                        r.map(x => x.n + "@" + x.y + "+" + x.h).join(" "));
        }
    }
    property var steps: [
        ["wifi open", () => { sheet.openMenu = "WifiToggle"; }],
        ["wifi close", () => { sheet.openMenu = ""; }],
        ["bt open", () => { sheet.openMenu = "BluetoothToggle"; }],
        ["bt to power mode", () => { sheet.openMenu = "PowerModeToggle"; }],
        ["pm close", () => { sheet.openMenu = ""; }],
        ["power open", () => { sheet.powerMenuOpen = true; }],
        ["power close", () => { sheet.powerMenuOpen = false; }],
        ["sound open", () => { const v = walk(sheet, o => o.menuOpen !== undefined && o.sink !== undefined, [])[0]; if (v) v.menuOpen = true; }],
        ["sound close", () => { const v = walk(sheet, o => o.menuOpen !== undefined && o.sink !== undefined, [])[0]; if (v) v.menuOpen = false; }],
    ]
    property int step: -1
    Timer {
        interval: 900
        repeat: true
        running: win.sheet !== null
        onTriggered: {
            if (win.step === -1) win.t0 = Date.now();
            win.step++;
            if (win.step >= win.steps.length) { Qt.quit(); return; }
            win.phase = win.steps[win.step][0].replace(/ /g, "_");
            console.log("STEP", win.phase);
            win.steps[win.step][1]();
            grabTimer.restart();
        }
    }
    // a screenshot 100 ms into each step (mid-animation), if SHEET_ANIM_SHOTS is set
    Timer {
        id: grabTimer
        interval: 100
        onTriggered: {
            const dir = Qt.application.arguments.find(a => a.startsWith("--shots="));
            if (dir) {
                const f = dir.substring(8) + "/sheet-anim-" + win.phase + ".png";
                loader.grabToImage(r => r.saveToFile(f));
            }
        }
    }
}
