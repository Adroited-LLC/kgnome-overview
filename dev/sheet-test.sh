#!/usr/bin/env bash
# Reinstall the system menu plasmoid and show it in a throwaway plasmawindowed
# process (fresh QML engine, so no plasmashell cache), screenshot it.
#   dev/sheet-test.sh [name] [seconds]
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
name=${1:-ss_test}; secs=${2:-8}
kpackagetool6 -t Plasma/Applet --upgrade plasmoid/org.kgnome.systemsheet >/dev/null
timeout "$secs" plasmawindowed org.kgnome.systemsheet > /tmp/sheet-test.log 2>&1 &
sleep 4
spectacle -b -n -a -o "$PWD/screenshots/$name.png" >/dev/null 2>&1
wait
grep -v '^$' /tmp/sheet-test.log | grep -iv "kf.config\|qt.qpa" || true
