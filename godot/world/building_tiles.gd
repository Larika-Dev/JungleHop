class_name BuildingTiles
extends Node3D
## Streams the detailed building exteriors (assets/buildings/T_c_r.glb, exported from the three.js
## city) in a 3x3 tile ring around the player, and hides the map massing inside loaded tiles.

const DIR := "res://assets/buildings/"
const TOTAL_X0 := -1900.0
const TOTAL_Z0 := -1450.0
const TILE := 200.0

var target: Node3D
var massing_mat: ShaderMaterial
var loaded := {}      # name -> Node3D
var pending := {}     # name -> path
var _t := 0.0


func _process(delta: float) -> void:
	if target == null:
		return
	for n in pending.keys():
		var st := ResourceLoader.load_threaded_get_status(pending[n])
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var inst: Node3D = ResourceLoader.load_threaded_get(pending[n]).instantiate()
			inst.name = n
			add_child(inst)
			loaded[n] = inst
			pending.erase(n)
			_update_mask()
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(n)
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var p := target.global_position
	var c := floori((p.x - TOTAL_X0) / TILE)
	var r := floori((p.z - TOTAL_Z0) / TILE)
	var want := {}
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var n := "T_%d_%d" % [c + dc, r + dr]
			if ResourceLoader.exists(DIR + n + ".glb"):
				want[n] = true
	for n in want:
		if not loaded.has(n) and not pending.has(n):
			pending[n] = DIR + n + ".glb"
			ResourceLoader.load_threaded_request(pending[n])
	for n in loaded.keys():
		if not want.has(n):
			loaded[n].queue_free()
			loaded.erase(n)
			_update_mask()


func _update_mask() -> void:
	if massing_mat == null:
		return
	var arr := PackedVector4Array()
	for n in loaded:
		var parts: PackedStringArray = String(n).split("_")
		var x0 := TOTAL_X0 + int(parts[1]) * TILE
		var z0 := TOTAL_Z0 + int(parts[2]) * TILE
		arr.append(Vector4(x0, z0, x0 + TILE, z0 + TILE))
	var count := arr.size()
	while arr.size() < 9:
		arr.append(Vector4.ZERO)
	massing_mat.set_shader_parameter("tiles", arr)
	massing_mat.set_shader_parameter("tile_count", count)
