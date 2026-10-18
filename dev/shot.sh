#!/bin/bash
# dev/shot.sh NAME [shortcut] [--keep]  : open overview via shortcut, screenshot, close
cd "$(dirname "$0")/.."
name=$1; sc=${2:-"Toggle GNOME Overview"}; mkdir -p screenshots
if [ "$sc" != none ]; then qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "$sc"; sleep 1.2; fi
rm -f screenshots/$name.png
spectacle -b -n -m -o "$PWD/screenshots/$name.png" >/dev/null 2>&1
for i in $(seq 30); do [ -s screenshots/$name.png ] && break; sleep 0.2; done
sleep 0.3
if [ "$3" != --keep ] && [ "$sc" != none ]; then qdbus org.kde.kglobalaccel /component/kwin invokeShortcut "$sc"; fi
magick screenshots/$name.png -resize 50% screenshots/${name}_small.png
echo screenshots/${name}_small.png
