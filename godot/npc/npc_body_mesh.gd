## Builds the skinned NPC body meshes in code (no Blender, like the rest of the
## city). One template per sex and level of detail; every NPC shares them and
## differs by scale (height), blend shape weights (weight, muscle) and colors.
##
## The surface is a set of lofted tubes (torso, legs, arms, neck, head, hands,
## feet). Each cross-section is an ellipse or superellipse plus anatomical
## "bumps": gastrocnemius heads, soleus, Achilles hollows, tibia, patella,
## vastus medialis/lateralis, rectus femoris, hamstrings, glutes, pecs,
## deltoids, biceps, triceps, nose, brow, cheekbones, lips, ears.
##
## Blend shapes:
##   fat, slim, muscle                 body build, set once per NPC
##   calf_flex_L/R                     gastrocnemius and soleus contract
##                                     (shorten, bulge, Achilles sharpens)
##   quad_flex_L/R                     quadriceps contract, patella rides up
##   glute_flex_L/R                    gluteus maximus contracts
## The walk cycle drives the flex shapes every frame (see NpcBody).
class_name NpcBodyMesh
extends RefCounted

const VERSION := 6
const SHAPES := ["fat", "slim", "muscle", "calf_flex_L", "calf_flex_R", "quad_flex_L", "quad_flex_R", "glute_flex_L", "glute_flex_R"]
const FLEX_FIRST := 3                 # shapes from this index on are muscle flex
const LOD_SPACING := [0.005, 0.02, 0.05]   # target vertex spacing in meters
const LOD_HEAD_SPACING := [0.004, 0.014, 0.04]
const REF_HEIGHT := {"male": 1.753, "female": 1.613}

const BONES := ["root", "pelvis", "spine", "chest", "neck", "head",
	"thigh_L", "shin_L", "foot_L", "thigh_R", "shin_R", "foot_R",
	"upperarm_L", "forearm_L", "hand_L", "upperarm_R", "forearm_R", "hand_R"]
const PARENT := [-1, 0, 1, 2, 3, 4, 1, 6, 7, 1, 9, 10, 3, 12, 13, 3, 15, 16]
enum { B_ROOT, B_PELVIS, B_SPINE, B_CHEST, B_NECK, B_HEAD, B_THIGH_L, B_SHIN_L, B_FOOT_L, B_THIGH_R, B_SHIN_R, B_FOOT_R,
	B_UPPERARM_L, B_FOREARM_L, B_HAND_L, B_UPPERARM_R, B_FOREARM_R, B_HAND_R }
enum { P_TORSO, P_LEG, P_ARM, P_HEAD, P_FOOT, P_HAND, P_NECK, P_FINGER }

# Joint heights as a fraction of standing height.
const Y_ANKLE := 0.039
const Y_KNEE := 0.285
const Y_HIP := 0.53
const Y_WAIST := 0.61
const Y_CHEST := 0.70
const Y_NECK := 0.83
const Y_HEAD := 0.885
const Y_SHOULDER := 0.81
const Y_ELBOW := 0.63
const Y_WRIST := 0.485

# Leg cross-section [y, lateral half width, front-back half depth], fraction of H.
const LEG := [[0.56, 0.054, 0.054], [0.50, 0.053, 0.051], [0.42, 0.047, 0.046], [0.34, 0.039, 0.038],
	[0.30, 0.034, 0.034], [0.285, 0.033, 0.032], [0.26, 0.031, 0.031], [0.22, 0.029, 0.029],
	[0.17, 0.026, 0.025], [0.12, 0.020, 0.018], [0.08, 0.016, 0.015], [0.05, 0.0175, 0.017], [0.036, 0.017, 0.019]]
# Torso [y, half width, half depth].
const TORSO := {
	"male": [[0.465, 0.062, 0.045], [0.50, 0.098, 0.060], [0.53, 0.103, 0.063], [0.56, 0.100, 0.060], [0.61, 0.086, 0.057],
		[0.66, 0.089, 0.060], [0.72, 0.094, 0.066], [0.77, 0.097, 0.063], [0.80, 0.106, 0.054], [0.818, 0.094, 0.046], [0.835, 0.037, 0.031]],
	"female": [[0.465, 0.066, 0.047], [0.50, 0.108, 0.064], [0.53, 0.116, 0.068], [0.56, 0.110, 0.062], [0.62, 0.082, 0.054],
		[0.66, 0.085, 0.056], [0.72, 0.092, 0.064], [0.77, 0.092, 0.062], [0.80, 0.100, 0.052], [0.818, 0.088, 0.044], [0.835, 0.035, 0.030]],
}
const ARM := [[0.822, 0.022, 0.024], [0.81, 0.029, 0.029], [0.795, 0.031, 0.030], [0.76, 0.027, 0.028], [0.71, 0.024, 0.026], [0.665, 0.021, 0.021],
	[0.63, 0.020, 0.021], [0.60, 0.022, 0.020], [0.55, 0.019, 0.016], [0.50, 0.015, 0.012], [0.485, 0.014, 0.010]]
