#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Make kgnome-overview the default overview (user config only, no root):
# backs up the touched config files to backup/<timestamp>/ first; undo with
# dev/restore-defaults.sh. Each step is idempotent.
#   dev/make-default.sh            all steps
#   dev/make-default.sh meta ...   only the named steps
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
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

# 1. Meta alone toggles our overview (instead of opening Kickoff)
step_meta() {
    echo ">> Meta key -> Toggle GNOME Overview"
    kwriteconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta \
        "org.kde.kglobalaccel,/component/kwin,org.kde.kglobalaccel.Component,invokeShortcut,Toggle GNOME Overview"
    reconfigure
    echo "   $(kreadconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta)"
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

# kglobalaccel helpers (key codes are Qt key combinations)
META_W=268435543   # Qt::META | Qt::Key_W
META_O=268435535   # Qt::META | Qt::Key_O
set_keys() {  # set_keys <action> <friendly> <gvariant a(ai)>
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setForeignShortcutKeys "['kwin','$1','KWin','$2']" "$3" >/dev/null
}
get_keys() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.shortcutKeys "['kwin','$1','KWin','$2']"
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

# 5. Panel: replace Kickoff with the launcher plasmoid at the same index.
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
echo "Done. Undo: dev/restore-defaults.sh"
