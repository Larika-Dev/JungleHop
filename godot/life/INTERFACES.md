# Life core: interfaces for other systems

This folder (`godot/life/`) is the shared life core of the Godot game: the
clock adapter, needs, skills, money (with hourly pay), relationships, and the
data-driven action system. Jobs, education, crime, furniture and NPCs plug into
it. Everything is reached through one autoload:

```
[autoload]
Life="*res://life/life.gd"
```

Godot 4.5, GDScript, no addons. Nothing here assumes a particular scene; the
core runs headless (see `tests/run_tests.gd`).

## Quick map

| Object | What it owns | Main calls | Signals |
|---|---|---|---|
| `Life.clock` | game time (1 game hour = 1 real minute) | `total_minutes`, `hour()`, `minute_of_day()`, `day()`, `weekday()`, `advance_minutes(n)`, `time_string()` | `minute_passed(total)`, `hour_passed(hour, day)`, `day_passed(day)` |
| `Life.needs` | hunger, energy, hygiene, fun, social, bladder (0 to 100, 100 = satisfied) | `get_value(n)`, `change(n, d)`, `set_value(n, v)`, `mood()`, `performance_multiplier()`, `enabled` | `need_changed(n, v)`, `need_critical(n)` |
| `Life.skills` | skills with XP and levels 0 to 10 | `level(id)`, `add_xp(id, xp)`, `xp(id)` | `skill_leveled(id, level)` |
| `Life.money` | cash, bank, hourly pay sessions, recurring bills | `add(amount, reason)`, `spend(amount, reason) -> bool`, `can_afford(a)`, `deposit(a)`, `withdraw(a)`, `start_paid_session(...)`, `end_paid_session(id)`, `add_bill(...)` | `money_changed(cash, bank, delta, reason)`, `pay_credited(session_id, amount)`, `paid_session_ended(session_id, total, minutes)` |
| `Life.relationships` | per-NPC friendship, romance, flags, memory | `register_npc(id, info)`, `get_rel(id)`, `change(id, friendship, romance, reason)`, `tier(id)`, `romance_tier(id)`, `add_flag(id, f)`, `has_flag(id, f)` | `relationship_changed(id, friendship, romance)`, `tier_changed(id, old, new)` |
| `Life.actions` | action registry and runner | `register(def)`, `register_many(defs)`, `set_handler(id, callable)`, `set_check(id, callable)`, `available_for(target)`, `perform(id, target)`, `cancel()`, `busy()` | `action_started(id, target)`, `action_finished(id, target, result)`, `action_failed(id, target, reason)` |
| `Life` | player flags, current place, save/load | `set_flag(k, v)`, `get_flag(k, default)`, `set_place(place)`, `place`, `register_save_provider(key, obj)`, `save_game(path)`, `load_game(path)` | `flag_changed(k, v)`, `place_changed(place)` |

## Clock

`Life.clock` uses an external clock when the Godot port provides one. On every
frame it looks for an autoload at `/root/Clock`, `/root/GameClock` or
`/root/TimeManager` and reads, in order of preference, `total_minutes`,
`get_total_minutes()`, or `day`, `hour`, `minute`. If none is found it runs its
own: 1 real second = 1 game minute, so 1 game hour = 1 real minute. Either way
it emits its own `minute_passed`, `hour_passed` and `day_passed`, so systems
only listen to `Life.clock`.

`advance_minutes(n)` skips time (sleeping, waiting). With an external clock it
calls `advance_minutes(n)` or `skip_minutes(n)` on it if present. Skipped time
still fires every `minute_passed` and `hour_passed`, so pay and needs stay
correct.

## Money and hourly pay (for jobs, tutoring, gigs)

