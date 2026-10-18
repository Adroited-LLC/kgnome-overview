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

STEPS=(meta corner)
[[ $# -gt 0 ]] && STEPS=("$@")
backup
for s in "${STEPS[@]}"; do
    "step_$s"
done
echo "Done. Undo: dev/restore-defaults.sh"
