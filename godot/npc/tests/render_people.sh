#!/usr/bin/env bash
# Close-up people shots (Forward+ on Vulkan; lavapipe works in the cloud).
#   GODOT=/path/to/godot godot/npc/tests/render_people.sh <out_dir> [shot ...]
set -euo pipefail
OUT=$(realpath -m "${1:-/tmp/people-shots}")
shift || true
mkdir -p "$OUT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ln -s "$(cd "$(dirname "$0")/.." && pwd)" "$TMP/npc"
printf '[application]\nconfig/name="npc-render"\n[rendering]\nanti_aliasing/quality/msaa_3d=2\n' > "$TMP/project.godot"
"${GODOT:-godot}" --headless --path "$TMP" --import >/dev/null 2>&1 || true
timeout 900 xvfb-run -a -s "-screen 0 1600x1000x24" "${GODOT:-godot}" --path "$TMP" --rendering-driver vulkan \
  --resolution 1600x1000 --audio-driver Dummy --script res://npc/tests/${SCRIPT:-render_people.gd} -- "$OUT" "$@" 2>&1 | grep -E "SCRIPT ERROR|ERROR:" -A2 | head -20 || true
ls "$OUT"
