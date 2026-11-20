#!/usr/bin/env bash
# Renders close-up PNGs of NPC bodies into the given folder (needs xvfb-run).
#   GODOT=/path/to/godot godot/npc/tests/render.sh /tmp/npc-shots
set -euo pipefail
OUT=$(realpath -m "${1:-/tmp/npc-shots}")
mkdir -p "$OUT"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ln -s "$(cd "$(dirname "$0")/.." && pwd)" "$TMP/npc"
printf '[application]\nconfig/name="npc-render"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$TMP/project.godot"
"${GODOT:-godot}" --headless --path "$TMP" --import >/dev/null 2>&1 || true
timeout 300 xvfb-run -a -s "-screen 0 1280x800x24" "${GODOT:-godot}" --path "$TMP" --rendering-driver opengl3 \
  --resolution 1280x800 --audio-driver Dummy --script res://npc/tests/render_closeup.gd -- "$OUT" 2>&1 | grep -E "SCRIPT ERROR|ERROR:" -A2 || true
ls "$OUT"
