extends PCMinigame
## Hilltop Hardware register: key in SKUs, then the exact change.

## Register stock by the employer's industry (companies.json "industry" / "industry_catalog").
const CATALOGS := {
	"Hardware": [["10412", "Box of 3-inch nails", 6.49], ["20877", "Claw hammer", 18.99], ["31150", "Gallon of trim white paint", 34.50],
		["31166", "Paint roller kit", 12.25], ["40220", "Duct tape", 7.79], ["40318", "Work gloves", 9.99], ["51004", "LED bulb 4-pack", 11.49],
		["51190", "Extension cord 25 ft", 21.99], ["62031", "Wood screws 100 ct", 8.39], ["73002", "Tape measure", 14.99]],
	"Clothing": [["2101", "Flannel shirt", 39.00], ["2140", "Wool beanie", 18.50], ["2210", "Denim jacket", 74.00], ["2302", "Rain shell", 89.00],
		["2415", "Crew socks 3-pack", 14.00], ["2550", "Corduroy pants", 52.00], ["2612", "Linen scarf", 26.00], ["2733", "Canvas belt", 22.00]],
	"Retail": [["8801", "ONSU hoodie", 54.99], ["8812", "Billram plush", 19.99], ["8830", "Heaven Blue cap", 24.99], ["8845", "Pennant", 12.50],
		["8860", "Travel mug", 16.75], ["8871", "Lamp oil", 8.25], ["8888", "Fiddle strings", 11.00], ["8893", "Sticker pack", 4.99]],
	"Gallery & Print": [["4101", "Letterpress print", 45.00], ["4122", "Postcard set", 9.50], ["4140", "Framed photo 8x10", 38.00],
		["4155", "Gallery catalogue", 22.00], ["4170", "Art pencils", 13.25], ["4188", "Poster tube", 6.50]],
	"Florist": [["6010", "Dozen roses", 42.00], ["6022", "Sunflower bunch", 16.50], ["6035", "Potted fern", 24.00], ["6048", "Corsage", 28.00],
		["6061", "Glass vase", 14.75], ["6077", "Delivery card", 3.50]],
	"Optician": [["7300", "Eye exam", 95.00], ["7312", "Frames", 129.00], ["7325", "Lens cloth", 6.00], ["7340", "Contact lens solution", 12.49],
		["7356", "Glasses case", 15.00], ["7371", "Reading glasses", 24.99]],
	"Records": [["5501", "LP, used", 14.00], ["5519", "LP, new pressing", 29.99], ["5530", "7-inch single", 7.50], ["5545", "Turntable belt", 18.00],
		["5560", "Record sleeves 25", 9.99], ["5577", "Band tee", 25.00]],
	"Books": [["9781", "Paperback novel", 16.99], ["9782", "Hardcover history", 32.00], ["9783", "Field guide", 21.50], ["9784", "Kids picture book", 12.99],
		["9785", "Notebook", 8.25], ["9786", "Bookmark", 2.50]],
	"Bakery": [["101", "Sourdough loaf", 8.50], ["102", "Cinnamon roll", 4.25], ["103", "Biscuit box (6)", 11.00], ["104", "Pound cake slice", 3.75],
		["105", "Baguette", 5.00], ["106", "Coffee, drip", 2.75]],
	"Diner": [["201", "Waffle plate", 11.49], ["202", "Two eggs any style", 8.99], ["203", "Hash browns", 4.25], ["204", "Pharmacy grill burger", 12.75],
		["205", "Milkshake", 6.50], ["206", "Coffee, bottomless", 2.95]],
	"Takeout": [["301", "Lo mein, large", 12.95], ["302", "General's chicken", 13.50], ["303", "Egg roll", 2.25], ["304", "Fried rice", 9.75],
		["305", "Dumplings (8)", 8.95], ["306", "Bubble tea", 5.50]],
	"Tacos": [["401", "Carnitas taco", 4.25], ["402", "Veggie taco", 3.75], ["403", "Chips and salsa", 4.50], ["404", "Burrito bowl", 11.95],
		["405", "Horchata", 3.95], ["406", "Elote", 4.75]],
	"Deli": [["501", "Turkey club", 11.50], ["502", "Pimento cheese sandwich", 8.95], ["503", "Pickle spear", 1.25], ["504", "Potato salad cup", 3.75],
		["505", "Sweet tea", 2.50], ["506", "Reuben", 12.75]],
	"Dental": [["D110", "Cleaning copay", 25.00], ["D140", "Exam copay", 20.00], ["D330", "Whitening kit", 49.00], ["D901", "Floss picks", 4.50],
		["D902", "Soft toothbrush", 3.99]],
	"Concessions": [["C10", "Stadium hot dog", 6.00], ["C11", "Souvenir soda", 7.50], ["C12", "Nachos", 8.25], ["C13", "Popcorn", 5.75],
		["C14", "Bottled water", 4.00], ["C15", "Foam finger", 12.00]],
	"Grocery": [["3001", "Organic apples (lb)", 2.89], ["3002", "Oat milk", 4.79], ["3003", "Local eggs dozen", 5.49], ["3004", "Bulk granola (lb)", 6.25],
		["3005", "Sourdough", 7.00], ["3006", "Collard greens", 3.25], ["3007", "Peanut butter", 5.99]],
	"Parking": [["P1", "1 hour", 2.00], ["P2", "2 hours", 4.00], ["P4", "4 hours", 7.50], ["P8", "All day", 12.00], ["P30", "Lost ticket", 25.00]],
}
const TAX := 0.0725


var catalog: Array = CATALOGS["Hardware"]


func _app_name() -> String:
	return "%s  ·  Register" % company_name("Hilltop Hardware")


func _setup() -> void:
	var key := "Hardware"
	if jobs and job_id != "" and jobs.has_method("get_job"):
		key = String(jobs.get_job(job_id).get("catalog", "Hardware"))
	catalog = CATALOGS.get(key, CATALOGS["Retail"])
	if app_label:
		app_label.text = _app_name()


func _make_task() -> Dictionary:
	var n := mini(catalog.size() - 1, 1 + rng.randi_range(0, 1 + int(difficulty * 3)))
	var cart := []
	var pool := catalog.duplicate()
	for i in n:
		cart.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var sub := 0.0
	var lines := "[b]Customer at the counter:[/b]\n\n"
	var fields := []
	for it in cart:
		sub += it[2]
		lines += "  [code]%s[/code]   %s   $%s\n" % [it[0], it[1], money(it[2])]
		fields.append({"label": "Item code", "answer": it[0], "kind": "exact"})
	var total := snappedf(sub * (1.0 + TAX), 0.01)
	var paid := ceilf(total / 5.0) * 5.0 + (20.0 if rng.randf() < 0.4 else 0.0)
	var change := snappedf(paid - total, 0.01)
	lines += "\nSubtotal $%s   Tax 7.25%%   [b]Total $%s[/b]\n\nCustomer hands you [b]$%s[/b] cash." % [money(sub), money(total), money(paid)]
	fields.append({"label": "Change due $", "answer": change, "kind": "money"})
	par_seconds = 6.0 + 5.0 * n
	return {"screen": lines, "side": "[b]Register[/b]\nType each SKU, Enter.\nThen type the change due.\n\nTax is already in the total.", "fields": fields}
