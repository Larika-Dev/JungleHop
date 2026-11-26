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

const SKY_RAIN := Color("#8D949B")

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var cam_attr: CameraAttributesPractical
var world_env: WorldEnvironment
var _cloud_t := 0.0
var _quality := 2


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://world/shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	# ACES filmic, exposure 1.0 (CLAUDE.md §15).
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	# Screen-space ambient occlusion, tuned to read in mortar joints and corners at 1 m.
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssao_ao_channel_affect = 0.4
	# Screen-space indirect light (color bleed from brick and grass).
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.ssil_sharpness = 0.98
	# Reflections on glass, polished floors and wet asphalt.
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.5
	env.ssr_depth_tolerance = 0.25
	# Full GI (Ultra): signed distance field GI follows the camera.
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_energy = 1.0
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	# Aerial perspective: depth fog + height fog that pools in the ravine and stadium bowl.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.00022
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.2
	env.fog_height = -10.0
	env.fog_height_density = 0.004
	env.fog_sun_scatter = 0.35
	# Volumetric fog for light shafts through oaks and haze around lamps at night.
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.92, 0.93, 0.95)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	# Bloom on the sun, sky, neon and lit windows.
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.4
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for i in 7:
		env.set_glow_level(i, [0.0, 0.0, 1.0, 0.7, 1.0, 0.6, 0.3][i])
	# Gentle grade: a touch of contrast and saturation.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	world_env = WorldEnvironment.new()
	world_env.environment = env
	# Camera attributes (auto exposure kept off; values below are used if it is enabled).
	cam_attr = CameraAttributesPractical.new()
	cam_attr.auto_exposure_enabled = false   # fixed exposure: auto exposure blew out dusk scenes
	cam_attr.auto_exposure_scale = 0.3
	cam_attr.auto_exposure_speed = 0.6
	cam_attr.auto_exposure_min_sensitivity = 100.0
	cam_attr.auto_exposure_max_sensitivity = 400.0
	world_env.camera_attributes = cam_attr
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 250.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.0
	sun.shadow_blur = 1.0
	sun.light_angular_distance = 0.53   # real sun size: soft contact-hardening penumbras
	sun.light_volumetric_fog_energy = 1.2
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = MOON
	moon.light_energy = 0.3
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	moon.light_angular_distance = 0.5
	add_child(moon)
	_update()


func _process(d: float) -> void:
	if not GameClock.paused:
		_cloud_t += d * (1.0 + float(GameClock.GAME_MINUTES_PER_REAL_SECOND) * 0.25)
	_update()


func set_shadows(on: bool, quality: int) -> void:
	if sun == null:
		return
	_quality = clampi(quality, 0, 3)
	sun.shadow_enabled = on
	moon.shadow_enabled = on and _quality >= 2
	sun.directional_shadow_max_distance = [90.0, 160.0, 260.0, 420.0][_quality]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if _quality == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_angular_distance = 0.0 if _quality == 0 else 0.53
	env.ssao_enabled = Settings.ambient_occlusion
	env.ssil_enabled = Settings.gi >= 1
	env.sdfgi_enabled = Settings.gi >= 2
	env.ssr_enabled = Settings.reflections
	env.volumetric_fog_enabled = Settings.volumetric_fog
	env.glow_enabled = true
	env.ssr_max_steps = [32, 48, 96, 160][_quality]
	sky_mat.set_shader_parameter("cloud_cover", 0.45)


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
	var sky_top := SKY_NIGHT.lerp(zen, day)
	var sky_hor := SKY_NIGHT.lightened(0.08).lerp(hor, day)
	sky_mat.set_shader_parameter("zenith_color", sky_top)
	sky_mat.set_shader_parameter("horizon_color", sky_hor)
	sky_mat.set_shader_parameter("ground_color", SKY_NIGHT.lerp(Color(0.25, 0.24, 0.22), day))
	sky_mat.set_shader_parameter("sun_tint", sun.light_color)
	sky_mat.set_shader_parameter("day", day)
	sky_mat.set_shader_parameter("golden", golden)
	sky_mat.set_shader_parameter("cloud_time", _cloud_t)
	# night: a little moonlit blue ambient so shadowed streets are dark, not black
	env.ambient_light_color = Color(0.1, 0.13, 0.22)
	env.ambient_light_sky_contribution = lerpf(0.35, 1.0, day)
	env.ambient_light_energy = lerpf(0.6, 1.0, day)
	env.fog_light_color = sky_hor
	env.fog_sun_scatter = 0.15 + 0.45 * golden
	env.volumetric_fog_density = lerpf(0.008, 0.0015, day) + 0.003 * golden
	env.volumetric_fog_albedo = Color(0.92, 0.93, 0.95).lerp(sky_hor, 0.3)
	RenderingServer.global_shader_parameter_set("cm_night", 1.0 - day)
	RenderingServer.global_shader_parameter_set("cm_sun_dir", dir)
	var gust := 0.7 + 0.3 * sin(_cloud_t * 0.21) * sin(_cloud_t * 0.067)
	RenderingServer.global_shader_parameter_set("cm_wind", Vector4(0.82, 0.35, gust, _cloud_t))
