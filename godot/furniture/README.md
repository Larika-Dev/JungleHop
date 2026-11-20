# Furniture (Godot)

100 to-scale furniture models (1 mm grid) placed in every Cathedral Mount room, all interactable.

| Path | What |
|---|---|
| `models/*.glb` | the 100 models from the Furniture Scale Library (metres, Y up, front +Z, origin at floor centre) |
| `source/catalog.json`, `source/specs.json` | the library's catalogue and per-part specs (mm) |
| `data/furniture_catalog.json` | per model: size, `kind`, actions, seat points, bed points, mount height |
| `data/furniture_actions.json` | 107 furniture action ids with label, game minutes, need effects |
| `data/furniture_placements.json` | 70,364 placements in 10,322 rooms of 701 buildings (building-local, see `format`) |
| `furniture_manager.gd` | autoload `Furniture`: data, queries, adds the streamer on `GameState.world_ready` |
| `scripts/furniture_streamer.gd` | loads pieces within ~30 m on the player's floor (±1), a few per frame |
| `scripts/furniture_piece.gd` | `FurniturePiece` (StaticBody3D, world layer): model, box collider, moving parts, lamp light |
| `scripts/furniture_interactable.gd` | `FurnitureInteractable extends Interactable`: actions, sit/sleep poses, open/close |
| `tests/furniture_smoke_test.tscn` | headless test: every model, every action, opening parts, streaming |
| `tests/room_preview.tscn` | renders furnished rooms to PNG (`screenshots/furniture/`) |

Regenerate the data after `data/rooms.json` changes: `node scripts/furniture/build-furniture-data.mjs`
(deterministic, seed 1795). Actions and room layouts live in `scripts/furniture/furniture-defs.mjs` and
`build-furniture-data.mjs`.

## Using furniture

* Look at a piece and press **E** for its main action (Sit, Sleep, Cook, Study, Open…); hold **E** for all.
* Seats and beds hold one person per seat point; while seated, **Stand up** is the first action.
* Drawers slide out, doors and lids swing on their hinges, sliding doors slide; **Open** picks the part
  nearest the player, **Close** closes them.
* Floor lamps switch on a warm light.

## Access

Every placed piece has a spot where a standing player (30 cm capsule radius) can reach it from the room's
door: the generator flood-fills a 10 cm grid of each room and skips any piece that would block another one
(tables count as reached through any of their chairs). Doorways and door swings stay clear, and tall pieces
keep out of windows. `tests/furniture.test.ts` checks rooms, floors, ceilings and doorways.

## For other systems

* Life systems: nodes in group `"furniture"` emit `action_started` / `action_finished(action_id, actor, furniture)`
  and expose `furniture_kind`. Timed actions finish immediately (Life applies time and needs); `sit` and
  `lie_down` finish when the actor stands up. `GameState.action_performed` also fires for every action.
* NPCs: `Furniture.placements_near(pos, radius, "sit")` finds furniture even when it is not loaded;
  `Furniture.find_nearest(pos, "sleep")` returns a loaded `FurnitureInteractable`. An actor with
  `sit_at(xform)` / `stand_up()` (and optionally `lie_at(xform)`) is posed by the piece; otherwise its
  transform is set directly. Seat transforms: origin on the seat surface, basis −Z facing out of the seat.
