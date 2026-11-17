#!/usr/bin/env bash
# Headless checks for a pull request: the import (which fails on any script
# error; unused code and untyped declarations are errors, see [debug] in
# project.godot), then every tests/test_*.gd.
#   GODOT=/path/to/godot tests/run.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Seconds before a test that never finishes counts as failed.
TEST_TIMEOUT=180
failed=0

# A fresh checkout has no import cache: its first import parses scripts before
# the resources they preload exist. That pass only builds the cache.
"$GODOT" --headless --path . --import >/dev/null 2>&1
output=$("$GODOT" --headless --path . --import 2>&1)
if grep -q "SCRIPT ERROR" <<<"$output"; then
	echo "FAIL import"
	grep -A2 "SCRIPT ERROR" <<<"$output"
	exit 1  # Nothing else can run on scripts that don't compile.
fi
echo "ok   import"

for test in tests/test_*.gd; do
	output=$(timeout "$TEST_TIMEOUT" "$GODOT" --headless --path . -s "$test" 2>&1)
	if [ $? -eq 0 ] && grep -q "TEST OK" <<<"$output" && ! grep -q "SCRIPT ERROR" <<<"$output"; then
		echo "ok   $test"
	else
		echo "FAIL $test"
		grep -A2 "FAILED\|SCRIPT ERROR" <<<"$output"
		failed=1
	fi
done
exit $failed
