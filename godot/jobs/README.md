# Jobs (`godot/jobs/`)

17 roles hired by 231 named companies in Cathedral Mount's real buildings. Each role is its own mini-game, either
**hands-on** (you physically move things on a close-up 3D workstation) or **PC work**
(you type into the work computer). Pay is **by the in-game hour** (1 game hour = 1 real
minute), with tips at the cafe, bar, barber, tattoo studio and delivery counter.

Autoload: `JobSystem="*res://jobs/job_system.gd"` (the one line this folder adds to `project.godot`).

## How a job works in game

1. Walk into the workplace and look at the **STAFF terminal** (a 120 cm kiosk in the main
   ground-floor room). Hold E for the menu: **Apply**, **Clock in**, **Ask for a promotion**,
   **Ask for a raise**, **Switch shift**, **Quit**, **Job info**.
2. Applying takes 20 game minutes. You start at the highest rank your education allows
   (a nursing grad starts as a Registered Nurse; nobody starts above a rank that needs experience).
3. You can clock in from 30 minutes before your shift until 30 minutes before it ends.
   Arriving more than 10 minutes late is noted on your review.
4. The mini-game opens full screen. Each task (a drink, a check, a patient) is a round
   scored 0-100%. Pay keeps ticking every game minute whatever your score; scores feed
   your review, tips and promotions. Needs (from Life) scale scores via `performance_multiplier()`.
5. Clock out with Esc or the button, or the shift ends you automatically. Partial hours pay pro rata.
6. Miss a shift (no clock-in within 2 hours of the start) and you get a strike.
   3 strikes in 14 days and you're fired.
7. Promotion: enough hours at your rank, a high enough review average, and the
   education/skill the next rank lists. Raise: +5% (max +20%) once a week with a 75%+ review.
8. Up to 2 jobs at once if the shifts don't clash.

## Companies

You don't work for "the bank" or "a cafe": every business on the map is a named employer,
generated from `data/buildings.json` by `tools/generate_companies.py` (seed 1795) into
`data/companies.json`. **231 companies, 333 job openings.**

- **Independents**: every storefront (Pamlico Coffee House, Hilltop Hardware, Pitch Soles Tattoo...)
  hires for the roles that fit its trade.
- **Local chains** own several storefronts and hire at every branch: Red Clay Roasters (4 shops), Golden Wok Group (4 shops), Ridgeline Apparel (3 shops), Summit Taco Co. (3 shops), Hamilton Street Pizza Group (3 shops), Night Owl Hospitality (3 shops), Twin Pines Salons (3 shops), Copper Saddle Delis (2 shops), Hilltop Bakeries (2 shops).
- **Institutions**: Old North State University (teaching in the academic halls, library staff,
  custodians in the union and residence halls, IT in Davies Stacks and the labs), ONSU Health
  (ER nursing in Tower D, lab in Tower A, custodians in B and C), ONSU Athletics, Pamlico Inn &
  Tavern, Loomhouse Co-op Market, Cathedral Mount Parking Authority, and two office firms in the
  Hamilton Street towers.

Each company has a manager, owner, founding year, staff count, star rating and tagline, plus
things that change the job:

| Field | Effect |
|---|---|
| `pay_scale` | every rank's wage × 0.94-1.15 (rounded to $0.25) |
| `standards` | higher review needed for promotions there |
| `experience_required` | hours in that role (from any employer) needed to get hired |
| `perks` | `free_meal` (+35 hunger after a 3 h+ shift), `tip_pool` (+30% tips), `signing_bonus` ($150 once), `flex_shifts` (clock in 60 min early, 20 min grace), `paid_breaks` (less tiring), `health_plan` and `staff_discount` (Life flags `job.health_plan`, `job.discount.<company>`) |

**Experience follows you.** Hours and your review average are kept per role across companies,
so a barista who moves cafes keeps their record, and half of it counts toward the starting rank
at the new place. The cash register stocks what the shop sells (17 catalogs: hardware, clothing,
groceries, stadium concessions...).

Industries: Bakery 9, Banking 1, Bar 18, Books 6, Brewpub 1, Cinema 1, Clothing 23, Coffee 23, Deli 10, Dental 1, Diner 2, Florist 9, Gallery & Print 16, Grocery 1, Hardware 1, Hospital 1, Hotel 1, Office 2, Optician 9, Parking 1, Pizza 9, Records 1, Retail 24, Salon 13, Sports & Events 1, Tacos 14, Takeout 30, Tattoo 1, Tutoring 1, University 1.

