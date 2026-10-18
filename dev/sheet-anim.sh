#!/bin/bash
# SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
# SPDX-License-Identifier: GPL-2.0-or-later
# Frame-by-frame check of the System Menu's expand/collapse animations,
# outside plasmashell (which caches applet QML for the session):
#   dev/sheet-anim.sh [--shots]
# Opens a test window for ~10 s, prints per menu: frames, sheet height
# start -> end, largest per-frame step, whether the height ever reverses
# (a glitch), and toggles that got squashed. --shots also saves a frame
# 100 ms into each step to screenshots/sheet-anim-*.png.
cd "$(dirname "$0")/.."
args=()
[[ ${1:-} == --shots ]] && args=(-- "--shots=$PWD/screenshots")
log=$(mktemp)
QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES='qml.debug=true;js.debug=true' \
    timeout 30 "$(command -v qml6 || echo /usr/lib64/qt6/bin/qml)" dev/sheet-anim.qml "${args[@]}" >"$log" 2>&1
grep -E 'QGridLayoutEngine|TypeError|ReferenceError' "$log" | grep -v preferredHeight | sort | uniq -c | head
python3 - "$log" <<'PY'
import re, sys, collections
frames = collections.defaultdict(list)
for line in open(sys.argv[1]):
    m = re.match(r'qml: F (\d+) (\S+) (\d+) (.*)', line.strip())
    if not m:
        continue
    _, ph, h, rest = m.groups()
    items = {}
    for tok in rest.split():
        n, geo = tok.rsplit('@', 1)
        y, hh = geo.split('+')
        items.setdefault(n, (int(y), int(hh)))
    frames[ph].append((int(h), items))
for ph, fr in frames.items():
    hs = [h for h, _ in fr]
    d = [b - a for a, b in zip(hs, hs[1:])]
    reverses = any(x > 0 for x in d) and any(x < 0 for x in d)
    squashed = sorted({n for _, it in fr for n, (y, hh) in it.items() if n.endswith('Toggle') and hh != fr[0][1].get(n, (0, hh))[1]})
    print(f"{ph:16} frames={len(fr):3} height {hs[0]}->{hs[-1]} maxStep={max(map(abs, d)) if d else 0:3} "
          f"reverses={reverses} squashed={squashed}")
PY
rm -f "$log"
