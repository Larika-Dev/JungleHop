## Autoload "NPCs": the 4,000 residents of Cathedral Mount.
##   project.godot:  NPCs="*res://npc/npc_manager.gd"
## Generates the population in the background at startup (about a second),
## simulates where everyone is from their schedules, and streams the nearest
## 100 in as detailed bodies once GameState.world_ready fires.
## Full API: godot/npc/README.md.
extends Node

signal population_ready
signal npc_loaded(index: int, body: NpcBody)
signal npc_unloaded(index: int)
signal npc_witnessed_crime(index: int, crime_id, crime_class, position: Vector3)

const CUSTOM_PATH := "user://npc/custom_npcs.json"

var population: Array = []
var buildings: Array = []
var sim: NpcSimulation
var streamer: NpcStreamer
var ready_state := false

var _by_id := {}
var _thread: Thread
var _custom: Array = []


func _ready() -> void:
	buildings = NpcPopulation.load_buildings()
	# Tool scripts and tests (godot --script ...) build their own populations.
	if not OS.get_cmdline_args().has("--script"):
		# Load every class on the main thread before the worker uses them.
		NpcDemographics.complexion_for("white", RandomNumberGenerator.new())
		NpcHeights.inverse_normal(0.5)
		_thread = Thread.new()
		_thread.start(_generate_in_background)
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.world_ready.connect(_on_world_ready)
		if gs.has_method("register_saveable"):
			gs.register_saveable("npcs", self)
		if gs.world:
			_on_world_ready.call_deferred(gs.world)


func _generate_in_background() -> Array:
	var pop := NpcPopulation.generate()
	# Warm the body mesh cache too, so the first close-up is not a hitch.
	for sex in ["male", "female"]:
		for lod in [2, 1, 0]:
			var path := "user://npc_cache/body_%s_lod%d_v%d.res" % [sex, lod, NpcBodyMesh.VERSION]
			if not FileAccess.file_exists(path):
				var arrays := NpcBodyMesh.new().build_arrays(sex, lod)
				_finish_mesh.call_deferred(sex, lod, arrays)
	_finish.call_deferred(pop)
	return pop


func _finish_mesh(sex: String, lod: int, arrays: Dictionary) -> void:
	NpcBodyMesh.save_built(sex, lod, arrays)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


## Generates on the calling thread if the background job has not finished.
func ensure_ready() -> void:
	if ready_state:
		return
	if _thread and _thread.is_started():
		var pop = _thread.wait_to_finish()
		_thread = null
		if pop is Array:
			_finish(pop)
			return
	_finish(NpcPopulation.generate())


func _finish(pop: Array) -> void:
	if ready_state:
		return
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	population = pop
	_load_custom()
	_reindex()
	sim = NpcSimulation.new(population, buildings)
	ready_state = true
	population_ready.emit()
	if streamer == null:
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.world:
			_on_world_ready(gs.world)


func _on_world_ready(world: Node3D) -> void:
	if not ready_state:
		return  # _finish() calls back once the population exists
	if streamer and is_instance_valid(streamer):
		streamer.queue_free()
	streamer = NpcStreamer.new()
	streamer.name = "NpcStreamer"
	streamer.setup(sim)
	streamer.npc_loaded.connect(func(i, b): npc_loaded.emit(i, b))
	streamer.npc_unloaded.connect(func(i): npc_unloaded.emit(i))
	world.add_child(streamer)


func _reindex() -> void:
	_by_id.clear()
	for i in population.size():
		_by_id[population[i].npc_id] = i


# --- lookups ------------------------------------------------------------------

## Index (0..3999+) for "npc_0123" or an int.
func index_of(id) -> int:
	if id is int: return id
	return _by_id.get(String(id), -1)


func get_record(id) -> Dictionary:
	var i := index_of(id)
	return population[i] if i >= 0 and i < population.size() else {}


func find_by_name(name: String) -> Array:
	var q := name.to_lower()
	return population.filter(func(r): return NpcPopulation.full_name(r).to_lower().contains(q))


func residents_of(building_id: String) -> Array:
	return population.filter(func(r): return r.home == building_id)


func workers_at(building_id: String) -> Array:
	return population.filter(func(r): return r.workplace == building_id)


## NPCs whose current schedule block is at this building (inside or arriving).
func npcs_at(building_id: String) -> Array:
	var out: Array = []
	for i in population.size():
		if sim.place_of(i) == building_id:
			out.append(population[i])
	return out


func position_of(id) -> Vector3:
	return sim.pos[index_of(id)]


## sleep, home, work, class, study, eat, shop, leisure, stroll or commuting.
func activity_of(id) -> String:
	return sim.activity_of(index_of(id))


func personality_of(id) -> int:
	return get_record(id).get("personality_id", 0)


## Seed relationships from generation: partner, household, coworkers,
## classmates, friends (indices). Life owns the live relationship values.
func social_ties(id) -> Dictionary:
	return get_record(id).get("social", {})


func body_of(id) -> NpcBody:
	return streamer.body_of(index_of(id)) if streamer else null


func loaded_bodies() -> Array:
	return streamer.loaded.values() if streamer else []


# --- changes ------------------------------------------------------------------

## Adds a person made with the NPC generator (or code) to the city. They get a
## home, a schedule and a place in streaming like everyone else, and they are
## kept in user://npc/custom_npcs.json across runs. Returns their index.
func add_npc(rec: Dictionary) -> int:
	var r := rec.duplicate(true)
	r.id = population.size()
	r.npc_id = "npc_c%04d" % _custom.size()
	NpcPopulation.place_new_resident(r, buildings, population)
	population.append(r)
	_custom.append(r)
	_by_id[r.npc_id] = r.id
	if sim:
		sim.resize_for_new_npcs()
	_save_custom()
	return r.id


## For the crime thread: "hurt" keeps them off the street for a while, "killed"
## removes them for good, "ok" brings them back.
func set_npc_status(id, status: String) -> void:
	var i := index_of(id)
	if i >= 0: sim.set_status(i, status)


func on_npc_witnessed_crime(index: int, crime_id, crime_class, position: Vector3) -> void:
	npc_witnessed_crime.emit(index, crime_id, crime_class, position)


# --- persistence ----------------------------------------------------------------

func save_data() -> Dictionary:
	var status := {}
	if sim:
		for i in sim._status:
			status[population[i].npc_id] = sim._status[i]
	return {"status": status}


func load_data(d: Dictionary) -> void:
	if sim == null:
		await population_ready
	for npc_id in d.get("status", {}):
		set_npc_status(npc_id, d.status[npc_id])


func _load_custom() -> void:
	if not FileAccess.file_exists(CUSTOM_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_PATH))
	if data is Array:
		for r in data:
			NpcPopulation.normalize_record(r)
			r.id = population.size()
			population.append(r)
			_custom.append(r)


func _save_custom() -> void:
	DirAccess.make_dir_recursive_absolute(CUSTOM_PATH.get_base_dir())
	var f := FileAccess.open(CUSTOM_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_custom))