## Roles

| Role | Hired by | Mini-game | Base ranks and hourly wage | Education used | Background check |
|---|---|---|---|---|---|
| Barista | 34 companies, e.g. Red Clay Roasters, Hilltop Bakeries | Hands-on: Grab the right cup and walk it through the espresso machine, steamer and syrup pumps exactly as the ticket says. | Barista Trainee $12.50 → Barista $14.50 → Shift Lead $17.50 → Cafe Manager $22.00 | cert_barista, cert_food_safety | basic |
| Bartender | 20 companies, e.g. Night Owl Hospitality, The Night Owl Tavern | Hands-on: Lift each bottle over the glass to pour, stop at the line, then slide the drink to the customer. | Barback $11.00 → Bartender $13.00 → Head Bartender $18.00 | cert_food_safety | basic |
| Pizza Cook | 10 companies, e.g. Hamilton Street Pizza Group, Top of the Mount | Hands-on: Slide raw pies into the deck oven with the peel and pull each one out golden, before it burns. | Prep Cook $13.00 → Line Cook $15.50 → Kitchen Manager $20.00 | cert_food_safety | basic |
| Cashier | 158 companies, e.g. Golden Wok Group, Ridgeline Apparel | PC: Key in each item's code on the register, then type the exact change due. | Cashier $12.75 → Senior Cashier $14.25 → Assistant Manager $19.00 → Store Manager $24.00 | ba_business, cert_bookkeeping, mba | basic |
| Bookseller | 6 companies, e.g. Tarry Page Books, Pine Cone Book Nook | Hands-on: Carry each book off the cart and set it on the right section of the shelf. | Stock Clerk $12.25 → Bookseller $14.00 → Head Buyer $18.00 | ba_english, ba_history | basic |
| Bank Teller | Bluebird Savings Bank | PC: Type each check's account number and amount into the teller system, then approve it or flag it as fraud. | Teller $16.00 → Senior Teller $18.50 → Personal Banker $24.00 → Branch Manager $34.00 | ba_business, cert_bookkeeping, mba | trusted |
| Emergency Nursing | ONSU Health | PC: Chart each arrival's vitals from the monitor into the EHR and enter the right triage level. | Patient Transporter $14.00 → Nursing Assistant $17.00 → Registered Nurse $36.00 → Charge Nurse $44.00 | bs_nursing, cert_cpr | trusted |
| Lab Technician | ONSU Health | Hands-on: Load sample tubes into the centrifuge rotor so it is perfectly balanced, then spin. | Lab Aide $15.00 → Phlebotomist $19.50 → Lab Technologist $30.00 → Lab Supervisor $38.00 | bs_biology, bs_chemistry, cert_phlebotomy | trusted |
| Library Staff | Old North State University | PC: Scan returns by typing the barcode, then key in the stack location from the call number. | Library Page $11.50 → Library Assistant $15.00 → Librarian $26.00 → Head Librarian $33.00 | degree:bachelor, degree:master | standard |
| Custodian | 8 companies, e.g. Old North State University, ONSU Health | Hands-on: Push the mop over spills across the Union floor before they spread. | Custodian $13.50 → Lead Custodian $15.50 → Facilities Supervisor $21.00 | aa_general | standard |
| Cinema Crew | Junior Varsity Cinema | PC: Type the film code, showtime, ticket count and total into the box office terminal. | Usher $11.25 → Projectionist $14.50 → Theater Manager $19.00 | - | basic |
| Tattoo Artist | Pitch Soles Tattoo | Hands-on: Guide the needle along the stencil line. Stray from it and the client notices. | Shop Apprentice $10.00 → Tattoo Artist $22.00 → Lead Artist $32.00 | - | none |
| Hair Stylist | 13 companies, e.g. Twin Pines Salons, The Twin Pines Thimble Salon | Hands-on: Run the clippers over the sides and back for a clean fade, and keep them off the top. | Shampoo Assistant $11.00 → Stylist $17.00 → Master Stylist $24.00 | - | basic |
| Front Desk | Pamlico Inn & Tavern | PC: Book each guest into a vacant room that fits their request and type the stay total. | Front Desk Agent $14.00 → Night Auditor $16.50 → Front Office Manager $23.00 | ba_business, cert_bookkeeping, mba | standard |
| Teaching | Cram Fortress Tutoring, Old North State University | PC: Compare each student's answers to the key and type the score and letter grade. | Grader $13.00 → Teaching Assistant $18.00 → Lecturer $32.00 | degree:bachelor, degree:master | trusted |
| Delivery Rider | 72 companies, e.g. Golden Wok Group, Summit Taco Co. | Hands-on: Ride the scooter through the blocks and hit every drop-off before the food gets cold. | Delivery Rider $12.00 → Dispatcher $15.50 → Shift Manager $18.50 | - | basic |
| IT Support | 3 companies, e.g. Old North State University, Piedmont Analytics | PC: Read each ticket and type the right command from the runbook into the admin console. | Help Desk Tech $17.00 → Systems Administrator $28.00 → IT Manager $40.00 | bs_computer_science, cert_it_support, ms_computer_science | standard |

