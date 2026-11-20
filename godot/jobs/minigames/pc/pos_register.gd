extends PCMinigame
## Hilltop Hardware register: key in SKUs, then the exact change.

const CATALOG := [
	["10412", "Box of 3-inch nails", 6.49], ["20877", "Claw hammer", 18.99], ["31150", "Gallon of trim white paint", 34.50],
	["31166", "Paint roller kit", 12.25], ["40220", "Duct tape", 7.79], ["40318", "Work gloves", 9.99],
	["51004", "LED bulb 4-pack", 11.49], ["51190", "Extension cord 25 ft", 21.99], ["62031", "Wood screws 100 ct", 8.39],
	["62077", "Wall anchors", 4.29], ["73002", "Tape measure", 14.99], ["73118", "Utility knife", 10.49],
	["84400", "Bag of potting soil", 9.25], ["84455", "Hose nozzle", 13.75], ["95010", "Padlock", 15.49],
]
const TAX := 0.0725


func _app_name() -> String:
	return "Hilltop Hardware POS  ·  Lane 2"


func _make_task() -> Dictionary:
	var n := 1 + rng.randi_range(0, 1 + int(difficulty * 3))
	var cart := []
	var pool := CATALOG.duplicate()
	for i in n:
		cart.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var sub := 0.0
	var lines := "[b]Customer sets on the counter:[/b]\n\n"
	var fields := []
	for it in cart:
		sub += it[2]
		lines += "  [code]%s[/code]   %s   $%s\n" % [it[0], it[1], money(it[2])]
		fields.append({"label": "Scan SKU", "answer": it[0], "kind": "exact"})
	var total := snappedf(sub * (1.0 + TAX), 0.01)
	var paid := ceilf(total / 5.0) * 5.0 + (20.0 if rng.randf() < 0.4 else 0.0)
	var change := snappedf(paid - total, 0.01)
	lines += "\nSubtotal $%s   Tax 7.25%%   [b]Total $%s[/b]\n\nCustomer hands you [b]$%s[/b] cash." % [money(sub), money(total), money(paid)]
	fields.append({"label": "Change due $", "answer": change, "kind": "money"})
	par_seconds = 6.0 + 5.0 * n
	return {"screen": lines, "side": "[b]Register[/b]\nType each SKU, Enter.\nThen type the change due.\n\nTax is already in the total.", "fields": fields}
