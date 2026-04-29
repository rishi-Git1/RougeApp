extends RefCounted
class_name PokemonFactory

const POKEDEX_PATH := "res://data/pokedex.json"
const MOVES_PATH := "res://data/moves.json"
const ABILITIES_PATH := "res://data/abilities.json"
const NATURES_PATH := "res://data/natures.json"
const TYPES_PATH := "res://data/types.json"
const SPECIES_PROFILES_PATH := "res://data/species_profiles.json"
const DEFAULT_IV := 31
const DEFAULT_EV := 0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var pokedex: Array = []
var moves: Array = []
var abilities: Array = []
var natures: Array = []
var types: Array = []
var supported_ability_names: Array[String] = []
var ability_effects: AbilityEffects
var move_index_by_norm_name: Dictionary = {}
var move_index_by_id: Dictionary = {}
var species_profiles_by_id: Dictionary = {}


func _init() -> void:
	rng.randomize()
	ability_effects = AbilityEffects.new()
	pokedex = _load_json_array(POKEDEX_PATH)
	moves = _load_json_array(MOVES_PATH)
	abilities = _load_json_array(ABILITIES_PATH)
	natures = _load_json_array(NATURES_PATH)
	types = _load_json_array(TYPES_PATH)
	supported_ability_names = ability_effects.extract_supported_abilities(abilities)
	_build_move_indexes()
	_load_species_profiles()


