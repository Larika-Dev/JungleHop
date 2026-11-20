extends Node
## Graphics, audio and control settings, persisted to user://settings.cfg.
## Autoload name: Settings. See docs/INTERFACES.md.

signal settings_changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const AUDIO_BUSES := ["Master", "Music", "SFX", "Ambient"]
## Rebindable actions shown in the Controls tab: action -> label.
const REBINDABLE := {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"jump": "Jump", "run": "Run", "interact": "Interact", "action_menu": "Action menu",
	"toggle_view": "First / third person", "map": "Map", "pause": "Pause menu",
}
const DEFAULT_KEYS := {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"jump": KEY_SPACE, "run": KEY_SHIFT, "interact": KEY_E, "action_menu": KEY_TAB,
	"toggle_view": KEY_C, "map": KEY_M, "pause": KEY_ESCAPE, "fly": KEY_F,
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


## Applies the preset's shadows, view distance and resolution scale.
func set_quality(q: int) -> void:
	quality = clampi(q, 0, 3)
	shadows = quality >= 1
	view_distance = [600.0, 1000.0, 1500.0, 2500.0][quality]
	resolution_scale = [0.67, 0.85, 1.0, 1.0][quality]


func save_settings() -> void:
	var c := ConfigFile.new()
	for k in ["quality", "fullscreen", "vsync", "resolution_scale", "fov", "shadows", "view_distance", "show_fps"]:
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
		return
	for k in ["quality", "fullscreen", "vsync", "resolution_scale", "fov", "shadows", "view_distance", "show_fps"]:
		set(k, c.get_value("graphics", k, get(k)))
	for bus in volumes.keys():
		volumes[bus] = c.get_value("audio", bus, volumes[bus])
	mouse_sensitivity = c.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_y = c.get_value("controls", "invert_y", invert_y)
	for a in DEFAULT_KEYS:
		keys[a] = c.get_value("keys", a, DEFAULT_KEYS[a])


static func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)
