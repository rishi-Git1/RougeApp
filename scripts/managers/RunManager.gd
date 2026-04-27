extends Node
class_name RunManager

signal run_started()
signal run_ended(message: String)
signal floor_changed(floor: int)
signal team_changed(team: Array)
signal enemy_changed(summary: String)
signal battle_log_changed(text: String)
signal battle_state_changed(state: Dictionary)
signal unlock_offer_created(summary: String)
signal unlock_offer_closed()
signal evolution_offer_created(summary: String)
signal evolution_offer_closed()
signal permanent_unlocks_changed(unlocks: Array[int])
signal run_save_debug_changed(text: String)

const TEAM_SIZE := 6
const MAX_FLOOR := 50
const UNLOCK_INTERVAL := 5
const BOSS_INTERVAL := 10
const FULL_HEAL_INTERVAL := 10
const CRIT_CHANCE_DENOM := 24
const STARTING_TEAM_LEVEL := 5
const BASIC_ONLY_FLOOR_LIMIT := 10
const STARTER_PIKACHU_ID := 25
const STARTER_EEVEE_ID := 133
const UNLOCK_SAVE_PATH := "user://permanent_unlocks.json"
const RUN_SAVE_PATH := "user://run_state.json"
const EVOLUTIONS_PATH := "res://data/evolutions.json"
const BASIC_SPECIES_PATH := "res://data/basic_species_ids.json"
const MAX_BATTLE_LOG_LINES := 8
const TYPE_COLORS := {
	"Bug": "#94BC4A",
	"Dark": "#736C75",
	"Dragon": "#6A7BAF",
	"Electric": "#E5C531",
	"Fairy": "#E397D1",
	"Fighting": "#CB5F48",
	"Fire": "#EA7A3C",
	"Flying": "#7DA6DE",
	"Ghost": "#846AB6",
	"Grass": "#71C558",
	"Ground": "#CC9F4F",
	"Ice": "#70CBD4",
	"Normal": "#AAB09F",
	"Poison": "#B468B7",
	"Psychic": "#E5709B",
	"Rock": "#B2A061",
	"Steel": "#89A1B0",
	"Water": "#539AE2"
}

const TYPE_CHART := {
	"Normal": {"Rock": 0.5, "Ghost": 0.0, "Steel": 0.5},
	"Fire": {"Fire": 0.5, "Water": 0.5, "Grass": 2.0, "Ice": 2.0, "Bug": 2.0, "Rock": 0.5, "Dragon": 0.5, "Steel": 2.0},
	"Water": {"Fire": 2.0, "Water": 0.5, "Grass": 0.5, "Ground": 2.0, "Rock": 2.0, "Dragon": 0.5},
	"Electric": {"Water": 2.0, "Electric": 0.5, "Grass": 0.5, "Ground": 0.0, "Flying": 2.0, "Dragon": 0.5},
	"Grass": {"Fire": 0.5, "Water": 2.0, "Grass": 0.5, "Poison": 0.5, "Ground": 2.0, "Flying": 0.5, "Bug": 0.5, "Rock": 2.0, "Dragon": 0.5, "Steel": 0.5},
	"Ground": {"Fire": 2.0, "Electric": 2.0, "Grass": 0.5, "Poison": 2.0, "Flying": 0.0, "Bug": 0.5, "Rock": 2.0, "Steel": 2.0},
	"Flying": {"Electric": 0.5, "Grass": 2.0, "Fighting": 2.0, "Bug": 2.0, "Rock": 0.5, "Steel": 0.5},
	"Poison": {"Grass": 2.0, "Poison": 0.5, "Ground": 0.5, "Rock": 0.5, "Ghost": 0.5, "Steel": 0.0, "Fairy": 2.0},
	"Rock": {"Fire": 2.0, "Ice": 2.0, "Fighting": 0.5, "Ground": 0.5, "Flying": 2.0, "Bug": 2.0, "Steel": 0.5},
	"Ghost": {"Normal": 0.0, "Psychic": 2.0, "Ghost": 2.0, "Dark": 0.5},
	"Dark": {"Fighting": 0.5, "Psychic": 2.0, "Ghost": 2.0, "Dark": 0.5, "Fairy": 0.5},
	"Fairy": {"Fire": 0.5, "Fighting": 2.0, "Poison": 0.5, "Dragon": 2.0, "Dark": 2.0, "Steel": 0.5}
}

var floor_level: int = 1
var active_team: Array = []
var unlocked_roster: Array = []
var locked_pokedex_ids: Array[int] = []
var current_offer: Dictionary = {}
var current_evolution_offer: Dictionary = {}
var pending_evolution_queue: Array = []
var current_enemy: Dictionary = {}
var active_team_index: int = 0
var permanent_unlocked_ids: Array[int] = []
var run_in_progress: bool = false
var awaiting_move_choice: bool = false
var awaiting_switch_choice: bool = false
var forced_switch_pending: bool = false
var switches_used_this_floor: int = 0
var runs_in_current_stretch: int = 0
var battle_log_lines: Array[String] = []
var last_run_save_time: String = "never"
var last_run_load_time: String = "never"

var factory: PokemonFactory
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var evolution_map: Dictionary = {}
var basic_species_ids: Array[int] = []


func _ready() -> void:
	rng.randomize()
	factory = PokemonFactory.new()
	_load_evolution_map()
	_load_basic_species_ids()
	_load_or_create_permanent_unlocks()
	_load_run_state()
	_emit_run_save_debug()


func start_new_run() -> void:
	start_new_run_with_team([])


func start_new_run_with_team(selected_species_ids: Array[int]) -> void:
	var selected_pokemon: Array = []
	for idx in range(selected_species_ids.size()):
		var dex_id: int = int(selected_species_ids[idx])
		var mon := factory.build_randomized_pokemon(dex_id, STARTING_TEAM_LEVEL)
		if mon.is_empty() == false:
			selected_pokemon.append(mon)
	start_new_run_with_pokemon(selected_pokemon)


func start_new_run_with_pokemon(selected_pokemon: Array) -> void:
	floor_level = 1
	active_team.clear()
	unlocked_roster.clear()
	battle_log_lines.clear()
	current_offer = {}
	current_evolution_offer = {}
	pending_evolution_queue.clear()
	current_enemy = {}
	active_team_index = 0
	awaiting_move_choice = false
	awaiting_switch_choice = false
	forced_switch_pending = false
	switches_used_this_floor = 0
	runs_in_current_stretch = 0
	locked_pokedex_ids = _build_locked_pool()

	var starters: Array = _sanitize_start_selection_pokemon(selected_pokemon)
	if starters.is_empty():
		var starter_ids: Array[int] = _roll_starting_team_ids(2)
		for starter_id in starter_ids:
			var starter := factory.build_randomized_pokemon(starter_id, STARTING_TEAM_LEVEL)
			if starter.is_empty():
				continue
			starters.append(starter)
	for idx in range(starters.size()):
		var starter: Dictionary = starters[idx]
		unlocked_roster.append(starter)
		active_team.append(starter)

	run_in_progress = true
	_spawn_enemy_for_current_floor()
	_emit_battle_log("Run started. A wild %s appears on floor %d." % [str(current_enemy.get("name", "Pokemon")), floor_level], false)
	_save_run_state()

	emit_signal("run_started")
	emit_signal("floor_changed", floor_level)
	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("enemy_changed", _enemy_summary_text())
	emit_signal("battle_log_changed", _battle_log_text())
	_emit_battle_state()
	emit_signal("permanent_unlocks_changed", permanent_unlocked_ids.duplicate())


