class_name PropModels
extends RefCounted
## The street prop catalog (CLAUDE.md §13 street furniture + clutter, original designs at real
## dimensions). build(name) returns {mesh, shadow, range, collide} where
##   range   = base visibility distance in meters (scaled by quality),
##   shadow  = casts shadows,
##   collide = Vector3 box size (or Vector3.ZERO) and the box sits on the model's base.
## Models face +Z unless noted; benches seat toward -Z and shelters open toward -Z (same as the web
## city's street furniture so the exported rotations match).

static var _mats := {}


static func materials() -> Dictionary:
	if _mats.is_empty():
		var solid := ShaderMaterial.new()
		solid.shader = load("res://world/shaders/prop.gdshader")
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.06, 0.08, 0.09, 0.42)
		glass.roughness = 0.04
		glass.metallic = 0.2
		glass.metallic_specular = 0.9
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		var leaf := ShaderMaterial.new()
		leaf.shader = load("res://world/shaders/foliage.gdshader")
		var card := ShaderMaterial.new()
		card.shader = leaf.shader
		card.set_shader_parameter("cards", true)
		_mats = {"solid": solid, "glass": glass, "leaf": leaf, "card": card}
	return _mats


static func pc(key: String, fb := Color(0.5, 0.5, 0.5)) -> Color:
	return CityData.color(key, fb)


const NAMES := ["bench", "bikerack", "hydrant", "shelter", "newsbox", "newsbox2", "trash", "recycle", "bollard",
	"meter", "manhole", "signal", "blade", "log", "stump", "bicycle", "tree_grate", "drain", "stop_sign",
	"signal_cabinet", "parking_sign", "speed_sign", "bus_sign", "mailbox_blue", "utility_box", "planter_big",
	"planter", "aframe", "mailbox_post", "rollcart_trash", "rollcart_recycle", "dumpster", "pallet_stack",
	"trash_bag", "cardboard", "litter_cup", "litter_can", "litter_paper", "litter_bottle", "litter_wrapper",
	"litter_flyer", "hedge", "shrub", "shrub_wild", "fern", "weeds", "leaf_pile", "rock", "picnic_table",
	"cone", "barricade", "car_sedan", "car_hatch", "car_suv", "car_pickup", "car_van", "car_wagon",
	"lamp_acorn", "lamp_lantern", "lamp_cobra", "pole"]