# Palm only (LOD0/1, fingers are separate): wrist to knuckles.
const PALM := [[0.487, 0.0085, 0.016], [0.47, 0.009, 0.022], [0.445, 0.0085, 0.0235], [0.428, 0.0075, 0.0225], [0.422, 0.005, 0.018]]
# Fingers: [name, z offset across the palm, length, base radius], fraction of H.
const FINGERS := [["index", -0.0155, 0.040, 0.0052], ["middle", -0.0052, 0.045, 0.0054], ["ring", 0.0052, 0.042, 0.0050], ["little", 0.0150, 0.033, 0.0044]]
# Mitten hand for the far LOD.
const HAND := [[0.487, 0.0085, 0.016], [0.47, 0.009, 0.022], [0.43, 0.008, 0.024], [0.415, 0.007, 0.022], [0.39, 0.0055, 0.018], [0.38, 0.003, 0.008]]
# Head [y, half width, half depth, center z].
const HEAD := [[0.862, 0.010, 0.012, -0.024], [0.866, 0.020, 0.026, -0.020], [0.874, 0.028, 0.036, -0.014], [0.888, 0.034, 0.044, -0.008], [0.905, 0.038, 0.049, -0.004],
	[0.92, 0.041, 0.052, -0.002], [0.94, 0.044, 0.055, 0.0], [0.96, 0.045, 0.056, 0.002], [0.975, 0.042, 0.052, 0.003],
	[0.99, 0.031, 0.038, 0.003], [0.997, 0.016, 0.020, 0.002], [1.0, 0.0, 0.0, 0.002]]
# Foot along its length, heel (0) to toe (1): [s, half width, half height, center y].
const FOOT := [[0.0, 0.010, 0.012, 0.016], [0.06, 0.017, 0.019, 0.020], [0.2, 0.019, 0.026, 0.028], [0.35, 0.021, 0.024, 0.026],
	[0.55, 0.024, 0.019, 0.020], [0.75, 0.027, 0.016, 0.016], [0.9, 0.025, 0.014, 0.0145], [0.97, 0.018, 0.011, 0.012], [1.0, 0.006, 0.004, 0.010]]

# Muscle and feature bumps: [name, y0, theta0 (deg), sigma_y, sigma_theta (deg), amplitude], fraction of H.
# Leg theta: 0 lateral, 90 back, 180 medial, 270 front.
const LEG_BUMPS := [
	["gastroc_med", 0.222, 125.0, 0.028, 40.0, 0.0085], ["gastroc_lat", 0.232, 58.0, 0.024, 35.0, 0.0062],
	["soleus", 0.165, 90.0, 0.025, 75.0, 0.003],
	["achilles_med", 0.085, 125.0, 0.02, 18.0, -0.0022], ["achilles_lat", 0.085, 58.0, 0.02, 18.0, -0.0022],
	["tibia", 0.17, 215.0, 0.06, 30.0, -0.0022], ["patella", 0.29, 270.0, 0.011, 30.0, 0.004],
	["vastus_med", 0.325, 215.0, 0.018, 38.0, 0.0046], ["vastus_lat", 0.395, 330.0, 0.035, 50.0, 0.0034],
	["rectus", 0.42, 270.0, 0.035, 32.0, 0.0029], ["hamstrings", 0.40, 90.0, 0.04, 60.0, 0.0034],
	["malleolus_med", 0.05, 180.0, 0.007, 25.0, 0.0035], ["malleolus_lat", 0.045, 0.0, 0.007, 25.0, 0.0035],
]
# Torso theta: 0 = +X (body's right), 90 back, 180 left, 270 front.
const TORSO_BUMPS := [
	["glute_R", 0.505, 55.0, 0.035, 35.0, 0.010], ["glute_L", 0.505, 125.0, 0.035, 35.0, 0.010],
	["spine", 0.69, 90.0, 0.09, 9.0, -0.0028],
	["scapula_R", 0.76, 50.0, 0.025, 25.0, 0.0035], ["scapula_L", 0.76, 130.0, 0.025, 25.0, 0.0035],
	["pec_R", 0.735, 300.0, 0.03, 30.0, 0.006], ["pec_L", 0.735, 240.0, 0.03, 30.0, 0.006],
	["breast_R", 0.722, 296.0, 0.032, 26.0, 0.0], ["breast_L", 0.722, 244.0, 0.032, 26.0, 0.0],
	["belly", 0.60, 270.0, 0.06, 70.0, 0.0], ["flank_R", 0.585, 0.0, 0.04, 40.0, 0.0], ["flank_L", 0.585, 180.0, 0.04, 40.0, 0.0],
]
const ARM_BUMPS := [
	["deltoid", 0.795, 0.0, 0.025, 70.0, 0.004], ["biceps", 0.71, 270.0, 0.025, 45.0, 0.004],
	["triceps", 0.73, 90.0, 0.03, 50.0, 0.004], ["brachioradialis", 0.6, 300.0, 0.02, 40.0, 0.0025],
]
# Head theta: 0 = +X, 90 back, 270 face.
const HEAD_BUMPS := [
	["nose", 0.923, 270.0, 0.009, 8.0, 0.0085], ["nose_tip", 0.917, 270.0, 0.004, 9.0, 0.0035], ["nose_bridge", 0.936, 270.0, 0.008, 6.0, 0.004],
	["brow", 0.947, 270.0, 0.004, 38.0, 0.0022],
	["eye_R", 0.938, 289.0, 0.004, 11.0, -0.0022], ["eye_L", 0.938, 251.0, 0.004, 11.0, -0.0022],
	["cheek_R", 0.928, 300.0, 0.008, 14.0, 0.0018], ["cheek_L", 0.928, 240.0, 0.008, 14.0, 0.0018],
	["lips", 0.902, 270.0, 0.004, 14.0, 0.0022], ["chin", 0.873, 270.0, 0.006, 22.0, 0.002],
	["ear_R", 0.933, 8.0, 0.013, 7.0, 0.0055], ["ear_L", 0.933, 172.0, 0.013, 7.0, 0.0055],
]

