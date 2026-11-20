extends Node3D
## The Cathedral Mount city scene: map geometry, trees, sky/sun, interiors, player.
## Other systems hook in through GameState.world_ready(self). See docs/INTERFACES.md.

const CITY_GLB := "res://assets/map/city.glb"
const TREES_GLB := "res://assets/map/trees.glb"
const TREES_JSON := "res://data/trees.json"
const PLAYER_SCENE := "res://player/player.tscn"
const HUD_SCENE := "res://ui/hud.tscn"
## Meshes in city.glb that get collision. Building massing / landmark shells do not: the
## InteriorStreamer builds their walls (with door openings) near the player.
const COLLIDE_PREFIXES := ["terrain", "roads"]
const TREE_CHUNK := 200.0
const TREE_NEAR := 260.0   # trees within this distance (of the chunk) use the detailed mesh
const SPAWN := Vector3(-6.0, 0.0, 6.0)   # sidewalk at The Summit, Hamilton x Columbia
const SPAWN_YAW := PI * 0.5               # facing west down Hamilton St

var player: CharacterBody3D
var interiors: InteriorStreamer
var day_night: DayNight
var map_root: Node3D
var terrain_mat: ShaderMaterial


func _ready() -> void:
	_load_map()
	_load_trees()
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	interiors = InteriorStreamer.new()
	interiors.name = "Interiors"
	add_child(interiors)
	interiors.building_loaded.connect(func(_id, _n): _update_terrain_holes())
	interiors.building_unloaded.connect(func(_id): _update_terrain_holes.call_deferred())
	_spawn_player()
	add_child(load(HUD_SCENE).instantiate())
	GameState.world = self
	GameState.in_game = true
	GameClock.paused = false
	Settings.settings_changed.connect(_apply_settings)
	_apply_settings()
	GameState.world_ready.emit(self)
	GameState.game_started.emit()


func _exit_tree() -> void:
	if GameState.world == self:
		GameState.world = null
		GameState.in_game = false


func _load_map() -> void:
	var packed: PackedScene = load(CITY_GLB)
	map_root = packed.instantiate()
	map_root.name = "Map"
	add_child(map_root)
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://world/terrain.gdshader")
	for mi in map_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name).to_lower().begins_with("terrain"):
			for s in m.mesh.get_surface_count():
				m.set_surface_override_material(s, terrain_mat)
		else:
			_fix_materials(m)
		var lname := String(m.name).to_lower()
		for p in COLLIDE_PREFIXES:
			if lname.begins_with(p):
				m.create_trimesh_collision()
				for c in m.get_children():
					if c is StaticBody3D:
						c.collision_layer = 1
						c.collision_mask = 0
				break


## The map stores palette colors as vertex colors (CLAUDE.md §4): make sure they drive albedo.
func _fix_materials(m: MeshInstance3D) -> void:
	if m.mesh == null:
		return
	for s in m.mesh.get_surface_count():
		var mat := m.mesh.surface_get_material(s) as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
		mat = mat.duplicate()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = false
		mat.roughness = 0.9
		mat.metallic = 0.0
		m.set_surface_override_material(s, mat)


## Cut the terrain where streamed interiors stand (the map ground can sit above interior floors).
func _update_terrain_holes() -> void:
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	for id in interiors.loaded:
		if a.size() >= 32:
			break
		var t: Dictionary = CityData.building(id)["transform"]
		var fp: Array = CityData.building(id).get("footprintCm", [0, 0])
		a.append(Vector4(t["x"], t["z"], cos(t["rotY"]), sin(t["rotY"])))
		b.append(Vector4(fp[0] / 100.0, fp[1] / 100.0, 0, 0))
	var n := a.size()
	while a.size() < 32:
		a.append(Vector4.ZERO)
		b.append(Vector4.ZERO)
	terrain_mat.set_shader_parameter("bld_a", a)
	terrain_mat.set_shader_parameter("bld_b", b)
	terrain_mat.set_shader_parameter("bld_count", n)