Base wages are scaled by each company's `pay_scale`. Screenshots of every mini-game and the job board: `screenshots/godot-jobs/`.

## Files

| Path | What |
|---|---|
| `job_system.gd` | autoload: hiring, shifts, pay, reviews, promotions, raises, strikes, save/load, Life actions |
| `data/roles.json` | the 17 roles: mini-game, shifts, ranks, base wages, requirements, tips, background-check tier |
| `data/companies.json` | the employers (generated; edit by hand or rerun `tools/generate_companies.py`) |
| `minigames/job_minigame.gd` | base class (`JobMinigame`): header with wage/earned/review, round loop, clock out |
| `minigames/physical_minigame.gd` | `PhysicalMinigame`: 3D workstation in its own SubViewport, mouse pick-up/carry/drop, zones |
| `minigames/pc_minigame.gd` | `PCMinigame`: monitor + work app, typed fields checked per field with a speed factor |
| `minigames/physical/*.gd`, `minigames/pc/*.gd` | the 17 mini-games |
| `scenes/*.tscn` | one scene per mini-game (what `UI.show_minigame` opens) |
| `world/job_sites.gd`, `world/job_site.gd` | staff terminals placed from `CityData` rooms when `GameState.world_ready` fires |
| `ui/job_board.gd` | job listings panel |
| `tests/run_tests.gd` | headless tests |

## Contract with other systems

All optional; JobSystem looks each one up at runtime and runs alone without them.

| System | Calls |
|---|---|
| `GameClock` | reads `total_minutes`, listens to `minute_passed` (Day 1 = Monday) |
| `Life` | `money.start_paid_session / end_paid_session` (pay), `pay_credited`, `add_money` (tips), `needs.performance_multiplier()`, `apply_need_delta("energy"/"fun")` after a shift, `skills.add_xp`, `set_flag` (`job.employed`, `job.on_shift` bool, `job.on_shift_id`, `job.primary`, `job.ids`, `job.<id>`), `actions.register` (10 actions in category `work`), `register_save_provider("jobs")` when GameState is absent |
| `Education` | `has_credential(id)`, `has_tag("degree:bachelor")`, signal `credential_earned` (tells you a promotion opened up) |
| `Law` | `job_check(tier)` before hiring; `convicted` fires you from "trusted" jobs |
| `UI` | `show_minigame`, `close_panel`, `open_panel`, `notify` |
| `GameState` | `register_saveable("jobs")`, `world_ready` (spawns terminals) |
| `CityData` | `rooms_for_building`, `building_transform` for terminal placement |

Signals other systems can use: `hired`, `quit_job`, `fired`, `promoted`, `shift_started`,
`shift_ended(job_id, summary)`, `paid`, `round_scored`, `strike_added`, `notice`.

Adding a role: add an entry to `data/roles.json`, list it in companies' `roles`, write a script extending `PhysicalMinigame`
or `PCMinigame` with `_setup`, `_new_round` (call `finish_round(score)` when a task ends) and
`simulate_round(perfect)` for the tests, and add a `scenes/<minigame>.tscn`.

## Tests

```
godot --headless --path godot --script res://jobs/tests/run_tests.gd
```

Checks every role, company and building id, chains, pay scaling, experience carry-over, perks, hiring rules, education gates, the hourly
pay maths (with and without Life), auto clock-out, promotions, raises, save/load, firing
after no-shows, that every mini-game scores perfect play at 100% and bad play low, and that
each staff terminal stands inside its building. With the foundation and life branches
together: 753 checks, 0 failures.