static func build(name: String, detail := 1.0) -> Dictionary:
	var g := PropBuilder.new()
	var info := {"shadow": true, "range": 120.0, "collide": Vector3.ZERO}
	var iron := pc("IRON_BLACK", Color(0.1, 0.1, 0.1))
	var green := pc("IRON_GREEN", Color(0.12, 0.23, 0.18))
	var galv := pc("GALV_STEEL", Color(0.56, 0.58, 0.59))
	match name:
		"bench":
			g.mat("satin", green)
			for x in [-0.8, 0.0, 0.8]:
				g.box(x - 0.03, 0, -0.25, x + 0.03, 0.45, -0.2); g.box(x - 0.03, 0, 0.2, x + 0.03, 0.45, 0.25)
				g.box(x - 0.03, 0.4, -0.25, x + 0.03, 0.45, 0.25); g.box(x - 0.03, 0.45, 0.2, x + 0.03, 0.85, 0.25)
				g.box(x - 0.025, 0.45, -0.27, x + 0.025, 0.6, -0.23)   # armrest scroll
			g.mat("wood", pc("BENCH_SLAT", Color(0.54, 0.42, 0.28)))
			for i in 5:
				g.box(-0.915, 0.45, -0.24 + i * 0.09, 0.915, 0.48, -0.17 + i * 0.09)
			for i in 3:
				g.box(-0.915, 0.55 + i * 0.1, 0.23, 0.915, 0.62 + i * 0.1, 0.26)
			info.collide = Vector3(1.85, 0.85, 0.55)
		"bikerack":
			g.mat("metal", galv)
			for x in [-0.4, 0.4]:
				g.bar(Vector3(x - 0.25, 0, 0), Vector3(x - 0.25, 0.7, 0), 0.025, 8, true)
				g.bar(Vector3(x + 0.25, 0, 0), Vector3(x + 0.25, 0.7, 0), 0.025, 8, true)
				for k in 6:
					var a0 := PI * k / 6.0
					var a1 := PI * (k + 1) / 6.0
					g.bar(Vector3(x - cos(a0) * 0.25, 0.7 + sin(a0) * 0.1, 0), Vector3(x - cos(a1) * 0.25, 0.7 + sin(a1) * 0.1, 0), 0.025, 8)
			info.range = 90.0
			info.collide = Vector3(1.4, 0.8, 0.1)
		"hydrant":
			g.mat("gloss", pc("HYDRANT_RED", Color(0.79, 0.19, 0.17)))
			g.lathe([Vector2(0.12, 0), Vector2(0.12, 0.08), Vector2(0.095, 0.1), Vector2(0.095, 0.62), Vector2(0.12, 0.66), Vector2(0.11, 0.72)], 14)
			g.mat("gloss", pc("HYDRANT_CAP", Color(0.9, 0.89, 0.85)))
			g.lathe([Vector2(0.11, 0.72), Vector2(0.09, 0.8), Vector2(0.03, 0.86), Vector2(0.02, 0.9), Vector2(0.0, 0.9)], 14)
			for a in [0.0, PI, PI * 0.5]:
				g.push(); g.rotate_y(a); g.translate(0, 0.48, 0); g.rotate_x(PI * 0.5)
				var rr := 0.06 if a == PI * 0.5 else 0.045
				g.cyl(rr, 0.0, 0.16, 10, true)
				g.cyl(rr * 0.5, 0.16, 0.19, 6, true)   # pentagon nut
				g.pop()
			info.range = 80.0
			info.collide = Vector3(0.35, 0.9, 0.35)
		"shelter":
			g.mat("satin", pc("ONSU_NAVY", Color(0.08, 0.17, 0.3)))
			for p in [Vector2(-2.0, -0.6), Vector2(2.0, -0.6), Vector2(-2.0, 0.6), Vector2(2.0, 0.6)]:
				g.box(p.x - 0.05, 0, p.y - 0.05, p.x + 0.05, 2.5, p.y + 0.05)
			g.box(-2.15, 2.5, -0.75, 2.15, 2.62, 0.75)
			g.box(-2.0, 0.2, 0.57, 2.0, 0.24, 0.62)
			g.mat("paint", pc("TRIM_WHITE", Color(0.95, 0.94, 0.91)))
			g.box(1.2, 0.4, 0.55, 1.95, 2.0, 0.58)
			g.mat("glow", Color(0.95, 0.95, 0.9))
			g.box(1.25, 0.45, 0.545, 1.9, 1.95, 0.551)
			g.mat("metal", galv)
			for x in [-1.5, -1.0, -0.5, 0.0, 0.5]:
				g.box(x, 0.45, 0.3, x + 0.45, 0.48, 0.55)
			g.box(-1.55, 0.0, 0.4, -1.5, 0.45, 0.45); g.box(0.9, 0.0, 0.4, 0.95, 0.45, 0.45)
			g.mat("glass", Color.WHITE)
			g.box(-2.0, 0.2, 0.595, 2.0, 2.4, 0.605)
			g.box(-2.005, 0.2, -0.55, -1.995, 2.4, 0.55)
			info.collide = Vector3(4.3, 2.6, 0.25)
		"newsbox", "newsbox2":
			var c := pc("AWNING_HARBOR_BLUE", Color(0.12, 0.3, 0.47)) if name == "newsbox" else pc("CURB_PAINT_RED", Color(0.66, 0.2, 0.16))
			g.mat("gloss", c)
			g.cbox(-0.25, 0.3, -0.2, 0.25, 1.05, 0.2, 0.02)
			g.box(-0.26, 1.03, -0.22, 0.26, 1.07, 0.21)
			g.mat("paint", Color(0.92, 0.9, 0.84))
			g.box(-0.19, 0.62, -0.212, 0.19, 0.93, -0.205)
			g.mat("metal", galv)
			g.box(-0.08, 0.52, -0.22, 0.08, 0.56, -0.2)
			g.mat("satin", iron)
			for x in [-0.22, 0.22]:
				g.box(x - 0.02, 0, -0.18, x + 0.02, 0.3, 0.18)
			g.mat("glass", Color.WHITE)
			g.box(-0.2, 0.6, -0.215, 0.2, 0.95, -0.212)
			info.range = 80.0
			info.collide = Vector3(0.52, 1.07, 0.44)
		"trash", "recycle":
			var c := iron if name == "trash" else pc("AWNING_HARBOR_BLUE", Color(0.12, 0.3, 0.47))
			g.mat("satin", c)
			g.lathe([Vector2(0.27, 0.0), Vector2(0.27, 0.03), Vector2(0.29, 0.05), Vector2(0.3, 0.88), Vector2(0.32, 0.9), Vector2(0.32, 0.93), Vector2(0.2, 0.98), Vector2(0.12, 1.0), Vector2(0.0, 1.0)], 18)
			for i in 18:
				var a := TAU * i / 18.0
				g.bar(Vector3(sin(a) * 0.3, 0.08, cos(a) * 0.3), Vector3(sin(a) * 0.312, 0.86, cos(a) * 0.312), 0.012, 4)
			g.mat("paint", Color(0.05, 0.05, 0.05))
			g.box(-0.13, 0.86, -0.33, 0.13, 0.95, -0.3)   # deposit opening
			if name == "recycle":
				g.mat("paint", Color(0.93, 0.93, 0.9))
				g.lathe([Vector2(0.302, 0.55), Vector2(0.302, 0.66)], 18, false)
			info.range = 90.0
			info.collide = Vector3(0.62, 1.0, 0.62)
		"bollard":
			g.mat("satin", iron)
			g.lathe([Vector2(0.1, 0), Vector2(0.1, 0.8), Vector2(0.11, 0.85), Vector2(0.07, 0.95), Vector2(0.005, 1.0)], 12)
			g.mat("paint", Color(0.9, 0.9, 0.86))
			g.lathe([Vector2(0.101, 0.66), Vector2(0.101, 0.72)], 12, false)
			info.range = 80.0
			info.collide = Vector3(0.22, 1.0, 0.22)
		"meter":
			g.mat("metal", galv)
			g.cyl(0.035, 0, 1.1, 8)
			g.cbox(-0.1, 1.1, -0.08, 0.1, 1.42, 0.08, 0.03)
			g.lathe([Vector2(0.1, 1.42), Vector2(0.07, 1.49), Vector2(0.0, 1.5)], 10)
			g.mat("paint", Color(0.1, 0.1, 0.1))
			g.box(-0.06, 1.24, -0.085, 0.06, 1.38, -0.081)
			g.mat("glass", Color.WHITE)
			g.box(-0.07, 1.28, -0.086, 0.07, 1.4, -0.084)
			info.range = 70.0
			info.collide = Vector3(0.2, 1.5, 0.2)
		"manhole":
			g.mat("satin", iron)
			g.lathe([Vector2(0.33, 0.0), Vector2(0.33, 0.004), Vector2(0.0, 0.006)], 24, false)
			for r in [0.08, 0.18, 0.28]:
				g.lathe([Vector2(r + 0.012, 0.004), Vector2(r + 0.012, 0.009), Vector2(r, 0.009), Vector2(r, 0.004)], 24, false)
			for i in 12:
				g.push(); g.rotate_y(PI * i / 12.0); g.box(-0.28, 0.004, -0.006, 0.28, 0.008, 0.006, false); g.pop()
			info.shadow = false
			info.range = 60.0
		"signal":
			g.mat("metal", galv)
			g.cyl(0.16, 0, 0.3, 14, true, 0, 0, 0.13)
			g.cyl(0.13, 0.3, 7.2, 14, true, 0, 0, 0.1)
			g.bar(Vector3(0, 7.0, 0), Vector3(0, 6.8, -9.0), 0.1, 10, true)
			g.bar(Vector3(0, 6.0, 0), Vector3(0, 6.9, -3.0), 0.05, 6)
			for z in [-3.5, -6.8]:
				g.mat("paint", pc("MARKING_YELLOW", Color(0.91, 0.73, 0.14)))
				g.box(-0.27, 5.6, z - 0.08, 0.27, 6.8, z - 0.05)
				g.mat("paint", pc("MARKING_WHITE", Color(0.93, 0.93, 0.9)))
				g.box(-0.29, 5.58, z - 0.085, 0.29, 6.82, z - 0.079)
				g.mat("satin", pc("SIGNAL_HEAD", Color(0.17, 0.17, 0.17)))
				g.box(-0.17, 5.7, z - 0.05, 0.17, 6.7, z + 0.25)
				for e in [[6.55, Color(1.0, 0.23, 0.18)], [6.2, Color(0.91, 0.73, 0.14)], [5.85, Color(0.31, 0.6, 0.35)]]:
					g.mat("glow", e[1])
					g.push(); g.translate(0, e[0], z - 0.06); g.rotate_x(PI * 0.5); g.cyl(0.1, -0.01, 0.01, 12); g.pop()
					g.mat("satin", pc("SIGNAL_HEAD", Color(0.17, 0.17, 0.17)))
					g.box(-0.13, e[0] + 0.08, z - 0.2, 0.13, e[0] + 0.1, z - 0.05)   # visor
			g.mat("satin", pc("SIGNAL_HEAD", Color(0.17, 0.17, 0.17)))
			g.box(0.16, 2.6, -0.18, 0.5, 3.0, 0.18)
			g.mat("glow", Color(1.0, 0.55, 0.2))
			g.box(0.2, 2.65, -0.181, 0.46, 2.95, -0.18)
			info.range = 300.0
			info.collide = Vector3(0.32, 7.2, 0.32)
		"blade":
			g.mat("metal", galv)
			g.cyl(0.04, 0, 3.05, 8)
			g.mat("paint", pc("SIGN_STREET_GREEN", Color(0.04, 0.42, 0.23)))
			g.box(-0.38, 2.9, -0.012, 0.38, 3.05, 0.012)
			g.box(-0.012, 2.7, -0.38, 0.012, 2.85, 0.38)
			g.mat("paint", pc("MARKING_WHITE", Color(0.93, 0.93, 0.9)))
			for i in 7:   # letters suggested by white glyph bars
				g.box(-0.3 + i * 0.085, 2.94, -0.014, -0.25 + i * 0.085, 3.01, 0.014)
				g.box(-0.014, 2.74, -0.3 + i * 0.085, 0.014, 2.81, -0.25 + i * 0.085)
			info.range = 160.0
			info.collide = Vector3(0.1, 3.0, 0.1)
		"log":
			var bark := pc("OAK_BARK", Color(0.36, 0.35, 0.33))
			g.mat("wood", bark)
			g.push(); g.translate(0, 0.22, 0); g.rotate_z(PI * 0.5)
			g.lathe([Vector2(0.0, -2.3), Vector2(0.2, -2.3), Vector2(0.24, -2.1), Vector2(0.23, 0.0), Vector2(0.25, 2.1), Vector2(0.21, 2.3), Vector2(0.0, 2.3)], 12, false)
			g.pop()
			g.push(); g.translate(-0.6, 0.3, 0); g.rotate_x(-0.9); g.cyl(0.08, 0, 0.7, 8, true, 0, 0, 0.05); g.pop()
			g.mat("paint", pc("MOSS", Color(0.31, 0.37, 0.17)))
			g.blob(Vector3(-0.3, 0.42, 0.0), Vector3(1.3, 0.06, 0.15), 0.2, 5)
			g.mat("wood", pc("WALNUT_DARK", Color(0.31, 0.21, 0.14)))
			g.push(); g.translate(2.3, 0.22, 0); g.rotate_z(-PI * 0.5); g.disc(0.2, 0.001, 12); g.pop()
			info.range = 110.0
			info.collide = Vector3(4.6, 0.45, 0.5)
		"stump":
			g.mat("wood", pc("OAK_BARK", Color(0.36, 0.35, 0.33)))
			g.lathe([Vector2(0.46, 0), Vector2(0.4, 0.12), Vector2(0.36, 0.4), Vector2(0.35, 0.55)], 12, false)
			g.mat("wood", pc("WALNUT_DARK", Color(0.31, 0.21, 0.14)))
			g.lathe([Vector2(0.35, 0.55), Vector2(0.2, 0.56), Vector2(0.0, 0.565)], 12, false)
			info.range = 90.0
			info.collide = Vector3(0.8, 0.55, 0.8)
		"bicycle":
			_bicycle(g)
			info.range = 70.0
		"tree_grate":
			g.mat("satin", iron)
			g.box(-0.6, 0, -0.6, 0.6, 0.02, -0.55, false); g.box(-0.6, 0, 0.55, 0.6, 0.02, 0.6, false)
			g.box(-0.6, 0, -0.55, -0.55, 0.02, 0.55, false); g.box(0.55, 0, -0.55, 0.6, 0.02, 0.55, false)
			for i in 9:
				var r := 0.26 + i * 0.033
				g.lathe([Vector2(r + 0.008, 0.012), Vector2(r, 0.016), Vector2(r - 0.008, 0.012)], 20, false)
			for i in 8:
				g.push(); g.rotate_y(TAU * i / 8.0); g.box(0.24, 0, -0.008, 0.58, 0.018, 0.008, false); g.pop()
			info.shadow = false
			info.range = 60.0
		"drain":
			g.mat("satin", iron)
			g.box(-0.45, 0, -0.22, 0.45, 0.01, -0.19, false); g.box(-0.45, 0, 0.19, 0.45, 0.01, 0.22, false)
			for i in 11:
				var z := -0.19 + i * 0.038
				g.box(-0.45, 0, z, 0.45, 0.012, z + 0.012, false)
			g.mat("paint", Color(0.02, 0.02, 0.02))
			g.box(-0.43, -0.002, -0.19, 0.43, -0.001, 0.19, false)
			info.shadow = false
			info.range = 50.0
		"stop_sign":
			g.mat("metal", galv)
			g.box(-0.03, 0, -0.03, 0.03, 2.55, 0.03)
			g.push(); g.translate(0, 2.2, 0.035)
			g.mat("gloss", pc("CURB_PAINT_RED", Color(0.75, 0.12, 0.1)))
			_octagon(g, 0.38, 0.0, 0.012)
			g.mat("paint", Color(0.96, 0.96, 0.94))
			_octagon_ring(g, 0.38, 0.35, 0.0125)
			for i in 4:   # the word, as four white glyph blocks
				g.box(-0.24 + i * 0.125, -0.07, 0.0, -0.15 + i * 0.125, 0.07, 0.014)
			g.pop()
			info.range = 160.0
			info.collide = Vector3(0.1, 2.6, 0.1)
		"signal_cabinet":
			g.mat("paint", pc("CONCRETE_AGED", Color(0.65, 0.64, 0.6)))
			g.box(-0.5, 0, -0.35, 0.5, 0.12, 0.35)
			g.mat("satin", Color(0.62, 0.64, 0.62))
			g.cbox(-0.42, 0.12, -0.28, 0.42, 1.45, 0.28, 0.02)
			g.box(-0.44, 1.45, -0.3, 0.44, 1.5, 0.3)
			g.mat("metal", galv)
			g.box(0.2, 0.7, -0.295, 0.24, 0.9, -0.28)
			info.collide = Vector3(1.0, 1.5, 0.7)
		"parking_sign", "speed_sign", "bus_sign":
			g.mat("metal", galv)
			g.box(-0.025, 0, -0.025, 0.025, 2.6, 0.025)
			g.push(); g.translate(0, 2.1, 0.03)
			var face := Color(0.96, 0.96, 0.94)
			var ink := pc("SIGN_STREET_GREEN", Color(0.04, 0.42, 0.23)) if name == "parking_sign" else Color(0.08, 0.08, 0.08)
			if name == "bus_sign":
				face = pc("ONSU_NAVY", Color(0.08, 0.17, 0.3)); ink = Color(0.96, 0.96, 0.94)
			g.mat("paint", face)
			g.box(-0.23, -0.3, 0.0, 0.23, 0.3, 0.01)
			g.mat("paint", ink)
			g.box(-0.21, -0.28, 0.011, 0.21, -0.265, 0.012); g.box(-0.21, 0.265, 0.011, 0.21, 0.28, 0.012)
			if name == "parking_sign":
				g.box(-0.08, -0.05, 0.011, -0.03, 0.2, 0.013); g.box(-0.08, 0.12, 0.011, 0.08, 0.2, 0.013); g.box(0.04, 0.03, 0.011, 0.08, 0.2, 0.013); g.box(-0.08, 0.03, 0.011, 0.08, 0.08, 0.013)
				for i in 3:
					g.box(-0.16, -0.22 + i * 0.06, 0.011, 0.16, -0.2 + i * 0.06, 0.012)
			elif name == "speed_sign":
				g.box(-0.16, 0.12, 0.011, 0.16, 0.18, 0.012)
				g.box(-0.13, -0.2, 0.011, -0.02, 0.05, 0.013); g.box(0.02, -0.2, 0.011, 0.13, 0.05, 0.013)
			else:
				g.box(-0.15, -0.05, 0.011, 0.15, 0.15, 0.013)
				g.box(-0.12, -0.2, 0.011, -0.04, -0.12, 0.013); g.box(0.04, -0.2, 0.011, 0.12, -0.12, 0.013)
			g.pop()
			info.range = 120.0
			info.collide = Vector3(0.08, 2.6, 0.08)
		"mailbox_blue":
			g.mat("gloss", pc("ONSU_NAVY", Color(0.08, 0.17, 0.3)))
			g.box(-0.3, 0.12, -0.27, 0.3, 1.02, 0.27)
			g.push(); g.translate(0, 1.02, 0); g.rotate_z(PI * 0.5); g.cyl(0.27, -0.3, 0.3, 14, true); g.pop()
			g.mat("satin", Color(0.05, 0.08, 0.14))
			for p in [Vector2(-0.26, -0.23), Vector2(0.26, -0.23), Vector2(-0.26, 0.23), Vector2(0.26, 0.23)]:
				g.box(p.x - 0.03, 0, p.y - 0.03, p.x + 0.03, 0.14, p.y + 0.03)
			g.box(-0.18, 1.05, 0.26, 0.18, 1.12, 0.3)   # pull-down slot
			g.mat("paint", Color(0.92, 0.92, 0.9))
			g.box(-0.18, 0.55, 0.271, 0.18, 0.75, 0.275)
			info.collide = Vector3(0.62, 1.3, 0.56)
		"utility_box":
			g.mat("paint", Color(0.24, 0.32, 0.24))
			g.cbox(-0.55, 0, -0.42, 0.55, 0.95, 0.42, 0.03)
			g.box(-0.57, 0.95, -0.44, 0.57, 0.99, 0.44)
			g.mat("paint", Color(0.85, 0.75, 0.2))
			g.box(-0.12, 0.62, -0.425, 0.12, 0.74, -0.42)
			info.collide = Vector3(1.14, 1.0, 0.88)
		"planter_big":
			g.mat("stone", pc("CONCRETE_NEW", Color(0.74, 0.73, 0.69)))
			g.box(-0.6, 0, -0.6, 0.6, 0.06, 0.6)
			g.box(-0.56, 0.06, -0.56, 0.56, 0.56, -0.48); g.box(-0.56, 0.06, 0.48, 0.56, 0.56, 0.56)
			g.box(-0.56, 0.06, -0.48, -0.48, 0.56, 0.48); g.box(0.48, 0.06, -0.48, 0.56, 0.56, 0.48)
			g.box(-0.6, 0.56, -0.6, 0.6, 0.6, 0.6)
			g.mat("paint", pc("PINE_STRAW", Color(0.55, 0.35, 0.17)))
			g.box(-0.48, 0.06, -0.48, 0.48, 0.5, 0.48, false)
			_shrub(g, Vector3(0, 0.5, 0), Vector3(0.45, 0.45, 0.45), pc("BOXWOOD", Color(0.25, 0.36, 0.18)), 7, detail)
			info.collide = Vector3(1.2, 0.6, 1.2)
		"planter":
			g.mat("satin", Color(0.16, 0.16, 0.16))
			g.lathe([Vector2(0.16, 0), Vector2(0.24, 0.55), Vector2(0.26, 0.58), Vector2(0.26, 0.6), Vector2(0.22, 0.6), Vector2(0.21, 0.52), Vector2(0.0, 0.52)], 14)
			_shrub(g, Vector3(0, 0.52, 0), Vector3(0.3, 0.35, 0.3), pc("BOXWOOD", Color(0.25, 0.36, 0.18)), 11, detail, true)
			info.range = 80.0
			info.collide = Vector3(0.5, 0.6, 0.5)
		"aframe":
			g.mat("wood", pc("WALNUT_DARK", Color(0.31, 0.21, 0.14)))
			for s in [-1.0, 1.0]:
				g.push(); g.rotate_x(s * 0.2)
				g.box(-0.32, 0, -0.02, -0.28, 1.0, 0.02); g.box(0.28, 0, -0.02, 0.32, 1.0, 0.02)
				g.box(-0.32, 0.96, -0.02, 0.32, 1.0, 0.02); g.box(-0.32, 0.12, -0.02, 0.32, 0.16, 0.02)
				g.mat("paint", Color(0.12, 0.14, 0.13))
				g.box(-0.28, 0.16, -0.012 * s - 0.005, 0.28, 0.96, -0.012 * s + 0.005)
				g.mat("paint", Color(0.95, 0.94, 0.88))
				for i in 4:
					g.box(-0.22, 0.75 - i * 0.14, -0.02 * s - 0.004, 0.1 + 0.08 * ((i * 7) % 3), 0.79 - i * 0.14, -0.02 * s + 0.004)
				g.mat("wood", pc("WALNUT_DARK", Color(0.31, 0.21, 0.14)))
				g.pop()
			info.range = 70.0
			info.collide = Vector3(0.65, 1.0, 0.45)
		"mailbox_post":
			g.mat("wood", Color(0.93, 0.92, 0.88))
			g.box(-0.05, 0, -0.05, 0.05, 1.05, 0.05)
			g.box(-0.1, 1.0, -0.28, 0.1, 1.04, 0.28)
			g.mat("satin", Color(0.08, 0.08, 0.08), true)
			g.box(-0.1, 1.04, -0.25, 0.1, 1.16, 0.25)
			g.push(); g.translate(0, 1.16, 0); g.rotate_x(PI * 0.5); g.cyl(0.1, -0.25, 0.25, 10, true); g.pop()
			g.mat("gloss", pc("CURB_PAINT_RED", Color(0.75, 0.12, 0.1)))
			g.box(0.1, 1.12, 0.05, 0.115, 1.3, 0.09); g.box(0.1, 1.24, 0.09, 0.115, 1.3, 0.18)
			info.range = 80.0
			info.collide = Vector3(0.22, 1.3, 0.56)
		"rollcart_trash", "rollcart_recycle":
			var c := Color(0.2, 0.22, 0.21) if name == "rollcart_trash" else Color(0.12, 0.3, 0.55)
			g.mat("plastic", c)
			g.push(); g.scale(1, 1, 1)
			g.loft([[-0.33, _rect(0.28, 0.06, 1.0)], [0.33, _rect(0.31, 0.06, 1.0)]])
			g.pop()
			g.mat("plastic", c.darkened(0.15))
			g.box(-0.34, 1.0, -0.37, 0.34, 1.05, 0.38)
			g.box(-0.3, 0.92, 0.34, 0.3, 0.96, 0.42)   # handle
			g.mat("rubber", Color(0.05, 0.05, 0.05))
			for x in [-0.27, 0.27]:
				g.push(); g.translate(x, 0.13, 0.32); g.rotate_z(PI * 0.5); g.cyl(0.13, -0.04, 0.04, 12); g.pop()
			info.range = 80.0
			info.collide = Vector3(0.62, 1.05, 0.75)
		"dumpster":
			g.mat("satin", Color(0.16, 0.3, 0.2), true)
			g.loft([[-0.9, _rect(0.9, 0.18, 1.1)], [0.9, _rect(0.9, 0.18, 1.25)]])
			g.box(-1.0, 0.95, -0.95, 1.0, 1.0, 0.95)
			g.mat("plastic", Color(0.07, 0.07, 0.07))
			g.push(); g.translate(0, 1.18, 0); g.rotate_x(-0.08)
			g.box(-0.9, 0.0, -0.92, -0.02, 0.05, 0.92); g.box(0.02, 0.0, -0.92, 0.9, 0.05, 0.92)
			g.pop()
			g.mat("rubber", Color(0.05, 0.05, 0.05))
			for p in [Vector2(-0.75, -0.7), Vector2(0.75, -0.7), Vector2(-0.75, 0.7), Vector2(0.75, 0.7)]:
				g.push(); g.translate(p.x, 0.09, p.y); g.rotate_z(PI * 0.5); g.cyl(0.09, -0.04, 0.04, 10); g.pop()
			info.range = 160.0
			info.collide = Vector3(1.85, 1.3, 2.0)
		"pallet_stack":
			g.mat("wood", Color(0.62, 0.5, 0.35))
			for k in 4:
				var y := k * 0.145
				g.push(); g.rotate_y((k % 2) * 0.06)
				for x in [-0.55, 0.0, 0.55]:
					g.box(x - 0.05, y, -0.6, x + 0.05, y + 0.1, 0.6)
				for i in 7:
					var z := -0.58 + i * 0.19
					g.box(-0.6, y + 0.1, z, 0.6, y + 0.125, z + 0.1)
				g.pop()
			info.collide = Vector3(1.2, 0.6, 1.2)
		"trash_bag":
			g.mat("plastic", Color(0.06, 0.06, 0.06), true)
			g.blob(Vector3(0, 0.27, 0), Vector3(0.3, 0.27, 0.26), 0.18, 7, 5, 9)
			g.blob(Vector3(0.02, 0.56, 0), Vector3(0.06, 0.07, 0.06), 0.2, 8, 3, 6)
			info.range = 70.0
		"cardboard":
			g.mat("paint", Color(0.62, 0.48, 0.32))
			g.push(); g.rotate_y(0.3); g.box(-0.3, 0, -0.22, 0.3, 0.4, 0.22); g.pop()
			g.push(); g.translate(0.1, 0.4, 0.05); g.rotate_y(-0.5); g.box(-0.2, 0, -0.15, 0.2, 0.25, 0.15); g.pop()
			g.push(); g.translate(-0.4, 0.0, 0.35); g.rotate_y(1.1); g.box(-0.4, 0, -0.3, 0.4, 0.02, 0.3); g.pop()
			info.range = 70.0
		"litter_cup":
			g.mat("paint", Color(0.95, 0.95, 0.93), true)
			g.push(); g.translate(0, 0.04, 0); g.rotate_z(PI * 0.5 - 0.08)
			g.lathe([Vector2(0.03, -0.07), Vector2(0.042, 0.07), Vector2(0.0, 0.07)], 10)
			g.mat("plastic", Color(0.9, 0.9, 0.9)); g.lathe([Vector2(0.045, 0.07), Vector2(0.03, 0.085), Vector2(0.0, 0.088)], 10)
			g.pop()
			info.shadow = false; info.range = 30.0
		"litter_can":
			g.mat("metal", Color(0.8, 0.2, 0.15), true)
			g.push(); g.translate(0, 0.033, 0); g.rotate_z(PI * 0.5); g.cyl(0.033, -0.06, 0.06, 10, true); g.pop()
			info.shadow = false; info.range = 30.0
		"litter_paper":
			g.mat("paint", Color(0.92, 0.91, 0.86), true)
			g.blob(Vector3(0, 0.035, 0), Vector3(0.05, 0.04, 0.045), 0.4, 3, 3, 6)
			info.shadow = false; info.range = 30.0
		"litter_bottle":
			g.mat("glass", Color.WHITE)
			g.push(); g.translate(0, 0.035, 0); g.rotate_z(PI * 0.5)
			g.lathe([Vector2(0.035, -0.11), Vector2(0.035, 0.03), Vector2(0.015, 0.08), Vector2(0.013, 0.11), Vector2(0.0, 0.11)], 10)
			g.mat("plastic", Color(0.2, 0.5, 0.25), true); g.lathe([Vector2(0.0355, -0.04), Vector2(0.0355, 0.0)], 10, false)
			g.pop()
			info.shadow = false; info.range = 30.0
		"litter_wrapper":
			g.mat("plastic", Color(0.85, 0.3, 0.2), true)
			g.quad(Vector3(-0.07, 0.006, -0.04), Vector3(0.06, 0.012, -0.05), Vector3(0.07, 0.004, 0.05), Vector3(-0.06, 0.014, 0.04))
			g.quad(Vector3(-0.06, 0.014, 0.04), Vector3(0.07, 0.004, 0.05), Vector3(0.06, 0.012, -0.05), Vector3(-0.07, 0.006, -0.04))
			info.shadow = false; info.range = 25.0
		"litter_flyer":
			g.mat("paint", Color(0.95, 0.85, 0.4), true)
			g.quad(Vector3(-0.105, 0.004, -0.14), Vector3(0.105, 0.012, -0.14), Vector3(0.105, 0.003, 0.0), Vector3(-0.105, 0.003, 0.0))
			g.quad(Vector3(-0.105, 0.003, 0.0), Vector3(0.105, 0.003, 0.0), Vector3(0.105, 0.01, 0.14), Vector3(-0.105, 0.004, 0.14))
			g.mat("paint", Color(0.1, 0.1, 0.12))
			g.quad(Vector3(-0.08, 0.0145, -0.1), Vector3(0.08, 0.0145, -0.1), Vector3(0.08, 0.009, -0.06), Vector3(-0.08, 0.009, -0.06))
			info.shadow = false; info.range = 25.0
		"hedge":
			_shrub_box(g, Vector3(0.5, 0.72, 0.6), pc("BOXWOOD", Color(0.25, 0.36, 0.18)), detail)
			info.range = 120.0
		"shrub":
			_shrub(g, Vector3(0, 0, 0), Vector3(0.6, 0.75, 0.6), Color(1, 1, 1), 3, detail)
			info.range = 120.0
		"shrub_wild":
			for i in 3:
				var a := TAU * i / 3.0 + 0.4
				_shrub(g, Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), Vector3(0.75, 1.0 + i * 0.2, 0.75), Color(1, 1, 1), 20 + i, detail * 0.8)
			info.range = 140.0
		"fern":
			_fern(g, detail)
			info.shadow = false; info.range = 45.0
		"weeds":
			_weeds(g)
			info.shadow = false; info.range = 40.0
		"leaf_pile":
			g.mat("paint", pc("FALLEN_LEAF_A", Color(0.54, 0.35, 0.18)))
			g.blob(Vector3(0, 0.0, 0), Vector3(0.8, 0.28, 0.65), 0.15, 4, 4, 9)
			var rng := RandomNumberGenerator.new(); rng.seed = 77
			var lc := [pc("FALLEN_LEAF_A", Color(0.54, 0.35, 0.18)), pc("FALLEN_LEAF_B", Color(0.69, 0.54, 0.18)), pc("FALLEN_LEAF_C", Color(0.42, 0.29, 0.16)), pc("RED_MAPLE_LEAF", Color(0.7, 0.23, 0.15))]
			for i in int(60 * detail):
				var a := rng.randf() * TAU
				var r := sqrt(rng.randf())
				var p := Vector3(cos(a) * r * 0.78, 0.0, sin(a) * r * 0.62)
				p.y = 0.28 * sqrt(max(0.0, 1.0 - r * r)) + 0.01
				g.card(p, Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)), 0.16, Vector3.UP, lc[i % 4])
			info.shadow = false; info.range = 60.0
		"rock":
			g.mat("stone", pc("FIELDSTONE_A", Color(0.54, 0.52, 0.47)))
			g.blob(Vector3(0, 0.12, 0), Vector3(0.45, 0.3, 0.35), 0.28, 13, 4, 7)
			g.mat("paint", pc("MOSS", Color(0.31, 0.37, 0.17)))
			g.blob(Vector3(0.05, 0.36, -0.05), Vector3(0.28, 0.04, 0.2), 0.2, 14, 3, 6)
			info.range = 70.0
		"picnic_table":
			g.mat("wood", pc("BENCH_SLAT", Color(0.54, 0.42, 0.28)))
			for i in 5:
				g.box(-0.9, 0.72, -0.4 + i * 0.16, 0.9, 0.76, -0.27 + i * 0.16)
			for s in [-1.0, 1.0]:
				for i in 2:
					g.box(-0.9, 0.42, s * (0.55 + i * 0.13) - 0.06, 0.9, 0.46, s * (0.55 + i * 0.13) + 0.06)
				for x in [-0.7, 0.7]:
					g.bar(Vector3(x, 0, s * 0.75), Vector3(x, 0.74, s * 0.05), 0.04, 6)
			for x in [-0.7, 0.7]:
				g.box(x - 0.04, 0.38, -0.85, x + 0.04, 0.42, 0.85)
			info.collide = Vector3(1.8, 0.8, 1.7)
		"cone":
			g.mat("plastic", Color(0.95, 0.38, 0.06))
			g.box(-0.18, 0, -0.18, 0.18, 0.03, 0.18)
			g.lathe([Vector2(0.14, 0.03), Vector2(0.03, 0.7), Vector2(0.0, 0.7)], 12)
			g.mat("plastic", Color(0.95, 0.95, 0.93))
			g.lathe([Vector2(0.1, 0.25), Vector2(0.075, 0.38)], 12, false)
			g.lathe([Vector2(0.065, 0.45), Vector2(0.05, 0.53)], 12, false)
			info.range = 90.0
			info.collide = Vector3(0.3, 0.7, 0.3)
		"barricade":
			g.mat("metal", galv)
			for x in [-0.9, 0.9]:
				g.bar(Vector3(x, 0, -0.35), Vector3(x, 1.0, 0), 0.025, 6); g.bar(Vector3(x, 0, 0.35), Vector3(x, 1.0, 0), 0.025, 6)
			for y in [0.65, 0.88]:
				for i in 6:
					g.mat("paint", Color(0.95, 0.45, 0.08) if i % 2 == 0 else Color(0.95, 0.95, 0.93))
					g.box(-1.0 + i * 0.334, y, -0.02, -0.666 + i * 0.334, y + 0.18, 0.02)
			info.collide = Vector3(2.0, 1.1, 0.7)
		"lamp_acorn":
			g.mat("satin", iron)
			g.lathe([Vector2(0.16, 0), Vector2(0.16, 0.4), Vector2(0.1, 0.5), Vector2(0.07, 0.6), Vector2(0.06, 3.6), Vector2(0.09, 3.72), Vector2(0.12, 3.8)], 12)
			g.mat("glow", Color(0.97, 0.97, 1.0))
			g.lathe([Vector2(0.12, 3.8), Vector2(0.22, 3.95), Vector2(0.23, 4.15), Vector2(0.14, 4.28), Vector2(0.04, 4.3)], 14)
			g.mat("satin", iron)
			g.lathe([Vector2(0.05, 4.28), Vector2(0.03, 4.4), Vector2(0.005, 4.5)], 8)
			info.range = 260.0
			info.collide = Vector3(0.32, 4.4, 0.32)
		"lamp_lantern":
			g.mat("satin", green)
			g.lathe([Vector2(0.13, 0), Vector2(0.13, 0.3), Vector2(0.06, 0.42), Vector2(0.05, 3.0), Vector2(0.09, 3.1)], 10)
			g.box(-0.16, 3.1, -0.16, 0.16, 3.14, 0.16)
			for p in [Vector2(-0.14, -0.14), Vector2(0.14, -0.14), Vector2(0.14, 0.14), Vector2(-0.14, 0.14)]:
				g.box(p.x - 0.01, 3.14, p.y - 0.01, p.x + 0.01, 3.52, p.y + 0.01)
			g.prism([Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(0.18, 0.18), Vector2(-0.18, 0.18)], 3.52, 3.54)
			for i in 4:
				var a0 := TAU * i / 4.0 + PI * 0.25
				var a1 := TAU * (i + 1) / 4.0 + PI * 0.25
				g.tri(Vector3(cos(a0) * 0.255, 3.54, sin(a0) * 0.255), Vector3(0, 3.72, 0), Vector3(cos(a1) * 0.255, 3.54, sin(a1) * 0.255))
			g.mat("glow", pc("LAMP_CAMPUS", Color(1.0, 0.85, 0.66)))
			g.box(-0.12, 3.16, -0.12, 0.12, 3.5, 0.12)
			info.range = 220.0
			info.collide = Vector3(0.26, 3.6, 0.26)
		"lamp_cobra":
			g.mat("metal", galv)
			g.cyl(0.11, 0, 8.2, 10, true, 0, 0, 0.07)
			g.bar(Vector3(0, 8.0, 0), Vector3(0, 8.4, -2.0), 0.06, 8)
			g.cbox(-0.22, 8.25, -2.6, 0.22, 8.45, -1.8, 0.06)
			g.mat("glow", pc("LAMP_SODIUM", Color(1.0, 0.72, 0.4)))
			g.box(-0.18, 8.22, -2.55, 0.18, 8.26, -1.85)
			info.range = 300.0
			info.collide = Vector3(0.22, 8.2, 0.22)
		"pole":
			# utility pole: treated wood, crossarm along local x, insulators, a transformer can
			g.mat("wood", Color(0.36, 0.3, 0.24))
			g.cyl(0.15, -0.2, 10.6, 10, true, 0, 0, 0.11)
			g.box(-1.1, 9.55, -0.06, 1.1, 9.68, 0.06)
			g.bar(Vector3(-0.7, 9.55, 0), Vector3(0, 9.0, 0), 0.025, 4); g.bar(Vector3(0.7, 9.55, 0), Vector3(0, 9.0, 0), 0.025, 4)
			g.mat("gloss", Color(0.55, 0.6, 0.55))
			for x in [-0.95, 0.0, 0.95]:
				g.lathe([Vector2(0.04, 9.68), Vector2(0.05, 9.72), Vector2(0.03, 9.76), Vector2(0.05, 9.8), Vector2(0.02, 9.85)], 8)
			g.mat("satin", Color(0.5, 0.52, 0.52))
			g.cyl(0.24, 7.6, 8.6, 12, true, 0.0, 0.3)
			g.mat("satin", Color(0.1, 0.1, 0.1))
			g.box(-0.18, 6.95, -0.03, 0.18, 7.0, 0.2)
			g.mat("paint", Color(0.9, 0.88, 0.2))
			g.box(-0.08, 1.6, 0.14, 0.08, 1.75, 0.16)
			info.range = 320.0
			info.collide = Vector3(0.3, 10.0, 0.3)
		_:
			if name.begins_with("car_"):
				_car(g, name.substr(4))
				info.range = 260.0
				info.collide = _CAR[name.substr(4)].size
	info.mesh = g.commit(materials())
	return info


