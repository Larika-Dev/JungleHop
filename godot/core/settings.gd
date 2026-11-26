extends Node
## Graphics, audio and control settings, persisted to user://settings.cfg.
## Autoload name: Settings. See docs/INTERFACES.md.

signal settings_changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const GRAPHICS_KEYS := ["quality", "fullscreen", "vsync", "resolution_scale", "fov", "shadows", "view_distance",
	"show_fps", "gi", "reflections", "volumetric_fog", "ambient_occlusion", "antialiasing", "upscaler",
	"grass_density", "foliage_distance", "shadow_quality", "building_distance"]
const AUDIO_BUSES := ["Master", "Music", "SFX", "Ambient"]
## Rebindable actions shown in the Controls tab: action -> label.
const REBINDABLE := {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"jump": "Jump", "run": "Run", "interact": "Interact", "action_menu": "Action menu",
	"toggle_view": "First / third person", "map": "Map", "pause": "Pause menu",
	"life_menu": "You / this place actions", "people": "People you know",
}
const DEFAULT_KEYS := {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"jump": KEY_SPACE, "run": KEY_SHIFT, "interact": KEY_E, "action_menu": KEY_TAB,
	"toggle_view": KEY_C, "map": KEY_M, "pause": KEY_ESCAPE, "fly": KEY_F,
	"life_menu": KEY_Q, "people": KEY_R,
}

# Graphics
var quality: int = 2
var fullscreen: bool = true
var vsync: bool = true
var resolution_scale: float = 1.0
var fov: float = 75.0
var shadows: bool = true
var view_distance: float = 1500.0
var show_fps: bool = false
## Advanced graphics (set by the quality preset, each can be overridden in Settings > Graphics).
## gi: 0 off, 1 screen-space (SSIL), 2 full global illumination (SDFGI + SSIL).
var gi: int = 1
var reflections: bool = true          # screen-space reflections
var volumetric_fog: bool = true
var ambient_occlusion: bool = true
## antialiasing: 0 FXAA, 1 TAA, 2 TAA + MSAA 2x
var antialiasing: int = 1
## upscaler when resolution_scale < 1: 0 bilinear, 1 FSR 1, 2 FSR 2
var upscaler: int = 2
var grass_density: float = 0.75       # 0 = no 3D grass
var foliage_distance: float = 260.0   # detailed trees within this distance
var shadow_quality: int = 2           # 0..3 -> atlas size and softness
var building_distance: float = 160.0  # modeled building exteriors within this distance
# Audio, linear 0..1
var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.8, "Ambient": 0.7}
# Controls
var mouse_sensitivity: float = 0.25
var invert_y: bool = false
var keys: Dictionary = DEFAULT_KEYS.duplicate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply()


func _ensure_buses() -> void:
	for bus in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func apply() -> void:
	var win := get_window()
	if not DisplayServer.get_name() == "headless":
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	win.scaling_3d_scale = resolution_scale
	_apply_rendering(win)
	for bus in volumes:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[bus], 0.0001)))
			AudioServer.set_bus_mute(i, volumes[bus] <= 0.001)
	_apply_keys()
	settings_changed.emit()


func _apply_keys() -> void:
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		var k := InputEventKey.new()
		k.physical_keycode = keys[action]
		InputMap.action_add_event(action, k)


func rebind(action: String, keycode: int) -> void:
	keys[action] = keycode
	apply()
	save_settings()


func reset_controls() -> void:
	keys = DEFAULT_KEYS.duplicate()
	mouse_sensitivity = 0.25
	invert_y = false
	apply()
	save_settings()


## Engine-level rendering options (viewport AA / upscaling, shadow atlas, LOD, shader globals).
## Lighting and post-processing that live on the Environment are applied by DayNight.
func _apply_rendering(win: Window) -> void:
	var vp := win.get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if antialiasing >= 2 else Viewport.MSAA_DISABLED
	vp.use_taa = antialiasing >= 1
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialiasing == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	if resolution_scale < 0.999:
		vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR, Viewport.SCALING_3D_MODE_FSR2][clampi(upscaler, 0, 2)]
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.5][clampi(quality, 0, 3)]
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][clampi(shadow_quality, 0, 3)]
	var dir_size: int = [1024, 2048, 4096, 8192][clampi(shadow_quality, 0, 3)]
	RenderingServer.directional_shadow_atlas_set_size(dir_size, true)
	var soft: int = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][clampi(shadow_quality, 0, 3)]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	RenderingServer.global_shader_parameter_set("cm_quality", float(quality))


## First-launch preset from the graphics adapter: integrated GPUs start on Low / Medium.
func detect_quality() -> int:
	if DisplayServer.get_name() == "headless":
		return 2
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	var integrated := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	if gpu.contains("llvmpipe") or gpu.contains("swiftshader"):
		return 2   # software renderer (screenshots / CI): keep the default look
	if integrated or gpu.contains("uhd") or gpu.contains("iris") or gpu.contains("hd graphics"):
		return 0 if gpu.contains("hd graphics") or gpu.contains("uhd") else 1
	if vendor.contains("nvidia") and (gpu.contains("rtx 40") or gpu.contains("rtx 50") or gpu.contains("rtx 309") or gpu.contains("rtx 308")):
		return 3
	if vendor.contains("amd") and (gpu.contains("rx 79") or gpu.contains("rx 69") or gpu.contains("rx 68") or gpu.contains("rx 9")):
		return 3
	return 2


## Applies a whole preset. Low runs on integrated graphics; Ultra is for current gaming GPUs.
func set_quality(q: int) -> void:
	quality = clampi(q, 0, 3)
	shadows = true
	shadow_quality = quality
	view_distance = [700.0, 1100.0, 1600.0, 2600.0][quality]
	resolution_scale = [0.7, 0.85, 1.0, 1.0][quality]
	upscaler = [1, 2, 2, 2][quality]
	gi = [0, 0, 1, 2][quality]
	reflections = quality >= 2
	volumetric_fog = quality >= 2
	ambient_occlusion = quality >= 1
	antialiasing = [0, 1, 1, 2][quality]
	grass_density = [0.0, 0.35, 0.75, 1.0][quality]
	foliage_distance = [140.0, 200.0, 260.0, 400.0][quality]
	building_distance = [70.0, 110.0, 160.0, 240.0][quality]


func save_settings() -> void:
	var c := ConfigFile.new()
	for k in GRAPHICS_KEYS:
		c.set_value("graphics", k, get(k))
	for bus in volumes:
		c.set_value("audio", bus, volumes[bus])
	c.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	c.set_value("controls", "invert_y", invert_y)
	for a in keys:
		c.set_value("keys", a, keys[a])
	c.save(PATH)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		set_quality(detect_quality())
		return
	# Older settings files only know the preset: fill new options from it, then override.
	set_quality(c.get_value("graphics", "quality", quality))
	for k in GRAPHICS_KEYS:
		set(k, c.get_value("graphics", k, get(k)))
	for bus in volumes.keys():
		volumes[bus] = c.get_value("audio", bus, volumes[bus])
	mouse_sensitivity = c.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = c.get_value("controls", "invert_y", invert_y)
	for a in DEFAULT_KEYS:
		keys[a] = c.get_value("keys", a, DEFAULT_KEYS[a])


static func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)
