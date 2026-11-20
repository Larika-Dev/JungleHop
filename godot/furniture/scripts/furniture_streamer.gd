class_name FurnitureStreamer
extends Node3D
## Keeps the furniture around the player loaded (CLAUDE.md §7.6: interiors stream within 35 m).
## Pieces on the player's floor and the floors just above / below load within `radius`; a few are built
## per frame so streaming never hitches. Added to the world by the Furniture autoload.

@export var radius := 30.0
@export var unload_margin := 6.0
@export var vertical_range := 4.5   # ~one floor up and down
@export var max_loaded := 900
@export var builds_per_frame := 6
@export var update_interval := 0.25

var manager: Node
var loaded: Dictionary = {}          # placement index -> FurniturePiece
var _queue: Array[int] = []
var _timer := 0.0


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.get("view_distance") != null:
		radius = clampf(float(settings.view_distance) * 0.25, 15.0, 35.0)


func _target_position() -> Variant:
	var gs := get_node_or_null("/root/GameState")
	var p: Node3D = gs.get_player() if gs and gs.has_method("get_player") else null
	if p == null:
		var list := get_tree().get_nodes_in_group("player")
		p = list[0] if not list.is_empty() else null
	if p == null:
		var cam := get_viewport().get_camera_3d()
		return cam.global_position if cam else null
	return p.global_position


func _process(delta: float) -> void:
	if manager == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = update_interval
		var pos = _target_position()
		if pos != null:
			refresh(pos)
	var n := 0
	while not _queue.is_empty() and n < builds_per_frame:
		_build(_queue.pop_front())
		n += 1


## Recomputes what should be loaded around `pos` (public so tests can drive it).
func refresh(pos: Vector3) -> void:
	var want := {}
	var cands: Array = []
	for i in manager.indices_near(pos, radius):
		if absf(manager.p_pos[i].y - pos.y + 1.0) <= vertical_range:
			cands.append([manager.p_pos[i].distance_squared_to(pos), i])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(cands.size(), max_loaded):
		want[cands[k][1]] = true
	# unload what fell out of range (with some hysteresis)
	var far := (radius + unload_margin) * (radius + unload_margin)
	for i in loaded.keys():
		if want.has(i):
			continue
		var d: Vector3 = manager.p_pos[i] - pos
		if d.x * d.x + d.z * d.z > far or absf(d.y + 1.0) > vertical_range + 1.5:
			_unload(i)
	_queue.clear()
	for k in mini(cands.size(), max_loaded):
		var i: int = cands[k][1]
		if not loaded.has(i):
			_queue.append(i)


func _build(i: int) -> void:
	if loaded.has(i):
		return
	var def: Dictionary = manager.model(manager.p_model[i])
	if def.is_empty():
		return
	var piece := FurniturePiece.create(def, manager.p_room[i])
	piece.placement_index = i
	add_child(piece)
	piece.global_transform = Transform3D(Basis(Vector3.UP, manager.p_rot[i]), manager.p_pos[i])
	loaded[i] = piece
	manager.piece_loaded.emit(piece)


func _unload(i: int) -> void:
	var piece: FurniturePiece = loaded[i]
	loaded.erase(i)
	if is_instance_valid(piece):
		manager.piece_unloaded.emit(piece)
		piece.interactable.release_all()
		piece.queue_free()


func unload_all() -> void:
	for i in loaded.keys():
		_unload(i)
	_queue.clear()