func begin_fight_choice() -> void:
	if not _can_take_battle_action():
		return
	awaiting_move_choice = true
	awaiting_switch_choice = false
	_emit_battle_state()


func use_move(move_index: int) -> void:
	if not run_in_progress or current_enemy.is_empty() or active_team.is_empty():
		return
	if not awaiting_move_choice:
		return

	if current_offer.is_empty() == false:
		_emit_battle_log("Resolve the unlock offer first.", true)
		return

	var attacker_idx: int = _current_living_member_index()
	if attacker_idx < 0:
		_end_run("All team members fainted. Run over.")
		return
	active_team_index = attacker_idx
	awaiting_move_choice = false
	awaiting_switch_choice = false

	var player_mon: Dictionary = active_team[active_team_index]
	var enemy_mon: Dictionary = current_enemy
	var player_move: Dictionary = _pick_player_move(player_mon, move_index)

	var player_first: bool = int(player_mon["stats"]["spe"]) >= int(enemy_mon["stats"]["spe"])
	if player_first:
		_resolve_player_attack(player_move)
		if _is_fainted(current_enemy):
			_apply_ko_ability_boost(active_team[active_team_index], true)
			_emit_battle_log("Wild %s fainted." % str(current_enemy["name"]), true)
			_advance_floor(true)
			return
		_resolve_enemy_attack()
	else:
		_resolve_enemy_attack()
		if _is_fainted(active_team[active_team_index]):
			_handle_player_faint()
			emit_signal("team_changed", active_team.duplicate(true))
			emit_signal("enemy_changed", _enemy_summary_text())
			emit_signal("battle_log_changed", _battle_log_text())
			_emit_battle_state()
			_save_run_state()
			return
		_resolve_player_attack(player_move)

	if _is_fainted(current_enemy):
		_apply_ko_ability_boost(active_team[active_team_index], true)
		_emit_battle_log("Wild %s fainted." % str(current_enemy["name"]), true)
		_advance_floor(true)
		return
	if _is_fainted(active_team[active_team_index]):
		_handle_player_faint()

	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("enemy_changed", _enemy_summary_text())
	emit_signal("battle_log_changed", _battle_log_text())
	_emit_battle_state()
	_save_run_state()


func begin_switch_choice() -> void:
	if not run_in_progress:
		return
	if not forced_switch_pending and switches_used_this_floor >= 1:
		_emit_battle_log("You can only switch once per floor.", true)
		emit_signal("battle_log_changed", _battle_log_text())
		return
	if get_available_switch_indices().is_empty():
		_emit_battle_log("No valid switch targets.", true)
		emit_signal("battle_log_changed", _battle_log_text())
		return
	awaiting_switch_choice = true
	awaiting_move_choice = false
	_emit_battle_state()


func switch_to_member(target_index: int) -> bool:
	if not run_in_progress or active_team.is_empty():
		return false
	if target_index < 0 or target_index >= active_team.size():
		return false
	if _is_fainted(active_team[target_index]):
		return false
	if target_index == active_team_index:
		return false

	active_team_index = target_index
	var mon: Dictionary = active_team[active_team_index]
	_emit_battle_log("Switched to %s." % str(mon["name"]), true)

	# Voluntary switch spends your turn, so enemy attacks once.
	if not forced_switch_pending:
		switches_used_this_floor += 1
	if current_enemy.is_empty() == false and not awaiting_switch_choice and not forced_switch_pending:
		_resolve_enemy_attack()
		if _is_fainted(active_team[active_team_index]):
			_handle_player_faint()

	awaiting_switch_choice = false
	awaiting_move_choice = false
	forced_switch_pending = false
	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("enemy_changed", _enemy_summary_text())
	emit_signal("battle_log_changed", _battle_log_text())
	_emit_battle_state()
	_save_run_state()
	return true


func run_from_encounter() -> void:
	if not _can_take_battle_action():
		return
	awaiting_move_choice = false
	awaiting_switch_choice = false
	runs_in_current_stretch += 1
	_emit_battle_log("You ran from %s. No level-up awarded." % str(current_enemy["name"]), true)
	_advance_floor(false)


func resolve_unlock_offer(add_to_active_team: bool) -> void:
	if current_offer.is_empty():
		return

	var offer_id := int(current_offer["id"])
	if not permanent_unlocked_ids.has(offer_id):
		permanent_unlocked_ids.append(offer_id)
		_save_permanent_unlocks()
		emit_signal("permanent_unlocks_changed", permanent_unlocked_ids.duplicate())

	unlocked_roster.append(current_offer)
	if add_to_active_team and active_team.size() < TEAM_SIZE and _is_permanently_unlocked(offer_id):
		active_team.append(current_offer)

	current_offer = {}
	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("unlock_offer_closed")
	if run_in_progress and current_enemy.is_empty():
		_spawn_enemy_for_current_floor()
		if current_enemy.is_empty() == false:
			_emit_battle_log("A wild %s appeared!" % str(current_enemy["name"]), true)
		emit_signal("enemy_changed", _enemy_summary_text())
	_maybe_show_next_evolution_offer()
	_emit_battle_state()
	_save_run_state()


func resolve_evolution_offer(evolve: bool) -> void:
	if current_evolution_offer.is_empty():
		return

	var team_index: int = int(current_evolution_offer.get("team_index", -1))
	var from_name: String = str(current_evolution_offer.get("from_name", "Pokemon"))
	var to_name: String = str(current_evolution_offer.get("to_name", "Pokemon"))
	var to_id: int = int(current_evolution_offer.get("to_id", 0))

	if evolve and team_index >= 0 and team_index < active_team.size() and to_id > 0:
		var mon: Dictionary = active_team[team_index]
		var new_entry: Dictionary = factory.get_base_entry(to_id)
		if new_entry.is_empty() == false:
			var old_hp_max: int = int(mon.get("stats", {}).get("hp", 1))
			var old_hp_now: int = int(mon.get("current_hp", old_hp_max))
			var hp_ratio: float = float(old_hp_now) / max(1.0, float(old_hp_max))
			mon["id"] = to_id
			mon["name"] = str(new_entry["name"])
			mon["base_stats"] = new_entry["base_stats"]
			mon["stats"] = factory.scaled_stats(mon["base_stats"], int(mon["level"]))
			var new_hp_max: int = int(mon["stats"]["hp"])
			mon["current_hp"] = max(1, int(round(new_hp_max * hp_ratio)))
			active_team[team_index] = mon
			_emit_battle_log("%s evolved into %s!" % [from_name, to_name], true)
	else:
		_emit_battle_log("%s stopped evolving. It may evolve on the next level-up." % from_name, true)

	current_evolution_offer = {}
	if pending_evolution_queue.is_empty():
		emit_signal("evolution_offer_closed")
	else:
		_maybe_show_next_evolution_offer()

	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("battle_log_changed", _battle_log_text())
	_emit_battle_state()
	_save_run_state()


