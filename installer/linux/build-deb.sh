#!/usr/bin/env bash
# Builds the Debian/Ubuntu package from an exported Linux binary.
# Usage: installer/linux/build-deb.sh <GemHunters.x86_64> <version> <output.deb>
set -euo pipefail
umask 022

BINARY="$1"
VERSION="$2"
OUTPUT="$3"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
chmod 755 "$ROOT"

install -Dm755 "$BINARY" "$ROOT/opt/gem-hunters/GemHunters.x86_64"
install -Dm644 "$HERE/../../LICENSE" "$ROOT/usr/share/doc/gem-hunters/copyright"
install -Dm644 "$HERE/gem-hunters.desktop" "$ROOT/usr/share/applications/gem-hunters.desktop"
install -Dm644 "$HERE/../../icon.svg" "$ROOT/usr/share/icons/hicolor/scalable/apps/gem-hunters.svg"
mkdir -p "$ROOT/usr/bin"
ln -s /opt/gem-hunters/GemHunters.x86_64 "$ROOT/usr/bin/gem-hunters"

mkdir -p "$ROOT/DEBIAN"
cat > "$ROOT/DEBIAN/control" <<CONTROL
Package: gem-hunters
Version: $VERSION
Section: games
Priority: optional
Architecture: amd64
Maintainer: Wennovate
Installed-Size: $(du -sk "$ROOT" | cut -f1)
Depends: libc6, libgl1, libx11-6
Description: Gem Hunters: Tag & Trap - couch party game for 2-4 players
 Split-screen 3D party game in freshly generated themed mazes: grab gems,
 open gift boxes for traps and items, and knock gems out of your friends.
 One player on keyboard and mouse, everyone else on a gamepad. By Wennovate.
CONTROL

dpkg-deb --root-owner-group --build "$ROOT" "$OUTPUT"
