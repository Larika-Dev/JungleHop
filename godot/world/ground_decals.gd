class_name GroundDecals
extends Node3D
## Ground decals from data/props.json "decals": fallen leaves and pine needles under trees and in the
## gutters, cracks / tar snakes / patches on asphalt, gum and grime on busy sidewalks, puddles in the
## gutters and on trails, oil drips in parking stalls, worn soil in lawns, pine-straw mulch beds.
## One MultiMesh per kind per 64 m chunk of flat quads aligned to the ground normal; patterns are
## procedural (ground_decal.gdshaderinc). Density and distance follow the graphics preset.

const DATA := "res://data/props.json"
const CHUNK := 64.0
const KINDS := {"leaves": 0, "needles": 1, "crack": 2, "tar": 3, "patch": 4, "gum": 5,
	"puddle": 6, "oil": 7, "stain": 8, "dirt": 9, "mulch": 10}
const BLENDED := ["puddle", "oil", "stain", "dirt", "mulch"]
const RANGE := {"leaves": 70.0, "needles": 55.0, "crack": 60.0, "tar": 70.0, "patch": 120.0, "gum": 35.0,
	"puddle": 90.0, "oil": 60.0, "stain": 50.0, "dirt": 110.0, "mulch": 110.0}
const DENSITY := [0.35, 0.65, 1.0, 1.0]
const RANGE_SCALE := [0.6, 0.8, 1.0, 1.4]

var _nodes: Array[MultiMeshInstance3D] = []
var _decals: Dictionary = {}
var _quality := -1


func _ready() -> void:
	if not FileAccess.file_exists(DATA):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if typeof(d) != TYPE_DICTIONARY:
		return
	_decals = d.get("decals", {})
	_build()
	Settings.settings_changed.connect(_on_settings)


func _on_settings() -> void:
	if Settings.quality != _quality:
		_build()


func _build() -> void:
	_quality = clampi(Settings.quality, 0, 3)
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	var quad := PlaneMesh.new()
	quad.size = Vector2(1, 1)
	var keep: float = DENSITY[_quality]
	for kind in _decals:
		if not KINDS.has(kind):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = load("res://world/shaders/ground_decal_blend.gdshader" if kind in BLENDED else "res://world/shaders/ground_decal.gdshader")
		mat.set_shader_parameter("kind", KINDS[kind])
		if kind in BLENDED:
			mat.render_priority = -1 if kind in ["dirt", "mulch"] else 0
		var chunks := {}
		for e in _decals[kind]:
			var seed := fposmod(float(e[0]) * 0.731 + float(e[2]) * 0.379, 1.0)
			if keep < 1.0 and seed > keep and kind != "patch":
				continue
			var n := Vector3(float(e[6]), 0.0, float(e[7]))
			n.y = sqrt(maxf(0.0, 1.0 - n.x * n.x - n.z * n.z))
			var align := Basis(Quaternion(Vector3.UP, n.normalized())) if n.y < 0.9999 else Basis()
			var b := align * Basis(Vector3.UP, float(e[3])).scaled(Vector3(float(e[4]), 1.0, float(e[5])))
			var key := Vector2i(floori(float(e[0]) / CHUNK), floori(float(e[2]) / CHUNK))
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append([Transform3D(b, Vector3(e[0], e[1], e[2])), Color(float(e[8]), seed, 0, 0)])
		for key in chunks:
			var arr: Array = chunks[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = quad
			mm.instance_count = arr.size()
			for j in arr.size():
				mm.set_instance_transform(j, arr[j][0])
				mm.set_instance_custom_data(j, arr[j][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [kind, key.x, key.y]
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = RANGE[kind] * RANGE_SCALE[_quality] + CHUNK * 0.5
			mmi.visibility_range_end_margin = 6.0
			add_child(mmi)
			_nodes.append(mmi)


func decal_count() -> int:
	var n := 0
	for m in _nodes:
		n += m.multimesh.instance_count
	return n
