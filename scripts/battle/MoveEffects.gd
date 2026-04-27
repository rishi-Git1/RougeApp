extends RefCounted
class_name MoveEffects

const MOVE_EFFECTS_PATH := "res://data/move_effects.json"

const FALLBACK_WEATHER := {
	"rain dance": "rain",
	"sunny day": "sun",
	"sandstorm": "sandstorm",
	"hail": "hail",
	"snowscape": "hail"
}

const FALLBACK_TERRAIN := {
	"electric terrain": "electric",
	"grassy terrain": "grassy",
	"psychic terrain": "psychic",
	"misty terrain": "misty"
}

const FALLBACK_BARRIER := {
	"reflect": "reflect",
	"light screen": "light_screen",
	"aurora veil": "aurora_veil"
}

const FALLBACK_HAZARD := {
	"stealth rock": "stealth_rock",
	"spikes": "spikes",
	"toxic spikes": "toxic_spikes",
	"sticky web": "sticky_web"
}

const FALLBACK_PROTECT := {
	"protect": true,
	"detect": true,
	"max guard": true
}

const BYPASS_PROTECT_MOVES := {
	"phantom force": true,
	"shadow force": true,
	"feint": true,
	"hyperspace fury": true,
	"hyperspace hole": true
}

const SEMI_INVULNERABLE_STATE_BY_MOVE := {
	"fly": "airborne",
	"bounce": "airborne",
	"dig": "underground",
	"dive": "underwater",
	"phantom force": "vanished",
	"shadow force": "vanished"
}

const SEMI_INVULNERABLE_BYPASS_BY_STATE := {
	"airborne": {
		"gust": 2.0,
		"thunder": 1.0,
		"hurricane": 1.0,
		"twister": 2.0,
		"sky uppercut": 1.0,
		"smack down": 1.0,
		"thousand arrows": 1.0
	},
	"underground": {
		"earthquake": 2.0,
		"magnitude": 2.0,
		"fissure": 1.0
	},
	"underwater": {
		"surf": 2.0,
		"whirlpool": 2.0
	},
	"vanished": {}
}

const DEFAULT_PROFILE := {
	"id": 0,
	"name": "",
	"status": "",
	"status_chance": 0,
	"weather": "",
	"terrain": "",
	"barrier": "",
	"hazard": "",
	"protect": false,
	"trap": false,
	"trap_min_turns": 0,
	"trap_max_turns": 0,
	"flinch": false,
	"flinch_chance": 0,
	"drain_fraction": 0.0,
	"recoil_fraction": 0.0,
	"self_heal_fraction": 0.0,
	"requires_charge": false,
	"requires_recharge": false,
	"min_hits": 0,
	"max_hits": 0,
	"stat_chance": 0,
	"effect_chance": 0,
	"category": "",
	"target": ""
}

var _profiles_by_id: Dictionary = {}
var _profiles_by_name: Dictionary = {}


func _init() -> void:
	_load_profiles()


func normalize_move_name(move_name: String) -> String:
	return move_name.strip_edges().to_lower()


func relation_profile_for_move(move: Dictionary) -> Dictionary:
	var profile: Dictionary = _lookup_profile(move)
	profile = _augment_profile(profile, move)
	return profile


func status_from_move_name(move_name: String) -> String:
	return str(_lookup_profile_by_name(move_name).get("status", ""))


func status_chance_for_move(move: Dictionary) -> int:
	return int(relation_profile_for_move(move).get("status_chance", 0))


func weather_from_move_name(move_name: String) -> String:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	var weather: String = str(profile.get("weather", ""))
	if weather.is_empty():
		return str(FALLBACK_WEATHER.get(normalize_move_name(move_name), ""))
	return weather


func terrain_from_move_name(move_name: String) -> String:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	var terrain: String = str(profile.get("terrain", ""))
	if terrain.is_empty():
		return str(FALLBACK_TERRAIN.get(normalize_move_name(move_name), ""))
	return terrain


func barrier_from_move_name(move_name: String) -> String:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	var barrier: String = str(profile.get("barrier", ""))
	if barrier.is_empty():
		return str(FALLBACK_BARRIER.get(normalize_move_name(move_name), ""))
	return barrier


func hazard_from_move_name(move_name: String) -> String:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	var hazard: String = str(profile.get("hazard", ""))
	if hazard.is_empty():
		return str(FALLBACK_HAZARD.get(normalize_move_name(move_name), ""))
	return hazard


func is_protect_move(move_name: String) -> bool:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	if bool(profile.get("protect", false)):
		return true
	return FALLBACK_PROTECT.has(normalize_move_name(move_name))


func bypasses_protect(move_name: String) -> bool:
	return BYPASS_PROTECT_MOVES.has(normalize_move_name(move_name))


func is_trap_move(move_name: String) -> bool:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	return bool(profile.get("trap", false))


func trap_turn_range_for_move(move: Dictionary) -> Vector2i:
	var profile: Dictionary = relation_profile_for_move(move)
	var min_turns: int = int(profile.get("trap_min_turns", 0))
	var max_turns: int = int(profile.get("trap_max_turns", 0))
	if min_turns <= 0 and max_turns <= 0:
		return Vector2i(4, 5)
	if max_turns < min_turns:
		max_turns = min_turns
	return Vector2i(max(1, min_turns), max(1, max_turns))