var sex: String
var h: float
var lod: int
var _shape_count: int
var _v: Array = []      # per shape (0 = base): PackedVector3Array
var _n: Array = []
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _idx := PackedInt32Array()


## Returns an ArrayMesh, cached on disk after the first build.
static func get_mesh(p_sex: String, p_lod: int) -> ArrayMesh:
	var path := "user://npc_cache/body_%s_lod%d_v%d.res" % [p_sex, p_lod, VERSION]
	if ResourceLoader.exists(path):
		var m = ResourceLoader.load(path)
		if m is ArrayMesh:
			return m
	return save_built(p_sex, p_lod, NpcBodyMesh.new().build_arrays(p_sex, p_lod))


## Turns build_arrays() output into a mesh and caches it (main thread).
static func save_built(p_sex: String, p_lod: int, data: Dictionary) -> ArrayMesh:
	var mesh := mesh_from_arrays(data)
	mesh.resource_name = "npc_body_%s_lod%d" % [p_sex, p_lod]
	DirAccess.make_dir_recursive_absolute("user://npc_cache")
	ResourceSaver.save(mesh, "user://npc_cache/body_%s_lod%d_v%d.res" % [p_sex, p_lod, VERSION])
	return mesh


static func mesh_from_arrays(data: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for n in SHAPES:
		mesh.add_blend_shape(n)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.arrays, data.shapes)
	return mesh


## Rest pose of the skeleton for this sex at its reference height.
static func bone_rest_positions(p_sex: String) -> Array:
	var H: float = REF_HEIGHT[p_sex]
	var hip_x := (0.051 if p_sex == "male" else 0.057) * H
	var sh_x := (0.105 if p_sex == "male" else 0.100) * H
	var arm_out := (0.135 if p_sex == "male" else 0.140) * H
	var model := []
	model.resize(BONES.size())
	model[B_ROOT] = Vector3.ZERO
	model[B_PELVIS] = Vector3(0, Y_HIP * H, 0)
	model[B_SPINE] = Vector3(0, Y_WAIST * H, 0)
	model[B_CHEST] = Vector3(0, Y_CHEST * H, 0)
	model[B_NECK] = Vector3(0, Y_NECK * H, 0)
	model[B_HEAD] = Vector3(0, Y_HEAD * H, 0)
	for side in [-1, 1]:
		var o := 0 if side < 0 else 3
		model[B_THIGH_L + o] = Vector3(side * hip_x, Y_HIP * H, 0)
		model[B_SHIN_L + o] = Vector3(side * hip_x * 0.85, Y_KNEE * H, 0)
		model[B_FOOT_L + o] = Vector3(side * hip_x * 0.8, Y_ANKLE * H, 0)
		var t_el := (0.825 - Y_ELBOW) / (0.825 - 0.485)
		model[B_UPPERARM_L + o] = Vector3(side * sh_x, Y_SHOULDER * H, 0)
		model[B_FOREARM_L + o] = Vector3(side * lerpf(sh_x, arm_out, t_el), Y_ELBOW * H, 0)
		model[B_HAND_L + o] = Vector3(side * arm_out, Y_WRIST * H, 0)
	return model


func build(p_sex: String, p_lod: int) -> ArrayMesh:
	var m := mesh_from_arrays(build_arrays(p_sex, p_lod))
	m.resource_name = "npc_body_%s_lod%d" % [p_sex, p_lod]
	return m


## Pure data, safe to run on a worker thread.
func build_arrays(p_sex: String, p_lod: int) -> Dictionary:
	sex = p_sex
	lod = p_lod
	h = REF_HEIGHT[sex]
	_shape_count = SHAPES.size() + 1
	for k in _shape_count:
		_v.append(PackedVector3Array())
		_n.append(PackedVector3Array())
	var sp: float = LOD_SPACING[lod]
	var hsp: float = LOD_HEAD_SPACING[lod]
	_build_torso(sp)
	for side in [-1, 1]:
		_build_leg(side, sp)
		_build_arm(side, sp)
		_build_hand(side, hsp)
		_build_foot(side, hsp * 1.2)
	_build_neck(sp)
	_build_head(hsp)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v[0]
	arrays[Mesh.ARRAY_NORMAL] = _n[0]
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_BONES] = _bones
	arrays[Mesh.ARRAY_WEIGHTS] = _weights
	arrays[Mesh.ARRAY_INDEX] = _idx
	var shapes := []
	for k in range(1, _shape_count):
		var sh := []
		sh.resize(Mesh.ARRAY_MAX)
		sh[Mesh.ARRAY_VERTEX] = _v[k]
		sh[Mesh.ARRAY_NORMAL] = _n[k]
		shapes.append(sh)
	return {"arrays": arrays, "shapes": shapes}


