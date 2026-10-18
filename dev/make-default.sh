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

STEPS=(meta)
[[ $# -gt 0 ]] && STEPS=("$@")
backup
for s in "${STEPS[@]}"; do
    "step_$s"
done
echo "Done. Undo: dev/restore-defaults.sh"