func get_offer_summary() -> String:
	if current_offer.is_empty():
		return ""
	return factory.summarize_pokemon(current_offer)


func _create_unlock_offer() -> void:
	current_offer = _roll_random_unlock_candidate(floor_level)
	if current_offer.is_empty():
		return
	emit_signal("unlock_offer_created", factory.summarize_pokemon(current_offer))
	_save_run_state()


func _roll_random_unlock_candidate(level: int) -> Dictionary:
	if locked_pokedex_ids.is_empty():
		return {}

	var index := rng.randi_range(0, locked_pokedex_ids.size() - 1)
	var dex_id := locked_pokedex_ids[index]
	locked_pokedex_ids.remove_at(index)
	return factory.build_randomized_pokemon(dex_id, level)


func can_add_species_to_team(pokedex_id: int) -> bool:
	return _is_permanently_unlocked(pokedex_id)


func set_team_member(slot_index: int, pokedex_id: int) -> bool:
	if not run_in_progress:
		return false
	if slot_index < 0 or slot_index >= TEAM_SIZE:
		return false
	if not can_add_species_to_team(pokedex_id):
		return false

	for idx in range(active_team.size()):
		if idx != slot_index and int(active_team[idx]["id"]) == pokedex_id:
			return false

	var candidate := factory.build_randomized_pokemon(pokedex_id, floor_level)
	if candidate.is_empty():
		return false

	if slot_index < active_team.size():
		active_team[slot_index] = candidate
	elif slot_index == active_team.size():
		active_team.append(candidate)
	else:
		return false

	unlocked_roster.append(candidate)
	emit_signal("team_changed", active_team.duplicate(true))
	_save_run_state()
	return true


func _grant_global_level_up() -> void:
	var queued: Array = []
	for idx in range(active_team.size()):
		var mon: Dictionary = active_team[idx]
		if int(mon["level"]) < MAX_FLOOR:
			var previous_max_hp: int = int(mon["stats"]["hp"])
			var previous_hp: int = int(mon["current_hp"])
			mon["level"] += 1
			mon["stats"] = factory.scaled_stats(mon["base_stats"], mon["level"])
			var new_max_hp: int = int(mon["stats"]["hp"])
			var hp_gain: int = new_max_hp - previous_max_hp
			var gained_hp: int = max(1, hp_gain)
			# Level-up should NOT revive fainted members.
			if previous_hp <= 0:
				mon["current_hp"] = 0
			else:
				mon["current_hp"] = min(new_max_hp, previous_hp + gained_hp)
			var evo_offer := _build_evolution_offer_for_member(idx, mon)
			if evo_offer.is_empty() == false:
				queued.append(evo_offer)
		active_team[idx] = mon
	pending_evolution_queue = queued


func _advance_floor(grant_level_up: bool) -> void:
	awaiting_move_choice = false
	awaiting_switch_choice = false
	forced_switch_pending = false
	switches_used_this_floor = 0
	var completed_floor: int = floor_level
	if grant_level_up:
		_grant_global_level_up()

	if completed_floor >= MAX_FLOOR:
		_end_run("You cleared floor %d. Run complete!" % MAX_FLOOR)
		return

	floor_level += 1
	emit_signal("floor_changed", floor_level)
	if completed_floor % FULL_HEAL_INTERVAL == 0:
		_full_team_heal()
		_emit_battle_log("Checkpoint heal: your team is fully restored after floor %d." % completed_floor, true)

	if completed_floor % UNLOCK_INTERVAL == 0:
		var unlock_eligible: bool = runs_in_current_stretch <= 1
		if unlock_eligible and active_team.size() < TEAM_SIZE:
			current_enemy = {}
			emit_signal("enemy_changed", "Unlock reward pending.")
			_create_unlock_offer()
		else:
			if not unlock_eligible:
				_emit_battle_log("Checkpoint penalty: %d runs in this 5-floor stretch. No unlock reward." % runs_in_current_stretch, true)
			_spawn_enemy_for_current_floor()
			if current_enemy.is_empty() == false:
				if bool(current_enemy.get("is_boss_encounter", false)):
					_emit_battle_log("Boss encounter! %s appeared on floor %d." % [str(current_enemy["name"]), floor_level], true)
				else:
					_emit_battle_log("A wild %s appeared on floor %d." % [str(current_enemy["name"]), floor_level], true)
			emit_signal("enemy_changed", _enemy_summary_text())
		runs_in_current_stretch = 0
	else:
		_spawn_enemy_for_current_floor()
		if current_enemy.is_empty() == false:
			if bool(current_enemy.get("is_boss_encounter", false)):
				_emit_battle_log("Boss encounter! %s appeared on floor %d." % [str(current_enemy["name"]), floor_level], true)
			else:
				_emit_battle_log("A wild %s appeared on floor %d." % [str(current_enemy["name"]), floor_level], true)
		emit_signal("enemy_changed", _enemy_summary_text())

	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("battle_log_changed", _battle_log_text())
	_maybe_show_next_evolution_offer()
	_emit_battle_state()
	_save_run_state()


func _spawn_enemy_for_current_floor() -> void:
	var enemy_id: int = _pick_wild_species_id_for_floor(floor_level)
	if enemy_id <= 0:
		current_enemy = {}
		return
	current_enemy = factory.build_randomized_pokemon(enemy_id, floor_level)
	var hp_multiplier: float = _boss_hp_multiplier_for_floor(floor_level)
	if hp_multiplier > 1.0:
		var old_hp_max: int = int(current_enemy.get("stats", {}).get("hp", 1))
		var new_hp_max: int = max(1, int(round(float(old_hp_max) * hp_multiplier)))
		var stats: Dictionary = current_enemy.get("stats", {})
		stats["hp"] = new_hp_max
		current_enemy["stats"] = stats
		current_enemy["current_hp"] = new_hp_max
		current_enemy["is_boss_encounter"] = true
		current_enemy["boss_hp_multiplier"] = hp_multiplier
	else:
		current_enemy["is_boss_encounter"] = false
		current_enemy["boss_hp_multiplier"] = 1.0


func _enemy_summary_text() -> String:
	if current_enemy.is_empty():
		return "No active encounter."
	var hp_now: int = int(current_enemy["current_hp"])
	var hp_max: int = int(current_enemy["stats"]["hp"])
	var boss_prefix: String = "Wild"
	if bool(current_enemy.get("is_boss_encounter", false)):
		boss_prefix = "Boss"
	return "%s %s Lv.%d | HP %d/%d | %s/%s | %s" % [
		boss_prefix,
		str(current_enemy["name"]),
		int(current_enemy["level"]),
		hp_now,
		hp_max,
		_colorize_type_name(str(current_enemy["types"][0])),
		_colorize_type_name(str(current_enemy["types"][1])),
		str(current_enemy["ability"])
	]


