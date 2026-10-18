#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
# SPDX-License-Identifier: GPL-2.0-or-later
# Put the GNOME-style System Menu (org.kgnome.systemsheet) on the panel that
# holds the Show Apps button, or take it off again. Live, through
# plasmashell's scripting interface; no restart needed (the applet id is new
# to plasmashell, so its QML is not cached).
#   scripts/system-menu.sh ensure   add it right before the system tray of every
#                                   panel with a Show Apps button, unless a
#                                   System Menu already exists anywhere
#                                   (panel, desktop or inside a system tray)
#   scripts/system-menu.sh remove   remove every System Menu from panels and desktops
# Idempotent. Exit 0 when plasmashell isn't running (nothing to do).
set -euo pipefail
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)
APPLETSRC="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
ID=org.kgnome.systemsheet

if [[ -z "$QDBUS" ]] || ! "$QDBUS" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
    echo "   plasmashell is not running; System Menu not placed (add it from Add Widgets…)"
    exit 0
fi
evaluate() { "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }

case "${1:-}" in
ensure)
    # a System Menu inside a system tray isn't visible to panel scripting;
    # the appletsrc has every instance (plasmashell writes it on change)
    if grep -qx "plugin=$ID" "$APPLETSRC" 2>/dev/null; then
        echo "   System Menu already present"
        exit 0
    fi
    evaluate '
let added = 0, panelsWithLauncher = 0;
for (const p of panels()) {
    if (p.widgets("org.kgnome.overview.showapps").length === 0) continue;
    panelsWithLauncher++;
    if (p.widgets("'"$ID"'").length > 0) continue;
    const tray = p.widgets("org.kde.plasma.systemtray")[0];
    const w = p.addWidget("'"$ID"'");
    if (tray) w.index = tray.index;   // takes the tray slot, the tray moves right
    added++;
    print("   System Menu #" + w.id + " added to panel " + p.id + " at index " + w.index
          + (tray ? " (just left of the system tray #" + tray.id + ")" : " (end of panel)"));
}
if (panelsWithLauncher === 0) print("   no panel has the Show Apps button; System Menu not placed (add it from Add Widgets…)");'
    ;;
remove)
    evaluate '
for (const c of panels().concat(desktops())) {
    for (const w of c.widgets("'"$ID"'")) {
        print("   removed System Menu #" + w.id + " from " + (c.type || "containment") + " " + c.id);
        w.remove();
    }
}'
    ;;
*)
    echo "usage: $0 ensure|remove" >&2; exit 2 ;;
esac
