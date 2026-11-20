extends PanelContainer
## Job listings grouped by company. From a staff terminal it shows that
## building's employers; from the "Browse job listings" action it shows every
## company in town with an industry filter and an "open to me" toggle.

var only_building := ""
var text: RichTextLabel
var industry := OptionButton.new()
var open_only := CheckBox.new()


func with_building(b: String) -> Control:
	only_building = b
	return self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1040, 720)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var title := Label.new()
	title.text = "Companies here" if only_building != "" else "Job listings"
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var js := _js()
	if only_building == "" and js:
		industry.add_item("All industries")
		var inds := {}
		for c in js.company_order:
			inds[js.companies[c].industry] = true
		var keys := inds.keys()
		keys.sort()
		for k in keys:
			industry.add_item(k)
		industry.item_selected.connect(func(_i): refresh())
		top.add_child(industry)
		open_only.text = "Only jobs I can get"
		open_only.toggled.connect(func(_b): refresh())
		top.add_child(open_only)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(on_back)
	v.add_child(close)
	position = -custom_minimum_size * 0.5
	refresh()
	close.grab_focus()


func _js() -> Node:
	return get_node_or_null("/root/JobSystem")


func refresh() -> void:
	text.text = build_text()


const PERK_TEXT := {"free_meal": "free staff meal", "tip_pool": "shared tip pool (+30% tips)", "staff_discount": "staff discount",
	"health_plan": "health plan", "signing_bonus": "$150 signing bonus", "flex_shifts": "flexible clock-in", "paid_breaks": "paid breaks"}


func build_text() -> String:
	var js := _js()
	if js == null:
		return "Job system not loaded."
	var want_ind := "" if only_building != "" or industry.selected <= 0 else industry.get_item_text(industry.selected)
	var s := ""
	var shown := 0
	for cid in js.company_order:
		var c: Dictionary = js.companies[cid]
		if want_ind != "" and c.industry != want_ind:
			continue
		if only_building != "" and not c.buildings.has(only_building):
			continue
		var posts: Array = js.job_order.filter(func(id): return js.jobs[id].company == cid and (only_building == "" or js.jobs[id].buildings.has(only_building)))
		if open_only.button_pressed:
			posts = posts.filter(func(id): return js.can_apply(id) == "")
		if posts.is_empty():
			continue
		shown += 1
		var perks := PackedStringArray(c.get("perks", []).map(func(p): return PERK_TEXT.get(p, p)))
		s += "[b][font_size=22]%s[/font_size][/b]  ·  %s  ·  %s★  ·  est. %d  ·  %d staff%s\n" % [c.name, c.industry, str(c.rating), int(c.founded),
			int(c.employees), "  ·  %d locations" % c.buildings.size() if c.buildings.size() > 1 else ""]
		s += "[i]%s[/i]  Manager: %s.  Pay %s.%s\n" % [c.get("tagline", ""), c.manager,
			"above average" if c.pay_scale > 1.03 else "below average" if c.pay_scale < 0.97 else "about average",
			(" Perks: " + ", ".join(perks) + ".") if not perks.is_empty() else ""]
		if c.get("chain", false):
			s += "Branches: %s\n" % ", ".join(PackedStringArray(c.branch_names.values()))
		for id in posts:
			s += _posting_text(js, id)
		s += "\n"
	if shown == 0:
		s = "No openings match."
	return s


func _posting_text(js: Node, id: String) -> String:
	var j: Dictionary = js.jobs[id]
	var mine: bool = js.is_employed(id)
	var s := "  [b]%s[/b] (%s)%s\n" % [j.name, "PC work" if j.kind == "pc" else "hands-on", "  [color=#7fd88a]you work here[/color]" if mine else ""]
	var sh := PackedStringArray()
	for x in j.shifts:
		sh.append("%s %02d:00-%02d:00" % [x.name, int(x.start), int(x.end) % 24])
	s += "    Shifts: %s\n" % ", ".join(sh)
	var ladder := PackedStringArray()
	for r in j.ranks.size():
		var rk: Dictionary = j.ranks[r]
		var req := PackedStringArray()
		if rk.has("education_any"):
			req.append(" or ".join(PackedStringArray(rk.education_any)))
		if rk.has("education_tags"):
			req.append(", ".join(PackedStringArray(rk.education_tags)))
		ladder.append("%s%s $%.2f%s" % ["> " if mine and js.rank_of(id) == r else "", rk.title, rk.wage, (" [" + "; ".join(req) + "]") if not req.is_empty() else ""])
	s += "    " + "  →  ".join(ladder) + "\n"
	if not mine:
		var why: String = js.can_apply(id)
		s += "    [color=%s]%s[/color]\n" % ["#7fd88a" if why == "" else "#f2a03d", "You can apply at the staff terminal." if why == "" else why]
	return s


func on_back() -> void:
	var ui := get_node_or_null("/root/UI")
	if ui:
		ui.close_panel(self)
	else:
		queue_free()
