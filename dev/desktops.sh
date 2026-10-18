#!/bin/bash
# Print the virtual desktops and the windows on each (debug helper).
# Runs a throwaway KWin script; output comes back through the journal.
set -euo pipefail
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
tag="kgnome-desktops-$$"
js=$(mktemp --suffix=.js)
cat > "$js" <<JS
const out = [];
const ds = workspace.desktops;
for (let i = 0; i < ds.length; ++i) {
    const d = ds[i];
    const wins = workspace.windowList().filter(w => !w.onAllDesktops && w.desktops.indexOf(d) >= 0
        && !w.dock && !w.desktopWindow && !w.popupWindow && !w.notification && !w.onScreenDisplay);
    out.push((d === workspace.currentDesktop ? "*" : " ") + i + " " + d.name + " (" + wins.length + "): "
        + wins.map(w => w.resourceClass + (w.minimized ? "[min]" : "")).join(", "));
}
out.push("  on all desktops: " + workspace.windowList().filter(w => w.onAllDesktops && w.normalWindow).map(w => w.resourceClass).join(", "));
console.info("$tag\n" + out.join("\n"));
JS
since=$(date '+%Y-%m-%d %H:%M:%S')
id=$("$QDBUS" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$js" "$tag")
"$QDBUS" org.kde.KWin /Scripting/Script"$id" org.kde.kwin.Script.run >/dev/null 2>&1 || "$QDBUS" org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 0.5
"$QDBUS" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$tag" >/dev/null
rm -f "$js"
journalctl --user -b --since "$since" --no-pager -o cat | sed -n "/$tag/,\$p" | grep -v "^js: $tag\|$tag" | sed 's/^js: //' | head -40
