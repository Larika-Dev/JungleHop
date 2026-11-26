# Cathedral Mount (Godot) — plug-in interfaces

Godot **4.5.1**, GDScript only, no addons. The Godot project root is `godot/` (`godot/project.godot`).
Branch with the foundation: `claude/godot-foundation`.

## Folder ownership

| Folder | Owner | Contents |
|---|---|---|
| `godot/core/` | foundation | autoloads (GameClock, GameState, Settings, CityData), `Interactable` |
| `godot/world/` | foundation | city scene, map import, interior streaming, day/night |
| `godot/player/` | foundation | player controller, look ray, character appearance |
| `godot/ui/` | foundation | title screen, settings, customization, HUD, pause, UI autoload |
| `godot/data/` | foundation | copies of `data/buildings.json`, `rooms.json`, map labels (`tools/sync-godot-data.sh`) |
| `godot/npc/` | NPC thread | NPC generation, bodies, crowd streaming |
| `godot/life/` | life-systems thread | actions, needs, money, relationships, jobs, education, mini games |
| `godot/furniture/` | furniture thread | furniture models, catalog, placement, interactables |
| `godot/jobs/` | jobs thread | jobs, shifts, hourly pay (`JobSystem` autoload) |
| `godot/education/` | education thread | school, classes, grades (`Education` autoload) |

**Only shared file:** `godot/project.godot`. Each thread adds exactly one line under `[autoload]`
for its own manager, e.g. `Life="*res://life/life.gd"`, `NPCs="*res://npc/npc_manager.gd"`,
`Furniture="*res://furniture/furniture_manager.gd"`. Do not edit other sections.
Add your own input actions in code (`InputMap.add_action`) if you need new keys, not in project.godot.

## Coordinates

Same as the three.js city: **1 unit = 1 m, +X east, −Z north, +Y up**, origin at The Summit
(Hamilton × Columbia). Building local → world: `CityData.building_transform(id) * local`
(`world = R_y(rotY) * local + (x, y, z)` from `buildings.json`). Room data (`rooms.json`) is building-local.

## Autoloads (load order)

### `GameClock` — `res://core/game_clock.gd`
**1 in-game hour = 60 real seconds** (1 game minute per real second). Day 1 is a Monday; a new game starts Day 1 08:00.

| Member | Type | Notes |
|---|---|---|
| `total_minutes` | float | minutes since Day 1 00:00 |
| `day` / `hour` / `minute` / `weekday` | int | read-only; `weekday` 0 = Mon |
| `hour_f` | float | 0.0–24.0 |
| `speed` | float | multiplier, default 1.0 |
| `paused` | bool | true on title screen / pause menu |
| `signal minute_passed(total_minutes: int)` | | every game minute |
| `signal hour_passed(day: int, hour: int)` | | on the hour — **pay-by-the-hour hooks here** |
| `signal day_passed(day: int)` | | at 00:00 |
| `signal time_set(total_minutes: float)` | | after `set_time` / load |
| `advance_minutes(m)` | | skip time (sleep, a shift, a class); emits every intervening signal |
| `set_time(day, hour, minute)`, `time_string()`, `date_string()`, `is_between(h0, h1)` | | |

### `GameState` — `res://core/game_state.gd`
| Member | Notes |
|---|---|
| `player_profile: Dictionary` | set by the character creator: `{name, sex, age (18–80), height_cm (150–200), weight_kg (40–150), muscle (1–10 preset; 7 is best), build (0–1 from BMI), skin, hair_style, hair_color, shirt_color, pants_color, starting_cash (= 1000)}` |
| `bmi(profile) -> float`, `STARTING_CASH` | every new life starts with $1,000; Life seeds its wallet and hidden stats (attractiveness, muscle, grooming, weight) from the profile on `game_started` |
| `get_player() -> Node3D` | the player (also in group `"player"`) |
| `world: Node3D` + `signal world_ready(world)` | the city root. **Add your streamers/managers as children of `world` when this fires.** |
| `signal action_performed(action_id, target, actor)` | fired for every `Interactable` action. Life systems listen here. |
| `register_saveable(id, node)` | node implements `save_data() -> Dictionary` and `load_data(d)`; data persists in `user://saves/slotN.json`. Late registrations still receive loaded data. |
| `save_game(slot)`, `load_game(slot)`, `has_save(slot)` | signals `game_saved`, `game_loaded`, `game_started` |

### `Settings` — `res://core/settings.gd`
Graphics (quality preset, resolution scale, fullscreen, vsync, fov, shadows, view distance), audio buses
(Master/Music/SFX/Ambient), controls (mouse sensitivity, invert Y, rebindable keys). `signal settings_changed`.
Read `Settings.view_distance` (m) and `Settings.quality` (0 low … 3 ultra) to scale NPC/furniture detail.
Advanced graphics (set by `Settings.set_quality`, each overridable): `gi` (0 off, 1 SSIL, 2 SDFGI), `reflections`,
`volumetric_fog`, `ambient_occlusion`, `antialiasing` (0 FXAA, 1 TAA, 2 TAA+MSAA), `upscaler` (0 bilinear, 1 FSR1, 2 FSR2),
`shadow_quality` (0..3), `grass_density` (0..1), `foliage_distance` (m). First launch picks a preset from the GPU.