func vertex_count() -> int:
	return _v[0].size()


# --- parts --------------------------------------------------------------------

func _build_leg(side: int, sp: float) -> void:
	var y0 := 0.56
	var y1 := 0.036
	var hip_x := (0.051 if sex == "male" else 0.057)
	var length := (y0 - y1) * h
	var rings := maxi(4, ceili(length / sp))
	var segs := _even(maxi(8, ceili(TAU * 0.0486 * h / sp)))
	var side_name := "L" if side < 0 else "R"
	var calf_k := SHAPES.find("calf_flex_" + side_name) + 1
	var quad_k := SHAPES.find("quad_flex_" + side_name) + 1
	var used := [0, 1, 2, 3, calf_k, quad_k]
	var fem := sex == "female"
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var yf := lerpf(y0, y1, s)
		var cx: float
		if yf > Y_KNEE:
			cx = lerpf(hip_x * 0.85, hip_x, (yf - Y_KNEE) / (y0 - Y_KNEE))
		else:
			cx = lerpf(hip_x * 0.8, hip_x * 0.85, (yf - y1) / (Y_KNEE - y1))
		var r2 := _table2(LEG, yf)
		var rx: float = r2.x
		var rz: float = r2.y
		if fem:
			var f := 1.06 if yf > 0.42 else (0.95 if yf < 0.30 else lerpf(0.95, 1.06, (yf - 0.30) / 0.12))
			rx *= f; rz *= f
		var th := t * TAU
		var c := cos(th)
		var sn := sin(th)
		var r := 1.0 / sqrt((c / rx) * (c / rx) + (sn / rz) * (sn / rz))
		var amp_mul := 0.78 if fem else 1.0
		match k:
			1: r *= 1.0 + (0.22 if yf > Y_KNEE else lerpf(0.05, 0.12, (yf - y1) / (Y_KNEE - y1))); amp_mul *= 0.7
			2: r *= 0.9
			3: r *= 1.03; amp_mul *= 1.9
		var deg := rad_to_deg(th)
		for b in LEG_BUMPS:
			var by: float = b[1]
			var bt: float = b[2]
			var sy: float = b[3]
			var st: float = b[4]
			var amp: float = b[5] * amp_mul
			var nm: String = b[0]
			if k == calf_k:
				if nm.begins_with("gastroc"): amp *= 1.5; by += 0.007; st *= 0.9
				elif nm == "soleus": amp *= 1.35
				elif nm.begins_with("achilles"): amp *= 1.4
			elif k == quad_k:
				if nm == "vastus_med": amp *= 1.6
				elif nm == "vastus_lat": amp *= 1.4
				elif nm == "rectus": amp *= 1.35
				elif nm == "patella": by += 0.005
			r += _bump(yf, deg, by, bt, sy, st, amp)
		return Vector3(side * (cx + c * r), yf, sn * r) * h
	var weights := func(p: Vector3) -> Array:
		var yf := p.y / h
		var thigh := B_THIGH_L if side < 0 else B_THIGH_R
		var shin := thigh + 1
		var foot := thigh + 2
		if yf > Y_HIP:
			return _w2(B_PELVIS, thigh, clampf((yf - Y_HIP) / 0.03, 0.0, 1.0) * 0.5)
		if yf > Y_KNEE:
			return _w2(thigh, shin, smoothstep(Y_KNEE - 0.015, Y_KNEE + 0.025, yf))
		return _w2(shin, foot, smoothstep(Y_ANKLE - 0.008, Y_ANKLE + 0.015, yf))
	_tube(P_LEG, rings, segs, eval, used, weights, Vector3.DOWN, side)