func _full_team_heal() -> void:
	for idx in range(active_team.size()):
		var mon: Dictionary = active_team[idx]
		var hp_max: int = int(mon.get("stats", {}).get("hp", 1))
		mon["current_hp"] = hp_max
		active_team[idx] = mon


func _boss_hp_multiplier_for_floor(floor: int) -> float:
	if floor % BOSS_INTERVAL != 0:
		return 1.0
	match floor:
		10:
			return 1.5
		20:
			return 2.0
		30:
			return 2.5
		40:
			return 3.0
		50:
			return 4.0
		_:
			return 1.0


func _move_list_text(pokemon: Dictionary) -> String:
	var move_names: Array[String] = []
	var moves_list: Array = pokemon["moves"]
	for idx in range(moves_list.size()):
		var move_data: Dictionary = moves_list[idx]
		move_names.append(str(move_data["name"]))
	return ", ".join(move_names)


func _resolve_player_attack(move: Dictionary) -> void:
	var attacker: Dictionary = active_team[active_team_index]
	_ensure_stat_stages(attacker)
	_ensure_stat_stages(current_enemy)
	active_team[active_team_index] = attacker
	var move_name := _colorize_move_name(move)

	if not _move_hits(attacker, current_enemy, move):
		_emit_battle_log("%s used %s, but it missed!" % [str(attacker["name"]), move_name], true)
		return

	var power: int = int(move.get("power", 0))
	if power > 0:
		var damage_result: Dictionary = _calculate_damage_result(attacker, current_enemy, move)
		var damage: int = int(damage_result.get("damage", 0))
		var is_critical: bool = bool(damage_result.get("is_critical", false))
		var type_multiplier: float = float(damage_result.get("type_multiplier", 1.0))
		current_enemy["current_hp"] = max(0, int(current_enemy["current_hp"]) - damage)
		var message: String = "%s used %s for %d damage." % [str(attacker["name"]), move_name, damage]
		if is_critical:
			message += " Critical hit!"
		_emit_battle_log(message, true)
		_emit_effectiveness_log(type_multiplier)
	else:
		_emit_battle_log("%s used %s." % [str(attacker["name"]), move_name], true)

	_apply_move_stat_changes(attacker, current_enemy, move, true)


func _resolve_enemy_attack() -> void:
	var defender: Dictionary = active_team[active_team_index]
	_ensure_stat_stages(defender)
	_ensure_stat_stages(current_enemy)
	var enemy_move: Dictionary = _pick_enemy_move(current_enemy)
	var move_name := _colorize_move_name(enemy_move)

	if not _move_hits(current_enemy, defender, enemy_move):
		_emit_battle_log("%s used %s, but it missed!" % [str(current_enemy["name"]), move_name], true)
		active_team[active_team_index] = defender
		return

	var power: int = int(enemy_move.get("power", 0))
	if power > 0:
		var damage_result: Dictionary = _calculate_damage_result(current_enemy, defender, enemy_move)
		var enemy_damage: int = int(damage_result.get("damage", 0))
		var is_critical: bool = bool(damage_result.get("is_critical", false))
		var type_multiplier: float = float(damage_result.get("type_multiplier", 1.0))
		defender["current_hp"] = max(0, int(defender["current_hp"]) - enemy_damage)
		var message: String = "%s used %s for %d damage." % [str(current_enemy["name"]), move_name, enemy_damage]
		if is_critical:
			message += " Critical hit!"
		_emit_battle_log(message, true)
		_emit_effectiveness_log(type_multiplier)
	else:
		_emit_battle_log("%s used %s." % [str(current_enemy["name"]), move_name], true)

	_apply_move_stat_changes(current_enemy, defender, enemy_move, false)
	active_team[active_team_index] = defender
	if _is_fainted(defender):
		_apply_ko_ability_boost(current_enemy, false)


func _pick_enemy_move(pokemon: Dictionary) -> Dictionary:
	var moves_list: Array = pokemon["moves"]
	var damaging_indices: Array[int] = []
	for idx in range(moves_list.size()):
		var move_data: Dictionary = moves_list[idx]
		if int(move_data.get("power", 0)) > 0:
			damaging_indices.append(idx)
	if damaging_indices.is_empty():
		return moves_list[0]
	var random_idx: int = damaging_indices[rng.randi_range(0, damaging_indices.size() - 1)]
	return moves_list[random_idx]


func _pick_player_move(pokemon: Dictionary, move_index: int) -> Dictionary:
	var moves_list: Array = pokemon["moves"]
	if move_index < 0 or move_index >= moves_list.size():
		return _pick_enemy_move(pokemon)
	return moves_list[move_index]


func _calculate_damage_result(attacker: Dictionary, defender: Dictionary, move: Dictionary) -> Dictionary:
	var is_critical: bool = _roll_critical_hit()
	var type_multiplier: float = _type_modifier(str(move.get("type", "Normal")), defender["types"])
	var damage: int = _calculate_damage(attacker, defender, move, is_critical, type_multiplier)
	return {
		"damage": damage,
		"is_critical": is_critical,
		"type_multiplier": type_multiplier
	}


func _calculate_damage(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_critical: bool, type_multiplier: float) -> int:
	var power: int = int(move.get("power", 0))
	if power <= 0:
		return 0

	var category: String = str(move.get("category", "Physical"))
	var attack_key: String = "atk"
	var defense_key: String = "def"
	if category == "Special":
		attack_key = "spa"
		defense_key = "spd"

	var level: int = int(attacker["level"])
	var attack_stat: float = _effective_stat(attacker, attack_key)
	var defense_stat: float = _effective_stat(defender, defense_key)
	var level_factor: float = floor((2.0 * float(level)) / 5.0 + 2.0)
	var base_unfloored: float = ((level_factor * float(power) * (attack_stat / max(1.0, defense_stat))) / 50.0) + 2.0
	var base_damage: int = max(1, int(floor(base_unfloored)))

	var move_type: String = str(move.get("type", "Normal"))
	var targets_multiplier: float = 1.0
	var pb_multiplier: float = 1.0
	var weather_multiplier: float = 1.0
	var glaive_rush_multiplier: float = 1.0
	var crit_multiplier: float = 1.0
	if is_critical:
		crit_multiplier = 1.5
	var random_multiplier: float = rng.randf_range(0.85, 1.0)
	var stab_multiplier: float = _stab_multiplier(attacker, move_type)
	var burn_multiplier: float = _burn_multiplier(attacker, category)
	var other_multiplier: float = 1.0

	if type_multiplier <= 0.0:
		return 0
	var total_modifier: float = targets_multiplier * pb_multiplier * weather_multiplier * glaive_rush_multiplier * crit_multiplier * random_multiplier * stab_multiplier * type_multiplier * burn_multiplier * other_multiplier
	var final_damage: int = max(1, int(floor(float(base_damage) * total_modifier)))
	return final_damage