Shader globals (project.godot `[shader_globals]`, set by DayNight / Settings): `cm_night` (0 day … 1 night),
`cm_wind` (xy direction, z gust, w time), `cm_sun_dir`, `cm_quality`. World shaders live in `world/shaders/`
(ground, facade, foliage, grass, water, interior, sky; shared noise in `noise.gdshaderinc`).

### `CityData` — `res://core/city_data.gd`
`buildings` (array), `building(id)`, `building_ids()`, `building_transform(id) -> Transform3D`,
`rooms_for_building(id)`, `room(roomId)`, `all_rooms()`, `room_world_center(roomId)`, `room_local_aabb(roomId)`,
`buildings_near(pos, radius)` (by building origin), `room_at(world_pos)`, `labels` (districts/landmarks).

### `UI` — `res://ui/ui_root.gd`
`UI.notify(text)` toast, `UI.open_panel(control)` / `UI.close_panel()` (frees the mouse, stops player input),
`UI.show_minigame(packed_scene) -> Node` (full-screen; the mini game calls `UI.close_panel()` when done),
`UI.is_panel_open()`. The HUD shows clock/date and shows `Life.money` (or `Life.money.cash`) if a `Life` autoload exists.
The HUD node (group `"hud"`) has `add_widget(control)` for extra panels in the top-right column.

## Interaction — `class_name Interactable extends Node3D` (`res://core/interaction/interactable.gd`)

Add an `Interactable` (or subclass) as a **child of a CollisionObject3D** (StaticBody3D, Area3D, CharacterBody3D).
The player casts a 2.5 m ray from the camera every frame (mask: layers 1 world + 3 interact);
`Interactable.find_from(collider)` checks the collider's children, then the collider and its ancestors
(an ancestor can also point at one with `set_meta("interactable", node)`).

```gdscript
extends Interactable   # e.g. res://furniture/scripts/chair_interactable.gd

func get_actions(actor: Node) -> Array[Dictionary]:
    return [
        {"id": "sit",   "label": "Sit",   "minutes": 0},
        {"id": "nap",   "label": "Nap",   "minutes": 30},
    ]

func perform(action_id: String, actor: Node) -> void:
    match action_id:
        "sit": actor.sit_at(global_transform)      # player helper, see below
        "nap": GameClock.advance_minutes(30)
    super.perform(action_id, actor)   # emits performed + GameState.action_performed
```

* **E** runs the first action; **hold E (0.35 s) or Tab** opens a menu listing all actions.
* `get_prompt(actor)` builds the HUD text; `interact(actor)` runs the first action.
* Exported fields: `display_name`, `enabled`, `default_action_id`, `default_action_label`, `default_action_minutes`.
* NPCs use the same path: give the NPC body an `Interactable` child that returns "Talk", "Compliment", "Ask on a date"…

Collision layers: 1 `world` (static city), 2 `player`, 3 `interact` (bodies the look ray should hit but the player can walk through, e.g. Area3D triggers), 4 `npc`.

## Player — `res://player/player.gd` (`CharacterBody3D`, group `player`)
`set_input_enabled(bool)`, `sit_at(xform)` (origin = seat surface where the hips go, −Z = facing out of the seat),
`lie_at(xform)` (origin = mattress at the hips, −Z = toward the head), `stand_up()`, `posture` ("stand"/"sit"/"lie"),
signals `sat_down(xform)` / `stood_up`, `teleport(pos, yaw)`,
`camera: Camera3D`, `appearance: Node3D` (rebuilt from `GameState.player_profile`). Eye height 165 cm,
walk 1.4 m/s, run 4 m/s (Shift), jump (Space), C toggles first/third person, F free-fly (debug).

## World — `res://world/city.tscn`
Loads the map GLB (`res://assets/map/cathedral-mount-map.glb`: terrain, roads, every building massing,
landmark exteriors, trees) with trimesh collision, a sky + sun driven by `GameClock.hour_f`,
and `InteriorStreamer`, which builds walkable building interiors (floors, walls, ceilings, doors as openings)
from `rooms.json` for buildings within 35 m of the player. Building interiors are named
`BLD_<buildingId>` under `world/Interiors`, with the building transform applied; each room is a child
`Node3D` named by its `roomId` with `meta("room")` = the rooms.json entry.
Signals on the streamer: `building_loaded(id, node)` and `building_unloaded(id)` — furniture can attach here,
or stream independently in world space using CityData.