```gdscript
# Clock in: pays $15.50 per in-game hour, credited at each hour boundary.
Life.money.start_paid_session("job:barista@HAM_N_004", 15.50, {"reason": "Barista shift"})
# Mini-game performance scales pay from now on (1.0 = base wage).
Life.money.set_session_multiplier("job:barista@HAM_N_004", 1.2)
# Clock out: credits the partial hour pro rata and returns the session total.
var total: float = Life.money.end_paid_session("job:barista@HAM_N_004")
```

- Pay accrues per in-game minute at `hourly_rate * multiplier` and is credited
  to cash on each in-game hour (`pay_credited`), then the remainder on end.
- Options: `reason` (ledger text), `to_bank` (bool, pay into the bank instead of
  cash), `max_minutes` (auto-ends the session), `tips_rate` (extra per hour).
- `Life.money.add_bill(id, amount, every_days, reason)` charges the bank (then
  cash) every N game days, e.g. rent or tuition installments. Missed payments
  emit `bill_missed(id, amount)` and add to `Life.money.debt`.
- `Life.money.ledger` keeps the last 200 transactions `{t, delta, reason}`.

## Needs

Six needs, 0 to 100, where 100 is fully satisfied. They decay every game minute
at the rates in `data/needs.json`. `Life.needs.performance_multiplier()`
returns 0.6 to 1.1 from overall mood, for job and class mini-games to scale
scores or pay. When energy hits 0 the player passes out (`need_critical`) and
the core skips 6 hours. `Life.needs.enabled = false` freezes all needs (for a
"no needs" setting).

## Skills

`charm, fitness, cooking, logic, creativity, music, mechanics, athletics,
stealth, writing, gaming, knowledge`. Levels 0 to 10; `add_xp(id, xp)` with
100 XP per level, rising 15% per level. Other systems may add skills by calling
`add_xp` with a new id.

## Relationships

- `register_npc(npc_id: String, info: Dictionary)` where info can hold `name`,
  `sex`, `age`, `traits` (`{"outgoing": 0..1, "kind": 0..1, "ambitious":
  0..1, "wild": 0..1, "lawful": 0..1}`) and `interests` (array of strings).
  NPC nodes in group `npc` with an `npc_id` property are registered
  automatically; properties `display_name`, `traits`, `interests`, `age`,
  `sex` are read if present.
- Values: friendship -100 to 100, romance 0 to 100. Records are sparse, so
  4,000 NPCs cost nothing until the player meets them.
- Friendship tiers: `enemy` (<= -60), `dislike` (<= -20), `stranger`
  (never met), `acquaintance` (met), `friend` (>= 30), `close_friend`
  (>= 60), `best_friend` (>= 85).
- Romance tiers: `none`, `crush` (>= 20), `dating` (flag), `partner` (flag),
  `engaged` (flag), `married` (flag). Romance actions need age 18+.
- Flags (free-form strings): `met`, `dating`, `partner`, `engaged`, `married`,
  `ex`, `roommate`, `coworker`, `classmate`, `enemy`, `owes_favor`. Jobs,
  education and crime threads may add their own (for example `witnessed_crime`).
- `remember(npc_id, event: String, weight: float)` stores a memory; crime can use
  it for witnesses. `memories(npc_id)` reads them.
- Friendship drifts 1 point a day toward 0 after 3 days without contact,
  except `best_friend`, partner and married which drift slower.

## Actions

Every player action is a dictionary. 100+ ship in `data/actions/*.json`; other
systems add theirs at runtime with `Life.actions.register(def)` or drop a JSON
file into `res://life/data/actions/` (all files there load at start).