func _move_hits(attacker: Dictionary, defender: Dictionary, move: Dictionary) -> bool:
	var base_accuracy: int = int(move.get("accuracy", 100))
	if base_accuracy <= 0:
		return true
	var acc_stage: int = int(attacker.get("stat_stages", {}).get("accuracy", 0))
	var ev_stage: int = int(defender.get("stat_stages", {}).get("evasion", 0))
	var chance: float = float(base_accuracy) * _stage_multiplier(acc_stage) / _stage_multiplier(ev_stage)
	chance = clamp(chance, 1.0, 100.0)
	return rng.randf_range(0.0, 100.0) <= chance


func _apply_move_stat_changes(attacker: Dictionary, defender: Dictionary, move: Dictionary, attacker_is_player: bool) -> void:
	var changes: Array = move.get("stat_changes", [])
	if changes.is_empty():
		return
	var effect_chance: int = int(move.get("effect_chance", 100))
	var roll: int = rng.randi_range(1, 100)
	if roll > effect_chance:
		return

	var targets_self: bool = bool(move.get("targets_self", false))
	var has_positive_status_change: bool = false
	var move_power: int = int(move.get("power", 0))
	var move_category: String = str(move.get("category", "Status"))
	if move_power <= 0 and move_category == "Status":
		for i in range(changes.size()):
			var entry: Dictionary = changes[i]
			if int(entry.get("change", 0)) > 0:
				has_positive_status_change = true
				break
	for idx in range(changes.size()):
		var change_data: Dictionary = changes[idx]
		var stat_key: String = str(change_data.get("stat", ""))
		var delta: int = int(change_data.get("change", 0))
		if stat_key.is_empty() or delta == 0:
			continue
		var apply_to_attacker: bool = _should_apply_change_to_attacker(move, targets_self, delta, has_positive_status_change)
		if apply_to_attacker:
			_apply_stage_change(attacker, stat_key, delta, str(attacker["name"]))
		else:
			_apply_stage_change(defender, stat_key, delta, str(defender["name"]))

	if attacker_is_player:
		active_team[active_team_index] = attacker
		current_enemy = defender
	else:
		current_enemy = attacker
		active_team[active_team_index] = defender


func _apply_stage_change(mon: Dictionary, stat_key: String, delta: int, mon_name: String) -> void:
	_ensure_stat_stages(mon)
	var stages: Dictionary = mon["stat_stages"]
	var before: int = int(stages.get(stat_key, 0))
	var after: int = clamp(before + delta, -6, 6)
	if after == before:
		return
	stages[stat_key] = after
	mon["stat_stages"] = stages

	var stat_label: String = _stage_stat_label(stat_key)
	if after > before:
		_emit_battle_log("%s's %s rose!" % [mon_name, stat_label], true)
	else:
		_emit_battle_log("%s's %s fell!" % [mon_name, stat_label], true)


func _should_apply_change_to_attacker(move: Dictionary, targets_self: bool, delta: int, has_positive_status_change: bool) -> bool:
	if targets_self:
		return true
	var power: int = int(move.get("power", 0))
	var category: String = str(move.get("category", "Status"))
	if power <= 0 and category == "Status":
		# Some move data has incorrect target flags; infer common status behavior.
		# If a status move grants any positive stage change, treat the entire stage-change block as self-target.
		if has_positive_status_change:
			return true
		return false
	# Damaging moves with positive stat stages are usually self-buffs (e.g. Charge Beam/Steel Wing).
	if power > 0 and delta > 0:
		return true
	return false


func _stab_multiplier(attacker: Dictionary, move_type: String) -> float:
	var types: Array = attacker.get("types", [])
	for idx in range(types.size()):
		if str(types[idx]) == move_type:
			return 1.5
	return 1.0


func _burn_multiplier(attacker: Dictionary, category: String) -> float:
	var status_name: String = str(attacker.get("status", "")).to_lower()
	if status_name == "burn" and category == "Physical":
		return 0.5
	return 1.0


func _roll_critical_hit() -> bool:
	return rng.randi_range(1, CRIT_CHANCE_DENOM) == 1


func _emit_effectiveness_log(type_multiplier: float) -> void:
	if type_multiplier <= 0.0:
		_emit_battle_log("It had no effect.", true)
		return
	if type_multiplier > 1.0:
		_emit_battle_log("It's super effective!", true)
	elif type_multiplier < 1.0:
		_emit_battle_log("It's not very effective...", true)


func _apply_ko_ability_boost(mon: Dictionary, is_player_side: bool) -> void:
	var ability_name: String = str(mon.get("ability", "")).to_lower()
	if ability_name != "moxie":
		return
	_apply_stage_change(mon, "atk", 1, str(mon.get("name", "Pokemon")))
	if is_player_side:
		active_team[active_team_index] = mon
	else:
		current_enemy = mon


func _stage_stat_label(stat_key: String) -> String:
	match stat_key:
		"atk":
			return "Attack"
		"def":
			return "Defense"
		"spa":
			return "Sp. Atk"
		"spd":
			return "Sp. Def"
		"spe":
			return "Speed"
		"accuracy":
			return "Accuracy"
		"evasion":
			return "Evasion"
		_:
			return stat_key


func _effective_stat(mon: Dictionary, stat_key: String) -> float:
	_ensure_stat_stages(mon)
	var base_value: float = max(1.0, float(mon["stats"][stat_key]))
	var stage: int = int(mon["stat_stages"].get(stat_key, 0))
	return max(1.0, base_value * _stage_multiplier(stage))


func _stage_multiplier(stage: int) -> float:
	if stage >= 0:
		return float(2 + stage) / 2.0
	return 2.0 / float(2 - stage)


func _ensure_stat_stages(mon: Dictionary) -> void:
	if mon.has("stat_stages") and typeof(mon["stat_stages"]) == TYPE_DICTIONARY:
		return
	mon["stat_stages"] = {
		"atk": 0,
		"def": 0,
		"spa": 0,
		"spd": 0,
		"spe": 0,
		"accuracy": 0,
		"evasion": 0
	}


func _type_modifier(move_type: String, defender_types: Array) -> float:
	var modifier: float = 1.0
	var type_effects: Dictionary = TYPE_CHART.get(move_type, {})
	for idx in range(defender_types.size()):
		var def_type: String = str(defender_types[idx])
		if type_effects.has(def_type):
			modifier *= float(type_effects[def_type])
	return modifier


func _is_fainted(pokemon: Dictionary) -> bool:
	return int(pokemon.get("current_hp", 0)) <= 0


func _current_living_member_index() -> int:
	if active_team_index >= 0 and active_team_index < active_team.size():
		if not _is_fainted(active_team[active_team_index]):
			return active_team_index
	return _find_next_living_member(active_team_index)


func _find_next_living_member(start_idx: int) -> int:
	if active_team.is_empty():
		return -1
	for step in range(1, active_team.size() + 1):
		var idx: int = (start_idx + step) % active_team.size()
		if not _is_fainted(active_team[idx]):
			return idx
	return -1


func _handle_player_faint() -> void:
	var fainted_mon: Dictionary = active_team[active_team_index]
	_emit_battle_log("%s fainted." % str(fainted_mon["name"]), true)
	var next_idx: int = _find_next_living_member(active_team_index)
	if next_idx >= 0:
		awaiting_switch_choice = true
		awaiting_move_choice = false
		forced_switch_pending = true
		_emit_battle_log("Choose a Pokemon to continue the fight.", true)
	else:
		_end_run("All team members fainted. Run over.")


