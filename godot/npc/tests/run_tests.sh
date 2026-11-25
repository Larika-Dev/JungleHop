#!/usr/bin/env bash
# Runs the NPC tests headless in the Godot project (godot/).
#   GODOT=/path/to/godot godot/npc/tests/run_tests.sh [test_name ...]
set -uo pipefail
GODOT=${GODOT:-godot}
PROJ=$(cd "$(dirname "$0")/../.." && pwd)
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
TESTS=("$@")
[ ${#TESTS[@]} -eq 0 ] && TESTS=(test_population test_simulation test_streaming test_body)
status=0
for t in "${TESTS[@]}"; do
  echo "== $t"
  timeout 600 "$GODOT" --headless --path "$PROJ" --audio-driver Dummy --script "res://npc/tests/$t.gd" 2>&1 \
    | grep -vE "^Godot Engine|^$|^WARNING: .*(vsync|V-Sync)" || true
  [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
done
exit $status
