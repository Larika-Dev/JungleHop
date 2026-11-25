extends PhysicalMinigame
## Tarry Page Books: lift each book off the cart and set it in its section.

const SECTIONS := [
	["Fiction", Color(0.18, 0.25, 0.2)], ["Mystery", Color(0.25, 0.14, 0.2)], ["Sci-Fi", Color(0.14, 0.2, 0.3)],
	["History", Color(0.36, 0.25, 0.14)], ["Cooking", Color(0.42, 0.2, 0.14)], ["Kids", Color(0.2, 0.32, 0.4)],
]
const BOOKS := {
	"Fiction": ["The Willow Oak Summer", "A Porch in Pamlico", "Letters from Rosemary Row"],
	"Mystery": ["Murder at the Old Cistern", "The Keep on Toadstool Hill", "Who Rang the Carillon?"],
	"Sci-Fi": ["Starfall over Carrburg", "The Quarry Protocol", "Billram 3000"],
	"History": ["Founders' Hall: 1795-1900", "The Mill Town Years", "Hamilton Street, Then and Now"],
	"Cooking": ["Biscuits of the Piedmont", "Late Night Lo Mein at Home", "Red Clay Barbecue"],
	"Kids": ["Billram Goes to School", "The Little Bell Tower", "Owl at the Inn"],
}
const PER_ROUND := 4

var placed := 0
var correct := 0
var book_id := ""
var _n := 0


func _setup() -> void:
	set_camera(Vector3(0, 0.75, 0.85), Vector3(0, 0.12, -0.15))
	add_box(Vector3(1.5, 0.02, 0.9), Color(0.64, 0.48, 0.31), Vector3(0, -0.02, 0))  # OAK_FLOOR
	add_box(Vector3(1.32, 0.42, 0.06), Color(0.31, 0.21, 0.14), Vector3(0, 0, -0.32))
	for i in SECTIONS.size():
		var x := -0.55 + i * 0.22
		add_box(Vector3(0.2, 0.01, 0.16), SECTIONS[i][1], Vector3(x, 0, -0.2))
		add_label(SECTIONS[i][0], Vector3(x, 0.47, -0.3), 0.026)
		add_zone(SECTIONS[i][0], Vector3(x, 0, -0.2), 0.1)
	add_box(Vector3(0.3, 0.12, 0.18), Color(0.46, 0.47, 0.48), Vector3(0, 0, 0.27))
	add_label("Cart", Vector3(0.22, 0.12, 0.3), 0.022)


func _new_round() -> void:
	placed = 0
	correct = 0
	_next_book()


func _next_book() -> void:
	_n += 1
	book_id = "book%d" % _n
	var sec: Array = pick(SECTIONS)
	var title: String = pick(BOOKS[sec[0]])
	var n := Node3D.new()
	n.position = Vector3(0, 0.12, 0.27)
	world_root.add_child(n)
	add_box(Vector3(0.12, 0.03, 0.17), Color(0.85, 0.8, 0.7).lerp(sec[1], 0.25), Vector3.ZERO, n)
	add_label(title, Vector3(0, 0.07, 0), 0.02, n, Color(1, 0.95, 0.8))
	add_item(book_id, n, true, {"section": sec[0]})
	set_hint("Book %d of %d: \"%s\". Carry it to its section." % [placed + 1, PER_ROUND, title])


func _on_drop(id: String, zone: String) -> bool:
	if zone == "" or not items.has(id):
		return false
	placed += 1
	if items[id].data.section == zone:
		correct += 1
	remove_item(id)
	if placed >= PER_ROUND:
		finish_round(float(correct) / PER_ROUND * time_factor(5.0 * PER_ROUND), "%d/%d shelved right" % [correct, PER_ROUND])
	else:
		_next_book()
	return true


func simulate_round(perfect: bool) -> float:
	var before := scores.size()
	for i in PER_ROUND:
		var sec: String = items[book_id].data.section
		var z := sec if perfect else ("Kids" if sec != "Kids" else "Fiction")
		move_item_to_zone(book_id, z)
	var s: float = scores[before] if scores.size() > before else 0.0
	_start_round()
	return s