```jsonc
{
  "id": "chat",                 // unique
  "name": "Chat",
  "category": "social",         // social, romance, self, food, hygiene, rest, fun, fitness, skill, home, shopping, money, work, school, crime ...
  "target": "npc",              // self | npc | furniture | place
  "furniture": ["sofa", "sit"], // target=furniture: matches furniture action ids or furniture_kind
  "place": ["cafe", "drink"],   // target=place, or extra requirement: Life.place.category/tags must match one
  "minutes": 10,                // game minutes it takes (0 = instant)
  "time_skip": false,           // true: skip the clock instead of waiting in real time (sleep)
  "cost": 0,                    // money spent up front
  "earn": 0,                    // money gained on success
  "needs": {"social": 12, "fun": 4},
  "skills": {"charm": 6},       // XP
  "rel": {"friendship": 3, "romance": 0},
  "chance": 0.85,               // success chance; omitted = always succeeds
  "chance_skill": "charm",      // +3% per level
  "fail": {"rel": {"friendship": -3}, "needs": {"social": -5}},
  "requires": {
    "met": true, "min_tier": "friend", "max_tier": "close_friend",
    "min_friendship": 30, "min_romance": 20, "rel_flags": ["dating"], "not_rel_flags": ["married"],
    "adult": true, "cash": 20, "needs_min": {"energy": 10}, "skills": {"charm": 2},
    "hours": [8, 22], "flags": ["enrolled"], "not_flags": ["in_jail"]
  },
  "sets_rel_flags": ["dating"], "clears_rel_flags": [],
  "sets_flags": {"has_gym_pass": true},
  "cooldown_minutes": 60,       // per target
  "message": "You chat with {npc} about the game."
}
```

Runtime hooks that JSON can't express:

```gdscript
# Extra gate: return "" when allowed, or a reason string to block.
Life.actions.set_check("pickpocket", func(def, target): return "" if not Law.wanted() else "Too hot right now")
# Custom outcome: receives (def, target, result) after the built-in effects; may edit result.
Life.actions.set_handler("pickpocket", func(def, target, result): result.earn += randi_range(5, 40); return result)
```

Running an action:

```gdscript
var options := Life.actions.available_for(npc_node)    # [{def, ok, reason}], for menus
var res := Life.actions.perform("chat", npc_node)       # starts it; returns {ok, reason}
# action_finished(id, target, result) fires when its minutes have passed.
# result = {ok, success, message, money, needs, skills, rel}
```

`target` may be `null` (self), an NPC node (group `npc`, property `npc_id`),
a furniture node (group `furniture`), a place dictionary, or an NPC id string.

### Furniture contract (agreed with the furniture thread)

Furniture nodes join group `furniture`, have `get_actions() -> Array[Dictionary]`
(`{id, label, verb, duration_game_minutes, needs_effects}`), `perform(id, actor)`,
optional `furniture_kind: String`, and emit
`action_finished(action_id, actor, furniture)`. Life connects to every furniture
node it sees. When the actor is in group `player`, Life applies the life effects
of the action with the same id (falling back to the furniture's
`needs_effects`). `Life.actions.available_for(furniture)` merges the furniture's
own actions with the life actions whose `furniture` list matches.

## Player flags and place

`Life.set_flag("enrolled", true)`, `Life.get_flag("employer", "")`. Flags are
saved. Use a prefix for your system's flags: `job.`, `edu.`, `crime.`.

`Life.set_place({"id": "HAM_N_004", "category": "food", "type": "cafe", "tags": ["cafe", "social_hub"]})`
is called by whoever knows where the player is (the port's room `Area3D`s).
Use the catalogue's `category` and `type` from `data/off-campus/businesses.json`.

## Save and load

`Life.register_save_provider("jobs", my_jobs_node)` where the object has
`to_save() -> Dictionary` and `from_save(d: Dictionary)`. `Life.save_game()`
writes `user://life_save.json` with every provider plus the core.

## UI shipped here

- `ui/action_menu.gd` (Control): call `open_for(target)`; lists actions with
  disabled reasons, runs the picked one.
- `ui/life_hud.gd` (CanvasLayer): clock, cash, bank, needs bars, current
  activity, toast messages.
- `ui/relationships_panel.gd` (Control): people you know, tiers, flags.
- `demo/life_demo.tscn`: a playable test scene with fake NPCs and furniture.
