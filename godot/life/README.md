# Life core (Godot)

Shared life systems for Cathedral Mount: game time, basic needs, skills, money
with hourly pay, relationships with NPCs, and a data-driven action system with
**189 player actions**. Jobs (`godot/jobs/`), education (`godot/education/`)
and crime plug into it. The full API is in [INTERFACES.md](INTERFACES.md).

## Hook it up

Add one line under `[autoload]` in `godot/project.godot`:

```
Life="*res://life/life.gd"
```

Export presets must include `*.json` in "non-resource files to export" so
`res://life/data/**` ships in the `.exe`.

## What's here

| Path | What |
|---|---|
| `life.gd` | the `Life` autoload: wires everything, flags, place tracking, save/load, foundation hooks |
| `core/life_clock.gd` | follows `GameClock` (1 game hour = 1 real minute) or runs its own |
| `core/life_needs.gd` | hunger, energy, hygiene, fun, social, bladder; mood; performance multiplier |
| `core/life_skills.gd` | 12 skills, levels 0 to 10, XP from doing things |
| `core/life_money.gd` | cash, bank, debt, ledger, hourly pay sessions, recurring bills |
| `core/life_relationships.gd` | friendship and romance per NPC, tiers, flags, memories, drift |
| `core/life_actions.gd` | action registry, requirement checks, success rolls, timed and time-skip actions |
| `data/actions/*.json` | the action catalogue (edit or add files, no code needed) |
| `data/needs.json` | need decay rates and starting values |
| `ui/action_menu.gd` | grouped action menu with greyed-out reasons and search |
| `ui/life_hud.gd` | needs bars, cash/bank, current action with Stop, toasts |
| `ui/relationships_panel.gd` | people you know |
| `demo/life_demo.tscn` | playable test bench with stand-in NPCs, furniture and places |
| `tests/run_tests.gd` | headless tests |

## How the pieces behave

- **Time.** Most actions take game minutes, which pass in real time (a 10
  minute chat is 10 real seconds). Sleep and naps skip the clock instead.
  Needs that an action restores don't decay while it runs. Stop early and you
  keep a share of the effect once at least a quarter is done.
- **Needs.** 0 to 100, decaying per game hour (energy lasts about 20 game
  hours). At 0 energy you pass out for 6 hours. `Life.needs.enabled = false`
  turns them off for a "no needs" setting.
- **Money.** You start with $400 cash. Pay sessions accrue every game minute
  and credit on the hour. Bills hit the bank first, missed bills become debt.
- **Relationships.** Stranger, acquaintance, friend (30), close friend (60),
  best friend (85); negative tiers dislike and enemy. Romance is adults only
  and needs friendship first; dating, partner, engaged and married are flags.
  Social success depends on Charm, the relationship tier, the NPC's traits
  (`likes`) and shared interests (`topic`), and your mood.
- **Furniture.** Furniture's own actions (sit, sleep, cook, study...) run on the
  furniture, and Life adds their effects. Life also adds actions by furniture
  kind (shower, toilet, TV, piano, weights, pool table and so on).
- **Places.** Place actions (buy coffee, deposit cash, watch a movie...) appear
  in the "yourself" menu when the player is inside a matching room or business.

## Run the tests

```
godot --headless --path godot -s res://life/tests/run_tests.gd
```

Last run: 637 checks passed, 0 failed (Godot 4.5.1).

## Action catalogue

### furniture.json (59)

Sit, Sleep, Nap, Lie down, Open, Close, Use, Cook a simple meal, Study, Work at the desk, Read, Wash hands, Change clothes, Store something, Browse, Check out, Listen to the lecture, Play, Take a shower, Take a bath, Use the toilet, Brush teeth, Wash your face, Fix your hair, Practice a speech in the mirror, Grab a snack, Make a sandwich, Cook a gourmet meal, Bake cookies, Make coffee, Eat a proper meal, Wash the dishes, Watch TV, Watch the news, Play video games, Browse the web, Practice coding, Write a story, Video chat with friends, Play the piano, Play the guitar, Paint, Lift weights, Run on the treadmill, Do yoga, Play pool, Play darts, Play the arcade machine, Play a board game, Do laundry, Make the bed, Tidy up, Water the plant, Take out the trash, Tune up a bike, Tinker with electronics, Relax on the bench, Drink from the fountain, Buy from the vending machine

### places.json (30)

Buy a coffee, Buy a pastry, Buy a meal, Eat at the dining hall, Order a drink, Order a soda, Watch a movie, Browse the books, Buy a book, Listen to records, Buy new clothes, Try on clothes, Buy groceries, Get a haircut, Get a tattoo, Buy glasses, Get a dental checkup, Buy flowers, Buy tools, Look at the art, Deposit all cash, Withdraw $50, Withdraw $200, Pay $100 toward debt, Swim laps, Shoot hoops, Watch the game, Research in the stacks, Ring the carillon, Rent a room for the night

### romance.json (16)

Flirt, Wink, Use a pickup line, Ask on a date, Go on a date, Hold hands, Kiss, Cuddle, Romantic dinner, Slow dance, Give roses, Write a love note, Ask to make it official, Propose, Get married, Break up

### self.json (38)

Check your phone, Scroll the town feed, Play a phone game, Listen to music, Call home, Practice a language on your phone, Read the news, Meditate, Stretch, Do push-ups, Do sit-ups, Go for a jog, Dance like no one's watching, Sing to yourself, Whistle a tune, Daydream, People-watch, Take a selfie, Take photos of the town, Sketch in a notebook, Write in your journal, Plan your day, Drink water, Eat a snack from your bag, Order takeout, Order a pizza, Wait an hour, Pee behind a dumpster, Sell old stuff online, Busk on the street, Do some freelance writing, Donate $10 to charity, Buy a scratch-off, Check your bank balance, Feed the pigeons, Pray, Take in the view, Volunteer for an hour

### social.json (46)

Introduce yourself, Say hi, Chat, Talk about the weather, Talk about Pitch Soles football, Talk about music, Talk about art, Talk about video games, Talk about classes, Talk about parties, Gossip, Tell a joke, Compliment, Ask about their day, Have a deep talk, Share a secret, Give advice, Ask for advice, High five, Hug, Apologize, Thank them, Brag, Cheer them up, Play rock paper scissors, Challenge to arm wrestling, Ask for their number, Text them, Call them, Invite to hang out, Buy them a coffee, Buy them a drink, Dance together, Study together, Work out together, Give a small gift, Give flowers, Lend them $20, Ask to borrow $20, Ask for a favor, Say goodbye, Insult, Argue, Prank them, Make up, Ask to be roommates
