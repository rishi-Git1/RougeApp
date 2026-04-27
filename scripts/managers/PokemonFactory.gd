extends RefCounted
class_name PokemonFactory

const POKEDEX_PATH := "res://data/pokedex.json"
const MOVES_PATH := "res://data/moves.json"
const ABILITIES_PATH := "res://data/abilities.json"
const NATURES_PATH := "res://data/natures.json"
const TYPES_PATH := "res://data/types.json"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var pokedex: Array = []
var moves: Array = []
var abilities: Array = []
var natures: Array = []
var types: Array = []
var supported_ability_names: Array[String] = []
var ability_effects: AbilityEffects


func _init() -> void:
	rng.randomize()
	ability_effects = AbilityEffects.new()
	pokedex = _load_json_array(POKEDEX_PATH)
	moves = _load_json_array(MOVES_PATH)
	abilities = _load_json_array(ABILITIES_PATH)
	natures = _load_json_array(NATURES_PATH)
	types = _load_json_array(TYPES_PATH)
	supported_ability_names = ability_effects.extract_supported_abilities(abilities)


func build_randomized_pokemon(pokedex_id: int, level: int) -> Dictionary:
	var base_entry: Dictionary = _get_pokedex_entry(pokedex_id)
	if base_entry.is_empty():
		return {}

	var assigned_types: Array = _pick_two_types()
	var assigned_moves: Array = _pick_four_moves_for_types(assigned_types)
	var move_pp: Array[int] = []
	for idx in range(assigned_moves.size()):
		var move_data: Dictionary = assigned_moves[idx]
		move_pp.append(max(1, int(move_data.get("pp", 1))))
	var ability: String = _pick_ability_name()
	var nature: String = str(natures[rng.randi_range(0, natures.size() - 1)])
	var stats: Dictionary = scaled_stats(base_entry["base_stats"], level)

	return {
		"id": base_entry["id"],
		"name": base_entry["name"],
		"level": level,
		"types": assigned_types,
		"moves": assigned_moves,
		"move_pp": move_pp.duplicate(),
		"move_pp_max": move_pp.duplicate(),
		"ability": ability,
		"nature": nature,
		"base_stats": base_entry["base_stats"],
		"stats": stats,
		"current_hp": int(stats["hp"]),
		"status": "",
		"sleep_turns": 0,
		"toxic_counter": 0,
		"stat_stages": {
			"atk": 0,
			"def": 0,
			"spa": 0,
			"spd": 0,
			"spe": 0,
			"accuracy": 0,
			"evasion": 0
		}
	}


func summarize_pokemon(pokemon: Dictionary) -> String:
	if pokemon.is_empty():
		return "Invalid Pokemon."

	var move_names: Array[String] = []
	var pokemon_moves: Array = pokemon["moves"]
	for idx in range(pokemon_moves.size()):
		var move_data: Dictionary = pokemon_moves[idx]
		move_names.append(str(move_data["name"]))

	return "%s (Lv.%d)\nTypes: %s / %s\nAbility: %s\nNature: %s\nMoves: %s" % [
		pokemon["name"],
		pokemon["level"],
		pokemon["types"][0],
		pokemon["types"][1],
		pokemon["ability"],
		pokemon["nature"],
		", ".join(move_names)
	]


func get_all_pokedex_ids() -> Array[int]:
	var ids: Array[int] = []
	for idx in range(pokedex.size()):
		var entry: Dictionary = pokedex[idx]
		ids.append(int(entry["id"]))
	return ids


func get_species_name(pokedex_id: int) -> String:
	var entry := _get_pokedex_entry(pokedex_id)
	if entry.is_empty():
		return "Unknown #%d" % pokedex_id
	return str(entry["name"])


func get_base_entry(pokedex_id: int) -> Dictionary:
	return _get_pokedex_entry(pokedex_id)


func get_random_pokedex_id() -> int:
	if pokedex.is_empty():
		return 0
	var idx: int = rng.randi_range(0, pokedex.size() - 1)
	var entry: Dictionary = pokedex[idx]
	return int(entry["id"])


func _pick_two_types() -> Array:
	var first: String = str(types[rng.randi_range(0, types.size() - 1)])
	var second: String = first
	while second == first:
		second = str(types[rng.randi_range(0, types.size() - 1)])
	return [first, second]


func _pick_four_moves_for_types(assigned_types: Array) -> Array:
	var picks: Array = []
	var used_move_ids: Dictionary = {}
	var type_one: String = "Normal"
	var type_two: String = "Normal"
	if assigned_types.size() > 0:
		type_one = str(assigned_types[0])
	if assigned_types.size() > 1:
		type_two = str(assigned_types[1])
	var type_one_damaging: Array[int] = _collect_move_indices(type_one, false)
	var type_two_damaging: Array[int] = _collect_move_indices(type_two, false)
	var status_moves: Array[int] = _collect_move_indices("", true)
	var all_damaging: Array[int] = _collect_move_indices("", false)

	# 1) Type one damaging move.
	_append_random_move_from_pools(picks, used_move_ids, [type_one_damaging, all_damaging, status_moves])
	# 2) Type two damaging move.
	_append_random_move_from_pools(picks, used_move_ids, [type_two_damaging, all_damaging, status_moves])
	# 3) Random status move.
	_append_random_move_from_pools(picks, used_move_ids, [status_moves, all_damaging])
	# 4) Random damaging move.
	_append_random_move_from_pools(picks, used_move_ids, [all_damaging, status_moves])

	while picks.size() < 4:
		var fallback_indices: Array[int] = _collect_move_indices("", false)
		if fallback_indices.is_empty():
			fallback_indices = _collect_move_indices("", true)
		var fallback_move: Dictionary = _pick_random_move_from_indices(fallback_indices, used_move_ids)
		if fallback_move.is_empty():
			break
		picks.append(fallback_move)

	return picks


