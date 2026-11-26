# Cathedral Mount — Godot 4.5 game

The life-sim version of Cathedral Mount. The city comes from the three.js generator in the repo root
(seed 1795); this folder is the playable Godot game that ships as a Windows `.exe`.

Plug-in contract for other systems (NPCs, life, jobs, education, furniture, crime): [`docs/INTERFACES.md`](docs/INTERFACES.md).

## Run

1. Install [Godot 4.5.1](https://godotengine.org/download) (standard, not .NET).
2. Open `godot/project.godot` in the editor and press F5, or run `godot --path godot`.

## Controls

| Key | Action |
|---|---|
| W A S D | Walk 1.4 m/s; hold **Shift** to run 4 m/s |
| Mouse | Look (click to recapture the mouse) |
| Space | Jump |
| E | Use what you are looking at (open a door, sit, take the stairs). **Hold E** or **Tab** for all actions |
| Tab (looking at nothing) or Q | Everything you can do yourself or at this place: exercise, phone, shop, study, apply for a job, crimes |
| R | People you know (relationship tiers) |
| M | City map (wheel to zoom, drag to pan); shows you and your workplace |
| C | First / third person |
| Esc | Pause menu (save, load, settings, quit) |
| F | Free-fly (debug builds only) |

All keys can be rebound in Settings → Controls.

**Time:** 1 in-game hour = 1 real minute. A new life starts on Day 1 (Monday) at 08:00.

## Build the Windows .exe

```bash
# one-time: install export templates 4.5.1 (Editor → Manage Export Templates, or unzip the .tpz
# into ~/.local/share/godot/export_templates/4.5.1.stable/)
cd godot
godot --headless --import
godot --headless --export-release "Windows Desktop" build/windows/CathedralMount.exe
```

The pck is embedded, so `CathedralMount.exe` is a single file (about 130 MB). It needs a GPU with Vulkan
(Forward+). Windows SmartScreen may warn because the build is not code-signed.

## Tests

```bash
godot --headless --path godot res://tests/smoke_test.tscn      # clock, spawn, interiors, doors, stairs, walking, save/load
xvfb-run godot --path godot res://tests/shots.tscn -- /tmp/shots  # review screenshots (needs a real renderer)
godot --headless --path godot -s res://tests/buildings_test.gd   # modeled building exteriors, all quality tiers
xvfb-run godot --path godot --rendering-driver vulkan res://tests/building_shots.tscn -- /tmp/shots after-  # building review shots
```

## Buildings

Every non-landmark building's exterior is modeled in code (`world/buildings/`): `BuildingDetail` builds
walls with real window and door openings (taken from the exterior openings in `rooms.json`, so they line
up with the streamed interiors), sashes and muntins, sills, lintels, shutters, storefronts with signs and
awnings, porches, cornices, gable / hip / gambrel roofs with gutters and downspouts, chimneys, fire
escapes, balconies, utility clutter and rooftop units. `BuildingStreamer` builds them on worker threads
around the camera and swaps between three levels: a simple massing far away, the modeled building, and a
"fine" layer of small parts close up. Ranges follow the quality preset and the "Detailed building
distance" setting (Low 70 m, Medium 110 m, High 160 m, Ultra 240 m). Surfaces use `facade.gdshader`
(material kind in the vertex alpha: brick, siding, fieldstone, slate, shingle, canvas ... plus grime,
drips, moss) and `window_glass.gdshader` (interior-mapped rooms and lit shops).

## Updating the city

The map and data are generated from the three.js project. After the city changes:

```bash
npm run data && npm run export   # repo root: data/*.json, export/cathedral-mount-map.glb
tools/godot/sync-data.sh         # copies data into godot/data and rebuilds godot/assets/map
```

`city.glb` is the map-detail city (terrain, roads, building massing, landmark exteriors). Walkable
interiors are built at runtime from `rooms.json` within 35 m of the player (`world/interior_streamer.gd`),
with hinged doors and stair/elevator travel between floors.

## Layout

```
core/       autoloads: GameClock, GameState, Settings, CityData; interaction/interactable.gd
world/      city scene, day/night, interior streamer, doors, floor travel, trees
player/     player controller and procedural character body
ui/         UI autoload (theme, toasts, panels, action menu), title, settings, character creator, HUD, pause
data/       buildings.json, rooms.json, palette.json, map labels, trees.json
assets/     map GLBs and fonts (open licenses in assets/fonts)
tests/      smoke test and screenshot scenes
```
