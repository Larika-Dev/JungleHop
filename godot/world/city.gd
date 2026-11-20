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
const SPAWN := Vector3(-6.0, 0.0, 6.0)   # sidewalk at The Summit, Hamilton x Columbia
const SPAWN_YAW := PI * 0.5               # facing west down Hamilton St

var player: CharacterBody3D
var interiors: InteriorStreamer
var day_night: DayNight
var map_root: Node3D


func _ready() -> void:
	_load_map()
	_load_trees()
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	interiors = InteriorStreamer.new()
	interiors.name = "Interiors"
	add_child(interiors)
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
	for mi in map_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
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


func _load_trees() -> void:
	if not FileAccess.file_exists(TREES_JSON):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(TREES_JSON))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var protos: Node = load(TREES_GLB).instantiate()
	var meshes := {}
	for mi in protos.find_children("*", "MeshInstance3D", true, false):
		var key := String(mi.name).replace("trees_", "")
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 1.0
		var mesh: Mesh = mi.mesh.duplicate()
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, mat)
		meshes[key] = mesh
	protos.free()
	var root := Node3D.new()
	root.name = "Trees"
	add_child(root)
	for species in data:
		if not meshes.has(species):
			continue
		var list: Array = data[species]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[species]
		mm.instance_count = list.size()
		for i in list.size():
			var e: Array = list[i]
			var b := Basis(Vector3.UP, e[3]).scaled(Vector3(e[4], e[5], e[4]))
			mm.set_instance_transform(i, Transform3D(b, Vector3(e[0], e[1], e[2])))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = species
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
