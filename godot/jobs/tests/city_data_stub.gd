class_name CityDataStub
## Tiny helper so tests can check building ids without the CityData autoload.

static var _ids := {}


static func known(id: String) -> bool:
	if _ids.is_empty():
		for p in ["res://data/buildings.json", "res://jobs/tests/buildings_ids.json"]:
			if FileAccess.file_exists(p):
				var d = JSON.parse_string(FileAccess.get_file_as_string(p))
				var arr: Array = d.buildings if d is Dictionary and d.has("buildings") else d
				for b in arr:
					_ids[b.id if b is Dictionary else b] = true
				break
	return _ids.has(id)
