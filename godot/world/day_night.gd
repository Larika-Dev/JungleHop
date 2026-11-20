class_name DayNight
extends Node3D
## Sun, moon, sky and fog driven by GameClock.hour_f. Colors follow the CLAUDE.md §4.9 light palette.

const SUN_GOLDEN := Color("#FFC98A")
const SUN_NOON := Color("#FFF4E5")
const SKY_GOLDEN_ZENITH := Color("#7FA6CC")
const SKY_GOLDEN_HORIZON := Color("#F2C48D")
const SKY_NOON_ZENITH := Color("#8FB8DE")
const SKY_NOON_HORIZON := Color("#D6E6F2")
const SKY_NIGHT := Color("#0B1424")
const MOON := Color("#AFC4E8")
const SUNRISE := 6.5
const SUNSET := 19.5

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial


func _ready() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = MOON
	moon.light_energy = 0.15
	add_child(moon)
	_update()


func _process(_d: float) -> void:
	_update()


func set_shadows(on: bool, quality: int) -> void:
	if sun == null:
		return
	sun.shadow_enabled = on
	sun.directional_shadow_max_distance = [80.0, 150.0, 250.0, 400.0][clampi(quality, 0, 3)]
	env.ssao_enabled = quality >= 2
	env.glow_enabled = quality >= 1


func _update() -> void:
	var h := GameClock.hour_f
	# Sun travels from east (sunrise) through south (noon) to west (sunset). +X east, -Z north.
	var t := (h - SUNRISE) / (SUNSET - SUNRISE)            # 0..1 over daylight
	var elev := sin(clampf(t, -0.25, 1.25) * PI) * deg_to_rad(58.0)
	var azim := lerpf(deg_to_rad(100.0), deg_to_rad(260.0), clampf(t, 0.0, 1.0))  # compass degrees
	# dir points from the ground toward the sun; compass 0 = north = -Z, 90 = east = +X.
	var dir := Vector3(sin(azim) * cos(elev), sin(elev), -cos(azim) * cos(elev))
	sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	var day := clampf(sin(elev) * 4.0, 0.0, 1.0)            # 0 night .. 1 full day
	var golden := clampf(1.0 - sin(elev) * 3.0, 0.0, 1.0) * day
	sun.visible = day > 0.01
	sun.light_energy = 2.2 * day + 0.8 * day * (1.0 - golden)
	sun.light_color = SUN_NOON.lerp(SUN_GOLDEN, golden)
	moon.visible = day < 0.3
	moon.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-120.0), 0.0)
	var zen := SKY_NOON_ZENITH.lerp(SKY_GOLDEN_ZENITH, golden)
	var hor := SKY_NOON_HORIZON.lerp(SKY_GOLDEN_HORIZON, golden)
	sky_mat.sky_top_color = SKY_NIGHT.lerp(zen, day)
	sky_mat.sky_horizon_color = SKY_NIGHT.lightened(0.08).lerp(hor, day)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = SKY_NIGHT.lerp(Color(0.25, 0.24, 0.22), day)
	env.ambient_light_energy = lerpf(0.25, 1.0, day)
	env.fog_light_color = sky_mat.sky_horizon_color