func causes_flinch(move_name: String) -> bool:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	if bool(profile.get("flinch", false)):
		return true
	return int(profile.get("flinch_chance", 0)) > 0


func flinch_chance_for_move(move: Dictionary) -> int:
	return int(relation_profile_for_move(move).get("flinch_chance", 0))


func drain_fraction_for_move(move_name: String) -> float:
	return float(_lookup_profile_by_name(move_name).get("drain_fraction", 0.0))


func recoil_fraction_for_move(move_name: String) -> float:
	return float(_lookup_profile_by_name(move_name).get("recoil_fraction", 0.0))


func self_heal_fraction_for_move(move_name: String) -> float:
	return float(_lookup_profile_by_name(move_name).get("self_heal_fraction", 0.0))


func requires_charge(move_name: String) -> bool:
	return bool(_lookup_profile_by_name(move_name).get("requires_charge", false))


func requires_recharge(move_name: String) -> bool:
	return bool(_lookup_profile_by_name(move_name).get("requires_recharge", false))


func hit_count_for_move(move_name: String, rng: RandomNumberGenerator, _team_size: int) -> int:
	var profile: Dictionary = _lookup_profile_by_name(move_name)
	var min_hits: int = int(profile.get("min_hits", 0))
	var max_hits: int = int(profile.get("max_hits", 0))
	if min_hits <= 0 and max_hits <= 0:
		return 1
	if max_hits < min_hits:
		max_hits = min_hits
	return rng.randi_range(max(1, min_hits), max(1, max_hits))


func stat_chance_for_move(move: Dictionary) -> int:
	return int(relation_profile_for_move(move).get("stat_chance", 0))


func effect_chance_for_move(move: Dictionary) -> int:
	var profile: Dictionary = relation_profile_for_move(move)
	return int(profile.get("effect_chance", 0))


func semi_invulnerable_state_for_move(move_name: String) -> String:
	return str(SEMI_INVULNERABLE_STATE_BY_MOVE.get(normalize_move_name(move_name), ""))


func can_hit_semi_invulnerable(move_name: String, defender_state: String) -> bool:
	if defender_state.is_empty():
		return true
	var lower_state: String = defender_state.to_lower()
	if not SEMI_INVULNERABLE_BYPASS_BY_STATE.has(lower_state):
		return false
	var move_map: Dictionary = SEMI_INVULNERABLE_BYPASS_BY_STATE[lower_state]
	return move_map.has(normalize_move_name(move_name))


func semi_invulnerable_damage_multiplier(move_name: String, defender_state: String) -> float:
	if defender_state.is_empty():
		return 1.0
	var lower_state: String = defender_state.to_lower()
	if not SEMI_INVULNERABLE_BYPASS_BY_STATE.has(lower_state):
		return 1.0
	var move_map: Dictionary = SEMI_INVULNERABLE_BYPASS_BY_STATE[lower_state]
	var key: String = normalize_move_name(move_name)
	if not move_map.has(key):
		return 1.0
	return float(move_map[key])


func _lookup_profile(move: Dictionary) -> Dictionary:
	var move_id: int = int(move.get("id", 0))
	if move_id > 0 and _profiles_by_id.has(move_id):
		return _profiles_by_id[move_id].duplicate(true)
	var move_name: String = str(move.get("name", ""))
	return _lookup_profile_by_name(move_name)


func _lookup_profile_by_name(move_name: String) -> Dictionary:
	var key: String = normalize_move_name(move_name)
	if _profiles_by_name.has(key):
		return _profiles_by_name[key].duplicate(true)
	return DEFAULT_PROFILE.duplicate(true)


func _augment_profile(profile: Dictionary, move: Dictionary) -> Dictionary:
	var move_name: String = str(move.get("name", ""))
	var move_name_normalized: String = normalize_move_name(move_name)
	if str(profile.get("weather", "")).is_empty():
		profile["weather"] = str(FALLBACK_WEATHER.get(move_name_normalized, ""))
	if str(profile.get("terrain", "")).is_empty():
		profile["terrain"] = str(FALLBACK_TERRAIN.get(move_name_normalized, ""))
	if str(profile.get("barrier", "")).is_empty():
		profile["barrier"] = str(FALLBACK_BARRIER.get(move_name_normalized, ""))
	if str(profile.get("hazard", "")).is_empty():
		profile["hazard"] = str(FALLBACK_HAZARD.get(move_name_normalized, ""))
	if bool(profile.get("protect", false)) == false and FALLBACK_PROTECT.has(move_name_normalized):
		profile["protect"] = true
	return profile


func _load_profiles() -> void:
	_profiles_by_id.clear()
	_profiles_by_name.clear()
	var file := FileAccess.open(MOVE_EFFECTS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = parsed
	var entries: Array = payload.get("entries", [])
	for idx in range(entries.size()):
		var entry_value = entries[idx]
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var move_id: int = int(entry.get("id", 0))
		var move_name: String = normalize_move_name(str(entry.get("name", "")))
		if move_id > 0:
			_profiles_by_id[move_id] = entry
		if not move_name.is_empty():
			_profiles_by_name[move_name] = entry
