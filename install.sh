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
      -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=OFF >/dev/null 2>"$BUILD_DIR.cmake.log" \
    || { cat "$BUILD_DIR.cmake.log" >&2; exit 1; }
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
# Fresh implementation directory per install: KWin's shared QML engine caches
# compiled QML by URL for the whole session (see contents/ui/main.qml).
IMPL_DIR="impl-$(date +%Y%m%d%H%M%S)"
rm -rf "$PKG_STAGE"
cp -r "$SRC_DIR/package" "$PKG_STAGE"
IMPL="$PKG_STAGE/contents/ui/impl"
sed "s|@KGO_QML_MODULE_DIR@|$MODULE_DIR|g" "$IMPL/BackendLocal.qml.in" > "$IMPL/BackendLocal.qml"
rm -f "$IMPL/BackendLocal.qml.in"
mv "$IMPL" "$PKG_STAGE/contents/ui/$IMPL_DIR"
if kpackagetool6 --type KWin/Effect --show "$EFFECT_ID" >/dev/null 2>&1; then
    kpackagetool6 --type KWin/Effect --upgrade "$PKG_STAGE"
else
    kpackagetool6 --type KWin/Effect --install "$PKG_STAGE"
fi

# KWin looks for declarative effects in kwin-wayland/effects/ first. Pointing
# that at the package gives main.qml a URL KWin has not cached yet when the
# package is first installed into an already-running session.
WAYLAND_EFFECTS="${XDG_DATA_HOME:-$HOME/.local/share}/kwin-wayland/effects"
mkdir -p "$WAYLAND_EFFECTS"
if [[ ! -e "$WAYLAND_EFFECTS/$EFFECT_ID" || -L "$WAYLAND_EFFECTS/$EFFECT_ID" ]]; then
    ln -sfn "${XDG_DATA_HOME:-$HOME/.local/share}/kwin/effects/$EFFECT_ID" "$WAYLAND_EFFECTS/$EFFECT_ID"
fi
kwriteconfig6 --file kwinrc --group "Effect-$EFFECT_ID" --key ImplDir "$IMPL_DIR"

# Dash favourites: share Kickoff's KActivities favourites (two-way). Picks the
# first Kickoff (else Kicker/Kickerdash) applet; set once, user value kept.
if [[ -z "$(kreadconfig6 --file kwinrc --group "Effect-$EFFECT_ID" --key FavoritesClient --default __unset__ | sed 's/^__unset__$//')" ]] \
   && ! grep -q '^FavoritesClient=' <(sed -n "/^\[Effect-$EFFECT_ID\]/,/^\[/p" "${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc" 2>/dev/null); then
    APPLETSRC="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
    CLIENT=$(awk '
        /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/ { split($0, a, /[][]+/); id = a[5]; next }
        /^\[/ { id = "" }
        id != "" && $0 == "plugin=org.kde.plasma.kickoff" && !k { k = "org.kde.plasma.kickoff.favorites.instance-" id }
        id != "" && ($0 == "plugin=org.kde.plasma.kicker" || $0 == "plugin=org.kde.plasma.kickerdash") && !o { o = "org.kde.plasma.kicker.favorites.instance-" id }
        END { print (k ? k : o) }' "$APPLETSRC" 2>/dev/null || true)
    if [[ -n "$CLIENT" ]]; then
        kwriteconfig6 --file kwinrc --group "Effect-$EFFECT_ID" --key FavoritesClient "$CLIENT"
        echo "   dash favourites shared with $CLIENT"
    fi
fi

echo ">> Installing env script ($ENV_DIR/kgnome-overview.sh)"
mkdir -p "$ENV_DIR"
sed "s|@KGO_QML_DIR@|$QML_DIR|g" "$SRC_DIR/env/kgnome-overview.sh.in" > "$ENV_DIR/kgnome-overview.sh"

if [[ $LOAD == 1 && -n "$QDBUS" ]] && "$QDBUS" org.kde.KWin /Effects >/dev/null 2>&1; then
    echo ">> Enabling and (re)loading the effect in KWin"
    kwriteconfig6 --file kwinrc --group Plugins --key "${EFFECT_ID}Enabled" true
    # make KWin re-read kwinrc (new ImplDir) before reloading the effect
    "$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null || true
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