func _end_run(message: String) -> void:
	run_in_progress = false
	current_enemy = {}
	current_offer = {}
	current_evolution_offer = {}
	pending_evolution_queue.clear()
	awaiting_move_choice = false
	awaiting_switch_choice = false
	forced_switch_pending = false
	emit_signal("enemy_changed", "No active encounter.")
	_emit_battle_log(message, true)
	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("battle_log_changed", _battle_log_text())
	emit_signal("evolution_offer_closed")
	_emit_battle_state()
	emit_signal("run_ended", message)
	_save_run_state()


func _emit_battle_log(message: String, append: bool) -> void:
	var styled_message: String = _style_log_message(message)
	if append:
		battle_log_lines.insert(0, styled_message)
	else:
		battle_log_lines = [styled_message]
	while battle_log_lines.size() > MAX_BATTLE_LOG_LINES:
		battle_log_lines.remove_at(battle_log_lines.size() - 1)


func _battle_log_text() -> String:
	return "\n".join(battle_log_lines)


func emit_current_state() -> void:
	emit_signal("permanent_unlocks_changed", permanent_unlocked_ids.duplicate())
	_emit_run_save_debug()
	if run_in_progress:
		emit_signal("run_started")
		emit_signal("floor_changed", floor_level)
		emit_signal("team_changed", active_team.duplicate(true))
		emit_signal("enemy_changed", _enemy_summary_text())
		emit_signal("battle_log_changed", _battle_log_text())
		if current_evolution_offer.is_empty() == false:
			emit_signal("evolution_offer_created", _evolution_offer_summary(current_evolution_offer))
		_emit_battle_state()
		if not current_offer.is_empty():
			emit_signal("unlock_offer_created", factory.summarize_pokemon(current_offer))
	else:
		emit_signal("floor_changed", 1)
		emit_signal("team_changed", [])
		emit_signal("enemy_changed", "No active encounter.")
		emit_signal("battle_log_changed", _battle_log_text())
		emit_signal("evolution_offer_closed")
		_emit_battle_state()
		emit_signal("unlock_offer_closed")


func get_permanent_unlock_ids() -> Array[int]:
	return permanent_unlocked_ids.duplicate()


func get_permanent_unlock_ids_sorted() -> Array[int]:
	var ids: Array[int] = permanent_unlocked_ids.duplicate()
	ids.sort()
	return ids


func get_species_name(pokedex_id: int) -> String:
	return factory.get_species_name(pokedex_id)


func get_species_tooltip(pokedex_id: int) -> String:
	var entry: Dictionary = factory.get_base_entry(pokedex_id)
	if entry.is_empty():
		return "Unknown Pokemon"
	var bs: Dictionary = entry["base_stats"]
	return "#%03d %s\nBase Stats:\nHP %d | ATK %d | DEF %d\nSPA %d | SPD %d | SPE %d" % [
		int(entry["id"]),
		str(entry["name"]),
		int(bs["hp"]),
		int(bs["atk"]),
		int(bs["def"]),
		int(bs["spa"]),
		int(bs["spd"]),
		int(bs["spe"])
	]


func get_randomized_preview_for_species(pokedex_id: int) -> Dictionary:
	return factory.build_randomized_pokemon(pokedex_id, STARTING_TEAM_LEVEL)


func get_randomized_pokemon_tooltip(pokemon: Dictionary) -> String:
	if pokemon.is_empty():
		return "Unknown Pokemon"
	var hp_now: int = int(pokemon.get("current_hp", 0))
	var hp_max: int = int(pokemon.get("stats", {}).get("hp", 0))
	var move_names: Array[String] = []
	var moves_list: Array = pokemon.get("moves", [])
	for idx in range(moves_list.size()):
		var move_data: Dictionary = moves_list[idx]
		move_names.append(str(move_data.get("name", "Move")))
	return "#%03d %s (Lv.%d)\nType: %s/%s\nHP: %d/%d\nAbility: %s\nNature: %s\nMoves: %s" % [
		int(pokemon.get("id", 0)),
		str(pokemon.get("name", "Pokemon")),
		int(pokemon.get("level", 1)),
		str(pokemon.get("types", ["", ""])[0]),
		str(pokemon.get("types", ["", ""])[1]),
		hp_now,
		hp_max,
		str(pokemon.get("ability", "Unknown")),
		str(pokemon.get("nature", "Unknown")),
		", ".join(move_names)
	]


func has_active_run() -> bool:
	return run_in_progress


func get_active_team_index() -> int:
	return active_team_index


func get_battle_state() -> Dictionary:
	var active_summary := {}
	if run_in_progress and active_team_index >= 0 and active_team_index < active_team.size():
		active_summary = active_team[active_team_index]

	var move_names: Array[String] = []
	if active_summary.is_empty() == false:
		var moves_list: Array = active_summary["moves"]
		for idx in range(moves_list.size()):
			var move_data: Dictionary = moves_list[idx]
			move_names.append(str(move_data.get("name", "Move")))

	return {
		"floor": floor_level,
		"run_in_progress": run_in_progress,
		"awaiting_move_choice": awaiting_move_choice,
		"awaiting_switch_choice": awaiting_switch_choice,
		"switches_used_this_floor": switches_used_this_floor,
		"move_names": move_names,
		"move_types": _active_move_types(active_summary),
		"move_tooltips": _active_move_tooltips(active_summary),
		"switch_targets": get_available_switch_indices(),
		"active_id": int(active_summary.get("id", 0)),
		"active_name": str(active_summary.get("name", "")),
		"active_level": int(active_summary.get("level", 0)),
		"active_ability": str(active_summary.get("ability", "")),
		"active_hp": int(active_summary.get("current_hp", 0)),
		"active_hp_max": int(active_summary.get("stats", {}).get("hp", 0)),
		"active_type_1": str(active_summary.get("types", ["", ""])[0]),
		"active_type_2": str(active_summary.get("types", ["", ""])[1]),
		"active_stage_text": _stage_summary_text(active_summary),
		"enemy_id": int(current_enemy.get("id", 0)),
		"enemy_name": str(current_enemy.get("name", "")),
		"enemy_level": int(current_enemy.get("level", 0)),
		"enemy_hp": int(current_enemy.get("current_hp", 0)),
		"enemy_hp_max": int(current_enemy.get("stats", {}).get("hp", 0)),
		"enemy_stage_text": _stage_summary_text(current_enemy),
		"runs_in_current_stretch": runs_in_current_stretch
	}


func get_current_offer_id() -> int:
	if current_offer.is_empty():
		return 0
	return int(current_offer.get("id", 0))


func get_available_switch_indices() -> Array[int]:
	var result: Array[int] = []
	if not run_in_progress:
		return result
	for idx in range(active_team.size()):
		if idx == active_team_index:
			continue
		if not _is_fainted(active_team[idx]):
			result.append(idx)
	return result


func force_save_to_disk() -> void:
	_save_permanent_unlocks()
	_save_run_state()
	_emit_run_save_debug()


