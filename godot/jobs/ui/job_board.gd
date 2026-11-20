extends PanelContainer
## Job listings: every job, its ranks, wages, shifts and requirements, and
## what the player still needs. Opened from a staff terminal ("Job info") or
## the "Browse job listings" action.

var only_building := ""


func with_building(b: String) -> Control:
	only_building = b
	return self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(980, 680)
	var v := VBoxContainer.new()
	add_child(v)
	var title := Label.new()
	title.text = "Job listings" if only_building == "" else "Jobs here"
	title.add_theme_font_size_override("font_size", 26)
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	text.text = build_text()
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(on_back)
	v.add_child(close)
	position = -custom_minimum_size * 0.5
	close.grab_focus()


func build_text() -> String:
	var js := get_node_or_null("/root/JobSystem")
	if js == null:
		return "Job system not loaded."
	var s := ""
	for id in js.job_order:
		var j: Dictionary = js.get_job(id)
		if only_building != "" and j.building != only_building:
			continue
		var mine: bool = js.is_employed(id)
		s += "[b][font_size=21]%s[/font_size][/b]  ·  %s  ·  %s%s\n[i]%s[/i]\n" % [j.name, j.place,
			"PC work" if j.kind == "pc" else "hands-on", "   [color=#7fd88a](you work here)[/color]" if mine else "", j.blurb]
		var sh := []
		for x in j.shifts:
			sh.append("%s %02d:00-%02d:00" % [x.name, int(x.start), int(x.end) % 24])
		s += "Shifts: %s\n" % ", ".join(PackedStringArray(sh))
		for r in j.ranks.size():
			var rk: Dictionary = j.ranks[r]
			var req := []
			if float(rk.min_hours) > 0:
				req.append("%d h at previous rank, %d%% review" % [int(rk.min_hours), roundi(rk.min_performance * 100)])
			if rk.has("education_any"):
				req.append(" or ".join(PackedStringArray(rk.education_any)))
			if rk.has("education_tags"):
				req.append(", ".join(PackedStringArray(rk.education_tags)))
			if rk.has("skills"):
				for k in rk.skills:
					req.append("%s %d" % [k, int(rk.skills[k])])
			var marker := "> " if mine and js.rank_of(id) == r else "   "
			s += "%s%s  $%.2f/hr  %s\n" % [marker, rk.title, rk.wage, ("(" + "; ".join(PackedStringArray(req)) + ")") if not req.is_empty() else ""]
		if not mine:
			var why: String = js.can_apply(id)
			s += "[color=%s]%s[/color]\n" % ["#7fd88a" if why == "" else "#f2a03d", "You can apply." if why == "" else why]
		s += "\n"
	return s


func on_back() -> void:
	var ui := get_node_or_null("/root/UI")
	if ui:
		ui.close_panel(self)
	else:
		queue_free()