func _build_torso(sp: float) -> void:
	var tab: Array = TORSO[sex]
	var y0 := 0.465
	var y1 := 0.835
	var rings := maxi(4, ceili((y1 - y0) * h / sp))
	var segs := _even(maxi(12, ceili(TAU * 0.09 * h / sp)))
	var fem := sex == "female"
	var gl_l := SHAPES.find("glute_flex_L") + 1
	var gl_r := SHAPES.find("glute_flex_R") + 1
	var used := [0, 1, 2, 3, gl_l, gl_r]
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var yf := lerpf(y0, y1, s)
		var ab := _table2(tab, yf)
		var a: float = ab.x * h
		var b: float = ab.y * h
		if k == 1:
			var f := 1.0 + 0.18 * _band(yf, 0.49, 0.70)
			a *= f; b *= f
		elif k == 2:
			a *= 0.93; b *= 0.92
		elif k == 3 and yf > 0.74:
			a *= 1.0 + 0.06 * smoothstep(0.74, 0.80, yf)
		var th := t * TAU
		var c := cos(th)
		var sn := sin(th)
		var n := 2.4
		var r := pow(pow(absf(c / a), n) + pow(absf(sn / b), n), -1.0 / n)
		var deg := rad_to_deg(th)
		for bump in TORSO_BUMPS:
			var nm: String = bump[0]
			var amp: float = bump[5]
			var by: float = bump[1]
			if nm.begins_with("glute"):
				amp *= 1.2 if fem else 1.0
				if k == 3: amp *= 1.15
				if (k == gl_l and nm == "glute_L") or (k == gl_r and nm == "glute_R"):
					amp *= 1.3; by += 0.005
			elif nm.begins_with("pec"):
				amp *= 0.25 if fem else 1.0
				if k == 3: amp *= 2.0
			elif nm.begins_with("breast"):
				amp = 0.016 if fem else 0.0
				if k == 1 and fem: amp *= 1.3
			elif nm == "belly":
				amp = 0.032 if k == 1 else 0.0
			elif nm.begins_with("flank"):
				amp = 0.014 if k == 1 else 0.0
			if amp != 0.0:
				r += _bump(yf, deg, by, bump[2], bump[3], bump[4], amp) * h
		var zc := 0.006 * h * _band(yf, 0.56, 0.66) - 0.004 * h * _band(yf, 0.70, 0.78)
		return Vector3(c * r, yf * h, sn * r + zc)
	var weights := func(p: Vector3) -> Array:
		var yf := p.y / h
		var w: Array
		if yf < 0.575:
			w = _w2(B_PELVIS, B_SPINE, 1.0 - smoothstep(0.55, 0.60, yf))
		elif yf < 0.69:
			w = _w2(B_SPINE, B_CHEST, 1.0 - smoothstep(0.66, 0.71, yf))
		else:
			w = _w2(B_CHEST, B_NECK, 1.0 - smoothstep(0.815, 0.835, yf))
			if yf > 0.77 and absf(p.x) > 0.075 * h:
				var arm := B_UPPERARM_R if p.x > 0 else B_UPPERARM_L
				var a := 0.35 * smoothstep(0.075 * h, 0.1 * h, absf(p.x)) * smoothstep(0.77, 0.80, yf)
				w = [[w[0][0], arm, 0, 0], [1.0 - a, a, 0.0, 0.0]]
		if yf < 0.53 and absf(p.x) > 0.02 * h:
			var thigh := B_THIGH_R if p.x > 0 else B_THIGH_L
			var a := 0.55 * smoothstep(0.53, 0.47, yf)
			w = [[w[0][0], thigh, 0, 0], [1.0 - a, a, 0.0, 0.0]]
		return w
	_tube(P_TORSO, rings, segs, eval, used, weights, Vector3.UP, 0)


func _build_arm(side: int, sp: float) -> void:
	var y0 := 0.822
	var y1 := 0.485
	var sh_x := (0.105 if sex == "male" else 0.100)
	var out_x := (0.135 if sex == "male" else 0.140)
	var rings := maxi(4, ceili((y0 - y1) * h / sp))
	var segs := _even(maxi(8, ceili(TAU * 0.031 * h / sp)))
	var fem := sex == "female"
	var used := [0, 1, 2, 3]
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var yf := lerpf(y0, y1, s)
		var r2 := _table2(ARM, yf)
		var rx: float = r2.x * (0.88 if fem else 1.0)
		var rz: float = r2.y * (0.88 if fem else 1.0)
		var th := t * TAU
		var c := cos(th)
		var sn := sin(th)
		var r := 1.0 / sqrt((c / rx) * (c / rx) + (sn / rz) * (sn / rz))
		var amp_mul := 0.6 if fem else 1.0
		match k:
			1: r *= 1.0 + 0.16 * smoothstep(0.6, 0.72, yf) + 0.06; amp_mul *= 0.6
			2: r *= 0.9
			3: r *= 1.05; amp_mul *= 1.9
		var deg := rad_to_deg(th)
		for b in ARM_BUMPS:
			r += _bump(yf, deg, b[1], b[2], b[3], b[4], b[5] * amp_mul)
		var cx := lerpf(sh_x, out_x, s)
		return Vector3(side * (cx + c * r), yf, sn * r) * h
	var weights := func(p: Vector3) -> Array:
		var yf := p.y / h
		var ua := B_UPPERARM_L if side < 0 else B_UPPERARM_R
		if yf > 0.79:
			return _w2(ua, B_CHEST, 1.0 - 0.4 * smoothstep(0.79, 0.825, yf))
		if yf > Y_ELBOW - 0.03:
			return _w2(ua, ua + 1, smoothstep(Y_ELBOW - 0.02, Y_ELBOW + 0.02, yf))
		return _w2(ua + 1, ua + 2, smoothstep(Y_WRIST - 0.004, Y_WRIST + 0.012, yf))
	_tube(P_ARM, rings, segs, eval, used, weights, Vector3.UP, side)


