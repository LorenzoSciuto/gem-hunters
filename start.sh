#!/usr/bin/env bash
# Gem Hunters: Tag & Trap — game launcher. Extra arguments are passed to Godot.
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate a Godot 4.3 binary: bundled copy, $GODOT_BIN, then PATH.
GODOT_EXEC=""
for candidate in "$PROJECT_DIR/.tools/Godot_v4.3-stable_linux.x86_64" "$GODOT_BIN" \
		"$(command -v godot4 2>/dev/null || true)" "$(command -v godot 2>/dev/null || true)"; do
	if [ -n "$candidate" ] && [ -x "$candidate" ]; then
		GODOT_EXEC="$candidate"
		break
	fi
done

if [ -z "$GODOT_EXEC" ]; then
	echo "Error: Godot 4 not found. Put the binary in $PROJECT_DIR/.tools/ or set GODOT_BIN."
	exit 1
fi

cat <<'BANNER'
==============================================================================
  GEM HUNTERS: TAG & TRAP  -  split-screen party game by Wennovate
==============================================================================
  PLAYER 1  (keyboard + mouse)
    Move WASD | Look mouse | Jump Space / right click | Items Q E R | Superpower F
    Mouse wheel picks item or superpower, left click fires it | View V
  PLAYERS 2-4  (gamepad)
    Move left stick | Look right stick | Jump RB / RT | Items X A B | Superpower Y
    View LB
  Jump on a rival's head to steal gems. Controls can be remapped from the menu.
  ESC or START pauses the match.
==============================================================================
BANNER

exec "$GODOT_EXEC" --path "$PROJECT_DIR" "$@"