func _load_trees() -> void:
	if not FileAccess.file_exists(TREES_JSON):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(TREES_JSON))
	if typeof(data) != TYPE_DICTIONARY:
		return
	# Leaf colors per species come from the map's tree materials (palette leaf colors).
	var protos: Node = load(TREES_GLB).instantiate()
	var leaf := {}
	for mi in protos.find_children("*", "MeshInstance3D", true, false):
		var key := String(mi.name).replace("trees_", "")
		var m := mi.mesh.surface_get_material(0) as BaseMaterial3D
		leaf[key] = m.albedo_color if m else Color(0.3, 0.4, 0.2)
	protos.free()
	var near := {}
	var far := {}
	var i := 0
	for key in leaf:
		var pine: bool = key == "loblolly"
		var bark := CityData.color("PINE_BARK" if pine else "OAK_BARK", Color(0.36, 0.34, 0.32))
		near[key] = TreeKit.make(pine, leaf[key], bark, i)
		far[key] = TreeKit.make_far(pine, leaf[key], bark)
		i += 1
	# Bucket instances into 200 m chunks so near/far meshes can switch per chunk.
	var chunks := {}   # "species|cx|cz" -> Array of transforms
	for species in data:
		if not near.has(species):
			continue
		for e in data[species]:
			var b := Basis(Vector3.UP, e[3]).scaled(Vector3(e[4], e[5], e[4]))
			var key := "%s|%d|%d" % [species, floori(e[0] / TREE_CHUNK), floori(e[2] / TREE_CHUNK)]
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(Transform3D(b, Vector3(e[0], e[1], e[2])))
	var root := Node3D.new()
	root.name = "Trees"
	add_child(root)
	for key in chunks:
		var parts: PackedStringArray = key.split("|")
		var xs: Array = chunks[key]
		for lod in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = near[parts[0]] if lod == 0 else far[parts[0]]
			mm.instance_count = xs.size()
			for j in xs.size():
				mm.set_instance_transform(j, xs[j])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s_%s_%s" % [parts[0], parts[1], parts[2], "near" if lod == 0 else "far"]
			mmi.multimesh = mm
			# chunk center for visibility ranges
			var center := Vector3((int(parts[1]) + 0.5) * TREE_CHUNK, 0, (int(parts[2]) + 0.5) * TREE_CHUNK)
			mmi.custom_aabb = AABB(center - Vector3(TREE_CHUNK, 50, TREE_CHUNK) * 0.75, Vector3(TREE_CHUNK, 100, TREE_CHUNK) * 1.5)
			if lod == 0:
				mmi.visibility_range_end = TREE_NEAR
				mmi.visibility_range_end_margin = 20.0
			else:
				mmi.visibility_range_begin = TREE_NEAR
				mmi.visibility_range_begin_margin = 20.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)


func _spawn_player() -> void:
	player = load(PLAYER_SCENE).instantiate()
	add_child(player)
	var pos := SPAWN
	var yaw := SPAWN_YAW
	var pending: Array = GameState.get_meta("pending_player_pos", [])
	if pending.size() == 4:
		pos = Vector3(pending[0], pending[1], pending[2])
		yaw = pending[3]
		GameState.remove_meta("pending_player_pos")
	else:
		pos.y = ground_height(pos) + 0.05
	player.teleport(pos, yaw)
	interiors.target = player


## Ground height under a point, by ray against the world layer. Physics must have stepped once
## for brand-new trimesh bodies, so this falls back to a mesh-free estimate of 0.
func ground_height(p: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 200.0, p.z), Vector3(p.x, -200.0, p.z), 1)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else p.y


func _apply_settings() -> void:
	if player and player.camera:
		player.camera.far = Settings.view_distance
		player.camera.fov = Settings.fov
	day_night.set_shadows(Settings.shadows, Settings.quality)
