extends RefCounted
class_name AbilityEffects

const WEATHER_SETTER_ABILITIES := {}

const TYPE_IMMUNITY_ABILITIES := {
	"ground": ["levitate"],
	"electric": ["volt absorb", "lightning rod", "motor drive"],
	"water": ["water absorb", "storm drain", "dry skin"],
	"fire": ["flash fire"],
	"grass": ["sap sipper"]
}

const STATUS_IMMUNITY_ABILITIES := {
	"burn": ["water veil", "water bubble"],
	"poison": ["immunity", "pastel veil"],
	"paralysis": ["limber"],
	"sleep": ["insomnia", "vital spirit", "sweet veil"],
	"freeze": ["magma armor"]
}

const CRIT_IMMUNE_ABILITIES := {
	"battle armor": true,
	"shell armor": true
}

const FLINCH_IMMUNE_ABILITIES := {
	"inner focus": true
}

const RECOIL_IMMUNE_ABILITIES := {
	"rock head": true
}

const IMPLEMENTED_ABILITIES := {
	# Core mechanics
	"moxie": true,
	"rock head": true,
	"intimidate": true,
	"battle armor": true,
	"shell armor": true,
	"inner focus": true,
	# Type immunities and absorb
	"levitate": true,
	"volt absorb": true,
	"water absorb": true,
	"flash fire": true,
	"motor drive": true,
	"lightning rod": true,
	"storm drain": true,
	"sap sipper": true,
	"dry skin": true,
	# Scaling multipliers
	"huge power": true,
	"pure power": true,
	"guts": true,
	"hustle": true,
	"blaze": true,
	"torrent": true,
	"overgrow": true,
	"swarm": true,
	"swift swim": true,
	"chlorophyll": true,
	"sand rush": true,
	"slush rush": true,
	"quick feet": true,
	"marvel scale": true,
	"thick fat": true,
	"fur coat": true,
	# Status immunity families
	"water veil": true,
	"water bubble": true,
	"immunity": true,
	"pastel veil": true,
	"limber": true,
	"insomnia": true,
	"vital spirit": true,
	"sweet veil": true,
	"magma armor": true,
	# End-of-turn/battleflow
	"rain dish": true,
	"ice body": true,
	"speed boost": true,
	"shed skin": true
}


func normalize_ability_name(name: String) -> String:
	return name.strip_edges().to_lower()


func is_supported_ability(name: String) -> bool:
	return IMPLEMENTED_ABILITIES.has(normalize_ability_name(name))


func extract_supported_abilities(raw_abilities: Array) -> Array[String]:
	var names: Array[String] = []
	for idx in range(raw_abilities.size()):
		var raw_value = raw_abilities[idx]
		var ability_name: String = ""
		if typeof(raw_value) == TYPE_DICTIONARY:
			ability_name = str(raw_value.get("name", ""))
		else:
			ability_name = str(raw_value)
		var lower_name: String = normalize_ability_name(ability_name)
		if lower_name.is_empty():
			continue
		if not is_supported_ability(lower_name):
			continue
		if names.has(ability_name):
			continue
		names.append(ability_name)
	return names


func switch_in_weather(ability_name: String) -> String:
	return str(WEATHER_SETTER_ABILITIES.get(normalize_ability_name(ability_name), ""))


func has_intimidate(ability_name: String) -> bool:
	return normalize_ability_name(ability_name) == "intimidate"


func is_crit_immune(ability_name: String) -> bool:
	return CRIT_IMMUNE_ABILITIES.has(normalize_ability_name(ability_name))


func is_flinch_immune(ability_name: String) -> bool:
	return FLINCH_IMMUNE_ABILITIES.has(normalize_ability_name(ability_name))


func is_recoil_immune(ability_name: String) -> bool:
	return RECOIL_IMMUNE_ABILITIES.has(normalize_ability_name(ability_name))


func blocks_status(ability_name: String, status_name: String) -> bool:
	var lower_ability: String = normalize_ability_name(ability_name)
	var lower_status: String = status_name.to_lower()
	if not STATUS_IMMUNITY_ABILITIES.has(lower_status):
		return false
	var blocked_by: Array = STATUS_IMMUNITY_ABILITIES[lower_status]
	for idx in range(blocked_by.size()):
		if lower_ability == str(blocked_by[idx]):
			return true
	return false


