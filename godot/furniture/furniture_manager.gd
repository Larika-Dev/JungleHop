extends Node
## Autoload "Furniture" (res://furniture/furniture_manager.gd).
##
## Loads the furniture catalogue, action list and the city's placements, and adds a FurnitureStreamer to
## the world when GameState.world_ready fires. Queries for NPCs and the life systems:
##   Furniture.action_def(id)                          -> {label, minutes, needs, perHour?}
##   Furniture.model(id)                               -> catalogue entry
##   Furniture.placements_near(pos, radius, action="") -> [{index, model_id, kind, position, rot_y, room_id, actions}]
##     (works for furniture that is not loaded yet, so NPCs can walk to it)
##   Furniture.find_nearest(pos, action_id, radius)   -> nearest loaded FurnitureInteractable offering it, or null
##   Furniture.spawn_piece(model_id, xform, parent)    -> FurniturePiece (for tests or hand-placed props)

const CATALOG_PATH := "res://furniture/data/furniture_catalog.json"
const ACTIONS_PATH := "res://furniture/data/furniture_actions.json"
const PLACEMENTS_PATH := "res://furniture/data/furniture_placements.json"

signal piece_loaded(piece: FurniturePiece)
signal piece_unloaded(piece: FurniturePiece)

var models: Dictionary = {}   # int id -> entry
var actions: Dictionary = {}  # action id -> def
var streamer: FurnitureStreamer

# flat placement arrays in world space (filled once)
var p_model := PackedInt32Array()
var p_pos := PackedVector3Array()
var p_rot := PackedFloat32Array()
var p_room := PackedStringArray()
var _cells: Dictionary = {}   # Vector2i -> PackedInt32Array
const CELL := 8.0


func _ready() -> void:
	_load_catalog()
	_load_placements()
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_signal("world_ready"):
		gs.world_ready.connect(_on_world_ready)
		if gs.get("world") is Node3D:
			_on_world_ready(gs.world)


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Furniture: cannot open %s" % path)
		return null
	return JSON.parse_string(f.get_as_text())


func _load_catalog() -> void:
	var c = _read_json(CATALOG_PATH)
	if c:
		for m in c["models"]:
			models[int(m["id"])] = m
	var a = _read_json(ACTIONS_PATH)
	if a:
		actions = a["actions"]
	actions["stand_up"] = {"label": "Stand up", "minutes": 0, "needs": {}}


func _load_placements() -> void:
	var d = _read_json(PLACEMENTS_PATH)
	if d == null:
		return
	var n := int(d.get("count", 0))
	p_model.resize(n); p_pos.resize(n); p_rot.resize(n); p_room.resize(n)
	var i := 0
	for bid in d["buildings"]:
		var e: Dictionary = d["buildings"][bid]
		var t: Array = e["t"]
		var bx := Transform3D(Basis(Vector3.UP, float(t[3])), Vector3(float(t[0]), float(t[1]), float(t[2])))
		var rooms: Array = e["rooms"]
		for it in e["items"]:
			if i >= n:
				break
			p_model[i] = int(it[0])
			p_pos[i] = bx * Vector3(float(it[1]), float(it[2]), float(it[3]))
			p_rot[i] = float(t[3]) + float(it[4])
			p_room[i] = String(rooms[int(it[5])])
			var key := Vector2i(floori(p_pos[i].x / CELL), floori(p_pos[i].z / CELL))
			if not _cells.has(key):
				_cells[key] = PackedInt32Array()
			_cells[key].append(i)
			i += 1


func _on_world_ready(world: Node3D) -> void:
	if streamer and is_instance_valid(streamer):
		return
	streamer = FurnitureStreamer.new()
	streamer.name = "FurnitureStreamer"
	streamer.manager = self
	world.add_child(streamer)


# ------------------------------------------------------------------ queries

func model(id: int) -> Dictionary:
	return models.get(id, {})


func action_def(id: String) -> Dictionary:
	return actions.get(id, {})


func placement_count() -> int:
	return p_model.size()


func indices_near(pos: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c0 := Vector2i(floori((pos.x - radius) / CELL), floori((pos.z - radius) / CELL))
	var c1 := Vector2i(floori((pos.x + radius) / CELL), floori((pos.z + radius) / CELL))
	var r2 := radius * radius
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var cell = _cells.get(Vector2i(cx, cz))
			if cell == null:
				continue
			for i in cell:
				var d := p_pos[i] - pos
				if d.x * d.x + d.z * d.z <= r2:
					out.append(i)
	return out


func placements_near(pos: Vector3, radius: float, action_id := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in indices_near(pos, radius):
		var m: Dictionary = models.get(p_model[i], {})
		if action_id != "" and action_id not in m.get("actions", []):
			continue
		out.append({"index": i, "model_id": p_model[i], "kind": m.get("kind", ""), "position": p_pos[i],
			"rot_y": p_rot[i], "room_id": p_room[i], "actions": m.get("actions", [])})
	return out


func find_nearest(pos: Vector3, action_id: String, radius := 30.0) -> FurnitureInteractable:
	var best: FurnitureInteractable = null
	var best_d := radius
	for n in get_tree().get_nodes_in_group("furniture"):
		var fi := n as FurnitureInteractable
		if fi == null or action_id not in fi.piece.def.get("actions", []):
			continue
		var d := fi.piece.global_position.distance_to(pos)
		if d < best_d:
			best_d = d; best = fi
	return best


func spawn_piece(model_id: int, xform: Transform3D, parent: Node, room_id := "") -> FurniturePiece:
	var def := model(model_id)
	if def.is_empty():
		return null
	var p := FurniturePiece.create(def, room_id)
	parent.add_child(p)
	p.global_transform = xform
	return p
