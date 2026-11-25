#!/usr/bin/env bash
# Parses every NPC script in the Godot project and prints any errors.
#   GODOT=/path/to/godot godot/npc/tests/check_scripts.sh
PROJ=$(cd "$(dirname "$0")/../.." && pwd)
"${GODOT:-godot}" --headless --path "$PROJ" --import >/dev/null 2>&1
for f in $(cd "$PROJ/npc" && find . -name '*.gd' | sed 's|^\./||'); do
  out=$(timeout 60 "${GODOT:-godot}" --headless --path "$PROJ" --check-only --script "res://npc/$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A1)
  [ -n "$out" ] && { echo "== $f"; echo "$out"; }
done
echo "check done"
