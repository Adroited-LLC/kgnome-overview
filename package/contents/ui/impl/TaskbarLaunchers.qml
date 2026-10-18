// SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
// SPDX-License-Identifier: GPL-2.0-or-later
// Removes an app from the pinned launchers of every panel/desktop task
// manager (org.kde.plasma.taskmanager and org.kde.plasma.icontasks) when it is
// unpinned from the dash. Runs a Plasma desktop script in plasmashell
// (org.kde.PlasmaShell.evaluateScript) through KWin's asynchronous DBusCall,
// so KWin never blocks and the task manager updates live, without a
// plasmashell restart. The script edits General/launchers of each applet the
// same way the task manager's own "Unpin from Task Manager" ends up in the
// config. Matches "applications:<id>", "file:///…/<id>" and "/…/<id>", also
// with an activity prefix ("[act1,act2]\n<url>"); preferred:// launchers
// (e.g. preferred://filemanager) are never touched. No match: nothing is
// written.
import QtQuick
import org.kde.kwin as KWinComponents

QtObject {
    id: launchers

    readonly property Component callComponent: Component {
        KWinComponents.DBusCall {
            service: "org.kde.plasmashell"
            path: "/PlasmaShell"
            dbusInterface: "org.kde.PlasmaShell"
            method: "evaluateScript"
        }
    }

    function normalized(desktopId) {
        let id = String(desktopId || "");
        if (id.startsWith("applications:")) {
            id = id.substring(13);
        }
        return id.endsWith(".desktop") ? id : id + ".desktop";
    }

    // Plasma desktop scripting (plasmashell's QJSEngine). Prints one JSON
    // object: {id, apply, applets: [{id, type, removed: [{index, entry}]}]}.
    function script(desktopId, apply) {
        return "(function () {\n"
            + "var id = " + JSON.stringify(normalized(desktopId)) + ";\n"
            + "var apply = " + (apply ? "true" : "false") + ";\n"
            + `function basename(p) { return p.substring(p.lastIndexOf("/") + 1); }
function matches(entry) {
    var url = String(entry);
    var nl = url.indexOf("\\n");
    if (url.charAt(0) === "[" && nl > 0) { url = url.substring(nl + 1); }
    url = url.split("?")[0];
    var name;
    if (url.indexOf("applications:") === 0) {
        name = url.substring(13);
        if (!/\\.desktop$/.test(name)) { name += ".desktop"; }
    } else if (url.indexOf("file://") === 0) {
        try { name = basename(decodeURIComponent(url.substring(7))); } catch (e) { name = basename(url.substring(7)); }
    } else if (url.charAt(0) === "/") {
        name = basename(url);
    } else {
        return false;
    }
    return name === id;
}
var result = {id: id, apply: apply, applets: []};
var cs = panels().concat(desktops());
for (var i = 0; i < cs.length; ++i) {
    var ws = cs[i].widgets();
    for (var j = 0; j < ws.length; ++j) {
        var w = ws[j];
        if (w.type !== "org.kde.plasma.taskmanager" && w.type !== "org.kde.plasma.icontasks") { continue; }
        w.currentConfigGroup = ["General"];
        var list = w.readConfig("launchers", []);
        if (typeof list === "string") { list = list.length > 0 ? list.split(",") : []; }
        var keep = [], removed = [];
        for (var k = 0; k < list.length; ++k) {
            if (matches(list[k])) { removed.push({index: k, entry: String(list[k])}); } else { keep.push(String(list[k])); }
        }
        if (removed.length > 0 && apply) { w.writeConfig("launchers", keep); w.reloadConfig(); }
        result.applets.push({id: w.id, type: w.type, count: list.length, removed: removed});
    }
}
print(JSON.stringify(result));
})();`;
    }

    // apply=false only reports matches. done(result|null) is optional.
    function run(desktopId, apply, done) {
        const call = callComponent.createObject(launchers, {arguments: [script(desktopId, apply)]});
        if (!call) {
            console.warn("kgnome-overview: task manager launchers: DBusCall unavailable");
            if (done) done(null);
            return;
        }
        call.finished.connect(function (returnValue) {
            let res = null;
            try {
                res = JSON.parse(String(returnValue && returnValue.length ? returnValue[0] : "").trim());
            } catch (e) {
                console.warn("kgnome-overview: task manager launchers: unexpected reply", returnValue);
            }
            if (res) {
                const hits = res.applets.filter(a => a.removed.length > 0);
                console.info("kgnome-overview: task manager launchers:", res.id,
                             hits.length === 0 ? "not pinned in " + res.applets.length + " task manager(s)"
                                               : (apply ? "removed " : "matches ") + JSON.stringify(hits.map(a => ({applet: a.id, removed: a.removed}))));
            }
            if (done) done(res);
            call.destroy();
        });
        call.failed.connect(function () {
            console.warn("kgnome-overview: task manager launchers: evaluateScript failed (plasmashell not running?)");
            if (done) done(null);
            call.destroy();
        });
        call.call();
    }
    function remove(desktopId, done) {
        run(desktopId, true, done);
    }
    function query(desktopId, done) {
        run(desktopId, false, done);
    }
}
