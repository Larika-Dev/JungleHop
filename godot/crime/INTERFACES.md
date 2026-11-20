# Crime: interfaces for other systems

`godot/crime/` owns crimes, witnesses, the wanted level, police response, arrests, jail and the
criminal record. One autoload:

```
[autoload]
Law="*res://crime/law.gd"
```

Put the line after `Life=` so Law finds the life core when it hooks up (it also hooks up deferred,
so the order is forgiving). Godot 4.5, GDScript, no addons. Tests run headless:

```
godot --headless --path godot --script res://crime/tests/run_tests.gd
```

## The 39 crimes

`crime_catalog.gd` holds every crime as data. Each has a class (infraction, misdemeanor, felony),
wanted stars, a fine, jail hours, how noticeable it is, a witness radius and what it targets.

| Class | Crimes |
|---|---|
| Infraction (ticket only) | jaywalking, littering, public urination, noise disturbance, fare evasion, speeding, running a red light |
| Misdemeanor | public intoxication, trespassing, indecent exposure, harassment, graffiti, vandalism, breaking and entering, shoplifting, dine and dash, pickpocketing, bike theft, fake ID, buying drugs, simple assault, resisting arrest, evading police, reckless driving, drunk driving |
| Felony | arson, car theft, burglary, mugging, armed robbery, bank robbery, check fraud, embezzlement, drug dealing, aggravated assault, murder, bribing an officer, assault on an officer, hit and run |

32 of them are player actions (`menu: true`); the 7 others (traffic, resisting, evading) are raised
by game systems through `Law.commit(id, ctx)`.

## What happens when you commit one

1. **Success roll** for crimes with a `chance` (pickpocketing, burglary...), +3% per level of the
   crime's skill (`stealth`, `charm`, `mechanics`...). A stealthy crime that works is not noticed by
   the victim. Skill XP is given either way.
2. **Witnesses.** Law scans nodes in groups `npc`, `police` and `security_camera` within the crime's
   radius, raycasts line of sight on collision layer 1, and rolls whether each one notices
   (closer, more alert and daytime = more likely). Each civilian who saw it may call the police:
   felonies 85%, misdemeanors 45%, scaled up by the NPC's `lawful` trait and down by their
   friendship with the player (friends cover for you). Police and cameras always report.
3. **Relationships.** Every witness with an id gets `Life.relationships.change(...)`,
   `remember(id, "saw_you_<crime>", weight)` and the flag `witnessed_crime`. Victims get
   `victim_of_<crime>`, `crime_victim`, and `enemy` when friendship drops 60 or more. Wild NPCs shrug
   off tickets and may like you more for them.
4. **Law.** Infractions only cost a ticket, and only if police saw it. Anything else that is reported
   adds a charge and raises the wanted level to the crime's stars (a second crime while wanted adds
   one more star, max 5). If the player was identified (a camera, a cop, the victim, or anyone who
   has met them) the charges become a warrant if they escape.
5. **Loot** goes through `Life.money.add(amount, "Stolen: ...")`.

## Wanted level and police

| Stars | Units | Response | First unit arrives | Unseen time to drop a star |
|---|---|---|---|---|
| 1 | 1 | patrol | 8 game min | 20 game min |
| 2 | 2 | patrol | 6 | 30 |
| 3 | 4 | patrol_roadblock | 4 | 45 |
| 4 | 6 | armed | 3 | 60 |
| 5 | 10 | swat_helicopter | 2 | 90 |

(1 game minute = 1 real second.) States go `responding` then `searching` then `pursuit`.
Hiding (`crime_hide` action) and being indoors make the player much harder to spot; athletics,
fitness and stealth help get away. Losing a pursuit adds an `evading_police` charge.

**Real officers.** When the NPC system has officer nodes (group `police`, or `is_police = true`),
Law stops rolling dice for sightings and lets them drive it:

```gdscript
Law.police_dispatched.connect(func(stars, units, kind, pos, eta): ...)  # spawn/move officers
Law.police_saw_player(self)     # an officer has eyes on the player (also triggers warrants)
Law.police_lost_player(self)
Law.police_contact(self)        # officer reached the player: arrest
```

Without officer nodes the response is simulated so crime works from day one.

## Arrest, fines and jail

On arrest every charge (plus any warrant and unpaid tickets) is convicted. Fines are paid with
`Life.money.spend`; whatever can't be paid turns into jail at $50 per hour. The booking screen offers:

- **Serve the sentence**: sets `crime.in_jail`, skips the clock with `Life.clock.advance_minutes`
  (so needs, bills and pay keep running), then releases. Max 90 in-game days.
- **Post bail** at $20 per sentence hour, for sentences up to 30 days with no 4+ star crime.

Turning yourself in (`Law.surrender()` or the `crime_surrender` action) takes a quarter off.
`Law.resist_arrest()` may break free for a `resisting_arrest` charge and one more star.
If nobody picks within 30 game minutes the sentence is served.

## Criminal record (jobs, education)

```gdscript
var check := Law.job_check("standard")   # {ok: bool, reason: String}
```

| Tier | Use for | Blocks |
|---|---|---|
| `none` | gigs, day labour | nothing |
| `basic` | retail, food service | violent felony ever, any felony in the last 30 days |
| `standard` | office, trades, campus jobs | any felony, theft or fraud in the last 14 days |
| `trusted` | bank, school, hospital, childcare, police | any felony, any active misdemeanor, any past theft, fraud or violence |

Any tier above `none` also fails while there is a warrant or the player is in custody. Tickets drop
off after 7 game days, misdemeanors after 30 clean days, felonies never. Listen to
`Law.convicted(entry)` if a job should fire the player on a conviction.

Flags Law publishes through `Life.set_flag`:

| Flag | Value |
|---|---|
| `crime.wanted` | 0 to 5 |
| `crime.record` | `{infractions, misdemeanors, felonies, clean, violent, theft, fraud, last_day}` |
| `crime.has_felony` | bool |
| `crime.warrant` | bool |
| `crime.in_jail` / `crime.booked` | bool; Life blocks most actions while in jail |
| `crime.unpaid_fines` | dollars |

Flags Law reads: `job.on_shift` (needed for embezzlement; the jobs system sets it during a shift).

## Life actions registered

Every menu crime as `crime_<id>` (category `crime`, target self/npc/furniture/place, place tags for
shops, banks, bars, homes), plus `crime_hide`, `crime_surrender` and `crime_pay_fines`. Custom checks:
police-only crimes need an officer target, bribery needs you to be wanted.

## NPC hooks (optional)

- `npc.react_to_crime(crime_id, crime_class, position, reported: bool)` is called on every NPC who saw
  it, for fleeing, phoning or cowering animations.
- `npc.alertness` (0..1) lowers how much a busy or sleeping NPC notices.
- `Law.npc_harmed(npc_id, "hurt" | "killed", crime_id)` for injuries and deaths.

## Driving hooks

```gdscript
Law.commit("speeding", {"position": car.global_position})
Law.commit("hit_and_run", {"position": pos, "victim_id": npc.npc_id})
```

## Saving

Registered with `Life.register_save_provider("crime", Law)` (`to_save` / `from_save`), or
`GameState.register_saveable("crime", Law)` when there is no Life.
