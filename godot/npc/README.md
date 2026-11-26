# NPCs (`godot/npc/`)

4,000 residents of Cathedral Mount with identities, homes, jobs, routines and
social ties, the nearest 100 streamed in as detailed skinned bodies.

Autoload line (in `project.godot`): `NPCs="*res://npc/npc_manager.gd"`

## What is here

| File | What it does |
|---|---|
| `npc_config.gd` | Every number asked for: 4,000 NPCs, 100 loaded, height rules, LOD distances |
| `npc_heights.gd` | Height sampling: exactly 90% inside the 25th to 75th range, everyone inside the +-10% bounds |
| `npc_demographics.gd` | Student and town mixes, see `docs/DEMOGRAPHICS.md` |
| `npc_population.gd` | Generates people: names, sex, age, height, weight, complexion, outfit, `personality_id` 0-29, traits, interests, attractiveness, role, job + hourly wage, home, weekday/weekend schedules, social ties |
| `npc_simulation.gd` | Where all 4,000 are at any game time (walk at real speed, ride long trips) |
| `npc_streamer.gd` | Pools bodies, keeps the nearest 100 loaded, picks LODs |
| `npc_body_mesh.gd` | Builds the body meshes in code (3 LODs per sex, cached in `user://npc_cache`) |
| `npc_body.gd` / `npc_body.gdshader` | One body: skeleton, procedural walk, muscle flex, skin/hair/eyes/clothes |
| `npc_interactable.gd` | Talk actions through Life, lines through Dialogue |
| `npc_manager.gd` | The `NPCs` autoload API |
| `generator/` | The NPC generator tool |

## Heights (cm, 1 mm precision)

| | 90% between | Median | Everyone between |
|---|---|---|---|
| Men | 169.9 to 180.1 | 175.3 | 152.9 to 198.1 |
| Women | 156.5 to 166.1 | 161.3 | 140.8 to 182.7 |

The outer 10% follows a stretched normal tail, so short and tall people exist
without anyone leaving the bounds. Verified on the 4,000: men 89.9%, women 90.0%
(n is not a multiple of 10, so exactly 90% is not possible for men).

## Body detail: what is real and what is not

* Close-up body (LOD0): about 120,000 vertices, roughly 5 mm apart on the body
  and 4 mm on the face. Muscles are modeled as shapes in the surface:
  gastrocnemius (two heads), soleus, Achilles hollows, tibia, patella, vastus
  medialis/lateralis, rectus femoris, hamstrings, glutes, pecs, deltoids,
  biceps, triceps.
* Calf muscles move: blend shapes `calf_flex_L/R` shorten and bulge the
  gastrocnemius and sharpen the Achilles; the walk cycle drives them every frame
  at push-off. Same for `quad_flex` and `glute_flex`.
* 1 mm: heights and proportions are stored to 1 mm, and the skin and fabric
  shader adds 1 mm pore and weave detail up close. Geometry at 1 mm everywhere
  would be millions of triangles per person, which no PC can draw for 100
  people, so it is not done.
* Budget: only the nearest 6 NPCs within 12 m use LOD0; up to 40 m use LOD1
  (7,000 vertices, still flexing); the rest use LOD2 (1,300 vertices).
* Hands: palm, four fingers and a thumb with knuckles and nails, two bones per finger (38 bones total). Fingers curl a little while walking; `body.set_grip(0..1)` closes them into a fist.
* Feet: five toes with nails inside the shoe toe box; `outfit.barefoot = true` (or `body.set_barefoot(true)`) reshapes the foot and shows them.
* Face: eyeballs (iris, pupil, limbal ring) in sockets with upper and lower lids; nose with bridge, tip, alae and nostrils; philtrum, upper and lower lips and mouth line; cheekbones, nasolabial folds, jaw and chin; ears with concha and lobe; brow ridge. The fat shape fills out cheeks and jaw.
* Clothes (`npc_wardrobe.gd` + `npc_garment_fit.gd`): every garment is its own skinned mesh with
  real volume. The body is sliced along the trunk, legs, arms and feet; each slice outline is
  replaced by its convex hull (cloth bridges the chest, the groin and the seat instead of
  following them), cloth hangs from the widest point above it (it can only come back in at a
  limited slope), is smoothed, and gets ease: about 1.5 cm on shirts, 2.5-4.5 cm on jackets,
  1.6-2.2 cm on trouser legs. Skirts and dresses add a tube around both legs that hangs from the
  hips with flare, folds or pleats. The fit is redone for the fat, slim and muscle shapes, so
  clothes follow weight and muscle changes; muscle flex does not show through. Crew and V
  necklines, waistbands, hem bands, jean pockets and belt loops, quilted puffers.
  `npc/tests/test_clothes.gd` checks ease, chest and groin coverage; `npc/tests/render_people.sh`
  renders close-ups (faces, torsos, backs, hands) of six people.
