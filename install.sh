#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# User-local install of kgnome-overview (no root needed).
#   ./install.sh            build + install module, effect package and env script, (re)load effect
#   ./install.sh --no-load  same, but don't touch the running KWin
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
SRC_DIR=$PWD
PREFIX="${PREFIX:-$HOME/.local}"
BUILD_DIR="${BUILD_DIR:-$SRC_DIR/build}"
EFFECT_ID=kgnomeoverview
ENV_DIR="$HOME/.config/plasma-workspace/env"
LOAD=1
[[ "${1:-}" == "--no-load" ]] && LOAD=0

QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)

echo ">> Configuring and building"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=OFF >/dev/null
cmake --build "$BUILD_DIR" -j"$(nproc)"

echo ">> Installing QML module"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
DESTDIR="$STAGE" cmake --install "$BUILD_DIR" >/dev/null
STAGED_QMLDIR_FILE=$(find "$STAGE" -path '*/org/kgnome/overview/qmldir' | head -n1)
[[ -n "$STAGED_QMLDIR_FILE" ]] || { echo "staged module not found" >&2; exit 1; }
STAGED_MODULE_DIR=$(dirname "$STAGED_QMLDIR_FILE")
MODULE_DIR=${STAGED_MODULE_DIR#"$STAGE"}               # e.g. ~/.local/lib64/qml/org/kgnome/overview
QML_DIR=${MODULE_DIR%/org/kgnome/overview}             # e.g. ~/.local/lib64/qml
mkdir -p "$MODULE_DIR"
# Copy to a temp name and rename: a running KWin may have the old plugin
# mmapped, and overwriting it in place could crash the compositor.
for f in "$STAGED_MODULE_DIR"/*; do
    name=$(basename "$f")
    cp -f "$f" "$MODULE_DIR/.$name.new"
    mv -f "$MODULE_DIR/.$name.new" "$MODULE_DIR/$name"
done
echo "   $MODULE_DIR"

echo ">> Installing KWin effect package"
PKG_STAGE="$BUILD_DIR/package"
rm -rf "$PKG_STAGE"
cp -r "$SRC_DIR/package" "$PKG_STAGE"
sed "s|@KGO_QML_MODULE_DIR@|$MODULE_DIR|g" "$PKG_STAGE/contents/ui/BackendLocal.qml.in" > "$PKG_STAGE/contents/ui/BackendLocal.qml"
rm -f "$PKG_STAGE/contents/ui/BackendLocal.qml.in"
if kpackagetool6 --type KWin/Effect --show "$EFFECT_ID" >/dev/null 2>&1; then
    kpackagetool6 --type KWin/Effect --upgrade "$PKG_STAGE"
else
    kpackagetool6 --type KWin/Effect --install "$PKG_STAGE"
fi

echo ">> Installing env script ($ENV_DIR/kgnome-overview.sh)"
mkdir -p "$ENV_DIR"
sed "s|@KGO_QML_DIR@|$QML_DIR|g" "$SRC_DIR/env/kgnome-overview.sh.in" > "$ENV_DIR/kgnome-overview.sh"

if [[ $LOAD == 1 && -n "$QDBUS" ]] && "$QDBUS" org.kde.KWin /Effects >/dev/null 2>&1; then
    echo ">> Enabling and (re)loading the effect in KWin"
    kwriteconfig6 --file kwinrc --group Plugins --key "${EFFECT_ID}Enabled" true
    if [[ "$("$QDBUS" org.kde.KWin /Effects isEffectLoaded "$EFFECT_ID")" == "true" ]]; then
        "$QDBUS" org.kde.KWin /Effects unloadEffect "$EFFECT_ID" >/dev/null
    fi
    "$QDBUS" org.kde.KWin /Effects loadEffect "$EFFECT_ID" >/dev/null || true
    echo "   loaded: $("$QDBUS" org.kde.KWin /Effects isEffectLoaded "$EFFECT_ID")"
fi

cat <<MSG
Done.
  Toggle overview:  Meta+O        App grid: Meta+Shift+O
  Note: KWin keeps an already-loaded C++ plugin in memory; changes to the
  C++ module only take effect after the next log out/in. QML changes apply
  after this script reloads the effect.
MSG