func _build_hand(side: int, sp: float) -> void:
	var y0 := 0.487
	var y1 := 0.38
	var x0 := (0.135 if sex == "male" else 0.140)
	var rings := maxi(4, ceili((y0 - y1) * h / sp))
	var segs := _even(maxi(8, ceili(TAU * 0.017 * h / sp)))
	var fem := sex == "female"
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var yf := lerpf(y0, y1, s)
		var r2 := _table2(HAND, yf)
		var f := 0.9 if fem else 1.0
		if k == 1: f *= 1.08
		var rx: float = r2.x * f
		var rz: float = r2.y * f
		var th := t * TAU
		var c := cos(th)
		var sn := sin(th)
		var r := 1.0 / sqrt((c / rx) * (c / rx) + (sn / rz) * (sn / rz))
		return Vector3(side * (x0 + 0.003 * s + c * r), yf, sn * r) * h
	var weights := func(_p: Vector3) -> Array:
		return _w2(B_HAND_L if side < 0 else B_HAND_R, 0, 1.0)
	if lod == 2:
		_tube(P_HAND, rings, segs, eval, [0, 1], weights, Vector3.UP, side)
		return
	# Palm, then four fingers and a thumb, each with knuckle and nail detail.
	var palm := func(s: float, t: float, k: int) -> Vector3:
		var yf := lerpf(y0, 0.422, s)
		var r2 := _table2(PALM, yf)
		var f := (0.9 if fem else 1.0) * (1.08 if k == 1 else 1.0)
		var th := t * TAU
		var c := cos(th)
		var sn := sin(th)
		var r := 1.0 / sqrt((c / (r2.x * f)) * (c / (r2.x * f)) + (sn / (r2.y * f)) * (sn / (r2.y * f)))
		return Vector3(side * (x0 + 0.002 * s + c * r), yf, sn * r) * h
	_tube(P_HAND, maxi(4, ceili((y0 - 0.422) * h / sp)), segs, palm, [0, 1], weights, Vector3.UP, side)
	var fs := 0.9 if fem else 1.0
	for fg in FINGERS:
		var zf: float = fg[1] * fs
		var fl: float = fg[2] * fs
		var fr: float = fg[3] * fs
		var base := Vector3(x0 + 0.002, 0.428, zf)
		var dir := Vector3(-0.08, -1.0, zf * 0.6).normalized()   # slight curl toward the palm, slight spread
		_finger(side, base, dir, fl, fr, sp, weights)
	# Thumb: from the base of the palm, forward and down.
	_finger(side, Vector3(x0 - 0.004, 0.468, -0.018 * fs), Vector3(-0.25, -0.62, -0.74).normalized(), 0.050 * fs, 0.0068 * fs, sp, weights)


## One finger: a tapered tube with knuckle swellings and a flattened nail side.
## Weighted to the hand bone (fingers keep a relaxed pose; no per-finger bones).
func _finger(side: int, base: Vector3, dir: Vector3, length: float, r0: float, sp: float, weights: Callable) -> void:
	var lateral := Vector3(1, 0, 0)
	var u := (lateral - dir * lateral.dot(dir)).normalized()   # back of the finger (nail side)
	var v := dir.cross(u).normalized()
	var rings := maxi(6, ceili(length * h / sp) + 2)
	var segs := _even(maxi(8, ceili(TAU * r0 * h / sp)))
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var th := t * TAU
		var r := r0 * lerpf(1.0, 0.78, s)
		r *= 1.0 + 0.09 * exp(-pow((s - 0.38) / 0.06, 2.0)) + 0.07 * exp(-pow((s - 0.7) / 0.05, 2.0))   # knuckles
		if s > 0.86:
			r *= sqrt(maxf(0.0, 1.0 - pow((s - 0.86) / 0.14, 2.0))) * 0.85 + 0.15   # rounded tip
		if k == 1: r *= 1.08
		var c := cos(th)
		var sn := sin(th)
		var ry := r * (0.82 if c > 0.0 else 1.0)   # nail side flatter
		var off := (u * c * ry + v * sn * r)
		var bend := s * s * 0.012                   # gentle curl along the length
		var p := base + dir * (s * length) - u * bend + off
		return Vector3(side * p.x, p.y, p.z) * h
	_tube(P_FINGER, rings, segs, eval, [0, 1], weights, -Vector3.UP, side)


func _build_foot(side: int, sp: float) -> void:
	var hip_x := (0.051 if sex == "male" else 0.057)
	var ax := hip_x * 0.8
	var z0 := 0.026
	var z1 := -0.126
	var rings := maxi(4, ceili((z0 - z1) * h / sp))
	var segs := _even(maxi(8, ceili(TAU * 0.022 * h / sp)))
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var row := _table3(FOOT, s)
		var a: float = row.x * (1.05 if k == 1 else 1.0)
		var b: float = row.y
		var yc: float = row.z
		var th := t * TAU
		var c := cos(th)
		var sn := sin(th)
		var r := 1.0 / sqrt((c / a) * (c / a) + (sn / b) * (sn / b))
		return Vector3(side * (ax + 0.008 * s + c * r), yc + sn * r, lerpf(z0, z1, s)) * h
	var weights := func(p: Vector3) -> Array:
		var foot := B_FOOT_L if side < 0 else B_FOOT_R
		var a := 0.3 * smoothstep(0.045 * h, 0.055 * h, p.y)
		return _w2(foot, foot - 1, 1.0 - a)
	_tube(P_FOOT, rings, segs, eval, [0, 1], weights, Vector3.BACK, side)


