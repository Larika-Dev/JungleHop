## Shared numbers for the NPC system. Every value the person asked for lives here.
class_name NpcConfig
extends RefCounted

const SEED := 1795                 # same seed as the city (CLAUDE.md section 3)
const POPULATION := 4000           # NPCs that exist across Cathedral Mount
const MAX_LOADED := 100            # NPCs with a body in the scene at any time

# Heights in cm (1 mm precision, stored to 0.1 cm).
# Source table, converted with 1 in = 2.54 cm:
#   men   25th 66.9 in, 50th 69.0 in, 75th 70.9 in
#   women 25th 61.6 in, 50th 63.5 in, 75th 65.4 in
# 90% of each sex falls between its 25th and 75th values, and every NPC falls
# between 10% under the 25th value and 10% over the 75th value. Rounded to
# 1 mm, the same precision the heights are stored at.
const HEIGHT := {
	"male":   {"low": 169.9, "median": 175.3, "high": 180.1, "min": 152.9, "max": 198.1},
	"female": {"low": 156.5, "median": 161.3, "high": 166.1, "min": 140.8, "max": 182.7},
}
const HEIGHT_CORE_SHARE := 0.90

# Streaming (meters). An NPC loads inside LOAD_RADIUS and unloads past UNLOAD_RADIUS.
const LOAD_RADIUS := 120.0
const UNLOAD_RADIUS := 140.0
const STREAM_INTERVAL := 0.2       # seconds between streaming passes

# Level of detail by distance (meters). LOD0 is the full close-up body with
# muscle deformation; only the nearest LOD0_BUDGET NPCs may use it at once.
const LOD0_DISTANCE := 12.0
const LOD1_DISTANCE := 40.0
const LOD0_BUDGET := 8

# Time: one in-game hour is one real minute.
const REAL_SECONDS_PER_GAME_HOUR := 60.0
const WALK_SPEED := 1.34           # m/s, average adult, scaled per NPC
