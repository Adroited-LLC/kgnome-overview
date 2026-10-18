#!/bin/bash
# SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
# SPDX-License-Identifier: GPL-2.0-or-later
# Reinstall and show relevant journal lines since the install started.
cd "$(dirname "$0")/.."
since=$(date '+%Y-%m-%d %H:%M:%S')
./install.sh "$@" 2>&1 | tail -5
sleep 1
journalctl --user -b --since "$since" --no-pager -o cat | grep -iE 'kgnome|qml|\.js:' | grep -v 'org.kde.kwin.scripting' | tail -40
