#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
# SPDX-License-Identifier: GPL-2.0-or-later
# Make kgnome-overview the default overview (user config only, no root):
# backs up the touched config files to backup/<timestamp>/ first; undo with
# scripts/restore-defaults.sh. Each step is idempotent.
#   scripts/make-default.sh            all steps
#   scripts/make-default.sh meta ...   only the named steps
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || ls /usr/lib*/qt6/bin/qdbus /usr/lib/*/qt6/bin/qdbus 2>/dev/null | head -n1 || true)
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
GROUP=Effect-kgnomeoverview

backup() {
    local ts dir
    ts=$(date +%Y%m%d-%H%M%S)
    dir="backup/$ts"
    mkdir -p "$dir"
    for f in kwinrc kglobalshortcutsrc plasma-org.kde.plasma.desktop-appletsrc plasmashellrc \
             kactivitymanagerdrc kactivitymanagerd-statsrc; do
        [[ -f "$CFG/$f" ]] && cp -p "$CFG/$f" "$dir/"
    done
    echo ">> Backup: $PWD/$dir"
}

reconfigure() {
    "$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null
}

# kglobalaccel helpers (key codes are Qt key combinations)
META_W=268435543   # Qt::META | Qt::Key_W
META_O=268435535   # Qt::META | Qt::Key_O
KEY_META=16777250  # Qt::Key_Meta: Meta pressed and released on its own
ALT_F1=150994992   # Qt::ALT | Qt::Key_F1
set_foreign_keys() {  # <component> <action> <component friendly> <action friendly> <gvariant a(ai)>
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setForeignShortcutKeys "['$1','$2','$3','$4']" "$5" >/dev/null
}
get_foreign_keys() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.shortcutKeys "['$1','$2','$3','$4']"
}
set_keys() { set_foreign_keys kwin "$1" KWin "$2" "$3"; }
get_keys() { get_foreign_keys kwin "$1" KWin "$2"; }

# 1. Meta alone opens our overview (instead of Kickoff): "Cycle GNOME
#    Overview" = window picker, app grid, close (MetaCycle=toggle: GNOME)
step_meta() {
    echo ">> Meta key -> Cycle GNOME Overview"
    # Plasma 6 handles Meta on its own in kglobalaccel: by default it is the
    # first key of plasmashell's "Activate Application Launcher", which with
    # the Show Apps button on the panel opens the app grid. KWin no longer
    # reads kwinrc [ModifierOnlyShortcuts]. So: Meta off the launcher (Alt+F1
    # stays), Meta onto our cycle action.
    set_foreign_keys plasmashell "activate application launcher" plasmashell \
        "Activate Application Launcher" "[([$ALT_F1, 0, 0, 0],)]"
    set_keys "Cycle GNOME Overview" "Cycle GNOME Overview (window picker, app grid, close)" \
        "[([$KEY_META, 0, 0, 0],)]"
    # written by kgnome-overview 0.1.0, unused by KWin 6
    if kreadconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta | grep -q "GNOME Overview"; then
        kwriteconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta --delete
    fi
    reconfigure
    echo "   launcher keys: $(get_foreign_keys plasmashell "activate application launcher" plasmashell "Activate Application Launcher")"
    echo "   Cycle GNOME Overview keys: $(get_keys "Cycle GNOME Overview" "Cycle GNOME Overview (window picker, app grid, close)")"
}

# 2. Hot corner: free the built-in Overview's edges, top-left goes to ours
step_corner() {
    echo ">> Top-left hot corner -> GNOME overview"
    # 9 = ElectricNone (KWin's ElectricBorder enum; 7 = TopLeft)
    kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivate 9
    kwriteconfig6 --file kwinrc --group Effect-overview --key GridBorderActivate 9
    if [[ "$(kreadconfig6 --file kwinrc --group ElectricBorders --key TopLeft)" != "" ]]; then
        kwriteconfig6 --file kwinrc --group ElectricBorders --key TopLeft --delete
    fi
    kwriteconfig6 --file kwinrc --group "$GROUP" --key HotCorner 1
    kwriteconfig6 --file kwinrc --group "$GROUP" --key TopRightCorner --delete
    reconfigure
    "$QDBUS" org.kde.KWin /Effects reconfigureEffect overview >/dev/null 2>&1 || true
    "$QDBUS" org.kde.KWin /Effects reconfigureEffect kgnomeoverview >/dev/null
    echo "   Effect-overview BorderActivate=$(kreadconfig6 --file kwinrc --group Effect-overview --key BorderActivate)" \
         "GridBorderActivate=$(kreadconfig6 --file kwinrc --group Effect-overview --key GridBorderActivate)" \
         "ours HotCorner=$(kreadconfig6 --file kwinrc --group "$GROUP" --key HotCorner)"
}


# 3. Switch off the built-in Overview (its gestures, edges and shortcuts go
#    with it) and give Meta+W to ours (Meta+O keeps working)
step_builtin() {
    echo ">> Built-in Overview off, Meta+W -> GNOME overview"
    kwriteconfig6 --file kwinrc --group Plugins --key overviewEnabled false
    reconfigure
    if [[ "$("$QDBUS" org.kde.KWin /Effects isEffectLoaded overview)" == "true" ]]; then
        "$QDBUS" org.kde.KWin /Effects unloadEffect overview >/dev/null
    fi
    set_keys "Overview" "Toggle Overview" "@a(ai) []"
    set_keys "Toggle GNOME Overview" "Toggle GNOME Overview" "[([$META_O, 0, 0, 0],), ([$META_W, 0, 0, 0],)]"
    echo "   overviewEnabled=$(kreadconfig6 --file kwinrc --group Plugins --key overviewEnabled)" \
         "loaded: overview=$("$QDBUS" org.kde.KWin /Effects isEffectLoaded overview)" \
         "kgnomeoverview=$("$QDBUS" org.kde.KWin /Effects isEffectLoaded kgnomeoverview)"
    echo "   Overview keys: $(get_keys "Overview" "Toggle Overview")"
    echo "   Toggle GNOME Overview keys: $(get_keys "Toggle GNOME Overview" "Toggle GNOME Overview")"
}

# 4. Touchpad: 4-finger up/down for ours (default now), no 3-finger grab
step_gestures() {
    echo ">> Touchpad: 4-finger swipes"
    kwriteconfig6 --file kwinrc --group "$GROUP" --key GestureFingers 4
    "$QDBUS" org.kde.KWin /Effects reconfigureEffect kgnomeoverview >/dev/null
    echo "   GestureFingers=$(kreadconfig6 --file kwinrc --group "$GROUP" --key GestureFingers)" \
         "(built-in Overview loaded: $("$QDBUS" org.kde.KWin /Effects isEffectLoaded overview))"
}

panel_layout() {
    "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
for (const p of panels()) {
    print("panel " + p.id + " (" + p.location + "): " + p.widgets().sort((a, b) => a.index - b.index).map(w => w.index + ":" + w.type + "#" + w.id).join("  "));
}'
}
favorites_count() {  # ordering kept in kactivitymanagerd-statsrc for the client
    local client
    client=$(kreadconfig6 --file kwinrc --group "$GROUP" --key FavoritesClient)
    kreadconfig6 --file kactivitymanagerd-statsrc --group "Favorites-$client-global" --key ordering | tr ',' '\n' | grep -c . || true
}

# 5. Panel: replace Kickoff with the launcher plasmoid at the same index,
#    and add the System Menu before the tray (Kickoff had Log Out/Power Off).
#    The favourites stay with Kickoff's KActivities client id (FavoritesClient
#    is not changed): links live in kactivitymanagerd, the order in
#    kactivitymanagerd-statsrc, neither belongs to the applet.
step_panel() {
    echo ">> Panel: Kickoff -> GNOME overview launcher"
    local before after
    before=$(favorites_count)
    echo "   favourites before: $before"
    panel_layout | sed 's/^/   before: /'
    "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
for (const p of panels()) {
    // Kickoff, or the pre-1.1 id of our own launcher
    for (const k of p.widgets("org.kde.plasma.kickoff").concat(p.widgets("org.kgnome.overview.launcher"))) {
        const index = k.index, type = k.type, id = k.id;
        const n = p.addWidget("org.kgnome.overview.showapps");
        n.currentConfigGroup = ["General"];
        n.writeConfig("icon", "view-app-grid-symbolic");
        n.index = index;
        k.remove();
        print("replaced " + type + " #" + id + " with launcher #" + n.id + " at index " + n.index);
    }
}'
    # Kickoff was the Log Out / Power Off entry point: make sure the System
    # Menu is on that panel
    scripts/system-menu.sh ensure
    sleep 1
    panel_layout | sed 's/^/   after:  /'
    after=$(favorites_count)
    echo "   favourites after: $after (client $(kreadconfig6 --file kwinrc --group "$GROUP" --key FavoritesClient))"
    [[ "$before" == "$after" ]] || echo "   WARNING: favourites count changed" >&2
}

STEPS=(meta corner builtin gestures panel)
[[ $# -gt 0 ]] && STEPS=("$@")
backup
for s in "${STEPS[@]}"; do
    "step_$s"
done
echo "Done. Undo: scripts/restore-defaults.sh"