func _build_neck(sp: float) -> void:
	var y0 := 0.80
	var y1 := 0.885
	var rings := maxi(4, ceili((y1 - y0) * h / sp))
	var segs := _even(maxi(8, ceili(TAU * 0.034 * h / sp)))
	var fem := sex == "female"
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var yf := lerpf(y0, y1, s)
		var r := lerpf(0.034, 0.031, s) * (0.85 if fem else 1.0)
		if k == 1: r *= 1.12
		if k == 3: r *= 1.06
		var th := t * TAU
		var deg := rad_to_deg(th)
		if not fem:
			r += _bump(yf, deg, 0.855, 270.0, 0.008, 15.0, 0.003)
		r += _bump(yf, deg, 0.84, 90.0, 0.04, 50.0, 0.004 if k == 3 else 0.002)  # trapezius
		var zc := lerpf(0.0, -0.006, s)
		return Vector3(cos(th) * r, yf, sin(th) * r + zc) * h
	var weights := func(p: Vector3) -> Array:
		var yf := p.y / h
		if yf < 0.83: return _w2(B_CHEST, B_NECK, 1.0 - smoothstep(0.80, 0.83, yf))
		return _w2(B_NECK, B_HEAD, 1.0 - smoothstep(0.865, 0.885, yf))
	_tube(P_NECK, rings, segs, eval, [0, 1, 2, 3], weights, Vector3.UP, 0)


func _build_head(sp: float) -> void:
	var y0 := 0.862
	var y1 := 1.0
	var rings := maxi(6, ceili((y1 - y0) * h / sp))
	var segs := _even(maxi(12, ceili(TAU * 0.05 * h / sp)))
	var fem := sex == "female"
	var eval := func(s: float, t: float, k: int) -> Vector3:
		var yf := lerpf(y0, y1, s)
		var row := _table3(HEAD, yf)
		var a: float = row.x * (0.96 if fem else 1.0)
		var b: float = row.y * (0.97 if fem else 1.0)
		var zc: float = row.z
		if k == 1 and yf < 0.9: a *= 1.12; b *= 1.08
		var th := t * TAU
		var c := cos(th)
		var sn := sin(th)
		var r := 0.0
		if a > 0.0:
			var n := 2.2
			r = pow(pow(absf(c / a), n) + pow(absf(sn / b), n), -1.0 / n)
			var deg := rad_to_deg(th)
			for bump in HEAD_BUMPS:
				var amp: float = bump[5]
				if fem and (bump[0] == "brow" or bump[0] == "nose"): amp *= 0.8
				r += _bump(yf, deg, bump[1], bump[2], bump[3], bump[4], amp)
		return Vector3(c * r, yf, sn * r + zc) * h
	var weights := func(_p: Vector3) -> Array:
		return _w2(B_HEAD, 0, 1.0)
	_tube(P_HEAD, rings, segs, eval, [0, 1], weights, Vector3.UP, 0)


# --- tube machinery -----------------------------------------------------------

## Lofts one part: `rings` cross-sections of `segs` vertices (+1 seam column),
## closed at both ends. `eval(s, t, shape)` gives the rest-pose position.
## Shapes not listed in `used` copy the base, so blend shapes stay sparse.
func _tube(part: int, rings: int, segs: int, eval: Callable, used: Array, weights: Callable, axis: Vector3, side: int) -> void:
	var cols := segs + 1
	var grids: Array = []
	grids.resize(_shape_count)
	for k in _shape_count:
		if k != 0 and not used.has(k):
			continue
		var g := PackedVector3Array()
		g.resize(rings * cols)
		for i in rings:
			var s := float(i) / float(rings - 1)
			for j in segs:
				g[i * cols + j] = eval.call(s, float(j) / float(segs), k)
			g[i * cols + segs] = g[i * cols]
		grids[k] = g
	var base_n := _grid_normals(grids[0], rings, cols, segs)
	var start: int = _v[0].size()
	var base: PackedVector3Array = grids[0]
	# Base attributes.
	for i in rings:
		for j in cols:
			var p: Vector3 = base[i * cols + j]
			_uv.append(Vector2(float(part) + (0.5 if side > 0 else 0.0), p.y / h))
			_uv2.append(Vector2(float(j) / float(segs), float(i) / float(rings - 1)))
			var w: Array = weights.call(p)
			_append_weights(w)
	# Caps: one center vertex at each end.
	var cap_ids := [start + rings * cols, start + rings * cols + 1]
	for ci in 2:
		var ring := 0 if ci == 0 else rings - 1
		var c := _ring_center(base, ring, cols, segs)
		_uv.append(Vector2(float(part) + (0.5 if side > 0 else 0.0), c.y / h))
		_uv2.append(Vector2(0.5, 0.0 if ci == 0 else 1.0))
		_append_weights(weights.call(c))
	for k in _shape_count:
		var g: PackedVector3Array = grids[k] if grids[k] != null else base
		var nrm: PackedVector3Array = base_n if grids[k] == null else (base_n if k == 0 else _grid_normals(g, rings, cols, segs))
		_v[k].append_array(g)
		_n[k].append_array(nrm)
		for ci in 2:
			var ring := 0 if ci == 0 else rings - 1
			var c := _ring_center(g, ring, cols, segs)
			var nb := _ring_center(g, 1 if ci == 0 else rings - 2, cols, segs)
			_v[k].append(c)
			var d := c - nb
			_n[k].append(d.normalized() if d.length_squared() > 1e-12 else (axis if ci == 1 else -axis))
	# Triangles. Godot's front faces wind clockwise.
	for i in rings - 1:
		for j in segs:
			var a: int = start + i * cols + j
			var b: int = a + 1
			var c: int = a + cols
			var d: int = c + 1
			_tri(a, b, c, grids[0], start)
			_tri(b, d, c, grids[0], start)
	for j in segs:
		_tri(cap_ids[0], start + j + 1, start + j, grids[0], start)
		var last: int = start + (rings - 1) * cols
		_tri(cap_ids[1], last + j, last + j + 1, grids[0], start)