func offensive_stat_multiplier(ability_name: String, stat_key: String, status_name: String, weather_name: String) -> float:
	var lower_ability: String = normalize_ability_name(ability_name)
	var lower_status: String = status_name.to_lower()
	var lower_weather: String = weather_name.to_lower()
	match stat_key:
		"atk":
			if lower_ability == "huge power" or lower_ability == "pure power":
				return 2.0
			if lower_ability == "guts" and not lower_status.is_empty():
				return 1.5
		"spe":
			if lower_ability == "swift swim" and lower_weather == "rain":
				return 2.0
			if lower_ability == "chlorophyll" and lower_weather == "sun":
				return 2.0
			if lower_ability == "sand rush" and lower_weather == "sandstorm":
				return 2.0
			if lower_ability == "slush rush" and lower_weather == "hail":
				return 2.0
			if lower_ability == "quick feet" and not lower_status.is_empty():
				return 1.5
		"def":
			if lower_ability == "marvel scale" and not lower_status.is_empty():
				return 1.5
			if lower_ability == "fur coat":
				return 2.0
	return 1.0


func physical_accuracy_multiplier(ability_name: String) -> float:
	if normalize_ability_name(ability_name) == "hustle":
		return 0.8
	return 1.0


func outgoing_damage_multiplier(ability_name: String, move_type: String, hp_now: int, hp_max: int, flash_fire_active: bool) -> float:
	var lower_ability: String = normalize_ability_name(ability_name)
	var normalized_move_type: String = move_type
	var hp_ratio: float = 1.0
	if hp_max > 0:
		hp_ratio = float(hp_now) / float(hp_max)
	var boosted: bool = hp_ratio <= (1.0 / 3.0)
	if lower_ability == "blaze" and normalized_move_type == "Fire" and boosted:
		return 1.5
	if lower_ability == "torrent" and normalized_move_type == "Water" and boosted:
		return 1.5
	if lower_ability == "overgrow" and normalized_move_type == "Grass" and boosted:
		return 1.5
	if lower_ability == "swarm" and normalized_move_type == "Bug" and boosted:
		return 1.5
	if lower_ability == "flash fire" and normalized_move_type == "Fire" and flash_fire_active:
		return 1.5
	return 1.0


func incoming_damage_multiplier(ability_name: String, move_type: String, category: String) -> float:
	var lower_ability: String = normalize_ability_name(ability_name)
	if lower_ability == "thick fat":
		if move_type == "Fire" or move_type == "Ice":
			return 0.5
	if lower_ability == "water bubble" and move_type == "Fire":
		return 0.5
	if lower_ability == "dry skin" and move_type == "Fire":
		return 1.25
	if lower_ability == "fur coat" and category == "Physical":
		return 0.5
	return 1.0


func type_immunity_action(ability_name: String, move_type: String) -> Dictionary:
	var lower_ability: String = normalize_ability_name(ability_name)
	var lower_type: String = move_type.to_lower()
	var action := {
		"immune": false,
		"heal_fraction": 0.0,
		"boost_stat": "",
		"activate_flash_fire": false
	}
	if not TYPE_IMMUNITY_ABILITIES.has(lower_type):
		return action
	var abilities: Array = TYPE_IMMUNITY_ABILITIES[lower_type]
	var matched: bool = false
	for idx in range(abilities.size()):
		if lower_ability == str(abilities[idx]):
			matched = true
			break
	if not matched:
		return action
	action["immune"] = true
	if lower_ability == "volt absorb" or lower_ability == "water absorb" or lower_ability == "dry skin":
		action["heal_fraction"] = 0.25
	if lower_ability == "motor drive":
		action["boost_stat"] = "spe"
	if lower_ability == "lightning rod" or lower_ability == "storm drain":
		action["boost_stat"] = "spa"
	if lower_ability == "sap sipper":
		action["boost_stat"] = "atk"
	if lower_ability == "flash fire":
		action["activate_flash_fire"] = true
	return action


func end_of_round_action(ability_name: String, weather_name: String, status_name: String, rng: RandomNumberGenerator) -> Dictionary:
	var lower_ability: String = normalize_ability_name(ability_name)
	var lower_weather: String = weather_name.to_lower()
	var action := {
		"heal_fraction": 0.0,
		"damage_fraction": 0.0,
		"cure_status": false,
		"boost_speed": false
	}
	if lower_ability == "rain dish" and lower_weather == "rain":
		action["heal_fraction"] = 1.0 / 16.0
	if lower_ability == "ice body" and lower_weather == "hail":
		action["heal_fraction"] = 1.0 / 16.0
	if lower_ability == "dry skin":
		if lower_weather == "rain":
			action["heal_fraction"] = 1.0 / 8.0
		elif lower_weather == "sun":
			action["damage_fraction"] = 1.0 / 8.0
	if lower_ability == "speed boost":
		action["boost_speed"] = true
	if lower_ability == "shed skin" and not status_name.is_empty():
		action["cure_status"] = rng.randf() < 0.3
	return action