# ------------------------------------------------------------------ helpers
static func _rect(hw: float, y0: float, y1: float) -> Array:
	return [Vector2(hw, y0), Vector2(hw, y1), Vector2(-hw, y1), Vector2(-hw, y0)]


static func _octagon(g: PropBuilder, r: float, z0: float, z1: float) -> void:
	var pts := []
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	for i in 8:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 8]
		g.tri(Vector3(0, 0, z1), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1))
		g.tri(Vector3(0, 0, z0), Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0))
		g.quad(Vector3(a.x, a.y, z0), Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(b.x, b.y, z0))


static func _octagon_ring(g: PropBuilder, r0: float, r1: float, z: float) -> void:
	for i in 8:
		var a0 := TAU * (i + 0.5) / 8.0
		var a1 := TAU * (i + 1.5) / 8.0
		g.quad(Vector3(cos(a0) * r1, sin(a0) * r1, z), Vector3(cos(a1) * r1, sin(a1) * r1, z), Vector3(cos(a1) * r0, sin(a1) * r0, z), Vector3(cos(a0) * r0, sin(a0) * r0, z))


## Rounded shrub: a mottled leaf volume plus alpha-cut leaf cards over its surface.
## Base color white = tinted per instance (the foliage shader multiplies the instance color).
static func _shrub(g: PropBuilder, base: Vector3, r: Vector3, col: Color, seed: int, detail: float, flowers := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lumps := 4
	g.mat("leaf", col)
	var centers := []
	for i in lumps:
		var a := TAU * i / lumps + rng.randf() * 0.6
		var c := base + Vector3(cos(a) * r.x * 0.35, r.y * (0.45 + rng.randf() * 0.15), sin(a) * r.z * 0.35)
		centers.append(c)
		g.blob(c, r * Vector3(0.7, 0.55, 0.7), 0.2, seed * 10 + i, 3, 6)
	g.blob(base + Vector3(0, r.y * 0.7, 0), r * Vector3(0.6, 0.4, 0.6), 0.2, seed * 7, 3, 6)
	var n := int(90 * detail)
	for i in n:
		var c: Vector3 = centers[i % lumps]
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		var p := c + d * r * Vector3(0.68, 0.55, 0.68)
		var lc := col.darkened(rng.randf_range(0.0, 0.25))
		if flowers and i % 5 == 0:
			lc = Color(0.85, 0.75, 0.35) if (seed + i) % 2 == 0 else Color(0.75, 0.25, 0.3)
		g.card(p, d, 0.34, ((p - base) * Vector3(1, 0.6, 1)).normalized(), lc)


static func _shrub_box(g: PropBuilder, h: Vector3, col: Color, detail: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	g.mat("leaf", col)
	g.blob(Vector3(0, h.y * 0.5, 0), Vector3(h.x * 1.02, h.y * 0.52, h.z * 0.52), 0.06, 3, 3, 8)
	for i in int(80 * detail):
		var f := rng.randi() % 4
		var p := Vector3(rng.randf_range(-h.x, h.x), rng.randf_range(0.1, h.y), rng.randf_range(-h.z, h.z) * 0.5)
		var nn := Vector3.UP
		if f == 0:
			p.y = h.y; nn = Vector3.UP
		elif f == 1:
			p.z = -h.z * 0.5; nn = Vector3.FORWARD
		elif f == 2:
			p.z = h.z * 0.5; nn = Vector3.BACK
		else:
			p.y = h.y * rng.randf_range(0.6, 1.0); p.z = rng.randf_range(-1, 1) * h.z * 0.5
		g.card(p, nn + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)), 0.28, nn, col.darkened(rng.randf_range(0.0, 0.22)))


