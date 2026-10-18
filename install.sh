#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Matt Hoffer <matt@adroited.com>
# SPDX-License-Identifier: GPL-2.0-or-later
# User-local install of kgnome-overview (no root needed).
#   ./install.sh                  build + install module, effect, plasmoids and env
#                                 script, (re)load the effect; asks whether to make
#                                 it the default (Meta key, panel) when run in a terminal
#   ./install.sh --make-default   same, and make it the default without asking
#   ./install.sh --no-make-default  never ask
#   ./install.sh --no-load        install only: don't touch KWin, the panel or defaults
# Undo the defaults with scripts/restore-defaults.sh, remove with ./uninstall.sh.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
SRC_DIR=$PWD
PREFIX="${PREFIX:-$HOME/.local}"
BUILD_DIR="${BUILD_DIR:-$SRC_DIR/build}"
EFFECT_ID=kgnomeoverview
ENV_DIR="$HOME/.config/plasma-workspace/env"
LOAD=1
MAKE_DEFAULT=ask
for arg in "$@"; do
    case "$arg" in
        --no-load) LOAD=0 ;;
        --make-default) MAKE_DEFAULT=yes ;;
        --no-make-default) MAKE_DEFAULT=no ;;
        -h|--help) sed -n '4,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done
[[ $LOAD == 0 && $MAKE_DEFAULT == yes ]] && { echo "--make-default needs the running session; drop --no-load" >&2; exit 2; }

QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || ls /usr/lib*/qt6/bin/qdbus /usr/lib/*/qt6/bin/qdbus 2>/dev/null | head -n1 || true)

# --- dependencies -----------------------------------------------------------
deps_hint() {
    local id like
    id=$(. /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}")
    echo "Install the build dependencies, then run ./install.sh again:" >&2
    case " $id " in
        *" fedora "*|*" rhel "*)
            echo "  sudo dnf install cmake gcc-c++ extra-cmake-modules qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kservice-devel kf6-kconfig-devel kf6-kcoreaddons-devel" >&2 ;;
        *" arch "*)
            echo "  sudo pacman -S --needed base-devel cmake extra-cmake-modules qt6-base qt6-declarative kservice kconfig kcoreaddons" >&2 ;;
        *" opensuse"*|*" suse "*)
            echo "  sudo zypper install cmake gcc-c++ kf6-extra-cmake-modules qt6-base-devel qt6-declarative-devel kf6-kservice-devel kf6-kconfig-devel kf6-kcoreaddons-devel" >&2 ;;
        *" debian "*|*" ubuntu "*)
            echo "  sudo apt install cmake g++ extra-cmake-modules qt6-base-dev qt6-declarative-dev libkf6service-dev libkf6config-dev libkf6coreaddons-dev" >&2 ;;
        *)  echo "  cmake, a C++20 compiler, extra-cmake-modules, Qt 6 Base/Declarative and KF6 Service/Config/CoreAddons development packages" >&2 ;;
    esac
    echo "  (see README.md, 'Requirements')" >&2
}
missing=()
for tool in cmake kpackagetool6 kwriteconfig6 kreadconfig6; do
    command -v "$tool" >/dev/null || missing+=("$tool")
done
command -v c++ >/dev/null || command -v g++ >/dev/null || command -v clang++ >/dev/null || missing+=("C++ compiler")
[[ $LOAD == 1 && -z "$QDBUS" ]] && missing+=("qdbus (Qt 6 tools)")
if (( ${#missing[@]} )); then
    echo "Missing: ${missing[*]}" >&2
    deps_hint
    exit 1
fi

echo ">> Configuring and building"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=OFF >/dev/null 2>"$BUILD_DIR.cmake.log" \
    || { cat "$BUILD_DIR.cmake.log" >&2; echo >&2; deps_hint; exit 1; }
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

echo ">> Installing the panel launcher plasmoid (org.kgnome.overview.showapps)"
LAUNCHER="$SRC_DIR/plasmoid/org.kgnome.overview.showapps"
if kpackagetool6 --type Plasma/Applet --show org.kgnome.overview.showapps >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$LAUNCHER" >/dev/null
else
    kpackagetool6 --type Plasma/Applet --install "$LAUNCHER" >/dev/null
fi

echo ">> Installing the system menu plasmoid (org.kgnome.systemsheet)"
SYSMENU="$SRC_DIR/plasmoid/org.kgnome.systemsheet"
if kpackagetool6 --type Plasma/Applet --show org.kgnome.systemsheet >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$SYSMENU" >/dev/null
else
    kpackagetool6 --type Plasma/Applet --install "$SYSMENU" >/dev/null
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

# The Show Apps button usually replaces Kickoff, and with it the only Log Out
# button: put the System Menu next to the tray of that panel (once).
if [[ $LOAD == 1 ]]; then
    echo ">> System menu on the Show Apps panel"
    APPLETSRC="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
    if [[ -f "$APPLETSRC" ]] && ! grep -qx "plugin=org.kgnome.systemsheet" "$APPLETSRC"; then
        BK="$SRC_DIR/backup/$(date +%Y%m%d-%H%M%S)-install"
        mkdir -p "$BK" && cp -p "$APPLETSRC" "$BK/"
        echo "   backup: $BK"
    fi
    "$SRC_DIR/scripts/system-menu.sh" ensure || true
fi

# Making it the default changes the Meta key, the hot corner and the panel
# launcher: opt-in only. Backups go to backup/<timestamp>/.
if [[ $LOAD == 1 && $MAKE_DEFAULT == ask && -t 0 && -t 1 ]]; then
    echo
    echo "Make the GNOME-style overview the default? This binds the Meta key, sets the"
    echo "top-left hot corner and replaces the Application Launcher on the panel with"
    echo "Show Apps + System Menu (KWin and panel config are backed up first; undo with"
    echo "scripts/restore-defaults.sh)."
    read -r -p "Make it the default now? [y/N] " answer
    [[ $answer == [yY]* ]] && MAKE_DEFAULT=yes
fi
if [[ $LOAD == 1 && $MAKE_DEFAULT == yes ]]; then
    "$SRC_DIR/scripts/make-default.sh"
fi

cat <<MSG
Done.
  Overview:  Meta+O      App grid: Meta+Shift+O
  Meta alone, Meta+W, the top-left hot corner and Show Apps on the panel
  once it is the default (./install.sh --make-default).
  Undo the defaults: scripts/restore-defaults.sh   Remove: ./uninstall.sh
  First install, or an update of the C++ module: log out and back in once
  (KWin keeps a loaded C++ plugin in memory). QML changes apply right away;
  an updated panel plasmoid shows after a re-login or
  'systemctl --user restart plasma-plasmashell'.
MSG
