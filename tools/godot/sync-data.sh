#!/usr/bin/env bash
# Copy the generated city data into the Godot project and rebuild the Godot map assets.
# Run after `npm run data` / `npm run export` change the city.
set -euo pipefail
cd "$(dirname "$0")/../.."
cp data/buildings.json data/rooms.json data/palette.json godot/data/
cp export/cathedral-mount-map-labels.json godot/data/map-labels.json
node tools/godot/export-godot-map.mjs
npx vite-node tools/godot/export-godot-props.ts   # street props, parked cars, lamps, poles, decals -> godot/data/props.json