* Ethnicity blend shapes are height-neutral (MakeHuman's targets changed stature by up to 10 cm).
* Not modeled: facial expressions or talking mouth, cloth simulation (cloth is fitted, not simulated).

## API (`NPCs` autoload)

```gdscript
NPCs.population            # Array of record Dictionaries (see npc_population.gd)
NPCs.population_ready      # signal, fires about a second after startup
NPCs.ensure_ready()        # generate now if you need records immediately
NPCs.get_record("npc_0123")   # or an index
NPCs.find_by_name("Marco")
NPCs.residents_of(building_id); NPCs.workers_at(building_id); NPCs.npcs_at(building_id)
NPCs.position_of(id); NPCs.activity_of(id)   # sleep/home/work/class/study/eat/shop/leisure/stroll/commuting
NPCs.personality_of(id)    # 0..29, for the dialogue thread
NPCs.social_ties(id)       # {partner, partner_kind, household, coworkers, classmates, friends}
NPCs.body_of(id); NPCs.loaded_bodies()
NPCs.npc_loaded(index, body) / npc_unloaded(index)   # signals
NPCs.add_npc(record) -> index   # new resident, gets home/job/schedule, saved to user://npc/custom_npcs.json
NPCs.set_npc_status(id, "hurt"|"killed"|"ok")   # crime thread
```

Bodies (`NpcBody`) are in group `"npc"` with `npc_id`, `display_name`, `age`,
`sex`, `traits` ({outgoing, kind, ambitious, wild, lawful}), `interests`,
`attractiveness` (1..10), `personality_id`, `occupation`, `alertness`,
`is_police`, and `react_to_crime(crime_id, crime_class, position, reported)`.
Collision on layers 3 (interact) and 4 (npc).

### Other threads

* Life: the NPC Interactable returns `Life.actions.interactable_actions(body)`
  and calls `Life.actions.perform(id, body)` when Life exists.
* Dialogue: `NpcManagerApi.line_for(body, context)` calls
  `Dialogue.line_for(body, context)` (or `get_line`) if a `Dialogue` autoload
  exists. Each body exposes `personality_id`.
* Player body: `body.apply_record(NpcAppearance.record_from_profile(GameState.player_profile))`
  then `body.apply_life_body(Life.body.visual_params())` on `Life.body.weight_changed`.
  Weight and muscle drive the fat/slim/muscle shapes (face included), grooming
  drives stubble and hairline.

## NPC generator

`res://npc/generator/npc_generator.tscn` (F6 in the editor), or in game
`UI.open_panel(NpcGenerator.new())`. Sex, role, age, a complexion slider,
height in ft + in or cm, weight in lb or kg (switching units converts the
values), muscle, personality, live rotating 3D preview, Randomize, Add to city,
Copy JSON. In code: `NpcPopulation.make_record(rng, {"sex": "female", "height_cm": 170.2, "weight_kg": 61})`.

## Tests

```
GODOT=/path/to/godot4.5 godot/npc/tests/run_tests.sh   # population, simulation, streaming, body
GODOT=... godot/npc/tests/render.sh /tmp/shots         # PNG close-ups (needs xvfb-run)
```

## Body mesh (MakeHuman base, CC0)

NPC bodies now use the MakeHuman 1.x base mesh, default rig weights and macro
targets (all CC0, makehumancommunity/makehuman on GitHub), converted by
`tools/build_mh_body.py` into `models/mh_<sex>.bin/.json`:

- blend shapes: fat, slim, muscle (MakeHuman weight/muscle targets), calf/quad/glute
  flex (walk), and caucasian/african/asian face and body shape (set from ethnicity);
- 38-bone skeleton (MakeHuman bones merged), arms hung down from the A-pose at runtime;
- eyeballs, a hair shell over the scalp, brows, lips, nails and the beard zone as
  vertex regions the shader paints; automatic mesh LODs (`ImporterMesh.generate_lods`).

Skin, hair and clothes are still painted by `npc_body.gdshader` (no texture packs
were reachable from the build machine). The old procedural body in
`npc_body_mesh.gd` is the fallback when `models/` is missing.
Rebuild: `python3 godot/npc/tools/build_mh_body.py --src /tmp/mh` (downloads the data).
