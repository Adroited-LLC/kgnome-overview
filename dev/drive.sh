#!/bin/bash
# dev/drive.sh 'JS'  : run JS inside the effect (needs kwinrc DevHooks=true,
# see Controller.runDevScript). In scope: effect, view (first screen), workspace.
# Prints the result line from the journal.
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
since=$(date "+%Y-%m-%d %H:%M:%S")
kwriteconfig6 --file kwinrc --group Effect-kgnomeoverview --key DevScript "// $(date +%s%N)
$1"
"$QDBUS" org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect kgnomeoverview
sleep "${DRIVE_WAIT:-0.3}"
journalctl --user -b --since "$since" --no-pager -o cat | grep "kgnome-overview dev" | tail -3