func force_reload_from_disk() -> void:
	_load_or_create_permanent_unlocks()
	_load_run_state()
	emit_current_state()


func clear_all_save_data() -> void:
	permanent_unlocked_ids = [STARTER_PIKACHU_ID, STARTER_EEVEE_ID]
	_save_permanent_unlocks()

	floor_level = 1
	active_team = []
	unlocked_roster = []
	locked_pokedex_ids = _build_locked_pool()
	current_offer = {}
	current_evolution_offer = {}
	pending_evolution_queue = []
	current_enemy = {}
	battle_log_lines = []
	active_team_index = 0
	awaiting_move_choice = false
	awaiting_switch_choice = false
	forced_switch_pending = false
	switches_used_this_floor = 0
	runs_in_current_stretch = 0
	run_in_progress = false
	_save_run_state()

	emit_current_state()


func _build_locked_pool() -> Array[int]:
	var pool: Array[int] = []
	for dex_id in factory.get_all_pokedex_ids():
		if dex_id == STARTER_PIKACHU_ID or dex_id == STARTER_EEVEE_ID:
			continue
		if permanent_unlocked_ids.has(dex_id):
			continue
		pool.append(dex_id)
	return pool


func _is_permanently_unlocked(pokedex_id: int) -> bool:
	return permanent_unlocked_ids.has(pokedex_id) or pokedex_id == STARTER_PIKACHU_ID or pokedex_id == STARTER_EEVEE_ID


