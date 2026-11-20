class_name NpcMhMesh
extends RefCounted
## Loads the MakeHuman-based body (models/mh_<sex>.bin + .json, built by
## tools/build_mh_body.py from CC0 MakeHuman data) as a skinned ArrayMesh with
## blend shapes and automatic LODs. Cached in user://npc_cache.

const VERSION := 6
## Blend shape names come from the model's meta (body, flex, ethnicity, face variety).
static func shape_list() -> Array:
	return meta("male").get("shapes", [])
const FACE_FIRST := "nose_width"

static var _meta := {}


static func available() -> bool:
	return FileAccess.file_exists("res://npc/models/mh_male.json") and FileAccess.file_exists("res://npc/models/mh_female.json")


static func meta(sex: String) -> Dictionary:
	if not _meta.has(sex):
		var f := FileAccess.open("res://npc/models/mh_%s.json" % sex, FileAccess.READ)
		_meta[sex] = JSON.parse_string(f.get_as_text()) if f else {}
	return _meta[sex]


static func height(sex: String) -> float:
	return float(meta(sex).get("height", 1.75))


static func rest_positions(sex: String) -> Array:
	var out := []
	for r in meta(sex).rest:
		out.append(Vector3(r[0], r[1], r[2]))
	return out


static func get_mesh(sex: String) -> ArrayMesh:
	var path := "user://npc_cache/mh_%s_v%d.res" % [sex, VERSION]
	if ResourceLoader.exists(path):
		var m = ResourceLoader.load(path)
		if m is ArrayMesh:
			return m
	var mesh := build(sex)
	DirAccess.make_dir_recursive_absolute("user://npc_cache")
	ResourceSaver.save(mesh, path)
	return mesh


static func build(sex: String) -> ArrayMesh:
	var md := meta(sex)
	var n: int = md.vertices
	var ni: int = md.indices
	var buf := FileAccess.get_file_as_bytes("res://npc/models/mh_%s.bin" % sex)
	var o := [0]   # lambdas capture by value: keep the offset in an array
	var take := func(count: int) -> PackedByteArray:
		var b := buf.slice(o[0], o[0] + count * 4)
		o[0] += count * 4
		return b
	var pos := _v3(take.call(n * 3).to_float32_array())
	var nor := _v3(take.call(n * 3).to_float32_array())
	var uv := _v2(take.call(n * 2).to_float32_array())
	var uv2 := _v2(take.call(n * 2).to_float32_array())
	take.call(n * 2)  # MakeHuman texture UVs (unused for now)
	var colf: PackedFloat32Array = take.call(n * 4).to_float32_array()
	var cols := PackedColorArray()
	cols.resize(n)
	for i in n:
		cols[i] = Color(colf[i * 4], colf[i * 4 + 1], colf[i * 4 + 2], colf[i * 4 + 3])
	var bones: PackedInt32Array = take.call(n * 4).to_int32_array()
	var weights: PackedFloat32Array = take.call(n * 4).to_float32_array()
	var idx: PackedInt32Array = take.call(ni).to_int32_array()
	# MakeHuman winds counter-clockwise; Godot front faces are clockwise.
	for t in range(0, ni, 3):
		var a := idx[t + 1]
		idx[t + 1] = idx[t + 2]
		idx[t + 2] = a
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var shapes := []
	for s in shape_list():
		var sa := []
		sa.resize(Mesh.ARRAY_MAX)
		sa[Mesh.ARRAY_VERTEX] = _v3(take.call(n * 3).to_float32_array())
		sa[Mesh.ARRAY_NORMAL] = _v3(take.call(n * 3).to_float32_array())
		shapes.append(sa)
	var im := ImporterMesh.new()
	im.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for s in shape_list():
		im.add_blend_shape(s)
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	im.generate_lods(60.0, 25.0, [])
	var mesh := im.get_mesh()
	mesh.resource_name = "npc_mh_%s" % sex
	return mesh


static func _v3(f: PackedFloat32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(f.size() / 3)
	for i in out.size():
		out[i] = Vector3(f[i * 3], f[i * 3 + 1], f[i * 3 + 2])
	return out


static func _v2(f: PackedFloat32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(f.size() / 2)
	for i in out.size():
		out[i] = Vector2(f[i * 2], f[i * 2 + 1])
	return out
