#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
# SPDX-License-Identifier: GPL-2.0-or-later
# Undo scripts/make-default.sh: put back the config files saved in
# backup/<timestamp>/ (the oldest, i.e. the state before the first make-default run, by default) and make KWin and plasmashell pick
# them up without logging out.
#   scripts/restore-defaults.sh                 restore the oldest backup
#   scripts/restore-defaults.sh <timestamp>     restore backup/<timestamp>
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || ls /usr/lib*/qt6/bin/qdbus /usr/lib/*/qt6/bin/qdbus 2>/dev/null | head -n1 || true)
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

TS=${1:-$(ls -1 backup 2>/dev/null | grep -v -- "-install$" | sort | head -n1)}
SRC="backup/$TS"
[[ -d "$SRC" ]] || { echo "no backup $SRC" >&2; exit 1; }
echo ">> Restoring from $SRC"

# The System Menu came with the launcher; Kickoff has Log Out again
scripts/system-menu.sh remove || true

# The panel: re-create Kickoff where the launcher sits, so plasmashell does
# not have to be restarted. (The appletsrc copy below is the full record and
# wins at the next plasmashell start.)
"$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
for (const p of panels()) {
    for (const w of p.widgets("org.kgnome.overview.showapps").concat(p.widgets("org.kgnome.overview.launcher"))) {
        const i = w.index;
        w.remove();
        const k = p.addWidget("org.kde.plasma.kickoff");
        k.index = i;
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

# live shortcut registry (kglobalaccel lives in KWin): Meta+W back to the
# built-in Overview, ours back to Meta+O only, Meta back to the launcher
keys() {
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setForeignShortcutKeys "['kwin','$1','KWin','$2']" "$3" >/dev/null || true
}
keys "Toggle GNOME Overview" "Toggle GNOME Overview" "[([268435535, 0, 0, 0],)]"
keys "Overview" "Toggle Overview" "[([268435543, 0, 0, 0],)]"
# Meta alone back to plasmashell's launcher (Meta, Alt+F1), off our cycle
keys "Cycle GNOME Overview" "Cycle GNOME Overview (window picker, app grid, close)" "@a(ai) []"
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
    --method org.kde.KGlobalAccel.setForeignShortcutKeys \
    "['plasmashell','activate application launcher','plasmashell','Activate Application Launcher']" \
    "[([16777250, 0, 0, 0],), ([150994992, 0, 0, 0],)]" >/dev/null || true

"$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null
"$QDBUS" org.kde.KWin /Effects loadEffect overview >/dev/null || true
echo "   overview loaded: $("$QDBUS" org.kde.KWin /Effects isEffectLoaded overview)"
cat <<MSG
Done. KWin settings (Meta key, edges, effects, Meta+W) are live again. The
exact panel layout is fully back after the next login (the panel already has
Kickoff again if the script above ran).
MSG
