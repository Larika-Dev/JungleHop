extends PCMinigame
## Wilberforce circulation desk: check in returns and route them to the stacks.

const RANGES := [[0, 99, "1A"], [100, 299, "1B"], [300, 399, "2A"], [400, 599, "2B"], [600, 699, "3A"], [700, 899, "3B"], [900, 999, "4A"]]
const TITLES := ["A Field Guide to Pamlico Birds", "Brick by Brick", "The Carillon Years", "Calculus Made Gentle", "Hamilton Street Stories",
	"Oaks of the Piedmont", "Medieval Keeps", "Statistics for Ramblers", "Clay and Fire", "Rivers of the Coastal Plain"]


func _app_name() -> String:
	return "%s  ·  Circulation" % company_name("Wilberforce Library")


func _make_task() -> Dictionary:
	var cls := rng.randi_range(0, 999)
	var call_no := "%03d.%d %s%d" % [cls, rng.randi_range(1, 99), char(65 + rng.randi_range(0, 25)), rng.randi_range(10, 99)]
	var barcode := "3%07d" % rng.randi_range(0, 9999999)
	var stack := ""
	for r in RANGES:
		if cls >= r[0] and cls <= r[1]:
			stack = r[2]
	var side := "[b]Stack map[/b]\n"
	for r in RANGES:
		side += "%03d-%03d  ->  %s\n" % [r[0], r[1], r[2]]
	par_seconds = 14.0
	return {"screen": "[b]Return bin[/b]\n\n\"%s\"\nSpine label: [code]%s[/code]\nBarcode: [code]%s[/code]" % [pick(TITLES), call_no, barcode],
		"side": side, "fields": [
			{"label": "Scan barcode", "answer": barcode, "kind": "exact"},
			{"label": "Stack location", "answer": stack, "kind": "text"},
		]}
