# OFF CAMPUS — Game Design Document

**Working title:** Off Campus
**Genre:** first-person open-world life game, with crime as part of the freedom
**Setting:** Cathedral Mount, home of Old North State University (ONSU), State of Pamlico
**Engine:** Godot 4.7.2, desktop builds for Windows and macOS
**Map:** the existing Cathedral Mount world (705 buildings, every one enterable, 13,102 rooms)
**Business data:** [`BUSINESS-CATALOGUE.md`](BUSINESS-CATALOGUE.md), generated from the map into `data/off-campus/*.json`

---

## 1. Pitch

You arrive in Cathedral Mount with a duffel bag, a little cash and a decision to make: enroll at ONSU, get a job on Hamilton Street, or do neither and live however you want. Every door in town opens. Everyone in town has a home, a job and a schedule. You can build a life, with a degree, a career, friends, a partner and a house on Toadstool Hill. You can also burn it all down. The town remembers what you did, and so do the people in it.

**GTA's freedom, at life scale.** The map is small and dense instead of huge and empty. Every building is a place you can live, work, study or rob.

## 2. Pillars

1. **Every door opens.** All 705 buildings have full interiors. If it's on the map, you can go inside.
2. **The town runs without you.** Shops open and close on their own hours, and NPCs commute, work, go to class and go home. The player joins a running simulation; nothing is staged around them.
3. **Consequences stick.** Crime, relationships, grades and money all feed each other. Getting arrested can cost you your job, your lease, your scholarship and your friends.
4. **First person, always.** You see the world through your own eyes: your hands, your phone, your wallet. There's no third-person camera.
5. **No needs meters.** There's no hunger, bladder or mood bar to babysit. Your life is measured in **money, relationships, housing, education and reputation**, not survival upkeep.

## 3. The player

