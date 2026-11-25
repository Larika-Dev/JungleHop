extends Control
## Full-screen city map (M): roads, every building, districts, landmarks, you, and
## your workplace(s). Mouse wheel zooms, drag pans, M / Esc closes.

const BG := Color("#2B3A2A")
const BUILDING := Color("#B9A58C")
const BUILDING_EDGE := Color("#6E5E4A")
const ROAD := {"hamilton": [Color("#E9E4D8"), 16.0], "main": [Color("#D9D2C2"), 11.0],
	"secondary": [Color("#C9C2B2"), 8.0], "campus": [Color("#CFC6B4"), 7.0],
	"lane": [Color("#BDB5A3"), 5.0], "alley": [Color("#A69E8C"), 4.0]}
const WORK := Color("#E8B923")
const YOU := Color("#FF4FA3")

var _zoom := 0.55        # pixels per meter
var _center := Vector2.ZERO   # world x,z at the screen center
var _drag := false
var _font: Font
var _polys: Array = []   # [PackedVector2Array world x,z]
var _work: Array = []    # [{name, pos}]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = ThemeDB.fallback_font
	for b in CityData.buildings:
		var fp: Array = b.get("footprintCm", [])
		if fp.size() < 2:
			continue
		var w := float(fp[0]) / 100.0
		var d := float(fp[1]) / 100.0
		var xf: Transform3D = CityData.building_transform(str(b.id))
		var poly := PackedVector2Array()
		for c in [Vector3(0, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, d), Vector3(0, 0, d)]:
			var p: Vector3 = xf * c
			poly.append(Vector2(p.x, p.z))
		_polys.append(poly)
	var js := get_node_or_null("/root/JobSystem")
	if js and "employment" in js:
		for jid in js.employment:
			var j: Dictionary = js.get_job(jid)
			var b := str(j.get("building", ""))
			if b != "":
				var p: Vector3 = CityData.building_transform(b).origin
				_work.append({"name": js.place_name(jid, b) if js.has_method("place_name") else b, "pos": Vector2(p.x, p.z)})
	var pl := GameState.get_player()
	if pl:
		_center = Vector2(pl.global_position.x, pl.global_position.z)
	grab_focus()


func _screen() -> Vector2:
	return get_viewport_rect().size


func _process(_d: float) -> void:
	# Fill the screen whatever the parent's layout; redraw so the "you" arrow stays live.
	if position != Vector2.ZERO or size != _screen():
		position = Vector2.ZERO
		size = _screen()
	queue_redraw()


func _to_screen(w: Vector2) -> Vector2:
	return _screen() * 0.5 + (w - _center) * _zoom


func _draw() -> void:
	var ss := _screen()
	draw_rect(Rect2(Vector2.ZERO, ss), BG)
	var roads: Array = CityData.labels.get("roads", [])
	for r in roads:
		var st: Array = ROAD.get(str(r.get("kind", "secondary")), ROAD.secondary)
		var pts := PackedVector2Array()
		for p in r.get("pts", []):
			pts.append(_to_screen(Vector2(float(p[0]), float(p[1]))))
		if pts.size() >= 2:
			draw_polyline(pts, st[0], maxf(1.5, float(st[1]) * _zoom), true)
	for poly in _polys:
		var sp := PackedVector2Array()
		for p in poly:
			sp.append(_to_screen(p))
		draw_colored_polygon(sp, BUILDING)
		if _zoom > 0.8:
			var closed := sp.duplicate()
			closed.append(sp[0])
			draw_polyline(closed, BUILDING_EDGE, 1.0)
	var fs := 18
	for d in CityData.labels.get("districts", []):
		var s := _to_screen(Vector2(float(d.x), float(d.z)))
		var t := str(d.name).to_upper()
		var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, s - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
		draw_string(_font, s - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#F3F0E8"))
	if _zoom > 0.4:
		for l in CityData.labels.get("landmarks", []):
			var s := _to_screen(Vector2(float(l.x), float(l.z)))
			draw_circle(s, 5.0, Color("#80B4D9"))
			draw_string_outline(_font, s + Vector2(8, 5), str(l.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, 0.7))
			draw_string(_font, s + Vector2(8, 5), str(l.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#D9E8F5"))
	for w in _work:
		var s := _to_screen(w.pos)
		draw_rect(Rect2(s - Vector2(6, 6), Vector2(12, 12)), WORK)
		draw_string_outline(_font, s + Vector2(10, -8), "Work: " + str(w.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color.BLACK)
		draw_string(_font, s + Vector2(10, -8), "Work: " + str(w.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WORK)
	var home := get_node_or_null("/root/Home")
	if home and home.room_id != "":
		var hp: Vector3 = home.home_position()
		var s := _to_screen(Vector2(hp.x, hp.z))
		draw_circle(s, 7.0, Color("#4F9A5A"))
		draw_string_outline(_font, s + Vector2(10, 5), "Home", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color.BLACK)
		draw_string(_font, s + Vector2(10, 5), "Home", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#B8E0BE"))
	var pl := GameState.get_player()
	if pl:
		var s := _to_screen(Vector2(pl.global_position.x, pl.global_position.z))
		var fwd := -pl.global_transform.basis.z
		var dir := Vector2(fwd.x, fwd.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([s + dir * 14.0, s - dir * 8.0 + side * 8.0, s - dir * 8.0 - side * 8.0]), YOU)
	var help := "Map  ·  wheel: zoom  ·  drag: pan  ·  M or Esc: close"
	draw_string_outline(_font, Vector2(24, ss.y - 24), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
	draw_string(_font, Vector2(24, ss.y - 24), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom = minf(_zoom * 1.15, 6.0)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom = maxf(_zoom / 1.15, 0.15)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		_center -= event.relative / _zoom
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UI.close_panel(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
