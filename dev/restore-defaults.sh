#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Undo dev/make-default.sh: put back the config files saved in
# backup/<timestamp>/ (the oldest, i.e. the state before the first make-default run, by default) and make KWin and plasmashell pick
# them up without logging out.
#   dev/restore-defaults.sh                 restore the oldest backup
#   dev/restore-defaults.sh 20261018-002519 restore that backup
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

TS=${1:-$(ls -1 backup | sort | head -n1)}
SRC="backup/$TS"
[[ -d "$SRC" ]] || { echo "no backup $SRC" >&2; exit 1; }
echo ">> Restoring from $SRC"

# The panel: re-create Kickoff where the launcher sits, so plasmashell does
# not have to be restarted. (The appletsrc copy below is the full record and
# wins at the next plasmashell start.)
"$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
for (const p of panels()) {
    for (const w of p.widgets("org.kgnome.overview.launcher")) {
        const ids = p.widgetIds;
        const i = ids.indexOf(w.id);
        w.remove();
        const k = p.addWidget("org.kde.plasma.kickoff");
        const now = p.widgetIds.filter(x => x !== k.id);
        now.splice(i, 0, k.id);
        p.widgetIds = now;
        print("re-added Kickoff " + k.id + " at " + i);
    }
}' || echo "   (plasmashell scripting failed; the appletsrc restore applies at next login)"

for f in kwinrc kglobalshortcutsrc kactivitymanagerdrc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc; do
    if [[ -f "$SRC/$f" ]]; then
        cp -p "$SRC/$f" "$CFG/$f"
        echo "   $f"
    fi
done
# kactivitymanagerd-statsrc holds the favourites order; only restore it on request
if [[ "${RESTORE_STATSRC:-0}" == 1 && -f "$SRC/kactivitymanagerd-statsrc" ]]; then
    cp -p "$SRC/kactivitymanagerd-statsrc" "$CFG/kactivitymanagerd-statsrc"
    echo "   kactivitymanagerd-statsrc"
fi

"$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null
"$QDBUS" org.kde.KWin /Effects loadEffect overview >/dev/null || true
echo "   overview loaded: $("$QDBUS" org.kde.KWin /Effects isEffectLoaded overview)"
cat <<MSG
Done. KWin settings (Meta key, edges, effects) are live again. Shortcut
rebinds in kglobalshortcutsrc and the exact panel layout are fully back after
the next login (the panel already has Kickoff again if the script above ran).
MSG
