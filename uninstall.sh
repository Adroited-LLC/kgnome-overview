#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Remove everything install.sh put in place (user-local only).
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
EFFECT_ID=kgnomeoverview
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)

if [[ -n "$QDBUS" ]] && "$QDBUS" org.kde.KWin /Effects >/dev/null 2>&1; then
    if [[ "$("$QDBUS" org.kde.KWin /Effects isEffectLoaded "$EFFECT_ID")" == "true" ]]; then
        echo ">> Unloading effect"
        "$QDBUS" org.kde.KWin /Effects unloadEffect "$EFFECT_ID" >/dev/null || true
    fi
fi
kwriteconfig6 --file kwinrc --group Plugins --key "${EFFECT_ID}Enabled" --delete || true
kwriteconfig6 --file kwinrc --group "Effect-$EFFECT_ID" --key ImplDir --delete || true

WAYLAND_LINK="${XDG_DATA_HOME:-$HOME/.local/share}/kwin-wayland/effects/$EFFECT_ID"
if [[ -L "$WAYLAND_LINK" ]]; then
    rm -f "$WAYLAND_LINK"
fi

echo ">> Removing the system menu"
"$(dirname "$(readlink -f "$0")")/scripts/system-menu.sh" remove || true
kpackagetool6 --type Plasma/Applet --remove org.kgnome.systemsheet 2>/dev/null || true

echo ">> Removing effect package"
kpackagetool6 --type KWin/Effect --remove "$EFFECT_ID" 2>/dev/null || true
# the panel launcher (put Kickoff back first: dev/restore-defaults.sh)
kpackagetool6 --type Plasma/Applet --remove org.kgnome.overview.showapps 2>/dev/null || true
# pre-1.1 id of the same plasmoid
kpackagetool6 --type Plasma/Applet --remove org.kgnome.overview.launcher 2>/dev/null || true

echo ">> Removing QML module"
for libdir in lib64 lib; do
    d="$PREFIX/$libdir/qml/org/kgnome/overview"
    if [[ -d "$d" ]]; then
        # Only the files we install.
        rm -f "$d"/libkgnomeoverviewplugin.so "$d"/qmldir "$d"/kgnomeoverviewplugin.qmltypes "$d"/kde-qmlmodule.version
        rmdir "$d" "$(dirname "$d")" 2>/dev/null || true
    fi
done

echo ">> Removing env script"
rm -f "$HOME/.config/plasma-workspace/env/kgnome-overview.sh"

if [[ -n "$QDBUS" ]]; then
    "$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
fi
echo "Done. The global shortcuts stay listed in System Settings > Shortcuts > KWin until removed there; log out/in to drop the plugin from KWin's memory."