func _load_or_create_permanent_unlocks() -> void:
	if not FileAccess.file_exists(UNLOCK_SAVE_PATH):
		permanent_unlocked_ids = [STARTER_PIKACHU_ID, STARTER_EEVEE_ID]
		_save_permanent_unlocks()
		return

	var file := FileAccess.open(UNLOCK_SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		permanent_unlocked_ids = [STARTER_PIKACHU_ID, STARTER_EEVEE_ID]
		_save_permanent_unlocks()
		return

	var loaded: Array[int] = []
	for value in parsed:
		loaded.append(int(value))
	var changed := false
	if not loaded.has(STARTER_PIKACHU_ID):
		loaded.append(STARTER_PIKACHU_ID)
		changed = true
	if not loaded.has(STARTER_EEVEE_ID):
		loaded.append(STARTER_EEVEE_ID)
		changed = true
	permanent_unlocked_ids = loaded
	if changed:
		_save_permanent_unlocks()


func _save_permanent_unlocks() -> void:
	var file := FileAccess.open(UNLOCK_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(permanent_unlocked_ids))


func _load_run_state() -> void:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		run_in_progress = false
		last_run_load_time = _now_string()
		_emit_run_save_debug()
		return

	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		run_in_progress = false
		last_run_load_time = _now_string()
		_emit_run_save_debug()
		return

	floor_level = int(parsed.get("floor_level", 1))
	active_team = parsed.get("active_team", [])
	unlocked_roster = parsed.get("unlocked_roster", [])
	active_team_index = int(parsed.get("active_team_index", 0))
	current_enemy = parsed.get("current_enemy", {})
	current_evolution_offer = parsed.get("current_evolution_offer", {})
	pending_evolution_queue = parsed.get("pending_evolution_queue", [])
	awaiting_move_choice = bool(parsed.get("awaiting_move_choice", false))
	awaiting_switch_choice = bool(parsed.get("awaiting_switch_choice", false))
	forced_switch_pending = bool(parsed.get("forced_switch_pending", false))
	switches_used_this_floor = int(parsed.get("switches_used_this_floor", 0))
	runs_in_current_stretch = int(parsed.get("runs_in_current_stretch", 0))
	battle_log_lines.clear()
	var loaded_battle_log: Array = parsed.get("battle_log_lines", [])
	for idx in range(loaded_battle_log.size()):
		battle_log_lines.append(str(loaded_battle_log[idx]))
	locked_pokedex_ids = []
	for value in parsed.get("locked_pokedex_ids", []):
		locked_pokedex_ids.append(int(value))
	current_offer = parsed.get("current_offer", {})
	run_in_progress = bool(parsed.get("run_in_progress", false))
	if run_in_progress and current_enemy.is_empty() and current_offer.is_empty():
		_spawn_enemy_for_current_floor()
	if not run_in_progress:
		awaiting_move_choice = false
		awaiting_switch_choice = false
		forced_switch_pending = false
		switches_used_this_floor = 0
	last_run_load_time = _now_string()
	_emit_run_save_debug()


func _save_run_state() -> void:
	var payload := {
		"floor_level": floor_level,
		"active_team": active_team,
		"unlocked_roster": unlocked_roster,
		"active_team_index": active_team_index,
		"current_enemy": current_enemy,
		"current_evolution_offer": current_evolution_offer,
		"pending_evolution_queue": pending_evolution_queue,
		"awaiting_move_choice": awaiting_move_choice,
		"awaiting_switch_choice": awaiting_switch_choice,
		"forced_switch_pending": forced_switch_pending,
		"switches_used_this_floor": switches_used_this_floor,
		"runs_in_current_stretch": runs_in_current_stretch,
		"battle_log_lines": battle_log_lines,
		"locked_pokedex_ids": locked_pokedex_ids,
		"current_offer": current_offer,
		"run_in_progress": run_in_progress
	}
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	last_run_save_time = _now_string()
	_emit_run_save_debug()


func _roll_starting_team_ids(count: int) -> Array[int]:
	var ids := permanent_unlocked_ids.duplicate()
	if ids.size() < count:
		ids = [STARTER_PIKACHU_ID, STARTER_EEVEE_ID]

	var picks: Array[int] = []
	while picks.size() < count and ids.size() > 0:
		var idx := rng.randi_range(0, ids.size() - 1)
		picks.append(int(ids[idx]))
		ids.remove_at(idx)
	return picks


func _sanitize_start_selection(raw_ids: Array[int]) -> Array[int]:
	var picks: Array[int] = []
	for idx in range(raw_ids.size()):
		var dex_id: int = int(raw_ids[idx])
		if not _is_permanently_unlocked(dex_id):
			continue
		if picks.has(dex_id):
			continue
		picks.append(dex_id)
		if picks.size() >= TEAM_SIZE:
			break
	if picks.size() >= 2:
		return picks
	return []


func _now_string() -> String:
	return Time.get_datetime_string_from_system()


func _emit_run_save_debug() -> void:
	var text := "Run Save: %s | Unlock Save: %s | Last Save: %s | Last Load: %s | Active Run: %s" % [
		RUN_SAVE_PATH,
		UNLOCK_SAVE_PATH,
		last_run_save_time,
		last_run_load_time,
		str(run_in_progress)
	]
	emit_signal("run_save_debug_changed", text)


func _style_log_message(message: String) -> String:
	if message.find("[color=") >= 0:
		return message
	var lower: String = message.to_lower()
	var color := "#EDEDED"
	if lower.find("appeared") >= 0:
		color = "#FFD166"
	elif lower.find("fainted") >= 0:
		color = "#FF6B6B"
	elif lower.find("switched") >= 0 or lower.find("go ") >= 0:
		color = "#B8F2E6"
	elif lower.find("ran from") >= 0:
		color = "#F4A261"
	elif lower.find("penalty") >= 0:
		color = "#FFB703"
	elif lower.find("run over") >= 0 or lower.find("complete") >= 0:
		color = "#CDB4DB"
	return "[color=%s]%s[/color]" % [color, message]


func get_type_color_hex(type_name: String) -> String:
	return str(TYPE_COLORS.get(type_name, "#EDEDED"))


func _colorize_type_name(type_name: String) -> String:
	return "[color=%s]%s[/color]" % [get_type_color_hex(type_name), type_name]


func _colorize_move_name(move: Dictionary) -> String:
	var move_name: String = str(move.get("name", "Move"))
	var move_type: String = str(move.get("type", "Normal"))
	return "[color=%s]%s[/color]" % [get_type_color_hex(move_type), move_name]


func _active_move_types(active_summary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if active_summary.is_empty():
		return result
	var moves_list: Array = active_summary.get("moves", [])
	for idx in range(moves_list.size()):
		var move_data: Dictionary = moves_list[idx]
		result.append(str(move_data.get("type", "Normal")))
	return result


func _active_move_tooltips(active_summary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if active_summary.is_empty():
		return result
	var moves_list: Array = active_summary.get("moves", [])
	for idx in range(moves_list.size()):
		var move_data: Dictionary = moves_list[idx]
		result.append(_move_tooltip_text(move_data))
	return result


func _move_tooltip_text(move_data: Dictionary) -> String:
	var name: String = str(move_data.get("name", "Move"))
	var move_type: String = str(move_data.get("type", "Normal"))
	var category: String = str(move_data.get("category", "Status"))
	var power: int = int(move_data.get("power", 0))
	var accuracy: int = int(move_data.get("accuracy", 100))
	var effect_chance: int = int(move_data.get("effect_chance", 100))
	var pp: int = int(move_data.get("pp", 0))
	var changes: Array = move_data.get("stat_changes", [])
	var stat_parts: Array[String] = []
	for idx in range(changes.size()):
		var entry: Dictionary = changes[idx]
		var stat_key: String = _stage_stat_label(str(entry.get("stat", "")))
		var delta: int = int(entry.get("change", 0))
		var sign: String = "+"
		if delta < 0:
			sign = ""
		stat_parts.append("%s %s%d" % [stat_key, sign, delta])
	var stat_text: String = "-"
	if stat_parts.is_empty() == false:
		stat_text = ", ".join(stat_parts)
	return "%s\nType: %s | Category: %s\nPower: %d | Accuracy: %d | PP: %d\nEffect Chance: %d%%\nStat Changes: %s" % [
		name,
		move_type,
		category,
		power,
		accuracy,
		pp,
		effect_chance,
		stat_text
	]


func _stage_summary_text(mon: Dictionary) -> String:
	if mon.is_empty():
		return "-"
	var stages: Dictionary = mon.get("stat_stages", {})
	if stages.is_empty():
		return "-"

	var order: Array[String] = ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]
	var parts: Array[String] = []
	for idx in range(order.size()):
		var key: String = order[idx]
		var value: int = int(stages.get(key, 0))
		if value == 0:
			continue
		var sign := "+"
		if value < 0:
			sign = ""
		parts.append("%s %s%d" % [_stage_stat_label(key), sign, value])

	if parts.is_empty():
		return "-"
	return ", ".join(parts)


func _sanitize_start_selection_pokemon(raw_team: Array) -> Array:
	var picks: Array = []
	var used_ids: Array[int] = []
	for idx in range(raw_team.size()):
		var mon: Dictionary = raw_team[idx]
		var dex_id: int = int(mon.get("id", 0))
		if dex_id <= 0:
			continue
		if not _is_permanently_unlocked(dex_id):
			continue
		if used_ids.has(dex_id):
			continue
		used_ids.append(dex_id)
		picks.append(mon.duplicate(true))
		if picks.size() >= TEAM_SIZE:
			break
	if picks.size() >= 2:
		return picks
	return []


func _emit_battle_state() -> void:
	emit_signal("battle_state_changed", get_battle_state())


func _can_take_battle_action() -> bool:
	if not run_in_progress or current_enemy.is_empty():
		return false
	if current_offer.is_empty() == false:
		return false
	if current_evolution_offer.is_empty() == false:
		return false
	return true


func _load_evolution_map() -> void:
	if not FileAccess.file_exists(EVOLUTIONS_PATH):
		evolution_map = {}
		return
	var file := FileAccess.open(EVOLUTIONS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		evolution_map = parsed
	else:
		evolution_map = {}


func _load_basic_species_ids() -> void:
	if not FileAccess.file_exists(BASIC_SPECIES_PATH):
		basic_species_ids = []
		return
	var file := FileAccess.open(BASIC_SPECIES_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		basic_species_ids = []
		return

	var valid_ids: Array[int] = []
	var available_ids := factory.get_all_pokedex_ids()
	for idx in range(parsed.size()):
		var dex_id: int = int(parsed[idx])
		if available_ids.has(dex_id):
			valid_ids.append(dex_id)
	basic_species_ids = valid_ids


func _pick_wild_species_id_for_floor(floor: int) -> int:
	if floor <= BASIC_ONLY_FLOOR_LIMIT and not basic_species_ids.is_empty():
		var idx: int = rng.randi_range(0, basic_species_ids.size() - 1)
		return basic_species_ids[idx]
	return factory.get_random_pokedex_id()


func _build_evolution_offer_for_member(team_index: int, mon: Dictionary) -> Dictionary:
	var mon_id: int = int(mon.get("id", 0))
	var mon_level: int = int(mon.get("level", 1))
	var key := str(mon_id)
	if not evolution_map.has(key):
		return {}
	var options: Array = evolution_map[key]
	for idx in range(options.size()):
		var option: Dictionary = options[idx]
		var required_level: int = int(option.get("level", 0))
		var to_id: int = int(option.get("to_id", 0))
		if mon_level >= required_level and to_id > 0:
			var to_entry: Dictionary = factory.get_base_entry(to_id)
			var to_name: String = "Pokemon"
			if to_entry.is_empty() == false:
				to_name = str(to_entry["name"])
			return {
				"team_index": team_index,
				"from_id": mon_id,
				"from_name": str(mon.get("name", "Pokemon")),
				"to_id": to_id,
				"to_name": to_name,
				"required_level": required_level
			}
	return {}


func _maybe_show_next_evolution_offer() -> void:
	if current_evolution_offer.is_empty() == false:
		return
	if current_offer.is_empty() == false:
		return
	if pending_evolution_queue.is_empty():
		return
	current_evolution_offer = pending_evolution_queue.pop_front()
	emit_signal("evolution_offer_created", _evolution_offer_summary(current_evolution_offer))
	_emit_battle_state()


func _evolution_offer_summary(offer: Dictionary) -> String:
	return "%s reached Lv.%d and can evolve into %s.\nEvolve now?" % [
		str(offer.get("from_name", "Pokemon")),
		int(offer.get("required_level", 1)),
		str(offer.get("to_name", "Pokemon"))
	]