func build_randomized_pokemon(pokedex_id: int, level: int) -> Dictionary:
	var base_entry: Dictionary = _get_pokedex_entry(pokedex_id)
	if base_entry.is_empty():
		return {}

	var assigned_types: Array = _types_for_species(pokedex_id)
	var assigned_moves: Array = _pick_species_moves_for_level(pokedex_id, level, assigned_types)
	var move_pp: Array[int] = []
	for idx in range(assigned_moves.size()):
		var move_data: Dictionary = assigned_moves[idx]
		move_pp.append(max(1, int(move_data.get("pp", 1))))
	var ability: String = _pick_species_ability_name(pokedex_id)
	var nature: String = str(natures[rng.randi_range(0, natures.size() - 1)])
	var stats: Dictionary = scaled_stats(base_entry["base_stats"], level)
	var growth_rate: String = _growth_rate_for_species(pokedex_id)
	var total_experience: int = experience_for_level(level, growth_rate)
	var base_experience: int = _base_experience_for_species(pokedex_id)

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
		"growth_rate": growth_rate,
		"experience": total_experience,
		"base_experience_yield": base_experience,
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

	var type_list: Array = pokemon.get("types", [])
	var type_text: String = "Unknown"
	if type_list.is_empty() == false:
		var names: Array[String] = []
		for idx in range(type_list.size()):
			names.append(str(type_list[idx]))
		type_text = " / ".join(names)

	return "%s (Lv.%d)\nTypes: %s\nAbility: %s\nNature: %s\nMoves: %s" % [
		pokemon["name"],
		pokemon["level"],
		type_text,
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


func get_base_experience_yield_for_species(pokedex_id: int) -> int:
	return _base_experience_for_species(pokedex_id)


func get_growth_rate_for_species(pokedex_id: int) -> String:
	return _growth_rate_for_species(pokedex_id)


func get_random_pokedex_id() -> int:
	if pokedex.is_empty():
		return 0
	var idx: int = rng.randi_range(0, pokedex.size() - 1)
	var entry: Dictionary = pokedex[idx]
	return int(entry["id"])


func _types_for_species(pokedex_id: int) -> Array:
	var profile: Dictionary = _species_profile_for_id(pokedex_id)
	var raw_types: Array = profile.get("types", [])
	var resolved: Array = []
	for idx in range(raw_types.size()):
		var type_name: String = str(raw_types[idx]).strip_edges()
		if type_name.is_empty():
			continue
		resolved.append(type_name)
	if resolved.is_empty():
		resolved.append("Normal")
	return resolved


func _base_experience_for_species(pokedex_id: int) -> int:
	var profile: Dictionary = _species_profile_for_id(pokedex_id)
	var value: int = int(profile.get("base_experience", 64))
	return max(1, value)


func _growth_rate_for_species(pokedex_id: int) -> String:
	var profile: Dictionary = _species_profile_for_id(pokedex_id)
	var value: String = str(profile.get("growth_rate", "medium")).to_lower()
	if value.is_empty():
		return "medium"
	return value


func _pick_species_moves_for_level(pokedex_id: int, level: int, species_types: Array) -> Array:
	var profile: Dictionary = _species_profile_for_id(pokedex_id)
	var learnset: Array = profile.get("level_up_moves", [])
	var eligible: Array = []
	for idx in range(learnset.size()):
		var row_value = learnset[idx]
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		var learn_level: int = int(row.get("level", 0))
		if learn_level > level:
			continue
		var resolved: Dictionary = _resolve_move_from_profile_row(row)
		if resolved.is_empty():
			continue
		eligible.append(resolved)
	if eligible.is_empty():
		return _pick_four_moves_for_types(species_types)

	var picks_reversed: Array = []
	var used: Dictionary = {}
	for idx in range(eligible.size() - 1, -1, -1):
		var move_data: Dictionary = eligible[idx]
		var move_key: String = _normalize_key(str(move_data.get("name", "")))
		if used.has(move_key):
			continue
		used[move_key] = true
		picks_reversed.append(move_data)
		if picks_reversed.size() >= 4:
			break

	var picks: Array = []
	for idx in range(picks_reversed.size() - 1, -1, -1):
		picks.append(picks_reversed[idx])
	return picks


func _resolve_move_from_profile_row(row: Dictionary) -> Dictionary:
	var move_id: int = int(row.get("id", 0))
	if move_id > 0 and move_index_by_id.has(move_id):
		return move_index_by_id[move_id]
	var move_name: String = str(row.get("name", ""))
	var move_key: String = _normalize_key(move_name)
	if move_index_by_norm_name.has(move_key):
		return move_index_by_norm_name[move_key]
	return {}


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


func _pick_species_ability_name(pokedex_id: int) -> String:
	var profile: Dictionary = _species_profile_for_id(pokedex_id)
	var ability_rows: Array = profile.get("abilities", [])
	var pool: Array[String] = []
	for idx in range(ability_rows.size()):
		var row_value = ability_rows[idx]
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		if bool(row.get("is_hidden", false)):
			continue
		var ability_name: String = str(row.get("name", "")).strip_edges()
		if ability_name.is_empty():
			continue
		pool.append(ability_name)
	if pool.is_empty() == false:
		return pool[rng.randi_range(0, pool.size() - 1)]
	return _pick_ability_name()


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


func _build_move_indexes() -> void:
	move_index_by_norm_name.clear()
	move_index_by_id.clear()
	for idx in range(moves.size()):
		var move_value = moves[idx]
		if typeof(move_value) != TYPE_DICTIONARY:
			continue
		var move_data: Dictionary = move_value
		var move_id: int = int(move_data.get("id", 0))
		if move_id > 0:
			move_index_by_id[move_id] = move_data
		var key: String = _normalize_key(str(move_data.get("name", "")))
		if key.is_empty():
			continue
		move_index_by_norm_name[key] = move_data


func _load_species_profiles() -> void:
	species_profiles_by_id.clear()
	if not FileAccess.file_exists(SPECIES_PROFILES_PATH):
		return
	var file := FileAccess.open(SPECIES_PROFILES_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	var rows: Array = []
	if typeof(parsed) == TYPE_ARRAY:
		rows = parsed
	elif typeof(parsed) == TYPE_DICTIONARY:
		rows = parsed.get("entries", [])
	for idx in range(rows.size()):
		var row_value = rows[idx]
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		var species_id: int = int(row.get("id", 0))
		if species_id <= 0:
			continue
		species_profiles_by_id[species_id] = row


func _species_profile_for_id(pokedex_id: int) -> Dictionary:
	if species_profiles_by_id.has(pokedex_id):
		return species_profiles_by_id[pokedex_id]
	return {}


func _normalize_key(value: String) -> String:
	var lower: String = value.to_lower()
	var out := ""
	for idx in range(lower.length()):
		var ch: String = lower[idx]
		var code: int = ch.unicode_at(0)
		var is_number: bool = code >= 48 and code <= 57
		var is_letter: bool = code >= 97 and code <= 122
		if is_number or is_letter:
			out += ch
	return out


func _pick_ability_name() -> String:
	if supported_ability_names.is_empty():
		return "Moxie"
	return supported_ability_names[rng.randi_range(0, supported_ability_names.size() - 1)]


func scaled_stats(base_stats: Dictionary, level: int) -> Dictionary:
	var clamped_level: int = clamp(level, 1, 100)
	var iv: float = float(DEFAULT_IV)
	var ev_quarter: float = float(DEFAULT_EV) / 4.0
	var hp: int = int(floor((((2.0 * float(base_stats["hp"]) + iv + ev_quarter) * float(clamped_level)) / 100.0) + float(clamped_level) + 10.0))
	var atk: int = int(floor((((2.0 * float(base_stats["atk"]) + iv + ev_quarter) * float(clamped_level)) / 100.0) + 5.0))
	var defense: int = int(floor((((2.0 * float(base_stats["def"]) + iv + ev_quarter) * float(clamped_level)) / 100.0) + 5.0))
	var spa: int = int(floor((((2.0 * float(base_stats["spa"]) + iv + ev_quarter) * float(clamped_level)) / 100.0) + 5.0))
	var spd: int = int(floor((((2.0 * float(base_stats["spd"]) + iv + ev_quarter) * float(clamped_level)) / 100.0) + 5.0))
	var spe: int = int(floor((((2.0 * float(base_stats["spe"]) + iv + ev_quarter) * float(clamped_level)) / 100.0) + 5.0))
	return {
		"hp": max(1, hp),
		"atk": max(1, atk),
		"def": max(1, defense),
		"spa": max(1, spa),
		"spd": max(1, spd),
		"spe": max(1, spe)
	}


func experience_for_level(level: int, growth_rate: String) -> int:
	var n: int = clamp(level, 1, 100)
	var n_f: float = float(n)
	var cubic: float = n_f * n_f * n_f
	var rate: String = str(growth_rate).to_lower()
	if rate == "fast":
		return int(floor((4.0 * cubic) / 5.0))
	if rate == "medium" or rate == "medium-fast" or rate == "medium fast":
		return int(floor(cubic))
	if rate == "medium-slow" or rate == "medium slow":
		return int(floor((6.0 / 5.0) * cubic - 15.0 * n_f * n_f + 100.0 * n_f - 140.0))
	if rate == "slow":
		return int(floor((5.0 * cubic) / 4.0))
	if rate == "fluctuating":
		if n <= 15:
			return int(floor(cubic * ((floor((n_f + 1.0) / 3.0) + 24.0) / 50.0)))
		if n <= 35:
			return int(floor(cubic * ((n_f + 14.0) / 50.0)))
		return int(floor(cubic * ((floor(n_f / 2.0) + 32.0) / 50.0)))
	if rate == "erratic":
		if n <= 50:
			return int(floor(cubic * ((100.0 - n_f) / 50.0)))
		if n <= 68:
			return int(floor(cubic * ((150.0 - n_f) / 100.0)))
		if n <= 98:
			return int(floor(cubic * floor((1911.0 - 10.0 * n_f) / 3.0) / 500.0))
		return int(floor(cubic * ((160.0 - n_f) / 100.0)))
	# Default to medium-fast if unknown.
	return int(floor(cubic))


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