- Starts at age 18 with $400, a phone and no housing (first night on a friend's couch in Carrburg).
- Has no fixed backstory. Who you are comes from what you do.
- **Stats** (all visible on the phone):

| Stat | What it is | Changes by |
|---|---|---|
| Cash / Bank | money on hand vs. in Bluebird Savings Bank | jobs, crime, rent, purchases |
| Reputation (Town) | how locals see you, −100 to +100 | helping, working, crime witnessed |
| Reputation (Campus) | how students and faculty see you | grades, parties, game days, crime |
| Record | criminal record: none, minor or felony | arrests, convictions |
| Skills | Cooking, Charm, Fitness, Study, Mechanics, Stealth, Art, Trades | doing the thing, classes, jobs |
| GPA | 0.0–4.0, only while enrolled | attending, studying, exams |

Skills rise with use (Skyrim-style), not by spending points.

## 4. Time

- **1 game day = 48 real minutes** (2 real seconds = 1 game minute). Day/night uses the map's lighting presets: golden hour, midday, night, rain.
- **Week:** Monday–Sunday. Classes run Monday to Friday, game days are Saturday, and rent is due on the 1st.
- **Semester = 6 game weeks** (≈ 34 real hours). There are 8 semesters to a degree, with summer break in between.
- **Sleeping** skips time in any bed you have the right to use: your own, a partner's, a paid inn room. Sleeping somewhere you don't belong counts as trespassing if someone finds you.
- The game saves when you sleep and also has manual saves.

## 5. Core loop

```
        ┌───────────── earn money ─────────────┐
        │  (jobs · crime · side gigs)          ▼
  build skills / GPA                    spend money
  (school · work · practice)            (rent · food · clothes · gifts · fines)
        ▲                                      │
        │                                      ▼
  unlock better jobs,  ◄──── relationships ◄── go out
  housing, people           (friends · dates · rivals · roommates)
```

- **Daily:** wake up, go to class or a shift, then the evening is yours (bars, dates, side jobs or crime), then sleep.
- **Weekly:** rent and bills, game day at Benefactor Stadium, parties, paychecks every Friday.
- **Long arc:** move from a dorm or couch to an apartment to a house, from part-time jobs to a career, from stranger to someone the town knows.

## 6. Systems

### 6.1 Money and jobs

- Every job comes from the [catalogue](BUSINESS-CATALOGUE.md): **573 role × location positions** across 241 businesses and 54 places. Wages run from $11/h (usher, server) to $70/h (doctor, which needs a medical degree).
- **Getting hired:** walk in during business hours and ask, or apply on the phone. Some roles have requirements in their `needs` field: age 21+, clean record, enrolled, a course or a degree.
- **Working a shift:** you have to physically show up at the building at shift start. A shift is a short interactive loop per job family (take orders, stock shelves, mix drinks, triage), then time skips to the end of the shift. You can quit any time.
- **Performance:** show up late or skip shifts and you get warnings, then get fired. Do well and you get raises and promotions (barista to shift lead, orderly to nurse with a degree).
- **Side gigs:** delivery (takeout, pizza, florist), tutoring, game-day concessions, busking on Hamilton St, and selling art at galleries (Art skill).
- **Banking:** a Bluebird Savings account keeps money safe from being mugged and from police seizure. Student loans pay tuition but come with monthly payments.
- **Costs:** rent, tuition, food (no hunger meter, but eating with people builds relationships and some jobs feed you), clothes, phone bill, fines and bail.

### 6.2 Housing

All housing comes from `data/off-campus/housing.json`.

| Tier | Where | Count | Cost |
|---|---|---|---|
| Couch / crash | a friend's place (relationship-gated) | — | free, but the friendship wears thin |
| Dorm room | Elder East/West, Hinson/Ehring/Craigmoor towers | 1,193 rooms | free if enrolled (housing fee in tuition) |
| Apartment above a shop | Hamilton Strip, Rosemary Row | 325 units | $950–$1,350/mo |
| House (rent) | Residential North, Carrburg, Cameron Heights | 393 houses | ~$1,150–$2,500/mo by size |
| House (buy) | anywhere, incl. Toadstool Hill (16 houses) | — | ~$200k–$700k, mortgage at the bank |
| Inn room | Pamlico Inn | per night | short-term |

- **Roommates:** share a unit with an NPC friend or a randomly assigned dorm roommate. Rent is split, and roommates have opinions about your behavior.
- **Furnishing:** every room already has `itemSlots: []`, `anchorWalls` and `openings` in `rooms.json`. The **furniture pass uses the existing furniture models**. You buy furniture at retail and hardware stores and place it in slots or along anchor walls. Furniture is cosmetic and also unlocks things at home, like a desk for studying or a bed for sleeping in.
- **Losing housing:** missing rent gets a warning, then late fees, then eviction. An arrest for a felony is grounds for eviction from apartments and dorms.

### 6.3 School (ONSU)

- **Enroll** at Founders' Hall (admissions office). Tuition is $6,000 a semester, or a scholarship if your GPA is high enough.
- **Majors** pick your class buildings and unlock careers:

| Major | Classes in | Unlocks |
|---|---|---|
| Business | Carroll Hall, Gerrard Hall | bank teller to manager, store manager |
| Nursing / Pre-med | Medical Center, Venable Hall | nurse, doctor (+ med school) |
| Sciences | Physics, Chemistry, Data Science buildings | lab assistant, research jobs |
| Art | Hooper Hall, galleries | apprentice tattoo artist, gallery sales |
| Journalism | Carroll Hall | campus paper, side gigs |
| Undeclared | anywhere | flexibility, nothing extra |

- **Classes** happen in real classroom and lecture rooms (the map has hundreds, e.g. Mangum Hall has 40). Attending means being in the room when class starts. Each class meets 2× a week and has a short first-person activity, then time skips.
- **Grades** come from attendance, study time (library, desk at home, tutoring at Cram Fortress) and exams at the end of the semester. Cheating is a crime-lite option with an expulsion risk.
- **Campus life:** clubs, game days, parties at dorms and houses, student elections (satirical posters already exist in the signage pass).
- **Dropping out** is allowed. So is getting expelled.

### 6.4 NPCs

- **Population:** about 1,500 named residents, generated from seed 1795. Every NPC has a **home** (from `housing.json`), a **role** (student, worker, professor, retiree, cop, criminal) and a **schedule**.
- **Schedules are built from the catalogue.** A barista's day is set by the café's `hours` and a `shift`. A student's day follows their class rooms. Everyone sleeps at their home address.
- **Simulation LOD:**
  - **Near (< 60 m):** full NPC, walking, talking, reacting, ~50–150 at once
  - **Mid (60–300 m):** simplified, moves along paths, no animation detail
  - **Far / indoors elsewhere:** schedule-only. Their position is computed from the clock when you arrive, so a shop is always staffed during its hours.
- **Personality:** 5 traits (Outgoing, Kind, Ambitious, Wild, Lawful), a few interests (music, sports, art, gaming, partying) and opinions on things the player does.
- **Memory:** NPCs remember interactions with the player and major events they witness, such as crimes, fights, kindness and public embarrassment.

### 6.5 Relationships

- **Per-NPC values:** Friendship (−100 to 100) and Romance (0 to 100, opt-in, adults only). Plus flags: knows-your-name, roommate, coworker, classmate, ex, enemy.
- **Tiers:** Stranger → Acquaintance → Friend → Close Friend → Best Friend (and Dating → Partner → Engaged → Married). Negative tiers: Dislike → Enemy.
- **Ways to build it:** talk (dialogue choices tuned to their traits), hang out at social hubs (catalogue `socialHub: true`: cafés, bars, the brewpub, the cinema, the 24 h waffle place), give gifts (the florist and record shop matter here), help them (moving day, covering a shift), go to events together.
- **What it unlocks:** couch to crash on, job referrals, roommates, alibis, partners in crime, a wedding at First Pamlico Chapel, moving in together.
- **Drift:** relationships decay slowly if ignored. Partners and best friends expect contact on the phone.
- **Phone:** contacts, texts, calls, invites to things happening in town, a social-media feed of town gossip (your own deeds show up there).

### 6.6 Crime and the law

Crime is a full option, not a punishment trap. It's another way to live, with real tradeoffs.

| Crime | Example | Heat |
|---|---|---|
| Petty | shoplifting, fare-dodging, graffiti, trespassing, public intoxication | ★ |
| Theft | pickpocketing, stealing from unlocked homes and cars, register grabs | ★★ |
| Burglary | breaking into houses and apartments (Toadstool Hill pays best) | ★★★ |
| Assault | fights, mugging | ★★–★★★ |
| Robbery | holding up a store (catalogue `robbery.risk` / `robbery.cash`), the bank vault | ★★★–★★★★★ |

- **Witnesses:** crimes only count if someone sees, hears or records them (NPC eyes, security cameras from the utility clutter pass, alarms). Witnesses can call the police, confront you or film you. Friends may cover for you, based on their Friendship and Lawful trait.
- **Heat (1–5 ★):** the police response scales from one patrol officer to a full lockdown of the district. You lose heat by breaking line of sight, hiding indoors, changing clothes or laying low.
- **Getting caught:** fine, then arrest, then court.
  - Arrest means a night in jail, losing carried cash, and calls home to your contacts.
  - A record blocks "clean record" jobs (bank, security) and can get you evicted.
  - Students face the honor court: probation, then suspension, then expulsion.
  - Reputation drops with everyone who hears about it.
- **Knocked out** (fights, falls): you wake up at the ONSU Medical Center with a bill.
- **Criminal career:** fences on Rosemary Row, a crew of NPC friends with the Wild trait, jobs that need planning (scouting hours, cameras, guard shifts, all from the catalogue). It's a path parallel to school and work, not a replacement for them.

### 6.7 How the systems connect

| If you… | then… |
|---|---|
| get arrested | job may fire you, landlord may evict you, school may suspend you, Lawful friends drop Friendship |
| raise GPA | scholarship covers tuition, better jobs unlock, Campus reputation goes up |
| work at a bar | you meet more people (social hub), get night shifts that clash with morning classes, earn tips |
| date someone | they might move in (rent split), expect your time, can be hurt by your crimes |
| move to Toadstool Hill | higher rent, quiet neighbors who notice everything (more witnesses) |
| become a regular at a café | staff know your name, small discounts, job offers |

## 7. The map as gameplay

| District | Gameplay role |
|---|---|
| **Hamilton Strip** | main street: 97 businesses, most jobs, nightlife, apartments upstairs, highest foot traffic (lots of witnesses) |
| **The Summit** | town center, Top of the Mount rooftop, scramble crosswalk, police presence |
| **Rosemary Row** | 97 businesses, cheapest downtown apartments, parking decks, late-night food, fences and shady contacts |
| **North Quad / Founders' Quad** | classes, admissions, libraries, the Old Cistern as a meeting spot |
| **The Quarry** | Student Union, Dining Hall, Davies Stacks (study), campus jobs |
| **Carillon Hill & South Campus** | dorm towers, Benefactor Stadium (game days), Coach's Dome, rec center (Fitness) |
| **Medical Center** | 4 towers: hospital jobs, respawn point, medical bills |
| **Carrburg** | 47 colorful shops, cheapest houses, Loomhouse Mill co-op, the player's first couch |
| **Cameron Heights** | Pamlico Inn, chapels (weddings), mid-priced houses |
| **Residential North** | 269 houses, family neighborhoods, burglary with moderate risk |
| **Toadstool Hill** | 16 expensive houses, Ghoulgrave Keep, dark and quiet, high burglary payout |
| **Battle Ravine / Grove Amphitheatre** | parties, concerts, hiding spot, shortcuts |

## 8. Out of scope (for now)

- **Mood or needs meters** (cut by design).
- **Driving.** Vehicles are part of the items pass in the map spec. Version 1 is on foot or by bike, and cars come later with the vehicle models.
- **Multiplayer.**
- **Kids or aging past graduation.** The game is centered on the 18–26 years.

## 9. Technical plan

### 9.1 Engine and project

- **Godot 4.7.2**, GDScript for gameplay. C# only if profiling demands it.
- The Godot project lives in `game/` in this repo, next to the Three.js map source.
- **Autoload singletons:** `Clock`, `Economy`, `Jobs`, `Housing`, `School`, `Relationships`, `NPCDirector`, `Law`, `Phone`, `SaveGame`.
- **Data-driven:** businesses, places, housing and rooms load from JSON. Gameplay tuning lives in the catalogue profiles, not in scene files.

### 9.2 Bringing the map into Godot

```
Cathedral Mount (Three.js / TS)  ──npm run export:gltf──►  per-tile + per-landmark .glb
                                 ──npm run data────────►  buildings.json, rooms.json
                                 ──npm run catalogue───►  off-campus/businesses|places|housing.json
                                                              │
                                                              ▼
                                      Godot: import .glb, build collision, place doors,
                                      spawn room Area3Ds from rooms.json, stream tiles
```

- The world streams by the existing 200 × 200 m tile grid (3 × 3 ring around the player) and interiors load within 35 m of a door, as in the map spec.
- Each room becomes an `Area3D` named with its `roomId`, so gameplay knows "player is in CM_HAM_N_000_F0_R2 (bar)".
- Doors from the map become interactable `AnimatableBody3D` hinges with lock states (locked after hours, which matters for burglary).
- The map's TypeScript stays the source of truth. Re-exporting is a command, not hand work.

### 9.3 Furniture pass

- Uses **the existing furniture models**, imported as glTF into `game/assets/furniture/`.
- A placement script fills `itemSlots` per `roomType` (bar → stools and counters, dorm_double → 2 beds and 2 desks, and so on) using `anchorWalls` and `openings` to keep doorways clear.
- Player-owned rooms use the same slots for player decorating.

### 9.4 Cloud workflow (Claude in the cloud)

| Where | What happens |
|---|---|
| **Cloud session (Claude)** | edits GDScript, scenes and JSON; runs `godot --headless` for import checks and unit tests (GUT); regenerates catalogue/export data; commits and pushes |
| **GitHub Actions** | builds Windows `.exe` and macOS `.app` on every push to the dev branch, using Godot export templates |
| **Your computer** | download the build and play-test; optionally open the project in the Godot editor to look around or tweak visuals |

Godot 4.7.2 is installed in the cloud container (`godot --headless`). Cloud containers are reset between sessions, so a setup script should reinstall it automatically. Pushing to GitHub has to work so the work survives between sessions.

## 10. Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | **Port** | Godot project in `game/`; one tile of Hamilton Strip imported with collision; first-person walk; doors open |
| M1 | **Living street** | clock + day/night; businesses open and close by catalogue hours; 50 NPCs on schedules |
| M2 | **Money** | get hired, work shifts, get paid, bank account, buy things |
| M3 | **Housing** | rent an apartment, pay rent, sleep/save, eviction; furniture pass v1 |
| M4 | **Relationships** | talk, befriend, date, roommates, phone texts |
| M5 | **School** | enroll, attend classes, GPA, semesters, majors unlock jobs |
| M6 | **Crime and law** | witnesses, heat, police, arrest, record, consequences across all systems |
| M7 | **Whole town** | all tiles streaming, full NPC population, performance pass |
| M8 | **Polish and ship** | audio, UI, tutorials, save robustness, signed Windows/Mac builds |

## 11. Open questions

1. **Start:** always "arrive in town at 18", or let the player pick a background (local, freshman, transfer)?
2. **Romance:** in scope for version 1, or added later?
3. **Violence ceiling:** fists and improvised weapons only, or firearms like GTA? This decision shapes police, the age rating and tone.
4. **Failure state:** can a life "end" (prison sentence, leaving town), or is it always recoverable?
5. **Tone:** grounded drama, or GTA-style satire? The map's signage is already satirical.
6. **Furniture models:** what format are they in, and where do they live? The plan assumes glTF in `game/assets/furniture/`.
