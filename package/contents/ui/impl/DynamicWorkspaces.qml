// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// GNOME's dynamic workspaces (js/ui/windowManager.js WorkspaceTracker,
// gnome-50): there is always exactly one empty workspace at the end, and
// other empty workspaces go away. Runs in the effect, so it works whether the
// overview is open or not (window closed, moved, desktop switched).
//
// _checkWorkspaces, ported:
//  - a workspace is non-empty if it holds a window that is not on all
//    workspaces (any activity, minimized windows count), if a dialog or
//    splash window left it less than LAST_WINDOW_GRACE_TIME (1 s) ago, or if
//    it is kept alive (a launch was just started on it);
//  - if the last workspace is not empty, append one;
//  - remove the empty ones, from the end, except the active workspace and the
//    first empty one after the last non-empty one; never go below
//    MIN_NUM_WORKSPACES (2).
// Checks are coalesced (GNOME: a BEFORE_REDRAW "later"; here a short timer).
//
// Getting along with other KWin scripts (Krohnkite, the
// virtualdesktopsonlyonprimary script, pagers):
//  - windows that are on all desktops never keep a desktop alive (that's how
//    virtualdesktopsonlyonprimary parks windows on other screens, and it's
//    GNOME's workspaces-only-on-primary semantics);
//  - a desktop is only removed when no window at all is on it, so tilers
//    never lose windows; KWin moves nothing;
//  - no removals during the first STARTUP_GRACE_MS after the effect loads
//    (session restore / scripts placing windows), only the trailing desktop
//    is added;
//  - if something keeps undoing our changes (more than MAX_CHANGES automatic
//    desktop additions/removals in CHANGE_WINDOW_MS *and* at least half as
//    many desktop changes made by someone else in that time, e.g. a script
//    that enforces a fixed desktop count), pause and log instead of fighting
//    it; resume after a minute without outside changes. Our own changes,
//    user drops/closes and effect reloads (settings dialog) can't trip it.
//  - the check also runs when the effect loads, when the overview opens,
//    when its settings change, and every 30 s, so the trailing desktop comes
//    back whatever happened.
import QtQuick
import org.kde.kwin as KWinComponents

