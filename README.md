# Cathedral Mount

A walkable, GTA-style fictional college town inspired by downtown Chapel Hill and the UNC campus. It is home of **Old North State University (ONSU)** in the fictional State of Pamlico. The whole city is generated in code with Three.js + TypeScript from seed `1795`, so the same seed builds the same city every run. Every building has a hollow architectural interior on every floor. Rooms carry metadata slots for a later furniture/items pass.

The full design spec is in [`CLAUDE.md`](CLAUDE.md). The Phase 1 concept map is in [`docs/phase-1/`](docs/phase-1/).

## Run it

```bash
npm install
npm run dev          # http://localhost:5173  (walkable city)
npm test             # Vitest: palette, kit dimensions, stairs/doors, interiors, landmarks, parody names
npm run typecheck
npm run data         # regenerate data/palette.json, buildings.json, rooms.json, parody-names.json
npm run export       # export/cathedral-mount-map.glb (+ labels) — whole city at map detail
npm run export:gltf  # export/landmarks/*.glb (full exterior + interior + room extras), export/tiles/T_c_r.glb (full detail)
                     #   args: landmarks|tiles|all [filter], e.g. `npm run export:gltf -- tiles T_9_7`
npm run shots -- 7   # Playwright screenshots for a phase (scripts/shots/phase-N.json → screenshots/phase-N/)
```

URL parameters:
- `?scene=city|gallery|interiors|scaffold` selects the full city, the kit gallery, the interior demo, or the scaffold test scene.
- `x`, `z`, `yaw` set the spawn point and facing.
- `preset=golden|midday|night|rain` sets the lighting preset.
- `shadows=csm|simple|off`, `ao=0|1`, `aa`, `fov`, `hud` control render options.

## Controls

| Key | Action |
|---|---|
| Click | Capture the mouse (pointer lock). If the page can't lock the pointer, drag to look |
| W A S D | Walk at 1.4 m/s. Hold **Shift** to run at 4 m/s |
| Space | Jump (walk mode), or rise (fly mode) |
| F | Toggle free-fly |
| E | Open or close the door you are looking at. Every door is hinged and animated |
| M | Full map screen. The minimap is always shown top right |
| 1 / 2 / 3 / 4 | Lighting preset: Golden Hour (default) / Midday / Night / Rain |
| ` (backtick) | Debug panel |

Debug panel toggles:
- **measure**: click two points to get the distance in cm
- **wireframe**
- **rooms**: room labels showing roomType and area
- **tiles**: 200 m tile boundaries
- **radius**: the 35 m interior streaming radius
- **picker**: the palette key under the cursor

A perf HUD shows FPS, draw calls, triangles, active tiles and loaded interiors.

## Architecture

```
src/core        units (integer cm → m), palette (the ONLY file with hex colors), seeded RNG, tiles, streaming,
                GeoBuilder (merged per-material geometry), procedural textures, material library
src/terrain     heightfield (ridge, ravine, stadium bowl, Carrburg flats), terrain meshes + splat shader
src/roads       road network (nodes, curb returns, ADA ramps, bridges), curbs, sidewalks, markings
src/kits        every modular kit from CLAUDE.md §6 as cm-dimensioned functions + near-detail instanced bricks/pavers
src/interiors   floor-plan generator (6 typologies), validation, stairs/shafts, room metadata, interior-mapping shader
src/buildings   facades, exterior builder, BuildingManager (interior streaming), impostors, landmarks/ (one file each)
src/districts   Hamilton Strip business roster + generated businesses, all other districts
src/vegetation  species, instanced trees, hedges, ivy, leaf litter, grass
src/street      lamps, signals, benches, hydrants, shelters, meters, manholes, street-name blades
src/signage     open-licensed fonts, parody text, posters, graffiti, the Billram mascot, sign atlas
src/lighting    presets (golden / midday / night / rain), sky, CSM shadows, rain streaks, eave drips, puddles
src/player      first-person controls, capsule collision, doors, minimap
src/debug       measure, wireframe, room labels, overlays, perf HUD
```

- **Tiles:** the world streams in 200 × 200 m tiles. The 3 × 3 ring around the player is active, a wider ring is prefetched, and far tiles show merged impostors. Each content system registers a tile builder (`registerTileBuilder`).
- **Interiors:** interiors stream per building within 35 m of a door and unload beyond 45 m. Distant windows use an interior-mapping shader, so the city never looks hollow.
- **City plan:** `src/world/cityPlan.ts` sites every building. Each building is cleared against road rights-of-way and other footprints, graded, and cut into the terrain. It currently places 705 buildings, and every floor plan passes validation.

## Adding items later (the items pass)

Rooms are built hollow on purpose. Each one is an `Object3D` named `CM_{BuildingId}_F{floor}_R{index}`, and its `userData` holds:

```ts
{ roomId, buildingId, floor, roomType, areaM2, ceilingCm,
  floorFinish, wallFinish, ceilingFinish, lightingKey,
  itemSlots: [],                          // ← fill this in the items pass
  anchorWalls: [{ start, end, normal }],  // wall runs usable for furniture
  openings: [{ type, position, widthCm }] }
```

`data/rooms.json` exports the same records for all 13,102 rooms in building-local meters. `data/buildings.json` gives each building's transform: `world = R_y(rotY) · local + (x, y, z)`.

To place items:
1. Pick rooms by `roomType`, e.g. every `dorm_double` or every `bar`.
2. Lay furniture along `anchorWalls`, keeping clear of `openings`.
3. Append each placement to `itemSlots`.
4. At load time, add the item meshes as children of the room's `Object3D`.

The items then stream with the building's interior automatically.

## Data & exports

- `data/palette.json`: the master palette from CLAUDE.md §4. `tests/palette.test.ts` fails if a hex literal appears anywhere in `src` outside `palette.ts`.
- `data/buildings.json`, `data/rooms.json`, `data/parody-names.json`: every name in the city maps to its real-world inspiration. `tests/parody.test.ts` checks every generated string against a trademark list.
- `export/cathedral-mount-map.glb`: the whole city as one map-detail model. It contains:
  - terrain
  - roads with sidewalks and centerlines
  - massing for all buildings
  - landmark exteriors
  - about 29k instanced trees (`EXT_mesh_gpu_instancing`)

  It uses vertex colors only and opens in any glTF viewer.
- `export/landmarks/*.glb` and `export/tiles/*.glb` are full-detail files: about 220 MB for the 20 landmarks and about 65 MB per core tile. They are build output and git-ignored, so regenerate them with `npm run export:gltf`. Landmark files contain each room as a named node, with its §7.4 metadata stored as glTF `extras`.

## Credits

Fonts are bundled in `public/fonts` under the SIL Open Font License; license files are alongside them. All names, schools, businesses and marks are original parodies. No real logos or business names are used.
