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

echo ">> Removing effect package"
kpackagetool6 --type KWin/Effect --remove "$EFFECT_ID" 2>/dev/null || true

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
