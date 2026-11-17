#!/usr/bin/env bash
# Puts the version in the name of every file of the web build except
# index.html (index.wasm -> index.1.2.3.wasm) and points the page at them.
# With fixed names a browser keeps serving its cached copy of the previous
# release; a name it has never seen can only be downloaded.
# Also writes probe.html: the same page, started on the graphics probe scene.
#   installer/version_web_build.sh <web build dir> <version>
set -euo pipefail
cd "$1"
version=$2

for file in index.*; do
	[ "$file" = index.html ] || mv "$file" "index.$version.${file#index.}"
done
# Every file the page names, then the base name the engine builds the rest from.
sed -i -E "s/index\.(js|png|pck|wasm|icon\.png|apple-touch-icon\.png)/index.$version.\1/g; s/\"executable\":\"index\"/\"executable\":\"index.$version\"/" index.html
# A scene path as the engine's only argument replaces the main scene.
sed 's|"args":\[\]|"args":["res://scenes/debug/GraphicsProbe.tscn"]|' index.html > probe.html
grep -q GraphicsProbe probe.html