static func _fern(g: PropBuilder, detail: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var col := Color(0.32, 0.45, 0.2)
	var fronds := int(9 * clampf(detail, 0.5, 1.0))
	for i in fronds:
		var a := TAU * i / fronds + rng.randf() * 0.4
		var L := rng.randf_range(0.5, 0.8)
		var dir := Vector3(cos(a), 0, sin(a))
		for k in 5:
			var t := (k + 0.5) / 5.0
			var p := dir * L * t + Vector3(0, 0.45 * sin(t * PI * 0.8) + 0.05, 0)
			g.card(p, Vector3(0, 1, 0) + dir * 0.6, 0.26 * (1.0 - t * 0.5), (dir + Vector3.UP).normalized(), col.darkened(rng.randf_range(0.0, 0.2)).lerp(Color(0.55, 0.4, 0.2), t * 0.3))


static func _weeds(g: PropBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	g.mat("leaf", Color(0.45, 0.5, 0.25))
	for i in 12:
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.15
		var b := Vector3(cos(a) * r, 0, sin(a) * r)
		var t := b + Vector3(cos(a) * 0.12, rng.randf_range(0.25, 0.5), sin(a) * 0.12)
		var s := Vector3(-sin(a), 0, cos(a)) * 0.012
		g.tri(b - s, t, b + s); g.tri(b + s, t, b - s)


static func _bicycle(g: PropBuilder) -> void:
	# along local z, wheels at z = +-0.53, tire radius 0.34; frame color = instance tint
	g.mat("rubber", Color(0.06, 0.06, 0.06))
	for z in [-0.53, 0.53]:
		g.ring(Vector3(0, 0.34, z), 0.32, 0.018, 20, 5)
	g.mat("metal", Color(0.75, 0.75, 0.76))
	for z in [-0.53, 0.53]:
		g.ring(Vector3(0, 0.34, z), 0.29, 0.008, 18, 3)
		for k in 8:
			var a := TAU * k / 8.0
			g.bar(Vector3(0, 0.34, z), Vector3(0, 0.34 + cos(a) * 0.29, z + sin(a) * 0.29), 0.0025, 3)
	g.mat("car", Color(1, 1, 1), true)
	var bb := Vector3(0, 0.3, 0.0)       # bottom bracket
	var st := Vector3(0, 0.82, -0.12)    # seat tube top
	var ht := Vector3(0, 0.86, 0.38)     # head tube top
	var hb := Vector3(0, 0.66, 0.42)     # head tube bottom
	var r := 0.016
	g.bar(bb, st, r); g.bar(st, ht, r); g.bar(bb, hb, r * 1.1); g.bar(hb, ht, r * 1.2)
	g.bar(bb, Vector3(0.05, 0.34, -0.53), r * 0.7); g.bar(bb, Vector3(-0.05, 0.34, -0.53), r * 0.7)
	g.bar(st, Vector3(0.05, 0.34, -0.53), r * 0.6); g.bar(st, Vector3(-0.05, 0.34, -0.53), r * 0.6)
	g.bar(hb, Vector3(0.04, 0.34, 0.53), r * 0.8); g.bar(hb, Vector3(-0.04, 0.34, 0.53), r * 0.8)
	g.mat("satin", Color(0.1, 0.1, 0.1))
	g.bar(st, st + Vector3(0, 0.12, -0.02), 0.012)
	g.box(-0.07, 0.94, -0.26, 0.07, 0.98, -0.02)       # saddle
	g.bar(ht, ht + Vector3(0, 0.1, -0.03), 0.013)
	g.bar(ht + Vector3(-0.3, 0.1, -0.03), ht + Vector3(0.3, 0.1, -0.03), 0.011)
	g.mat("rubber", Color(0.05, 0.05, 0.05))
	g.bar(ht + Vector3(-0.3, 0.1, -0.03), ht + Vector3(-0.2, 0.1, -0.03), 0.016); g.bar(ht + Vector3(0.2, 0.1, -0.03), ht + Vector3(0.3, 0.1, -0.03), 0.016)
	g.mat("metal", Color(0.6, 0.6, 0.6))
	g.push(); g.translate(0, 0.3, 0); g.rotate_z(PI * 0.5); g.cyl(0.08, -0.04, -0.03, 14); g.pop()


# ------------------------------------------------------------------ cars
## [length, width, y0 sill, belt, roof, z windshield base, z roof front, z roof rear, z rear glass base, tire r, hood front y, tail y]
const _CAR := {
	"sedan": {"L": 4.75, "W": 1.82, "y0": 0.26, "belt": 0.98, "roof": 1.45, "ws": 0.85, "rf": 0.12, "rr": -0.95, "rg": -1.48, "tr": 0.32, "hood": 0.8, "tail": 0.98, "size": Vector3(1.85, 1.45, 4.75)},
	"hatch": {"L": 4.15, "W": 1.77, "y0": 0.25, "belt": 0.96, "roof": 1.47, "ws": 0.78, "rf": 0.05, "rr": -1.5, "rg": -1.95, "tr": 0.31, "hood": 0.78, "tail": 1.02, "size": Vector3(1.8, 1.47, 4.15)},
	"wagon": {"L": 4.85, "W": 1.83, "y0": 0.27, "belt": 0.98, "roof": 1.5, "ws": 0.9, "rf": 0.18, "rr": -2.05, "rg": -2.3, "tr": 0.32, "hood": 0.8, "tail": 1.0, "size": Vector3(1.86, 1.5, 4.85)},
	"suv": {"L": 4.8, "W": 1.92, "y0": 0.38, "belt": 1.13, "roof": 1.76, "ws": 1.05, "rf": 0.38, "rr": -2.05, "rg": -2.3, "tr": 0.38, "hood": 1.0, "tail": 1.12, "size": Vector3(1.95, 1.76, 4.8)},
	"van": {"L": 5.1, "W": 2.0, "y0": 0.36, "belt": 1.12, "roof": 2.05, "ws": 1.95, "rf": 1.3, "rr": -2.5, "rg": -2.55, "tr": 0.36, "hood": 1.05, "tail": 1.12, "size": Vector3(2.02, 2.05, 5.1)},
	"pickup": {"L": 5.35, "W": 1.98, "y0": 0.42, "belt": 1.14, "roof": 1.85, "ws": 1.25, "rf": 0.55, "rr": -0.5, "rg": -0.6, "tr": 0.4, "hood": 1.08, "tail": 1.14, "size": Vector3(2.0, 1.85, 5.35)},
}


static func _sec(w: float, y0: float, y1: float, bv: float) -> Array:
	var b := minf(bv, (y1 - y0) * 0.4)
	return [Vector2(w - b, y0), Vector2(w, y0 + b), Vector2(w, y1 - b * 1.5), Vector2(w - b * 1.5, y1),
		Vector2(-w + b * 1.5, y1), Vector2(-w, y1 - b * 1.5), Vector2(-w, y0 + b), Vector2(-w + b, y0)]


static func _car(g: PropBuilder, kind: String) -> void:
	var c: Dictionary = _CAR[kind]
	var L: float = c.L
	var hw: float = c.W * 0.5
	var zf := L * 0.5
	var zr := -L * 0.5
	var belt: float = c.belt
	var y0: float = c.y0
	var tr: float = c.tr
	var pickup := kind == "pickup"
	var van := kind == "van"
	# --- lower body (painted): loft rear bumper -> trunk/tailgate -> cabin -> hood -> nose
	g.mat("car", Color(1, 1, 1), true)
	var tail: float = c.tail
	var st := []
	st.append([zr, _sec(hw * 0.92, y0 + 0.08, tail - 0.1, 0.1)])
	st.append([zr + 0.14, _sec(hw, y0, tail, 0.12)])
	if not pickup:
		st.append([c.rg, _sec(hw, y0, belt, 0.12)])
	else:
		st.append([c.rg - 0.04, _sec(hw, y0, belt, 0.12)])
	st.append([c.ws, _sec(hw, y0, belt - 0.02, 0.12)])
	st.append([zf - 0.35, _sec(hw * 0.985, y0, c.hood + 0.04, 0.12)])
	st.append([zf - 0.1, _sec(hw * 0.95, y0 + 0.02, c.hood - 0.04, 0.12)])
	st.append([zf, _sec(hw * 0.86, y0 + 0.1, c.hood - 0.16, 0.08)])
	if pickup:
		# cab body only from the cab back forward; the bed is built separately
		st = [[c.rg - 0.04, _sec(hw, y0, belt, 0.12)]] + st.slice(3)
	g.loft(st)
	# --- glasshouse
	var gw0 := hw - 0.05
	var gw1 := hw - 0.24
	var gs := func(h: float, bw: float, tw: float) -> Array:
		return [Vector2(bw, belt - 0.02), Vector2(tw, h), Vector2(-tw, h), Vector2(-bw, belt - 0.02)]
	var roof: float = c.roof
	g.mat("glass", Color.WHITE)
	if van:
		g.loft([[c.rf, gs.call(roof - 0.03, gw0, gw1)], [c.ws, gs.call(belt + 0.02, gw0, gw0 - 0.02)]], false)
		g.loft([[c.rf - 1.1, gs.call(roof - 0.25, hw + 0.002, hw - 0.04)], [c.rf - 0.05, gs.call(roof - 0.25, hw + 0.002, hw - 0.04)]], false)
	else:
		g.loft([[c.rg, gs.call(belt + 0.03, gw0, gw0 - 0.02)], [c.rr, gs.call(roof - 0.03, gw0 - 0.04, gw1)], [c.rf, gs.call(roof - 0.03, gw0 - 0.04, gw1)], [c.ws, gs.call(belt + 0.02, gw0, gw0 - 0.02)]], false)
	# --- roof panel and pillars (painted)
	g.mat("car", Color(1, 1, 1), true)
	if van:
		g.loft([[zr + 0.05, _sec(hw, belt - 0.05, roof, 0.14)], [c.rf - 1.15, _sec(hw, belt - 0.05, roof, 0.14)], [c.rf, _sec(hw - 0.02, roof - 0.35, roof, 0.14)]])
		g.loft([[c.rf - 0.05, _sec(gw1 + 0.02, roof - 0.04, roof, 0.03)], [c.rf + 0.05, _sec(gw1, roof - 0.05, roof - 0.01, 0.03)]])
	else:
		g.loft([[c.rr - 0.06, _sec(gw1 + 0.03, roof - 0.05, roof + 0.01, 0.04)], [c.rf + 0.06, _sec(gw1 + 0.03, roof - 0.05, roof + 0.01, 0.04)]])
		for s in [-1.0, 1.0]:
			g.bar(Vector3(s * (gw0 - 0.01), belt, c.ws - 0.05), Vector3(s * (gw1 + 0.02), roof - 0.02, c.rf + 0.02), 0.035, 5)
			g.bar(Vector3(s * (gw0 - 0.01), belt, c.rg + 0.05), Vector3(s * (gw1 + 0.02), roof - 0.02, c.rr - 0.02), 0.05, 5)
			var zb := lerpf(c.rr, c.rf, 0.48)
			g.bar(Vector3(s * (gw0 - 0.005), belt, zb), Vector3(s * (gw1 + 0.03), roof - 0.02, zb), 0.035, 5)
			g.box(s * hw - 0.06 if s > 0 else -hw - 0.04, belt + 0.02, c.ws - 0.2, s * hw + 0.04 if s > 0 else -hw + 0.06, belt + 0.12, c.ws - 0.05)   # mirror
	if pickup:
		# bed: floor, sides, tailgate
		var bz0 := zr + 0.05
		var bz1: float = c.rg - 0.1
		g.box(-hw, y0, bz0, hw, 0.82, bz1)
		g.box(-hw, 0.82, bz0, -hw + 0.06, belt, bz1); g.box(hw - 0.06, 0.82, bz0, hw, belt, bz1)
		g.box(-hw, 0.82, bz0, hw, belt, bz0 + 0.06)
		g.box(-hw, 0.82, bz1 - 0.06, hw, belt + 0.02, bz1)
	# --- trim: bumpers, grille, lights, plates, handles, sills
	g.mat("plastic", Color(0.07, 0.07, 0.07))
	g.box(-hw * 0.95, y0 - 0.02, zf - 0.2, hw * 0.95, y0 + 0.2, zf + 0.04)
	g.box(-hw * 0.95, y0 - 0.02, zr - 0.04, hw * 0.95, y0 + 0.2, zr + 0.2)
	g.box(-hw - 0.01, y0, zr + 0.6, hw + 0.01, y0 + 0.07, zf - 0.6)   # rocker sills
	g.box(-hw * 0.5, c.hood - 0.38, zf - 0.04, hw * 0.5, c.hood - 0.2, zf + 0.01)   # grille
	g.mat("chrome", Color(0.85, 0.86, 0.88))
	for s in [-1.0, 1.0]:
		g.box(s * (hw * 0.82) - 0.14, c.hood - 0.3, zf - 0.08, s * (hw * 0.82) + 0.14, c.hood - 0.18, zf - 0.035)   # headlights
		for zz in [lerpf(c.rf, c.ws, 0.1), lerpf(c.rr, c.rf, 0.35)]:
			g.box(s * hw - 0.012, belt - 0.12, zz - 0.07, s * hw + 0.012, belt - 0.1, zz + 0.07)   # door handles
	g.mat("gloss", Color(0.6, 0.05, 0.04))
	for s in [-1.0, 1.0]:
		g.box(s * (hw * 0.8) - 0.15, tail - 0.28, zr + 0.06, s * (hw * 0.8) + 0.15, tail - 0.14, zr + 0.11)
	g.mat("paint", Color(0.92, 0.92, 0.88))
	g.box(-0.16, y0 + 0.24, zr + 0.13, 0.16, y0 + 0.4, zr + 0.14)
	g.box(-0.16, y0 + 0.04, zf + 0.04, 0.16, y0 + 0.16, zf + 0.05)
	# --- wheels (dark arches behind them, tires, alloy rims)
	var wb := L * 0.6 * 0.5 + 0.1
	g.mat("paint", Color(0.02, 0.02, 0.02))
	for z in [-wb, wb]:
		for s in [-1.0, 1.0]:
			g.push(); g.translate(s * (hw + 0.002), tr + 0.04, z); g.rotate_z(PI * 0.5)
			g.lathe([Vector2(tr + 0.035, 0.0), Vector2(tr + 0.035, 0.004)], 14, true)
			g.pop()
	for z in [-wb, wb]:
		for s in [-1.0, 1.0]:
			g.push(); g.translate(s * (hw - 0.11), tr, z); g.rotate_z(-PI * 0.5 * s)
			g.mat("rubber", Color(0.04, 0.04, 0.04))
			g.lathe([Vector2(tr * 0.66, -0.1), Vector2(tr - 0.03, -0.11), Vector2(tr, -0.08), Vector2(tr, 0.08), Vector2(tr - 0.03, 0.11), Vector2(tr * 0.66, 0.11)], 16, false)
			g.mat("metal", Color(0.7, 0.71, 0.72))
			g.lathe([Vector2(tr * 0.66, 0.105), Vector2(tr * 0.55, 0.1), Vector2(tr * 0.2, 0.094), Vector2(0.0, 0.1)], 14, false)
			g.pop()