QtObject {
    id: dyn

    property bool enabled: true

    readonly property int minWorkspaces: 2           // MIN_NUM_WORKSPACES
    readonly property int lastWindowGraceMs: 1000    // LAST_WINDOW_GRACE_TIME
    readonly property int startupGraceMs: 10000
    readonly property int maxChanges: 24
    readonly property int changeWindowMs: 10000

    property double loadedAt: Date.now()
    property bool suspended: false
    property var changeLog: []           // timestamps of our automatic add/remove calls
    property var externalLog: []         // timestamps of desktop changes not made by us
    property bool selfChanging: false
    property var keepAlive: ({})         // desktop id -> ms timestamp until which it is kept
    property var lastRemoved: ({})       // desktop id -> ms timestamp (dialog/splash grace)
    // bumped after every check, so bindings on canClose() re-evaluate
    property int revision: 0

    onEnabledChanged: {
        suspended = false;
        changeLog = [];
        queue();
    }

    function queue() {
        // runs (and bumps revision) even when disabled, for canClose() bindings
        checkTimer.restart();
    }

    // A window that keeps the desktops it is on alive (GNOME counts every
    // window actor except sticky ones; KWin also has panels, popups, OSDs,
    // notifications and the desktop window, which are on all desktops or
    // not workspace windows at all).
    function counts(w) {
        if (!w || w.deleted || w.onAllDesktops) {
            return false;
        }
        if (w.desktopWindow || w.dock || w.popupWindow || w.notification || w.criticalNotification
                || w.onScreenDisplay || w.appletPopup || w.outline) {
            return false;
        }
        // helper windows hidden from every list (e.g. xwaylandvideobridge)
        if (w.skipTaskbar && w.skipPager && w.skipSwitcher) {
            return false;
        }
        return w.desktops && w.desktops.length > 0;
    }

    function noteChange() {
        const now = Date.now();
        const log = changeLog.filter(t => now - t < changeWindowMs);
        log.push(now);
        changeLog = log;
        const outside = externalLog.filter(t => now - t < changeWindowMs);
        externalLog = outside;
        if (log.length > maxChanges && outside.length >= maxChanges / 2) {
            suspended = true;
            console.warn("kgnome-overview: dynamic workspaces paused: desktops changed",
                         log.length, "times in", changeWindowMs / 1000,
                         "s (another script managing desktops?); resuming after a minute without outside changes.");
            return false;
        }
        return true;
    }

    // KWin names new desktops "Desktop N" by position and never renumbers;
    // keep default-named desktops numbered after we insert or remove one.
    function renumber() {
        const ds = KWinComponents.Workspace.desktops;
        for (let i = 0; i < ds.length; ++i) {
            if (/^Desktop \d+$/.test(ds[i].name) && ds[i].name !== "Desktop " + (i + 1)) {
                ds[i].name = "Desktop " + (i + 1);
            }
        }
    }

    // managed windows (the declarative Workspace has the windows list
    // instead of the scripting windowList())
    function allWindows() {
        const list = KWinComponents.Workspace.windows;
        const out = [];
        for (let i = 0; i < list.length; ++i) {
            out.push(list[i]);
        }
        return out;
    }

    // desktop changes made here, so onDesktopsChanged can tell them apart
    // A script reacting to desktopsChanged runs inside our call, so a change
    // undone right away shows up as an unchanged desktop count.
    function createAt(pos) {
        const before = KWinComponents.Workspace.desktops.length;
        selfChanging = true;
        try {
            KWinComponents.Workspace.createDesktop(pos, "");
        } finally {
            selfChanging = false;
        }
        if (KWinComponents.Workspace.desktops.length <= before) {
            externalLog = externalLog.concat([Date.now()]);
        }
    }
    function remove(desktop) {
        const before = KWinComponents.Workspace.desktops.length;
        selfChanging = true;
        try {
            KWinComponents.Workspace.removeDesktop(desktop);
        } finally {
            selfChanging = false;
        }
        if (KWinComponents.Workspace.desktops.length >= before) {
            externalLog = externalLog.concat([Date.now()]);
        }
    }

    function windowsOn(desktop) {
        return allWindows().filter(w => counts(w) && w.desktops.indexOf(desktop) >= 0);
    }
    function isEmpty(desktop) {
        return windowsOn(desktop).length === 0;
    }

    function check() {
        revision++;
        if (!enabled || suspended) {
            return;
        }
        const ws = KWinComponents.Workspace;
        const ds = ws.desktops;
        const n = ds.length;
        const now = Date.now();
        const empty = [];
        for (let i = 0; i < n; ++i) {
            const id = ds[i].id;
            empty[i] = !((keepAlive[id] || 0) > now || (lastRemoved[id] || 0) > now);
        }
        const windows = allWindows();
        for (const w of windows) {
            if (!counts(w)) {
                continue;
            }
            for (const d of w.desktops) {
                const i = ds.indexOf(d);
                if (i >= 0) {
                    empty[i] = false;
                }
            }
        }

        // If we don't have an empty workspace at the end, add one
        // (and enforce the minimum); the next pass removes the rest.
        if (n === 0) {
            return;
        }
        if (!empty[n - 1] || n < minWorkspaces) {
            if (noteChange()) {
                createAt(n);
                renumber();
                queue();
            }
            return;
        }

        if (now - loadedAt < startupGraceMs) {
            graceTimer.interval = startupGraceMs - (now - loadedAt) + 50;
            graceTimer.restart();
            return;
        }

        const lastEmptyIndex = empty.lastIndexOf(false) + 1;
        const activeIndex = ds.indexOf(ws.currentDesktop);
        if (activeIndex >= 0) {
            empty[activeIndex] = false;
        }
        let count = n;
        let removed = false;
        // from the end, so the indices of the others don't change
        for (let i = n - 1; i >= 0; --i) {
            if (count <= minWorkspaces) {
                break;
            }
            if (empty[i] && i !== lastEmptyIndex) {
                if (!noteChange()) {
                    break;
                }
                remove(ds[i]);
                count--;
                removed = true;
            }
        }
        if (removed) {
            renumber();
        }
        expire(now);
    }

    // drop bookkeeping for desktops that are gone or expired, and re-check
    // right after the next expiry
    function expire(now) {
        const live = KWinComponents.Workspace.desktops.map(d => d.id);
        let next = 0;
        for (const map of [keepAlive, lastRemoved]) {
            for (const id in map) {
                if (live.indexOf(id) < 0 || map[id] <= now) {
                    delete map[id];
                } else if (next === 0 || map[id] < next) {
                    next = map[id];
                }
            }
        }
        if (next > 0) {
            expiryTimer.interval = next - now + 50;
            expiryTimer.restart();
        }
    }

    // GNOME Main.wm.keepWorkspaceAlive: a launch on a fresh workspace keeps it
    // until the app's window shows up (or the time runs out).
    function keepWorkspaceAlive(desktop, ms) {
        if (!desktop) {
            return;
        }
        keepAlive[desktop.id] = Date.now() + ms;
        queue();
    }

    // GNOME Main.wm.insertWorkspace: a new empty desktop at index; returns it.
    // KWin can insert in place, so no windows have to be shifted.
    function insertDesktop(index) {
        const ws = KWinComponents.Workspace;
        const n = ws.desktops.length;
        const pos = Math.max(0, Math.min(n, index));
        createAt(pos);
        renumber();
        const d = ws.desktops[pos] || null;
        // short keep-alive so the drop can land before the next check
        keepWorkspaceAlive(d, 1000);
        queue();
        return d;
    }

    // Close a desktop from the overview (not in GNOME): its windows move to
    // the neighbouring desktop (the previous one, or the next one for the
    // first desktop); windows are never closed. The last desktop stays.
    function canClose(desktop) {
        const ds = KWinComponents.Workspace.desktops;
        const i = ds.indexOf(desktop);
        if (i < 0 || ds.length <= 1) {
            return false;
        }
        // the trailing empty workspace would only come back
        if (enabled && !suspended && i === ds.length - 1 && isEmpty(desktop)) {
            return false;
        }
        return true;
    }
    function closeDesktop(desktop) {
        if (!canClose(desktop)) {
            return false;
        }
        const ws = KWinComponents.Workspace;
        const ds = ws.desktops;
        const i = ds.indexOf(desktop);
        const target = i > 0 ? ds[i - 1] : ds[i + 1];
        for (const w of allWindows()) {
            if (!w || w.deleted || w.onAllDesktops || !w.desktops || w.desktops.indexOf(desktop) < 0) {
                continue;
            }
            if (w.desktops.length > 1) {
                w.desktops = w.desktops.filter(d => d !== desktop);
            } else {
                w.desktops = [target];
            }
        }
        if (ws.currentDesktop === desktop) {
            ws.currentDesktop = target;
        }
        console.info("kgnome-overview: closing desktop", desktop.name, "- windows moved to", target.name);
        remove(desktop);
        renumber();
        queue();
        return true;
    }

    property Connections _workspace: Connections {
        target: KWinComponents.Workspace
        function onDesktopsChanged() {
            if (!dyn.selfChanging) {
                dyn.externalLog = dyn.externalLog.concat([Date.now()]);
            }
            dyn.queue();
        }
        function onCurrentDesktopChanged() { dyn.queue(); }   // GNOME: switch-workspace
        function onWindowAdded(w) {
            dyn.watch(w);
            dyn.queue();
        }
        function onWindowRemoved(w) {
            // GNOME _windowRemoved: a closing dialog/splash keeps its
            // workspace for a second (the app's main window may follow)
            if (w && (w.dialog || w.splash) && !w.onAllDesktops && w.desktops) {
                const until = Date.now() + dyn.lastWindowGraceMs;
                for (const d of w.desktops) {
                    dyn.lastRemoved[d.id] = until;
                }
            }
            dyn.queue();
        }
    }

    function watch(w) {
        if (w && w.desktopsChanged) {
            w.desktopsChanged.connect(queue);
        }
    }

    property Timer checkTimer: Timer {
        id: checkTimer
        interval: 50
        onTriggered: dyn.check()
    }
    // safety net: re-check every 30 s; resume a pause after a quiet minute
    property Timer safetyTimer: Timer {
        interval: 30000
        repeat: true
        running: dyn.enabled
        onTriggered: {
            const now = Date.now();
            if (dyn.suspended && dyn.externalLog.every(t => now - t > 60000)) {
                console.info("kgnome-overview: dynamic workspaces resumed");
                dyn.suspended = false;
                dyn.changeLog = [];
            }
            dyn.queue();
        }
    }
    property Timer graceTimer: Timer {
        id: graceTimer
        onTriggered: dyn.queue()
    }
    property Timer expiryTimer: Timer {
        id: expiryTimer
        onTriggered: dyn.queue()
    }

    Component.onCompleted: {
        for (const w of allWindows()) {
            watch(w);
        }
        console.info("kgnome-overview: dynamic workspaces", enabled ? "on" : "off");
        queue();
    }
}
