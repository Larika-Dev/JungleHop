extends Node3D
## Visible police: when Law dispatches units, officers in navy uniforms show up near the
## last place you were seen and run at you. Catching you is an arrest
## (Law.police_contact). When you're no longer wanted they walk off and despawn.
## Presentation only: Law's own pursuit model still decides sightings, stars and escape
## (officers are in group "police_visual", not "police", so they don't switch it off).

const MAX_OFFICERS := 4
const RUN_MPS := 3.6
const CATCH_M := 1.4
const UNIFORM := {"top": "oxford_blue", "bottom": "slacks", "shoes": "work_boot", "outer": ""}
const UNIFORM_TINT := {"top": Color("#142B4E"), "bottom": Color("#1A1F2B")}

var officers: Array = []
var _pending: Array = []   # [{at: game minutes, pos: Vector3, n: int}]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var law := get_node_or_null("/root/Law")
	if law and law.has_signal("police_dispatched"):
		law.police_dispatched.connect(_on_dispatched)


func _on_dispatched(stars: int, units: int, _kind: String, pos: Vector3, eta_minutes: int) -> void:
	if stars <= 0:
		return
	var want := clampi(units, 1, MAX_OFFICERS) - officers.size()
	if want <= 0:
		return
	_pending.append({"at": GameClock.total_minutes + clampf(float(eta_minutes), 0.0, 6.0), "pos": pos, "n": want})


func _physics_process(delta: float) -> void:
	var law := get_node_or_null("/root/Law")
	var p := GameState.get_player()
	if law == null or p == null:
		return
	var wanted: bool = law.wanted() > 0
	# Arrivals
	for i in range(_pending.size() - 1, -1, -1):
		if GameClock.total_minutes >= float(_pending[i].at):
			var e: Dictionary = _pending[i]
			_pending.remove_at(i)
			if wanted:
				for k in int(e.n):
					_spawn(p.global_position, e.pos)
				UI.notify("Police are here.")
	# Chase or leave
	var pp: Vector3 = p.global_position
	for o in officers.duplicate():
		if not is_instance_valid(o):
			officers.erase(o)
			continue
		var body: Node3D = o
		var to := pp - body.global_position
		to.y = 0.0
		var d := to.length()
		var speed := 0.0
		if wanted and not bool(law.get("hiding")) and not bool(law.get("in_jail")):
			if d <= CATCH_M:
				law.police_contact(body)
				continue
			var step := minf(RUN_MPS * delta, d)
			body.global_position += to.normalized() * step
			body.global_position.y = lerpf(body.global_position.y, pp.y - 0.9, clampf(delta * 4.0, 0.0, 1.0))
			body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.z), clampf(delta * 8.0, 0.0, 1.0))
			speed = RUN_MPS
		else:
			# Walk away from the player, then go.
			var away := -to.normalized() if d > 0.01 else Vector3.FORWARD
			body.global_position += away * 1.4 * delta
			body.rotation.y = atan2(away.x, away.z)
			speed = 1.4
			if d > 60.0 or not wanted and o.get_meta("leave_t", 0.0) > 25.0:
				officers.erase(o)
				o.queue_free()
				continue
			o.set_meta("leave_t", float(o.get_meta("leave_t", 0.0)) + delta)
		if body.has_method("animate"):
			body.animate(delta, speed)


func _spawn(player_pos: Vector3, seen_at: Vector3) -> void:
	if officers.size() >= MAX_OFFICERS or not ResourceLoader.exists("res://npc/npc_body.gd"):
		return
	var base := seen_at if seen_at != Vector3.ZERO else player_pos
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(22.0, 34.0)
	var pos := base + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	pos.y = player_pos.y - 0.9
	var prof := {"sex": "male" if _rng.randf() < 0.75 else "female", "height_cm": _rng.randf_range(165, 190),
		"build": _rng.randf_range(0.35, 0.65), "skin": _rng.randi_range(0, 5), "hair_style": 5,
		"hair_color": _rng.randi_range(0, 3), "muscle": 6, "name": "Officer"}
	var rec: Dictionary = load("res://npc/npc_appearance.gd").record_from_profile(prof)
	rec["npc_id"] = "police_%d" % _rng.randi()
	rec["wardrobe"] = UNIFORM
	rec["wardrobe_tint"] = UNIFORM_TINT
	var body: Node3D = load("res://npc/npc_body.gd").new()
	body.name = "Officer"
	add_child(body)
	body.remove_from_group("npc")
	body.add_to_group("police_visual")
	body.set("is_police", true)
	body.set("display_name", "Officer")
	body.apply_record(rec)
	body.set_lod(1)
	body.global_position = pos
	officers.append(body)


func clear() -> void:
	for o in officers:
		if is_instance_valid(o):
			o.queue_free()
	officers.clear()
	_pending.clear()
