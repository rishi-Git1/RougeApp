extends RefCounted
class_name EncounterDatabase

const ENCOUNTERS_PATH := "res://data/project_encounters.json"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _encounters_by_key: Dictionary = {}
var _pokedex_id_by_normalized_name: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	rng.randomize()


func load_database(pokedex_entries: Array) -> void:
	_loaded = false
	_encounters_by_key.clear()
	_pokedex_id_by_normalized_name.clear()
	_index_pokedex(pokedex_entries)
	_load_encounters_json()
	_loaded = true


func is_loaded() -> bool:
	return _loaded


func get_location_methods() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _encounters_by_key.keys():
		var parsed: Dictionary = _split_key(str(key))
		result.append(parsed)
	return result


func get_encounters(location: String, method: String) -> Array:
	var key: String = _encounter_key(location, method)
	if not _encounters_by_key.has(key):
		return []
	return _encounters_by_key[key]


func roll_encounter(location: String, method: String) -> Dictionary:
	var entries: Array = get_encounters(location, method)
	if entries.is_empty():
		return {}
	var total_rate: int = 0
	for idx in range(entries.size()):
		var row: Dictionary = entries[idx]
		total_rate += max(0, int(row.get("rate", 0)))
	if total_rate <= 0:
		return {}

	var roll: int = rng.randi_range(1, total_rate)
	var cursor: int = 0
	for idx in range(entries.size()):
		var row: Dictionary = entries[idx]
		cursor += max(0, int(row.get("rate", 0)))
		if roll <= cursor:
			var pokemon_name: String = str(row.get("pokemon", ""))
			return {
				"location": location,
				"method": method,
				"pokemon": pokemon_name,
				"rate": int(row.get("rate", 0)),
				"pokedex_id": species_id_from_name(pokemon_name)
			}
	return {}


func species_id_from_name(species_name: String) -> int:
	var normalized: String = _normalize_name(species_name)
	if _pokedex_id_by_normalized_name.has(normalized):
		return int(_pokedex_id_by_normalized_name[normalized])
	return 0


func _index_pokedex(pokedex_entries: Array) -> void:
	for idx in range(pokedex_entries.size()):
		var entry_value = pokedex_entries[idx]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var species_id: int = int(entry.get("id", 0))
		var species_name: String = str(entry.get("name", ""))
		if species_id <= 0 or species_name.is_empty():
			continue
		_pokedex_id_by_normalized_name[_normalize_name(species_name)] = species_id


func _load_encounters_json() -> void:
	if not FileAccess.file_exists(ENCOUNTERS_PATH):
		return
	var file := FileAccess.open(ENCOUNTERS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	var sections: Array = root.get("pokemon_red_encounters", [])
	for idx in range(sections.size()):
		var section_value = sections[idx]
		if typeof(section_value) != TYPE_DICTIONARY:
			continue
		var section: Dictionary = section_value
		var location: String = str(section.get("location", "")).strip_edges()
		var method: String = str(section.get("method", "")).strip_edges()
		if location.is_empty() or method.is_empty():
			continue
		var key: String = _encounter_key(location, method)
		var packed: Array = []
		var entries: Array = section.get("encounters", [])
		for entry_idx in range(entries.size()):
			var row_value = entries[entry_idx]
			if typeof(row_value) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_value
			var species_name: String = str(row.get("pokemon", "")).strip_edges()
			var rate: int = max(0, int(row.get("rate", 0)))
			if species_name.is_empty() or rate <= 0:
				continue
			packed.append({
				"pokemon": species_name,
				"rate": rate
			})
		if not packed.is_empty():
			_encounters_by_key[key] = packed


func _encounter_key(location: String, method: String) -> String:
	return "%s||%s" % [_normalize_name(location), _normalize_name(method)]


func _split_key(key: String) -> Dictionary:
	var chunks: PackedStringArray = key.split("||")
	if chunks.size() < 2:
		return {"location": key, "method": ""}
	return {"location": chunks[0], "method": chunks[1]}


func _normalize_name(value: String) -> String:
	var normalized: String = value.to_lower()
	normalized = normalized.replace("é", "e")
	normalized = normalized.replace("♀", " f ")
	normalized = normalized.replace("♂", " m ")
	normalized = normalized.replace("-", " ")
	normalized = normalized.replace("_", " ")
	normalized = normalized.replace(".", " ")
	normalized = normalized.replace("'", " ")
	normalized = normalized.strip_edges()
	var cleaned := ""
	var previous_space: bool = false
	for idx in range(normalized.length()):
		var ch: String = normalized[idx]
		var code: int = ch.unicode_at(0)
		var is_alpha_num: bool = (code >= 48 and code <= 57) or (code >= 97 and code <= 122)
		if is_alpha_num:
			cleaned += ch
			previous_space = false
		elif not previous_space:
			cleaned += " "
			previous_space = true
	return cleaned.strip_edges()
