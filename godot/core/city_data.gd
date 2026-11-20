extends Node
## Read-only access to the generated city data (data/buildings.json, data/rooms.json).
## Autoload name: CityData. Coordinates match the three.js city 1:1:
## 1 unit = 1 m, +X east, -Z north, +Y up. world = R_y(rotY) * local + (x, y, z).
## Room data is building-local: rect = [x0, z0, x1, z1], y = floor elevation.

const BUILDINGS_PATH := "res://data/buildings.json"
const ROOMS_PATH := "res://data/rooms.json"
const LABELS_PATH := "res://data/map-labels.json"
const PALETTE_PATH := "res://data/palette.json"
const GRID := 100.0  # spatial hash cell size, meters

var buildings: Array = []
var labels: Dictionary = {}
## Palette key -> Color, from data/palette.json (the city's master palette, CLAUDE.md §4).
var palette: Dictionary = {}
var _by_id: Dictionary = {}
var _grid: Dictionary = {}          # Vector2i -> Array[String] building ids
var _rooms: Array = []
var _rooms_by_id: Dictionary = {}
var _rooms_by_building: Dictionary = {}
var _rooms_loaded := false


func _ready() -> void:
	var b = _read_json(BUILDINGS_PATH)
	if b is Dictionary:
		buildings = b.get("buildings", [])
	for bd in buildings:
		_by_id[bd["id"]] = bd
		var t: Dictionary = bd["transform"]
		var cell := Vector2i(floori(t["x"] / GRID), floori(t["z"] / GRID))
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(bd["id"])
	var pal = _read_json(PALETTE_PATH)
	if pal is Dictionary:
		for k in pal:
			if pal[k] is String and String(pal[k]).begins_with("#"):
				palette[k] = Color(pal[k])
	var l = _read_json(LABELS_PATH)
	if l is Dictionary:
		labels = l


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("CityData: missing " + path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## rooms.json is ~11 MB; it loads on first use.
func _ensure_rooms() -> void:
	if _rooms_loaded:
		return
	_rooms_loaded = true
	var r = _read_json(ROOMS_PATH)
	if r is Dictionary:
		_rooms = r.get("rooms", [])
	for room in _rooms:
		_rooms_by_id[room["roomId"]] = room
		var bid: String = room["buildingId"]
		if not _rooms_by_building.has(bid):
			_rooms_by_building[bid] = []
		_rooms_by_building[bid].append(room)


## Palette color by key; unknown keys fall back to `fallback`.
func color(key: String, fallback: Color = Color(0.93, 0.92, 0.9)) -> Color:
	return palette.get(key, fallback)


func building(id: String) -> Dictionary:
	return _by_id.get(id, {})


func building_ids() -> Array:
	return _by_id.keys()


func building_transform(id: String) -> Transform3D:
	var bd: Dictionary = _by_id.get(id, {})
	if bd.is_empty():
		return Transform3D.IDENTITY
	var t: Dictionary = bd["transform"]
	return Transform3D(Basis(Vector3.UP, float(t["rotY"])), Vector3(t["x"], t["y"], t["z"]))


func all_rooms() -> Array:
	_ensure_rooms()
	return _rooms


func rooms_for_building(id: String) -> Array:
	_ensure_rooms()
	return _rooms_by_building.get(id, [])


func room(room_id: String) -> Dictionary:
	_ensure_rooms()
	return _rooms_by_id.get(room_id, {})


## Room floor rectangle center in world space (at floor level).
func room_world_center(room_id: String) -> Vector3:
	var r := room(room_id)
	if r.is_empty():
		return Vector3.ZERO
	var rc: Array = r["rect"]
	var local := Vector3((rc[0] + rc[2]) * 0.5, r["y"], (rc[1] + rc[3]) * 0.5)
	return building_transform(r["buildingId"]) * local


## Local (building space) AABB of a room: floor to ceiling.
func room_local_aabb(room_id: String) -> AABB:
	var r := room(room_id)
	if r.is_empty():
		return AABB()
	var rc: Array = r["rect"]
	return AABB(Vector3(rc[0], r["y"], rc[1]), Vector3(rc[2] - rc[0], r["ceilingCm"] / 100.0, rc[3] - rc[1]))


## Building ids whose origin lies within radius of pos (XZ distance).
func buildings_near(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	var c0 := Vector2i(floori((pos.x - radius) / GRID), floori((pos.z - radius) / GRID))
	var c1 := Vector2i(floori((pos.x + radius) / GRID), floori((pos.z + radius) / GRID))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for id in _grid.get(Vector2i(cx, cz), []):
				var t: Dictionary = _by_id[id]["transform"]
				if Vector2(t["x"] - pos.x, t["z"] - pos.z).length() <= radius:
					out.append(id)
	return out


## The room containing a world position, or {} (checks buildings within 80 m).
func room_at(world_pos: Vector3) -> Dictionary:
	for id in buildings_near(world_pos, 80.0):
		var local := building_transform(id).affine_inverse() * world_pos
		for r in rooms_for_building(id):
			var rc: Array = r["rect"]
			if local.x >= rc[0] and local.x <= rc[2] and local.z >= rc[1] and local.z <= rc[3] \
					and local.y >= r["y"] - 0.3 and local.y < r["y"] + r["ceilingCm"] / 100.0:
				return r
	return {}