func _collect_move_indices(required_type: String, status_only: bool) -> Array[int]:
	var result: Array[int] = []
	for idx in range(moves.size()):
		var move_data: Dictionary = moves[idx]
		if _is_banned_move(move_data):
			continue
		var is_status: bool = str(move_data.get("category", "Status")) == "Status"
		if status_only and not is_status:
			continue
		if not status_only and is_status:
			continue
		if not required_type.is_empty() and str(move_data.get("type", "")) != required_type:
			continue
		result.append(idx)
	return result


func _append_random_move_from_pools(picks: Array, used_move_ids: Dictionary, pools: Array) -> void:
	for pool_idx in range(pools.size()):
		var indices: Array[int] = pools[pool_idx]
		var selected: Dictionary = _pick_random_move_from_indices(indices, used_move_ids)
		if selected.is_empty():
			continue
		picks.append(selected)
		return


func _pick_random_move_from_indices(indices: Array[int], used_move_ids: Dictionary) -> Dictionary:
	if indices.is_empty():
		return {}
	var available: Array[int] = indices.duplicate()
	while available.is_empty() == false:
		var roll: int = rng.randi_range(0, available.size() - 1)
		var move_idx: int = int(available[roll])
		available.remove_at(roll)
		var move_data: Dictionary = moves[move_idx]
		var move_id: int = int(move_data.get("id", 0))
		if used_move_ids.has(move_id):
			continue
		used_move_ids[move_id] = true
		return move_data
	return {}


func _is_banned_move(move_data: Dictionary) -> bool:
	var move_id: int = int(move_data.get("id", 0))
	# Canonical Z-Move ranges in this dataset.
	if move_id >= 622 and move_id <= 658:
		return true
	if move_id >= 695 and move_id <= 703:
		return true
	if move_id >= 719 and move_id <= 728:
		return true

	var move_name: String = str(move_data.get("name", "")).to_lower()
	# Dynamax/Max move exclusions.
	if move_name.begins_with("max "):
		return true
	if move_name.begins_with("g-max "):
		return true
	if move_name == "max guard":
		return true

	var z_move_names := {
		"breakneck blitz  physical": true,
		"breakneck blitz  special": true,
		"all-out pummeling  physical": true,
		"all-out pummeling  special": true,
		"supersonic skystrike  physical": true,
		"supersonic skystrike  special": true,
		"acid downpour  physical": true,
		"acid downpour  special": true,
		"tectonic rage  physical": true,
		"tectonic rage  special": true,
		"continental crush  physical": true,
		"continental crush  special": true,
		"savage spin-out  physical": true,
		"savage spin-out  special": true,
		"never-ending nightmare  physical": true,
		"never-ending nightmare  special": true,
		"corkscrew crash  physical": true,
		"corkscrew crash  special": true,
		"inferno overdrive  physical": true,
		"inferno overdrive  special": true,
		"hydro vortex  physical": true,
		"hydro vortex  special": true,
		"bloom doom  physical": true,
		"bloom doom  special": true,
		"gigavolt havoc  physical": true,
		"gigavolt havoc  special": true,
		"shattered psyche  physical": true,
		"shattered psyche  special": true,
		"subzero slammer  physical": true,
		"subzero slammer  special": true,
		"devastating drake  physical": true,
		"devastating drake  special": true,
		"black hole eclipse  physical": true,
		"black hole eclipse  special": true,
		"twinkle tackle  physical": true,
		"twinkle tackle  special": true,
		"catastropika": true,
		"10000000 volt thunderbolt": true,
		"stoked sparksurfer": true,
		"extreme evoboost": true,
		"pulverizing pancake": true,
		"genesis supernova": true,
		"sinister arrow raid": true,
		"malicious moonsault": true,
		"oceanic operetta": true,
		"splintered stormshards": true,
		"let's snuggle forever": true,
		"lets snuggle forever": true,
		"clangorous soulblaze": true,
		"guardian of alola": true,
		"searing sunraze smash": true,
		"menacing moonraze maelstrom": true,
		"light that burns the sky": true,
		"soul-stealing 7-star strike": true,
		"soul stealing 7 star strike": true,
		"10,000,000 volt thunderbolt": true,
		"10 000 000 volt thunderbolt": true
	}
	return z_move_names.has(move_name)


func _pick_ability_name() -> String:
	if supported_ability_names.is_empty():
		return "Moxie"
	return supported_ability_names[rng.randi_range(0, supported_ability_names.size() - 1)]


func scaled_stats(base_stats: Dictionary, level: int) -> Dictionary:
	return {
		"hp": int((base_stats["hp"] * level) / 50.0) + 10,
		"atk": int((base_stats["atk"] * level) / 50.0) + 5,
		"def": int((base_stats["def"] * level) / 50.0) + 5,
		"spa": int((base_stats["spa"] * level) / 50.0) + 5,
		"spd": int((base_stats["spd"] * level) / 50.0) + 5,
		"spe": int((base_stats["spe"] * level) / 50.0) + 5
	}


func _get_pokedex_entry(pokedex_id: int) -> Dictionary:
	for idx in range(pokedex.size()):
		var entry: Dictionary = pokedex[idx]
		if int(entry["id"]) == pokedex_id:
			return entry
	return {}


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid array JSON at: %s" % path)
		return []

	return parsed