var _winding_checked := false
var _flip := false

func _tri(a: int, b: int, c: int, _g, _start) -> void:
	if _flip:
		_idx.append_array([a, c, b])
	else:
		_idx.append_array([a, b, c])


func _grid_normals(g: PackedVector3Array, rings: int, cols: int, segs: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(rings * cols)
	for i in rings:
		var ip := mini(i + 1, rings - 1)
		var im := maxi(i - 1, 0)
		var c := _ring_center(g, i, cols, segs)
		for j in segs:
			var jp := (j + 1) % segs
			var jm := (j - 1 + segs) % segs
			var ds := g[ip * cols + j] - g[im * cols + j]
			var dt := g[i * cols + jp] - g[i * cols + jm]
			var n := ds.cross(dt)
			var p := g[i * cols + j]
			if n.length_squared() < 1e-14:
				n = p - c
			n = n.normalized()
			if n.dot(p - c) < 0.0:
				n = -n
			out[i * cols + j] = n
		out[i * cols + segs] = out[i * cols]
	return out


func _ring_center(g: PackedVector3Array, ring: int, cols: int, segs: int) -> Vector3:
	var c := Vector3.ZERO
	for j in segs:
		c += g[ring * cols + j]
	return c / float(segs)


func _append_weights(w: Array) -> void:
	var bones: Array = w[0]
	var ws: Array = w[1]
	for q in 4:
		_bones.append(bones[q])
		_weights.append(ws[q])


static func _w2(b0: int, b1: int, w0: float) -> Array:
	w0 = clampf(w0, 0.0, 1.0)
	if w0 >= 0.999:
		return [[b0, 0, 0, 0], [1.0, 0.0, 0.0, 0.0]]
	if w0 <= 0.001:
		return [[b1, 0, 0, 0], [1.0, 0.0, 0.0, 0.0]]
	return [[b0, b1, 0, 0], [w0, 1.0 - w0, 0.0, 0.0]]


static func _bump(y: float, deg: float, y0: float, t0: float, sy: float, st: float, amp: float) -> float:
	var dy := (y - y0) / sy
	if dy * dy > 16.0:
		return 0.0
	var dt := fposmod(deg - t0 + 180.0, 360.0) - 180.0
	dt /= st
	if dt * dt > 16.0:
		return 0.0
	return amp * exp(-dy * dy - dt * dt)


static func _band(y: float, a: float, b: float) -> float:
	var m := (a + b) * 0.5
	var w := (b - a) * 0.5
	var d := (y - m) / w
	return exp(-d * d * 2.0)


## Linear lookup in [[key, x, y], ...] tables sorted either way by key.
static func _table2(t: Array, key: float) -> Vector2:
	var r := _table3(t, key)
	return Vector2(r.x, r.y)


static func _table3(t: Array, key: float) -> Vector3:
	var asc: bool = t[0][0] < t[t.size() - 1][0]
	for i in t.size() - 1:
		var k0: float = t[i][0]
		var k1: float = t[i + 1][0]
		var inside := (key >= k0 and key <= k1) if asc else (key <= k0 and key >= k1)
		if inside:
			var f := (key - k0) / (k1 - k0) if k1 != k0 else 0.0
			f = f * f * (3.0 - 2.0 * f) * 0.35 + f * 0.65  # gentle smoothing between rows
			var a: Array = t[i]
			var b: Array = t[i + 1]
			return Vector3(lerpf(a[1], b[1], f), lerpf(a[2], b[2], f), lerpf(a[3] if a.size() > 3 else 0.0, b[3] if b.size() > 3 else 0.0, f))
	var e: Array = t[0] if ((key < t[0][0]) == asc) else t[t.size() - 1]
	return Vector3(e[1], e[2], e[3] if e.size() > 3 else 0.0)


static func _even(n: int) -> int:
	return n + (n % 2)
