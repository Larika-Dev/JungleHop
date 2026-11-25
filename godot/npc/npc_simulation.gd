## Where every one of the 4,000 NPCs is, all the time, from their schedules.
## Cheap enough to update everyone a few times a second; bodies only exist for
## the nearest few (see NpcStreamer).
##
## Travel: NPCs walk at their own speed between front doors. For trips longer
## than RIDE_DISTANCE they walk the first and last WALK_EDGE meters and ride
## (bus, car, bike) in between (time-compressed, at most MAX_RIDE_SECONDS), during which they are off the street and never
## streamed in. Straight lines for now: swap `route_point()` for sidewalk or
## navmesh routing when the world has one.
class_name NpcSimulation
extends RefCounted

enum { AT_PLACE, WALKING, RIDING, GONE }

const RIDE_DISTANCE := 40.0
const WALK_EDGE := 15.0
const RIDE_SPEED := 9.0
const MAX_RIDE_SECONDS := 10.0   # real seconds; one game hour is 60 s, so trips fit the schedule

var population: Array
var buildings: Array
## Optional: func(x: float, z: float, fallback_y: float) -> float, e.g. a terrain raycast.
var ground_height: Callable

var pos := PackedVector3Array()
var heading := PackedFloat32Array()
var state := PackedByteArray()
var _from := PackedVector3Array()
var _dest := PackedVector3Array()
var _depart := PackedFloat64Array()
var _key := PackedInt64Array()
var _block := PackedInt32Array()
var _last_t := -1.0
var _status := {}   # index -> "hurt" | "killed" | "away" (removed from the street)


func _init(p_population: Array, p_buildings: Array) -> void:
	population = p_population
	buildings = p_buildings
	var n := population.size()
	for arr in [pos, _from, _dest]:
		arr.resize(n)
	heading.resize(n)
	state.resize(n)
	_depart.resize(n)
	_key.resize(n)
	_key.fill(-1)
	_block.resize(n)


func resize_for_new_npcs() -> void:
	var n := population.size()
	var old := pos.size()
	for arr in [pos, _from, _dest]:
		arr.resize(n)
	heading.resize(n)
	state.resize(n)
	_depart.resize(n)
	_key.resize(n)
	_block.resize(n)
	for i in range(old, n):
		_key[i] = -1


## Game time in hours since Day 1 00:00 (GameClock.total_minutes / 60).
func update_all(t: float) -> void:
	var snap := _last_t < 0.0 or absf(t - _last_t) > 0.75
	for i in population.size():
		update_one(i, t, snap)
	_last_t = t


func update_one(i: int, t: float, snap := false) -> void:
	if _status.has(i):
		state[i] = GONE
		return
	var rec: Dictionary = population[i]
	var day := int(floorf(t / 24.0))
	var h := t - day * 24.0
	var sched: Array = rec.day_work if rec.work_days[day % 7] else rec.day_off
	var bi := sched.size() - 1
	while bi > 0 and sched[bi][0] > h:
		bi -= 1
	var key := day * 64 + bi
	if key != _key[i]:
		var first := _key[i] < 0
		_key[i] = key
		_block[i] = bi
		var dest := place_point(i, sched[bi])
		if first or snap:
			pos[i] = dest
			_from[i] = dest
			_dest[i] = dest
			_depart[i] = t - 1000.0
		else:
			_from[i] = pos[i]
			_dest[i] = dest
			_depart[i] = day * 24.0 + float(sched[bi][0])
	var from := _from[i]
	var to := _dest[i]
	var dist := from.distance_to(to)
	var travelled := maxf(0.0, (t - _depart[i]) * NpcConfig.REAL_SECONDS_PER_GAME_HOUR) * float(rec.walk_speed)
	if dist < 0.05 or travelled >= _travel_equivalent(dist, float(rec.walk_speed)) * float(rec.walk_speed):
		pos[i] = to
		state[i] = AT_PLACE
		return
	var along := _distance_along(dist, travelled, float(rec.walk_speed))
	state[i] = RIDING if along.y > 0.5 else WALKING
	var p := from.lerp(to, along.x / dist)
	if ground_height.is_valid():
		p.y = ground_height.call(p.x, p.z, p.y)
	pos[i] = p
	var d := to - from
	heading[i] = atan2(-d.x, -d.z)


## Total trip time expressed as seconds of walking at `speed`.
func _travel_equivalent(dist: float, speed: float) -> float:
	if dist <= RIDE_DISTANCE:
		return dist / speed
	return (2.0 * WALK_EDGE) / speed + (dist - 2.0 * WALK_EDGE) / _ride_speed(dist)


static func _ride_speed(dist: float) -> float:
	return maxf(RIDE_SPEED, (dist - 2.0 * WALK_EDGE) / MAX_RIDE_SECONDS)


## x = meters along the line, y = 1 while riding.
func _distance_along(dist: float, walked_equiv: float, speed: float) -> Vector2:
	var secs := walked_equiv / speed
	if dist <= RIDE_DISTANCE:
		return Vector2(minf(secs * speed, dist), 0.0)
	var t1 := WALK_EDGE / speed
	var rs := _ride_speed(dist)
	var t2 := t1 + (dist - 2.0 * WALK_EDGE) / rs
	if secs < t1:
		return Vector2(secs * speed, 0.0)
	if secs < t2:
		return Vector2(WALK_EDGE + (secs - t1) * rs, 1.0)
	return Vector2(minf(dist, dist - WALK_EDGE + (secs - t2) * speed), 0.0)


## The spot an NPC goes to for a schedule block: inside the building on the
## ground floor, or outside near the door for a stroll. Stable per NPC.
func place_point(i: int, block: Array) -> Vector3:
	var b: Dictionary = buildings[block[2]]
	var hsh := hash([i, block[2], block[1]])
	var u := float(hsh & 0xffff) / 65535.0 - 0.5
	var v := float((hsh >> 16) & 0xffff) / 65535.0 - 0.5
	var door := Vector3(b.door[0], b.door[1], b.door[2])
	if block[1] == "stroll":
		var ang := u * TAU
		return door + Vector3(cos(ang), 0, sin(ang)) * (3.0 + 6.0 * (v + 0.5))
	# Building local -> world, same convention as buildings.json:
	# world = R_y(rotY) * local + origin, local +x along the frontage, +z inward.
	var rot: float = b.rot_y
	var c := cos(rot)
	var s := sin(rot)
	var lx: float = b.size[0] * (0.5 + u * 0.6)
	var lz: float = b.size[1] * (0.5 + v * 0.6)
	return Vector3(b.origin[0] + c * lx + s * lz, door.y, b.origin[2] - s * lx + c * lz)


func activity_of(i: int) -> String:
	var rec: Dictionary = population[i]
	if _key[i] < 0: return ""
	var day := int(_key[i] / 64)
	var sched: Array = rec.day_work if rec.work_days[day % 7] else rec.day_off
	if state[i] == WALKING or state[i] == RIDING:
		return "commuting"
	return sched[_block[i]][1]


func place_of(i: int) -> String:
	var rec: Dictionary = population[i]
	if _key[i] < 0: return ""
	var day := int(_key[i] / 64)
	var sched: Array = rec.day_work if rec.work_days[day % 7] else rec.day_off
	return buildings[sched[_block[i]][2]].id


func set_status(i: int, status: String) -> void:
	if status == "" or status == "ok":
		_status.erase(i)
		_key[i] = -1
	else:
		_status[i] = status


func status_of(i: int) -> String:
	return _status.get(i, "ok")


func is_visible_candidate(i: int) -> bool:
	return state[i] != RIDING and state[i] != GONE
