extends Node
class_name RunManager

signal run_started()
signal run_ended(message: String)
signal floor_changed(floor_level_value: int)
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
signal single_battle_finished(result: String)

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
const SLEEP_MIN_TURNS := 1
const SLEEP_MAX_TURNS := 3
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
var current_weather: String = ""
var weather_turns_remaining: int = 0
var current_terrain: String = ""
var terrain_turns_remaining: int = 0
var player_side_barriers: Dictionary = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
var enemy_side_barriers: Dictionary = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
var player_side_hazards: Dictionary = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
var enemy_side_hazards: Dictionary = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
var player_protect_active: bool = false
var enemy_protect_active: bool = false
var single_battle_mode: bool = false

var factory: PokemonFactory
var move_effects: MoveEffects
var ability_effects: AbilityEffects
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var evolution_map: Dictionary = {}
var basic_species_ids: Array[int] = []


func _ready() -> void:
	rng.randomize()
	factory = PokemonFactory.new()
	move_effects = MoveEffects.new()
	ability_effects = AbilityEffects.new()
	_load_evolution_map()
	_load_basic_species_ids()
	_load_or_create_permanent_unlocks()
	_load_run_state()
	_sanitize_loaded_abilities()
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
	single_battle_mode = false
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
	current_weather = ""
	weather_turns_remaining = 0
	current_terrain = ""
	terrain_turns_remaining = 0
	player_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	enemy_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	player_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	enemy_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	player_protect_active = false
	enemy_protect_active = false
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


func start_single_battle(player_team: Array, enemy_pokemon: Dictionary) -> void:
	single_battle_mode = true
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
	_reset_battlefield_for_new_encounter()

	for idx in range(player_team.size()):
		var mon_value = player_team[idx]
		if typeof(mon_value) != TYPE_DICTIONARY:
			continue
		var mon: Dictionary = mon_value.duplicate(true)
		_ensure_status_state(mon)
		_reset_battle_volatile_state(mon)
		active_team.append(mon)
		unlocked_roster.append(mon.duplicate(true))
	if active_team.is_empty():
		return

	current_enemy = enemy_pokemon.duplicate(true)
	_ensure_status_state(current_enemy)
	_reset_battle_volatile_state(current_enemy)
	run_in_progress = true
	_emit_battle_log("A rival challenges you!", false)
	emit_signal("run_started")
	emit_signal("floor_changed", floor_level)
	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("enemy_changed", _enemy_summary_text())
	emit_signal("battle_log_changed", _battle_log_text())
	_emit_battle_state()


func begin_fight_choice() -> void:
	if not _can_take_battle_action():
		return
	awaiting_move_choice = true
	awaiting_switch_choice = false
	_emit_battle_state()


func cancel_fight_choice() -> void:
	if not run_in_progress:
		return
	if not awaiting_move_choice:
		return
	awaiting_move_choice = false
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
	var preview_player_mon: Dictionary = active_team[attacker_idx]
	_ensure_status_state(preview_player_mon)
	var preview_queued: Dictionary = preview_player_mon.get("queued_move", {})
	if preview_queued.is_empty() and not _has_pp_for_move(preview_player_mon, move_index):
		_emit_battle_log("That move is out of PP.", true)
		emit_signal("battle_log_changed", _battle_log_text())
		_emit_battle_state()
		return
	active_team_index = attacker_idx
	awaiting_move_choice = false
	awaiting_switch_choice = false
	_begin_new_turn()

	var player_mon: Dictionary = active_team[active_team_index]
	var enemy_mon: Dictionary = current_enemy
	var player_move: Dictionary = _pick_player_move(player_mon, move_index)
	if player_mon.has("queued_move"):
		var queued: Dictionary = player_mon.get("queued_move", {})
		if queued.is_empty() == false:
			player_move = queued.duplicate(true)
			player_mon["queued_move"] = {}
			active_team[active_team_index] = player_mon
		else:
			_consume_pp_for_move(player_mon, move_index)
			active_team[active_team_index] = player_mon
	else:
		_consume_pp_for_move(player_mon, move_index)
		active_team[active_team_index] = player_mon

	var player_first: bool = int(player_mon["stats"]["spe"]) >= int(enemy_mon["stats"]["spe"])
	if player_first:
		_resolve_player_attack(player_move)
		if _is_fainted(current_enemy):
			_apply_ko_ability_boost(active_team[active_team_index], true)
			_emit_battle_log("Wild %s fainted." % str(current_enemy["name"]), true)
			if single_battle_mode:
				_finish_single_battle("win")
				return
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

	if run_in_progress and not _is_fainted(current_enemy) and not _is_fainted(active_team[active_team_index]):
		_apply_end_of_round_effects()

	if _is_fainted(current_enemy):
		_apply_ko_ability_boost(active_team[active_team_index], true)
		_emit_battle_log("Wild %s fainted." % str(current_enemy["name"]), true)
		if single_battle_mode:
			_finish_single_battle("win")
			return
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
	if active_team_index >= 0 and active_team_index < active_team.size():
		var active_mon: Dictionary = active_team[active_team_index]
		if int(active_mon.get("trapped_turns", 0)) > 0 and not forced_switch_pending:
			_emit_battle_log("%s is trapped and can't switch out!" % str(active_mon.get("name", "Pokemon")), true)
			emit_signal("battle_log_changed", _battle_log_text())
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
	_ensure_status_state(mon)
	_apply_switch_in_hazards(mon, true)
	_apply_switch_in_ability(mon, current_enemy, true)
	active_team[active_team_index] = mon
	_emit_battle_log("Switched to %s." % str(mon["name"]), true)

	# Voluntary switch spends your turn, so enemy attacks once.
	if not forced_switch_pending:
		switches_used_this_floor += 1
	if current_enemy.is_empty() == false and not awaiting_switch_choice and not forced_switch_pending:
		_begin_new_turn()
		_resolve_enemy_attack()
		if run_in_progress and not _is_fainted(current_enemy) and not _is_fainted(active_team[active_team_index]):
			_apply_end_of_round_effects()
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
	_reset_battlefield_for_new_encounter()
	for idx in range(active_team.size()):
		var mon: Dictionary = active_team[idx]
		_reset_battle_volatile_state(mon)
		active_team[idx] = mon
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
	_ensure_status_state(current_enemy)
	_reset_battle_volatile_state(current_enemy)
	if active_team_index >= 0 and active_team_index < active_team.size():
		var player_active: Dictionary = active_team[active_team_index]
		_ensure_status_state(player_active)
		_apply_switch_in_ability(player_active, current_enemy, true)
		player_active = active_team[active_team_index]
		_apply_switch_in_ability(current_enemy, player_active, false)


func _enemy_summary_text() -> String:
	if current_enemy.is_empty():
		return "No active encounter."
	var hp_now: int = int(current_enemy["current_hp"])
	var hp_max: int = int(current_enemy["stats"]["hp"])
	var status_badge: String = _status_badge_for_mon(current_enemy)
	var boss_prefix: String = "Wild"
	if bool(current_enemy.get("is_boss_encounter", false)):
		boss_prefix = "Boss"
	var enemy_types: Array = current_enemy.get("types", [])
	var type_parts: Array[String] = []
	for idx in range(enemy_types.size()):
		type_parts.append(_colorize_type_name(str(enemy_types[idx])))
	var type_text: String = "Unknown"
	if type_parts.is_empty() == false:
		type_text = "/".join(type_parts)
	return "%s %s Lv.%d %s | HP %d/%d | %s | %s" % [
		boss_prefix,
		str(current_enemy["name"]),
		int(current_enemy["level"]),
		status_badge,
		hp_now,
		hp_max,
		type_text,
		str(current_enemy["ability"])
	]


func _full_team_heal() -> void:
	for idx in range(active_team.size()):
		var mon: Dictionary = active_team[idx]
		var hp_max: int = int(mon.get("stats", {}).get("hp", 1))
		mon["current_hp"] = hp_max
		mon["status"] = ""
		mon["sleep_turns"] = 0
		mon["toxic_counter"] = 0
		mon["flinch"] = false
		mon["trapped_turns"] = 0
		mon["trapped_by"] = ""
		mon["must_recharge"] = false
		mon["queued_move"] = {}
		mon["semi_invulnerable_state"] = ""
		_ensure_move_pp_state(mon)
		var pp_max: Array = mon.get("move_pp_max", [])
		var restored_pp: Array = []
		for pp_idx in range(pp_max.size()):
			restored_pp.append(int(pp_max[pp_idx]))
		mon["move_pp"] = restored_pp
		active_team[idx] = mon


func heal_active_team_full() -> void:
	_full_team_heal()
	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("battle_log_changed", _battle_log_text())
	_emit_battle_state()


func _boss_hp_multiplier_for_floor(floor_level_value: int) -> float:
	if floor_level_value % BOSS_INTERVAL != 0:
		return 1.0
	if floor_level_value == 10:
		return 1.5
	if floor_level_value == 20:
		return 2.0
	if floor_level_value == 30:
		return 2.5
	if floor_level_value == 40:
		return 3.0
	if floor_level_value == 50:
		return 4.0
	return 1.0


func _reset_battlefield_for_new_encounter() -> void:
	current_weather = ""
	weather_turns_remaining = 0
	current_terrain = ""
	terrain_turns_remaining = 0
	player_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	enemy_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	player_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	enemy_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	player_protect_active = false
	enemy_protect_active = false


func _reset_battle_volatile_state(mon: Dictionary) -> void:
	_ensure_status_state(mon)
	mon["flinch"] = false
	mon["must_recharge"] = false
	mon["queued_move"] = {}
	mon["trapped_turns"] = 0
	mon["trapped_by"] = ""
	mon["semi_invulnerable_state"] = ""


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
	_ensure_status_state(attacker)
	_ensure_stat_stages(current_enemy)
	_ensure_status_state(current_enemy)
	active_team[active_team_index] = attacker
	var move_plain_name: String = str(move.get("name", "Move"))
	var move_name := _colorize_move_name(move)

	if not _can_act_due_to_status(attacker, true):
		active_team[active_team_index] = attacker
		return

	if bool(attacker.get("must_recharge", false)):
		attacker["must_recharge"] = false
		_emit_battle_log("%s must recharge!" % str(attacker.get("name", "Pokemon")), true)
		active_team[active_team_index] = attacker
		return

	var from_charge: bool = bool(move.get("_from_charge", false))
	if from_charge:
		_clear_semi_invulnerable_state(attacker)
	if _requires_charge(move_plain_name) and not from_charge:
		if _can_skip_charge_turn(attacker, move_plain_name):
			pass
		else:
			var queued_move: Dictionary = move.duplicate(true)
			queued_move["_from_charge"] = true
			attacker["queued_move"] = queued_move
			var semi_state: String = move_effects.semi_invulnerable_state_for_move(move_plain_name)
			if not semi_state.is_empty():
				_set_semi_invulnerable_state(attacker, semi_state)
			_emit_battle_log("%s is charging up %s!" % [str(attacker.get("name", "Pokemon")), move_name], true)
			active_team[active_team_index] = attacker
			return

	if _is_target_protected(false, move):
		_emit_battle_log("%s used %s, but the foe protected itself!" % [str(attacker["name"]), move_name], true)
		return

	if not _move_hits(attacker, current_enemy, move):
		_emit_battle_log("%s used %s, but it missed!" % [str(attacker["name"]), move_name], true)
		return

	var power: int = int(move.get("power", 0))
	var resolved_move: Dictionary = move
	if _is_solar_move(move_plain_name) and _is_weakened_solar_weather():
		power = int(floor(float(power) * 0.5))
		resolved_move = move.duplicate(true)
		resolved_move["power"] = power
	if power > 0:
		var damage_result: Dictionary = _calculate_damage_result(attacker, current_enemy, resolved_move, true)
		var damage: int = int(damage_result.get("damage", 0))
		var immunity_action: Dictionary = damage_result.get("ability_immunity_action", {})
		var hit_count: int = _hit_count_for_move(move)
		var total_damage: int = 0
		var total_hits: int = 0
		var critical_hit_seen: bool = false
		for _hit in range(hit_count):
			if _is_fainted(current_enemy):
				break
			var per_hit_result: Dictionary = _calculate_damage_result(attacker, current_enemy, resolved_move, true)
			var per_hit_damage: int = int(per_hit_result.get("damage", damage))
			var per_hit_critical: bool = bool(per_hit_result.get("is_critical", false))
			if per_hit_critical:
				critical_hit_seen = true
			var per_hit: int = min(per_hit_damage, int(current_enemy["current_hp"]))
			current_enemy["current_hp"] = max(0, int(current_enemy["current_hp"]) - per_hit)
			total_damage += per_hit
			total_hits += 1
		var type_multiplier: float = float(damage_result.get("type_multiplier", 1.0))
		var message: String = "%s used %s for %d damage." % [str(attacker["name"]), move_name, total_damage]
		if total_hits > 1:
			message += " (%dx hits)" % total_hits
		if critical_hit_seen:
			message += " Critical hit!"
		_emit_battle_log(message, true)
		if bool(immunity_action.get("immune", false)):
			_apply_ability_immunity_action(current_enemy, immunity_action, false)
		_apply_drain_heal(attacker, move, total_damage)
		_apply_recoil_damage(attacker, move, total_damage)
		_apply_named_move_effects(attacker, current_enemy, move, true, total_damage)
		if _requires_recharge(move_plain_name):
			attacker["must_recharge"] = true
		_emit_effectiveness_log(type_multiplier)
	else:
		_emit_battle_log("%s used %s." % [str(attacker["name"]), move_name], true)
		_apply_non_damaging_self_heal(attacker, move)
		_apply_named_move_effects(attacker, current_enemy, move, true, 0)

	_apply_move_stat_changes(attacker, current_enemy, move, true)


func _resolve_enemy_attack() -> void:
	var defender: Dictionary = active_team[active_team_index]
	_ensure_stat_stages(defender)
	_ensure_status_state(defender)
	_ensure_stat_stages(current_enemy)
	_ensure_status_state(current_enemy)
	if bool(current_enemy.get("must_recharge", false)):
		current_enemy["must_recharge"] = false
		_emit_battle_log("%s must recharge!" % str(current_enemy.get("name", "Pokemon")), true)
		active_team[active_team_index] = defender
		return

	var enemy_move: Dictionary = {}
	var queued_enemy_move: Dictionary = current_enemy.get("queued_move", {})
	var enemy_move_index: int = -1
	if queued_enemy_move.is_empty() == false:
		enemy_move = queued_enemy_move.duplicate(true)
		current_enemy["queued_move"] = {}
	else:
		enemy_move_index = _pick_enemy_move_index(current_enemy)
		if enemy_move_index < 0:
			_emit_battle_log("%s has no PP left!" % str(current_enemy.get("name", "Pokemon")), true)
			active_team[active_team_index] = defender
			return
		var enemy_moves: Array = current_enemy.get("moves", [])
		enemy_move = enemy_moves[enemy_move_index]
		_consume_pp_for_move(current_enemy, enemy_move_index)
	var move_plain_name: String = str(enemy_move.get("name", "Move"))
	var move_name := _colorize_move_name(enemy_move)

	if not _can_act_due_to_status(current_enemy, false):
		return

	var from_charge: bool = bool(enemy_move.get("_from_charge", false))
	if from_charge:
		_clear_semi_invulnerable_state(current_enemy)
	if _requires_charge(move_plain_name) and not from_charge:
		if _can_skip_charge_turn(current_enemy, move_plain_name):
			pass
		else:
			var queued_move: Dictionary = enemy_move.duplicate(true)
			queued_move["_from_charge"] = true
			current_enemy["queued_move"] = queued_move
			var semi_state: String = move_effects.semi_invulnerable_state_for_move(move_plain_name)
			if not semi_state.is_empty():
				_set_semi_invulnerable_state(current_enemy, semi_state)
			_emit_battle_log("%s is charging up %s!" % [str(current_enemy.get("name", "Pokemon")), move_name], true)
			active_team[active_team_index] = defender
			return

	if _is_target_protected(true, enemy_move):
		_emit_battle_log("%s used %s, but %s protected itself!" % [str(current_enemy["name"]), move_name, str(defender["name"])], true)
		active_team[active_team_index] = defender
		return

	if not _move_hits(current_enemy, defender, enemy_move):
		_emit_battle_log("%s used %s, but it missed!" % [str(current_enemy["name"]), move_name], true)
		active_team[active_team_index] = defender
		return

	var power: int = int(enemy_move.get("power", 0))
	var resolved_enemy_move: Dictionary = enemy_move
	if _is_solar_move(move_plain_name) and _is_weakened_solar_weather():
		power = int(floor(float(power) * 0.5))
		resolved_enemy_move = enemy_move.duplicate(true)
		resolved_enemy_move["power"] = power
	if power > 0:
		var damage_result: Dictionary = _calculate_damage_result(current_enemy, defender, resolved_enemy_move, false)
		var enemy_damage: int = int(damage_result.get("damage", 0))
		var immunity_action: Dictionary = damage_result.get("ability_immunity_action", {})
		var hit_count: int = _hit_count_for_move(enemy_move)
		var total_damage: int = 0
		var total_hits: int = 0
		var critical_hit_seen: bool = false
		for _hit in range(hit_count):
			if _is_fainted(defender):
				break
			var per_hit_result: Dictionary = _calculate_damage_result(current_enemy, defender, resolved_enemy_move, false)
			var per_hit_damage: int = int(per_hit_result.get("damage", enemy_damage))
			var per_hit_critical: bool = bool(per_hit_result.get("is_critical", false))
			if per_hit_critical:
				critical_hit_seen = true
			var per_hit: int = min(per_hit_damage, int(defender["current_hp"]))
			defender["current_hp"] = max(0, int(defender["current_hp"]) - per_hit)
			total_damage += per_hit
			total_hits += 1
		var type_multiplier: float = float(damage_result.get("type_multiplier", 1.0))
		var message: String = "%s used %s for %d damage." % [str(current_enemy["name"]), move_name, total_damage]
		if total_hits > 1:
			message += " (%dx hits)" % total_hits
		if critical_hit_seen:
			message += " Critical hit!"
		_emit_battle_log(message, true)
		if bool(immunity_action.get("immune", false)):
			_apply_ability_immunity_action(defender, immunity_action, true)
		_apply_drain_heal(current_enemy, enemy_move, total_damage)
		_apply_recoil_damage(current_enemy, enemy_move, total_damage)
		_apply_named_move_effects(current_enemy, defender, enemy_move, false, total_damage)
		if _requires_recharge(move_plain_name):
			current_enemy["must_recharge"] = true
		_emit_effectiveness_log(type_multiplier)
	else:
		_emit_battle_log("%s used %s." % [str(current_enemy["name"]), move_name], true)
		_apply_non_damaging_self_heal(current_enemy, enemy_move)
		_apply_named_move_effects(current_enemy, defender, enemy_move, false, 0)

	_apply_move_stat_changes(current_enemy, defender, enemy_move, false)
	active_team[active_team_index] = defender
	if _is_fainted(defender):
		_apply_ko_ability_boost(current_enemy, false)


func _can_skip_charge_turn(_attacker: Dictionary, move_name: String) -> bool:
	if not _is_solar_move(move_name):
		return false
	return current_weather == "sun"


func _is_solar_move(move_name: String) -> bool:
	var lower_name: String = move_name.to_lower()
	return lower_name == "solar beam" or lower_name == "solarblade" or lower_name == "solar blade"


func _is_weakened_solar_weather() -> bool:
	return current_weather == "rain" or current_weather == "sandstorm" or current_weather == "hail"


func _set_semi_invulnerable_state(mon: Dictionary, state_name: String) -> void:
	mon["semi_invulnerable_state"] = state_name


func _clear_semi_invulnerable_state(mon: Dictionary) -> void:
	mon["semi_invulnerable_state"] = ""


func _semi_invulnerability_multiplier(attacker_move: Dictionary, defender: Dictionary) -> float:
	var defender_state: String = str(defender.get("semi_invulnerable_state", ""))
	if defender_state.is_empty():
		return 1.0
	var move_name: String = str(attacker_move.get("name", ""))
	return move_effects.semi_invulnerable_damage_multiplier(move_name, defender_state)


func _is_blocked_by_semi_invulnerability(attacker_move: Dictionary, defender: Dictionary) -> bool:
	var defender_state: String = str(defender.get("semi_invulnerable_state", ""))
	if defender_state.is_empty():
		return false
	var move_name: String = str(attacker_move.get("name", ""))
	return not move_effects.can_hit_semi_invulnerable(move_name, defender_state)


func _pick_enemy_move_index(pokemon: Dictionary) -> int:
	var moves_list: Array = pokemon["moves"]
	var damaging_indices: Array[int] = []
	var usable_indices: Array[int] = []
	for idx in range(moves_list.size()):
		var move_data: Dictionary = moves_list[idx]
		if not _has_pp_for_move(pokemon, idx):
			continue
		usable_indices.append(idx)
		if int(move_data.get("power", 0)) > 0:
			damaging_indices.append(idx)
	if damaging_indices.is_empty():
		if usable_indices.is_empty():
			return -1
		return usable_indices[rng.randi_range(0, usable_indices.size() - 1)]
	var random_idx: int = damaging_indices[rng.randi_range(0, damaging_indices.size() - 1)]
	return random_idx


func _pick_player_move(pokemon: Dictionary, move_index: int) -> Dictionary:
	var moves_list: Array = pokemon["moves"]
	if move_index < 0 or move_index >= moves_list.size():
		var fallback_idx: int = _pick_enemy_move_index(pokemon)
		if fallback_idx < 0:
			return {}
		return moves_list[fallback_idx]
	return moves_list[move_index]


func _calculate_damage_result(attacker: Dictionary, defender: Dictionary, move: Dictionary, attacker_is_player_side: bool) -> Dictionary:
	var is_critical: bool = _roll_critical_hit(defender)
	var type_multiplier: float = _type_modifier(str(move.get("type", "Normal")), defender["types"])
	var move_type: String = str(move.get("type", "Normal"))
	var immunity_action: Dictionary = ability_effects.type_immunity_action(str(defender.get("ability", "")), move_type)
	if bool(immunity_action.get("immune", false)):
		type_multiplier = 0.0
	var damage: int = _calculate_damage(attacker, defender, move, is_critical, type_multiplier, not attacker_is_player_side)
	return {
		"damage": damage,
		"is_critical": is_critical,
		"type_multiplier": type_multiplier,
		"ability_immunity_action": immunity_action
	}


func _calculate_damage(attacker: Dictionary, defender: Dictionary, move: Dictionary, is_critical: bool, type_multiplier: float, defender_is_player_side: bool) -> int:
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
	var weather_multiplier: float = _weather_damage_multiplier(move_type)
	var glaive_rush_multiplier: float = 1.0
	var crit_multiplier: float = 1.0
	if is_critical:
		crit_multiplier = 1.5
	var random_multiplier: float = rng.randf_range(0.85, 1.0)
	var stab_multiplier: float = _stab_multiplier(attacker, move_type)
	var burn_multiplier: float = _burn_multiplier(attacker, category)
	var terrain_multiplier: float = _terrain_damage_multiplier(attacker, move_type)
	var screen_multiplier: float = _screen_damage_multiplier(defender_is_player_side, category)
	var semi_multiplier: float = _semi_invulnerability_multiplier(move, defender)
	var hp_now: int = int(attacker.get("current_hp", 0))
	var hp_max: int = int(attacker.get("stats", {}).get("hp", 1))
	var flash_fire_active: bool = bool(attacker.get("flash_fire_active", false))
	var ability_offense_multiplier: float = ability_effects.outgoing_damage_multiplier(str(attacker.get("ability", "")), move_type, hp_now, hp_max, flash_fire_active)
	var ability_defense_multiplier: float = ability_effects.incoming_damage_multiplier(str(defender.get("ability", "")), move_type, category)
	var other_multiplier: float = terrain_multiplier * screen_multiplier * semi_multiplier * ability_offense_multiplier * ability_defense_multiplier

	if type_multiplier <= 0.0:
		return 0
	var total_modifier: float = targets_multiplier * pb_multiplier * weather_multiplier * glaive_rush_multiplier * crit_multiplier * random_multiplier * stab_multiplier * type_multiplier * burn_multiplier * other_multiplier
	var final_damage: int = max(1, int(floor(float(base_damage) * total_modifier)))
	return final_damage


func _move_hits(attacker: Dictionary, defender: Dictionary, move: Dictionary) -> bool:
	if _is_blocked_by_semi_invulnerability(move, defender):
		return false
	var move_name: String = str(move.get("name", "")).to_lower()
	if current_weather == "rain" and (move_name == "thunder" or move_name == "hurricane"):
		return true
	if current_weather == "hail" and move_name == "blizzard":
		return true
	var base_accuracy: int = int(move.get("accuracy", 100))
	if current_weather == "sun" and (move_name == "thunder" or move_name == "hurricane"):
		base_accuracy = 50
	var category: String = str(move.get("category", "Status"))
	if category == "Physical":
		base_accuracy = int(round(float(base_accuracy) * ability_effects.physical_accuracy_multiplier(str(attacker.get("ability", "")))))
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
	var stat_proc_chance: int = move_effects.stat_chance_for_move(move)
	if stat_proc_chance > 0 and not _effect_procs(move, stat_proc_chance):
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


func _effect_procs(move: Dictionary, chance_override: int = -1) -> bool:
	var raw_chance = chance_override
	if chance_override < 0:
		raw_chance = move_effects.effect_chance_for_move(move)
	if int(raw_chance) <= 0:
		raw_chance = move.get("effect_chance", 100)
	var chance: float = float(raw_chance)
	chance = clamp(chance, 0.0, 100.0)
	if chance >= 100.0:
		return true
	if chance <= 0.0:
		return false
	return rng.randf() <= (chance / 100.0)


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
		var ability_name: String = str(attacker.get("ability", ""))
		if ability_effects.normalize_ability_name(ability_name) == "guts":
			return 1.0
		return 0.5
	return 1.0


func _weather_damage_multiplier(move_type: String) -> float:
	if current_weather == "rain":
		if move_type == "Water":
			return 1.5
		if move_type == "Fire":
			return 0.5
	if current_weather == "sun":
		if move_type == "Fire":
			return 1.5
		if move_type == "Water":
			return 0.5
	return 1.0


func _terrain_damage_multiplier(_attacker: Dictionary, move_type: String) -> float:
	if current_terrain.is_empty():
		return 1.0
	if current_terrain == "electric" and move_type == "Electric":
		return 1.3
	if current_terrain == "grassy" and move_type == "Grass":
		return 1.3
	if current_terrain == "psychic" and move_type == "Psychic":
		return 1.3
	return 1.0


func _screen_damage_multiplier(defender_is_player_side: bool, category: String) -> float:
	var side: Dictionary = enemy_side_barriers
	if defender_is_player_side:
		side = player_side_barriers
	if int(side.get("aurora_veil", 0)) > 0:
		return 0.5
	if category == "Physical" and int(side.get("reflect", 0)) > 0:
		return 0.5
	if category == "Special" and int(side.get("light_screen", 0)) > 0:
		return 0.5
	return 1.0


func _roll_critical_hit(defender: Dictionary) -> bool:
	var defender_ability: String = str(defender.get("ability", ""))
	if ability_effects.is_crit_immune(defender_ability):
		return false
	return rng.randi_range(1, CRIT_CHANCE_DENOM) == 1


func _emit_effectiveness_log(type_multiplier: float) -> void:
	if type_multiplier <= 0.0:
		_emit_battle_log("It had no effect.", true)
		return
	if type_multiplier > 1.0:
		_emit_battle_log("It's super effective!", true)
	elif type_multiplier < 1.0:
		_emit_battle_log("It's not very effective...", true)


func _apply_drain_heal(attacker: Dictionary, move: Dictionary, damage_dealt: int) -> void:
	if damage_dealt <= 0:
		return
	var drain_fraction: float = _drain_fraction_for_move(move)
	if drain_fraction <= 0.0:
		return
	var current_hp: int = int(attacker.get("current_hp", 0))
	var max_hp: int = int(attacker.get("stats", {}).get("hp", 1))
	if current_hp >= max_hp:
		return
	var heal_amount: int = max(1, int(floor(float(damage_dealt) * drain_fraction)))
	var new_hp: int = min(max_hp, current_hp + heal_amount)
	var recovered: int = new_hp - current_hp
	if recovered <= 0:
		return
	attacker["current_hp"] = new_hp
	_emit_battle_log("%s restored %d HP." % [str(attacker.get("name", "Pokemon")), recovered], true)


func _drain_fraction_for_move(move: Dictionary) -> float:
	var move_name: String = str(move.get("name", ""))
	return move_effects.drain_fraction_for_move(move_name)


func _apply_recoil_damage(attacker: Dictionary, move: Dictionary, damage_dealt: int) -> void:
	if damage_dealt <= 0:
		return
	if _is_recoil_blocked(attacker):
		return
	var recoil_fraction: float = _recoil_fraction_for_move(move)
	if recoil_fraction <= 0.0:
		return
	var current_hp: int = int(attacker.get("current_hp", 0))
	if current_hp <= 0:
		return
	var recoil: int = max(1, int(floor(float(damage_dealt) * recoil_fraction)))
	attacker["current_hp"] = max(0, current_hp - recoil)
	_emit_battle_log("%s was hurt by recoil for %d HP." % [str(attacker.get("name", "Pokemon")), recoil], true)


func _recoil_fraction_for_move(move: Dictionary) -> float:
	var move_name: String = str(move.get("name", ""))
	return move_effects.recoil_fraction_for_move(move_name)


func _is_recoil_blocked(attacker: Dictionary) -> bool:
	var ability_name: String = str(attacker.get("ability", ""))
	return ability_effects.is_recoil_immune(ability_name)


func _apply_non_damaging_self_heal(attacker: Dictionary, move: Dictionary) -> void:
	var heal_fraction: float = _self_heal_fraction_for_move(move)
	if heal_fraction <= 0.0:
		return
	var hp_now: int = int(attacker.get("current_hp", 0))
	var hp_max: int = int(attacker.get("stats", {}).get("hp", 1))
	if hp_now >= hp_max:
		return
	var heal_amount: int = max(1, int(floor(float(hp_max) * heal_fraction)))
	var new_hp: int = min(hp_max, hp_now + heal_amount)
	var recovered: int = new_hp - hp_now
	if recovered <= 0:
		return
	attacker["current_hp"] = new_hp
	_emit_battle_log("%s restored %d HP." % [str(attacker.get("name", "Pokemon")), recovered], true)


func _self_heal_fraction_for_move(move: Dictionary) -> float:
	var move_name: String = str(move.get("name", ""))
	return move_effects.self_heal_fraction_for_move(move_name)


func _requires_charge(move_name: String) -> bool:
	return move_effects.requires_charge(move_name)


func _requires_recharge(move_name: String) -> bool:
	return move_effects.requires_recharge(move_name)


func _hit_count_for_move(move: Dictionary) -> int:
	var move_name: String = str(move.get("name", ""))
	return move_effects.hit_count_for_move(move_name, rng, active_team.size())


func _begin_new_turn() -> void:
	player_protect_active = false
	enemy_protect_active = false


func _ensure_status_state(mon: Dictionary) -> void:
	if mon.is_empty():
		return
	_sanitize_mon_ability(mon)
	_ensure_move_pp_state(mon)
	if not mon.has("status"):
		mon["status"] = ""
	if not mon.has("sleep_turns"):
		mon["sleep_turns"] = 0
	if not mon.has("toxic_counter"):
		mon["toxic_counter"] = 0
	if not mon.has("flinch"):
		mon["flinch"] = false
	if not mon.has("must_recharge"):
		mon["must_recharge"] = false
	if not mon.has("queued_move"):
		mon["queued_move"] = {}
	if not mon.has("trapped_turns"):
		mon["trapped_turns"] = 0
	if not mon.has("trapped_by"):
		mon["trapped_by"] = ""
	if not mon.has("semi_invulnerable_state"):
		mon["semi_invulnerable_state"] = ""
	if not mon.has("flash_fire_active"):
		mon["flash_fire_active"] = false


func _sanitize_mon_ability(mon: Dictionary) -> void:
	var ability_name: String = str(mon.get("ability", ""))
	if ability_name.is_empty():
		mon["ability"] = "Moxie"


func _ensure_move_pp_state(mon: Dictionary) -> void:
	var moves_list: Array = mon.get("moves", [])
	var pp_max: Array = mon.get("move_pp_max", [])
	var pp_now: Array = mon.get("move_pp", [])
	if pp_max.size() != moves_list.size():
		pp_max.clear()
		for idx in range(moves_list.size()):
			var move_data: Dictionary = moves_list[idx]
			pp_max.append(max(1, int(move_data.get("pp", 1))))
	if pp_now.size() != moves_list.size():
		pp_now.clear()
		for idx in range(pp_max.size()):
			pp_now.append(int(pp_max[idx]))
	for idx in range(moves_list.size()):
		var max_pp: int = max(1, int(pp_max[idx]))
		pp_max[idx] = max_pp
		var cur_pp: int = int(pp_now[idx])
		pp_now[idx] = clamp(cur_pp, 0, max_pp)
	mon["move_pp_max"] = pp_max
	mon["move_pp"] = pp_now


func _has_pp_for_move(mon: Dictionary, move_index: int) -> bool:
	_ensure_move_pp_state(mon)
	var pp_now: Array = mon.get("move_pp", [])
	if move_index < 0 or move_index >= pp_now.size():
		return false
	return int(pp_now[move_index]) > 0


func _consume_pp_for_move(mon: Dictionary, move_index: int) -> bool:
	_ensure_move_pp_state(mon)
	var pp_now: Array = mon.get("move_pp", [])
	if move_index < 0 or move_index >= pp_now.size():
		return false
	var value: int = int(pp_now[move_index])
	if value <= 0:
		return false
	pp_now[move_index] = value - 1
	mon["move_pp"] = pp_now
	return true


func _can_act_due_to_status(mon: Dictionary, is_player_side: bool) -> bool:
	_ensure_status_state(mon)
	if bool(mon.get("flinch", false)):
		mon["flinch"] = false
		_emit_battle_log("%s flinched and couldn't move!" % str(mon.get("name", "Pokemon")), true)
		_commit_side_mon(mon, is_player_side)
		return false
	var status_name: String = str(mon.get("status", "")).to_lower()
	if status_name == "sleep":
		var sleep_turns: int = int(mon.get("sleep_turns", 0))
		if sleep_turns > 0:
			mon["sleep_turns"] = sleep_turns - 1
			_emit_battle_log("%s is fast asleep." % str(mon.get("name", "Pokemon")), true)
			_commit_side_mon(mon, is_player_side)
			return false
		mon["status"] = ""
		mon["sleep_turns"] = 0
		_emit_battle_log("%s woke up!" % str(mon.get("name", "Pokemon")), true)
	elif status_name == "freeze":
		if rng.randf() < 0.2:
			mon["status"] = ""
			_emit_battle_log("%s thawed out!" % str(mon.get("name", "Pokemon")), true)
		else:
			_emit_battle_log("%s is frozen solid." % str(mon.get("name", "Pokemon")), true)
			_commit_side_mon(mon, is_player_side)
			return false
	elif status_name == "paralysis":
		if rng.randf() < 0.25:
			_emit_battle_log("%s is paralyzed! It can't move!" % str(mon.get("name", "Pokemon")), true)
			_commit_side_mon(mon, is_player_side)
			return false
	_commit_side_mon(mon, is_player_side)
	return true


func _commit_side_mon(mon: Dictionary, is_player_side: bool) -> void:
	if is_player_side:
		active_team[active_team_index] = mon
	else:
		current_enemy = mon


func _is_target_protected(target_is_player_side: bool, move: Dictionary) -> bool:
	var move_name: String = str(move.get("name", ""))
	var targets_self: bool = bool(move.get("targets_self", false))
	if targets_self:
		return false
	if move_effects.is_protect_move(move_name):
		return false
	if move_effects.bypasses_protect(move_name):
		return false
	if target_is_player_side:
		return player_protect_active
	return enemy_protect_active


func _apply_named_move_effects(attacker: Dictionary, defender: Dictionary, move: Dictionary, attacker_is_player: bool, _damage_dealt: int) -> void:
	var move_name: String = str(move.get("name", ""))
	var relation: Dictionary = move_effects.relation_profile_for_move(move)
	if move_name.is_empty():
		return

	# Protective stances
	if bool(relation.get("protect", false)):
		_set_side_protect(attacker_is_player, true)
		_emit_battle_log("%s protected itself!" % str(attacker.get("name", "Pokemon")), true)
		_commit_side_mon(attacker, attacker_is_player)
		if attacker_is_player:
			current_enemy = defender
		else:
			active_team[active_team_index] = defender
		return

	# Field effects
	if _try_apply_weather(move_name):
		pass
	if _try_apply_terrain(move_name):
		pass
	_try_apply_barrier(move_name, attacker_is_player)
	_try_apply_hazard(move_name, attacker_is_player)
	if _damage_dealt > 0:
		_try_apply_trap(defender, move, relation)
		_try_apply_flinch(defender, move, relation)

	# Status ailments
	var status_to_apply: String = str(relation.get("status", ""))
	if move_name == "rest":
		attacker["status"] = "sleep"
		attacker["sleep_turns"] = rng.randi_range(SLEEP_MIN_TURNS, SLEEP_MAX_TURNS)
		attacker["toxic_counter"] = 0
		_emit_battle_log("%s fell asleep." % str(attacker.get("name", "Pokemon")), true)
	elif not status_to_apply.is_empty():
		var status_chance: int = _status_proc_chance(move, relation)
		if _effect_procs(move, status_chance):
			_try_apply_status(defender, status_to_apply)

	_commit_side_mon(attacker, attacker_is_player)
	if attacker_is_player:
		current_enemy = defender
	else:
		active_team[active_team_index] = defender


func _set_side_protect(is_player_side: bool, active: bool) -> void:
	if is_player_side:
		player_protect_active = active
	else:
		enemy_protect_active = active


func _try_apply_weather(move_name: String) -> bool:
	var weather_name: String = move_effects.weather_from_move_name(move_name)
	if weather_name == "rain":
		current_weather = weather_name
		weather_turns_remaining = 5
		_emit_battle_log("It started to rain!", true)
		return true
	if weather_name == "sun":
		current_weather = weather_name
		weather_turns_remaining = 5
		_emit_battle_log("The sunlight turned harsh!", true)
		return true
	if weather_name == "sandstorm":
		current_weather = weather_name
		weather_turns_remaining = 5
		_emit_battle_log("A sandstorm kicked up!", true)
		return true
	if weather_name == "hail":
		current_weather = weather_name
		weather_turns_remaining = 5
		_emit_battle_log("It started to hail!", true)
		return true
	return false


func _try_apply_terrain(move_name: String) -> bool:
	var terrain_name: String = move_effects.terrain_from_move_name(move_name)
	if terrain_name.is_empty():
		return false
	current_terrain = terrain_name
	terrain_turns_remaining = 5
	if terrain_name == "electric":
		_emit_battle_log("Electric Terrain spread out!", true)
	elif terrain_name == "grassy":
		_emit_battle_log("Grassy Terrain spread out!", true)
	elif terrain_name == "psychic":
		_emit_battle_log("Psychic Terrain spread out!", true)
	else:
		_emit_battle_log("Misty Terrain spread out!", true)
	return true


func _try_apply_barrier(move_name: String, attacker_is_player: bool) -> bool:
	var side: Dictionary = player_side_barriers
	if not attacker_is_player:
		side = enemy_side_barriers
	var applied: bool = false
	var barrier_name: String = move_effects.barrier_from_move_name(move_name)
	if not barrier_name.is_empty():
		side[barrier_name] = 5
		applied = true
	if applied:
		if attacker_is_player:
			player_side_barriers = side
		else:
			enemy_side_barriers = side
		_emit_battle_log("%s's team is shielded." % str(_side_name(attacker_is_player)), true)
	return applied


func _try_apply_hazard(move_name: String, attacker_is_player: bool) -> bool:
	var target_side: Dictionary = enemy_side_hazards
	if not attacker_is_player:
		target_side = player_side_hazards
	var applied: bool = false
	var hazard_name: String = move_effects.hazard_from_move_name(move_name)
	if hazard_name == "stealth_rock" and bool(target_side.get("stealth_rock", false)) == false:
		target_side["stealth_rock"] = true
		applied = true
	if hazard_name == "spikes":
		var spikes_layers: int = int(target_side.get("spikes", 0))
		target_side["spikes"] = min(3, spikes_layers + 1)
		applied = true
	if hazard_name == "toxic_spikes":
		var toxic_layers: int = int(target_side.get("toxic_spikes", 0))
		target_side["toxic_spikes"] = min(2, toxic_layers + 1)
		applied = true
	if hazard_name == "sticky_web" and bool(target_side.get("sticky_web", false)) == false:
		target_side["sticky_web"] = true
		applied = true
	if applied:
		if attacker_is_player:
			enemy_side_hazards = target_side
		else:
			player_side_hazards = target_side
		_emit_battle_log("Entry hazards were set on %s side." % _side_name(not attacker_is_player), true)
	return applied


func _try_apply_trap(defender: Dictionary, move: Dictionary, relation: Dictionary) -> bool:
	if not bool(relation.get("trap", false)):
		return false
	var trap_chance: int = int(relation.get("effect_chance", 0))
	if trap_chance > 0 and not _effect_procs(move, trap_chance):
		return false
	var turns_range: Vector2i = move_effects.trap_turn_range_for_move(move)
	defender["trapped_turns"] = rng.randi_range(turns_range.x, turns_range.y)
	var move_name: String = str(move.get("name", ""))
	defender["trapped_by"] = move_name
	_emit_battle_log("%s became trapped!" % str(defender.get("name", "Pokemon")), true)
	return true


func _try_apply_flinch(defender: Dictionary, move: Dictionary, relation: Dictionary) -> bool:
	if not bool(relation.get("flinch", false)):
		return false
	if ability_effects.is_flinch_immune(str(defender.get("ability", ""))):
		return false
	var flinch_chance: int = int(relation.get("flinch_chance", 0))
	if flinch_chance <= 0:
		flinch_chance = int(relation.get("effect_chance", 0))
	if flinch_chance <= 0:
		flinch_chance = 100
	if not _effect_procs(move, flinch_chance):
		return false
	defender["flinch"] = true
	return true


func _status_proc_chance(move: Dictionary, relation: Dictionary) -> int:
	var chance: int = int(relation.get("status_chance", 0))
	if chance > 0:
		return chance
	var power: int = int(move.get("power", 0))
	var category: String = str(move.get("category", "Status"))
	if power <= 0 or category == "Status":
		return 100
	chance = int(relation.get("effect_chance", 0))
	if chance > 0:
		return chance
	return int(move.get("effect_chance", 100))


func _status_from_move_name(move_name: String) -> String:
	return move_effects.status_from_move_name(move_name)


func _try_apply_status(target: Dictionary, status_name: String) -> bool:
	_ensure_status_state(target)
	var ability_name: String = str(target.get("ability", ""))
	if ability_effects.blocks_status(ability_name, status_name):
		_emit_battle_log("%s's %s prevents %s." % [str(target.get("name", "Pokemon")), str(target.get("ability", "Ability")), status_name], true)
		return false
	if str(target.get("status", "")).is_empty() == false:
		return false
	target["status"] = status_name
	target["toxic_counter"] = 0
	if status_name == "sleep":
		target["sleep_turns"] = rng.randi_range(SLEEP_MIN_TURNS, SLEEP_MAX_TURNS)
		_emit_battle_log("%s fell asleep." % str(target.get("name", "Pokemon")), true)
	elif status_name == "bad_poison":
		target["status"] = "poison"
		target["toxic_counter"] = 1
		_emit_battle_log("%s was badly poisoned!" % str(target.get("name", "Pokemon")), true)
	elif status_name == "poison":
		_emit_battle_log("%s was poisoned!" % str(target.get("name", "Pokemon")), true)
	elif status_name == "burn":
		_emit_battle_log("%s was burned!" % str(target.get("name", "Pokemon")), true)
	elif status_name == "paralysis":
		_emit_battle_log("%s was paralyzed!" % str(target.get("name", "Pokemon")), true)
	elif status_name == "freeze":
		_emit_battle_log("%s was frozen solid!" % str(target.get("name", "Pokemon")), true)
	return true


func _apply_end_of_round_effects() -> void:
	if run_in_progress == false:
		return
	var player: Dictionary = active_team[active_team_index]
	var enemy: Dictionary = current_enemy
	_ensure_status_state(player)
	_ensure_status_state(enemy)
	_apply_status_residual(player)
	_apply_status_residual(enemy)
	_apply_trap_residual(player)
	_apply_trap_residual(enemy)
	_apply_weather_residual(player, enemy)
	_apply_end_of_round_ability(player, true)
	_apply_end_of_round_ability(enemy, false)
	active_team[active_team_index] = player
	current_enemy = enemy
	_tick_field_effects()


func _apply_status_residual(mon: Dictionary) -> void:
	var status_name: String = str(mon.get("status", "")).to_lower()
	if status_name != "burn" and status_name != "poison":
		return
	var hp_max: int = int(mon.get("stats", {}).get("hp", 1))
	var hp_now: int = int(mon.get("current_hp", 0))
	if hp_now <= 0:
		return
	var damage: int = 0
	if status_name == "burn":
		damage = max(1, int(floor(float(hp_max) / 16.0)))
	else:
		var toxic_counter: int = int(mon.get("toxic_counter", 0))
		if toxic_counter > 0:
			damage = max(1, int(floor(float(hp_max) * float(toxic_counter) / 16.0)))
			mon["toxic_counter"] = toxic_counter + 1
		else:
			damage = max(1, int(floor(float(hp_max) / 8.0)))
	mon["current_hp"] = max(0, hp_now - damage)
	_emit_battle_log("%s is hurt by %s (%d HP)." % [str(mon.get("name", "Pokemon")), status_name, damage], true)


func _apply_trap_residual(mon: Dictionary) -> void:
	var trapped_turns: int = int(mon.get("trapped_turns", 0))
	if trapped_turns <= 0:
		return
	var hp_now: int = int(mon.get("current_hp", 0))
	if hp_now <= 0:
		mon["trapped_turns"] = 0
		return
	var hp_max: int = int(mon.get("stats", {}).get("hp", 1))
	var damage: int = max(1, int(floor(float(hp_max) / 8.0)))
	mon["current_hp"] = max(0, hp_now - damage)
	mon["trapped_turns"] = trapped_turns - 1
	_emit_battle_log("%s is hurt by trapping (%d HP)." % [str(mon.get("name", "Pokemon")), damage], true)
	if int(mon.get("trapped_turns", 0)) <= 0:
		mon["trapped_by"] = ""
		_emit_battle_log("%s was freed from the trap." % str(mon.get("name", "Pokemon")), true)


func _apply_switch_in_hazards(mon: Dictionary, is_player_side: bool) -> void:
	var hazards: Dictionary = enemy_side_hazards
	if is_player_side:
		hazards = player_side_hazards
	if bool(hazards.get("stealth_rock", false)):
		var rock_multiplier: float = _type_modifier("Rock", mon.get("types", []))
		var sr_damage: int = max(1, int(floor(float(mon.get("stats", {}).get("hp", 1)) * rock_multiplier / 8.0)))
		mon["current_hp"] = max(0, int(mon.get("current_hp", 0)) - sr_damage)
		_emit_battle_log("%s was hurt by Stealth Rock (%d HP)." % [str(mon.get("name", "Pokemon")), sr_damage], true)
	var spikes_layers: int = int(hazards.get("spikes", 0))
	if spikes_layers > 0 and not _has_type(mon, "Flying"):
		var fraction: float = 0.125
		if spikes_layers == 2:
			fraction = 1.0 / 6.0
		elif spikes_layers >= 3:
			fraction = 0.25
		var spikes_damage: int = max(1, int(floor(float(mon.get("stats", {}).get("hp", 1)) * fraction)))
		mon["current_hp"] = max(0, int(mon.get("current_hp", 0)) - spikes_damage)
		_emit_battle_log("%s was hurt by Spikes (%d HP)." % [str(mon.get("name", "Pokemon")), spikes_damage], true)
	if bool(hazards.get("sticky_web", false)):
		_apply_stage_change(mon, "spe", -1, str(mon.get("name", "Pokemon")))
	var toxic_layers: int = int(hazards.get("toxic_spikes", 0))
	if toxic_layers > 0 and str(mon.get("status", "")).is_empty():
		if not _has_type(mon, "Steel") and not _has_type(mon, "Poison"):
			if toxic_layers >= 2:
				mon["status"] = "poison"
				mon["toxic_counter"] = 1
				_emit_battle_log("%s was badly poisoned by Toxic Spikes!" % str(mon.get("name", "Pokemon")), true)
			else:
				mon["status"] = "poison"
				mon["toxic_counter"] = 0
				_emit_battle_log("%s was poisoned by Toxic Spikes!" % str(mon.get("name", "Pokemon")), true)


func _has_type(mon: Dictionary, type_name: String) -> bool:
	var types: Array = mon.get("types", [])
	for idx in range(types.size()):
		if str(types[idx]) == type_name:
			return true
	return false


func _apply_weather_residual(player: Dictionary, enemy: Dictionary) -> void:
	if weather_turns_remaining <= 0:
		return
	if current_weather != "sandstorm" and current_weather != "hail":
		return
	_apply_single_weather_residual(player, current_weather)
	_apply_single_weather_residual(enemy, current_weather)


func _apply_single_weather_residual(mon: Dictionary, weather_name: String) -> void:
	var hp_now: int = int(mon.get("current_hp", 0))
	if hp_now <= 0:
		return
	var types: Array = mon.get("types", [])
	if weather_name == "sandstorm":
		for idx in range(types.size()):
			var t: String = str(types[idx])
			if t == "Rock" or t == "Ground" or t == "Steel":
				return
	if weather_name == "hail":
		for idx in range(types.size()):
			if str(types[idx]) == "Ice":
				return
	var hp_max: int = int(mon.get("stats", {}).get("hp", 1))
	var damage: int = max(1, int(floor(float(hp_max) / 16.0)))
	mon["current_hp"] = max(0, hp_now - damage)
	_emit_battle_log("%s is buffeted by %s (%d HP)." % [str(mon.get("name", "Pokemon")), weather_name, damage], true)


func _tick_field_effects() -> void:
	if weather_turns_remaining > 0:
		weather_turns_remaining -= 1
		if weather_turns_remaining <= 0 and not current_weather.is_empty():
			_emit_battle_log("The weather returned to normal.", true)
			current_weather = ""
	if terrain_turns_remaining > 0:
		terrain_turns_remaining -= 1
		if terrain_turns_remaining <= 0 and not current_terrain.is_empty():
			_emit_battle_log("The terrain disappeared.", true)
			current_terrain = ""
	_tick_side_barriers(true)
	_tick_side_barriers(false)


func _tick_side_barriers(is_player_side: bool) -> void:
	var side: Dictionary = player_side_barriers
	if not is_player_side:
		side = enemy_side_barriers
	var keys: Array[String] = ["reflect", "light_screen", "aurora_veil"]
	var changed: bool = false
	for idx in range(keys.size()):
		var key: String = keys[idx]
		var turns: int = int(side.get(key, 0))
		if turns > 0:
			side[key] = turns - 1
			changed = true
	if changed:
		if is_player_side:
			player_side_barriers = side
		else:
			enemy_side_barriers = side


func _side_name(is_player_side: bool) -> String:
	if is_player_side:
		return "Your"
	return "Foe"


func _apply_ability_immunity_action(defender: Dictionary, action: Dictionary, defender_is_player_side: bool) -> void:
	if bool(action.get("immune", false)):
		_emit_battle_log("%s's ability nullified the attack." % str(defender.get("name", "Pokemon")), true)
	var heal_fraction: float = float(action.get("heal_fraction", 0.0))
	if heal_fraction > 0.0:
		var hp_now: int = int(defender.get("current_hp", 0))
		var hp_max: int = int(defender.get("stats", {}).get("hp", 1))
		var heal_amount: int = max(1, int(floor(float(hp_max) * heal_fraction)))
		var new_hp: int = min(hp_max, hp_now + heal_amount)
		var recovered: int = new_hp - hp_now
		if recovered > 0:
			defender["current_hp"] = new_hp
			_emit_battle_log("%s restored %d HP." % [str(defender.get("name", "Pokemon")), recovered], true)
	var boost_stat: String = str(action.get("boost_stat", ""))
	if not boost_stat.is_empty():
		_apply_stage_change(defender, boost_stat, 1, str(defender.get("name", "Pokemon")))
	if bool(action.get("activate_flash_fire", false)):
		defender["flash_fire_active"] = true
		_emit_battle_log("%s's Flash Fire activated!" % str(defender.get("name", "Pokemon")), true)
	_commit_side_mon(defender, defender_is_player_side)


func _apply_switch_in_ability(mon: Dictionary, opponent: Dictionary, mon_is_player_side: bool) -> void:
	var ability_name: String = str(mon.get("ability", ""))
	var weather_name: String = ability_effects.switch_in_weather(ability_name)
	if not weather_name.is_empty():
		current_weather = weather_name
		weather_turns_remaining = 5
		_emit_battle_log("%s's %s changed the weather!" % [str(mon.get("name", "Pokemon")), ability_name], true)
	if ability_effects.has_intimidate(ability_name):
		_apply_stage_change(opponent, "atk", -1, str(opponent.get("name", "Pokemon")))
		_emit_battle_log("%s's Intimidate lowers %s's Attack!" % [str(mon.get("name", "Pokemon")), str(opponent.get("name", "Pokemon"))], true)
	_commit_side_mon(mon, mon_is_player_side)
	_commit_side_mon(opponent, not mon_is_player_side)


func _apply_end_of_round_ability(mon: Dictionary, is_player_side: bool) -> void:
	var ability_name: String = str(mon.get("ability", ""))
	var status_name: String = str(mon.get("status", ""))
	var action: Dictionary = ability_effects.end_of_round_action(ability_name, current_weather, status_name, rng)
	var hp_max: int = int(mon.get("stats", {}).get("hp", 1))
	var hp_now: int = int(mon.get("current_hp", 0))
	var heal_fraction: float = float(action.get("heal_fraction", 0.0))
	if heal_fraction > 0.0 and hp_now > 0:
		var heal_amount: int = max(1, int(floor(float(hp_max) * heal_fraction)))
		var new_hp: int = min(hp_max, hp_now + heal_amount)
		var recovered: int = new_hp - hp_now
		if recovered > 0:
			mon["current_hp"] = new_hp
			_emit_battle_log("%s restored %d HP from %s." % [str(mon.get("name", "Pokemon")), recovered, ability_name], true)
	var damage_fraction: float = float(action.get("damage_fraction", 0.0))
	if damage_fraction > 0.0 and int(mon.get("current_hp", 0)) > 0:
		var dmg: int = max(1, int(floor(float(hp_max) * damage_fraction)))
		mon["current_hp"] = max(0, int(mon.get("current_hp", 0)) - dmg)
		_emit_battle_log("%s was hurt by %s (%d HP)." % [str(mon.get("name", "Pokemon")), ability_name, dmg], true)
	if bool(action.get("cure_status", false)):
		mon["status"] = ""
		mon["sleep_turns"] = 0
		mon["toxic_counter"] = 0
		_emit_battle_log("%s shed its status with %s." % [str(mon.get("name", "Pokemon")), ability_name], true)
	if bool(action.get("boost_speed", false)):
		_apply_stage_change(mon, "spe", 1, str(mon.get("name", "Pokemon")))
	_commit_side_mon(mon, is_player_side)


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
	var staged_value: float = max(1.0, base_value * _stage_multiplier(stage))
	var ability_name: String = str(mon.get("ability", ""))
	var status_name: String = str(mon.get("status", ""))
	var ability_multiplier: float = ability_effects.offensive_stat_multiplier(ability_name, stat_key, status_name, current_weather)
	return max(1.0, staged_value * ability_multiplier)


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
		if single_battle_mode:
			_finish_single_battle("lose")
			return
		_end_run("All team members fainted. Run over.")


func _end_run(message: String) -> void:
	single_battle_mode = false
	run_in_progress = false
	current_enemy = {}
	current_offer = {}
	current_evolution_offer = {}
	pending_evolution_queue.clear()
	awaiting_move_choice = false
	awaiting_switch_choice = false
	forced_switch_pending = false
	current_weather = ""
	weather_turns_remaining = 0
	current_terrain = ""
	terrain_turns_remaining = 0
	player_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	enemy_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	player_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	enemy_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	player_protect_active = false
	enemy_protect_active = false
	emit_signal("enemy_changed", "No active encounter.")
	_emit_battle_log(message, true)
	emit_signal("team_changed", active_team.duplicate(true))
	emit_signal("battle_log_changed", _battle_log_text())
	emit_signal("evolution_offer_closed")
	_emit_battle_state()
	emit_signal("run_ended", message)
	_save_run_state()


func _finish_single_battle(result: String) -> void:
	var message: String = "Battle finished."
	if result == "win":
		message = "You won the battle!"
	elif result == "lose":
		message = "You lost the battle."
	_end_run(message)
	emit_signal("single_battle_finished", result)


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
	var type_parts: Array[String] = []
	var mon_types: Array = pokemon.get("types", [])
	for idx in range(mon_types.size()):
		type_parts.append(str(mon_types[idx]))
	var type_text: String = "Unknown"
	if type_parts.is_empty() == false:
		type_text = "/".join(type_parts)
	return "#%03d %s (Lv.%d)\nType: %s\nHP: %d/%d\nAbility: %s\nNature: %s\nMoves: %s" % [
		int(pokemon.get("id", 0)),
		str(pokemon.get("name", "Pokemon")),
		int(pokemon.get("level", 1)),
		type_text,
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


func get_active_team_snapshot() -> Array:
	return active_team.duplicate(true)


func get_battle_state() -> Dictionary:
	var active_summary := {}
	if run_in_progress and active_team_index >= 0 and active_team_index < active_team.size():
		active_summary = active_team[active_team_index]

	var move_names: Array[String] = []
	var move_can_use: Array[bool] = []
	if active_summary.is_empty() == false:
		_ensure_move_pp_state(active_summary)
		var moves_list: Array = active_summary["moves"]
		var pp_now: Array = active_summary.get("move_pp", [])
		var pp_max: Array = active_summary.get("move_pp_max", [])
		for idx in range(moves_list.size()):
			var move_data: Dictionary = moves_list[idx]
			var move_name: String = str(move_data.get("name", "Move"))
			var cur_pp: int = 0
			var max_pp: int = int(move_data.get("pp", 1))
			if idx < pp_now.size():
				cur_pp = int(pp_now[idx])
			if idx < pp_max.size():
				max_pp = int(pp_max[idx])
			move_names.append("%s (%d/%d)" % [move_name, cur_pp, max_pp])
			move_can_use.append(cur_pp > 0)

	return {
		"floor": floor_level,
		"run_in_progress": run_in_progress,
		"awaiting_move_choice": awaiting_move_choice,
		"awaiting_switch_choice": awaiting_switch_choice,
		"switches_used_this_floor": switches_used_this_floor,
		"move_names": move_names,
		"move_can_use": move_can_use,
		"move_types": _active_move_types(active_summary),
		"move_tooltips": _active_move_tooltips(active_summary),
		"switch_targets": get_available_switch_indices(),
		"active_id": int(active_summary.get("id", 0)),
		"active_name": str(active_summary.get("name", "")),
		"active_level": int(active_summary.get("level", 0)),
		"active_status": _status_badge_for_mon(active_summary),
		"active_ability": str(active_summary.get("ability", "")),
		"active_hp": int(active_summary.get("current_hp", 0)),
		"active_hp_max": int(active_summary.get("stats", {}).get("hp", 0)),
		"active_type_1": _type_name_at(active_summary, 0),
		"active_type_2": _type_name_at(active_summary, 1),
		"active_stage_text": _stage_summary_text(active_summary),
		"enemy_id": int(current_enemy.get("id", 0)),
		"enemy_name": str(current_enemy.get("name", "")),
		"enemy_level": int(current_enemy.get("level", 0)),
		"enemy_status": _status_badge_for_mon(current_enemy),
		"enemy_hp": int(current_enemy.get("current_hp", 0)),
		"enemy_hp_max": int(current_enemy.get("stats", {}).get("hp", 0)),
		"enemy_stage_text": _stage_summary_text(current_enemy),
		"runs_in_current_stretch": runs_in_current_stretch,
		"weather": current_weather,
		"weather_turns": weather_turns_remaining,
		"terrain": current_terrain,
		"terrain_turns": terrain_turns_remaining
	}


func _type_name_at(mon: Dictionary, index: int) -> String:
	var types_list: Array = mon.get("types", [])
	if index < 0 or index >= types_list.size():
		return ""
	return str(types_list[index])


func _status_badge_for_mon(mon: Dictionary) -> String:
	if mon.is_empty():
		return "[color=#9AA0A6][OK][/color]"
	var status_name: String = str(mon.get("status", "")).to_lower()
	if status_name == "burn":
		return "[color=#EF6C00][BRN][/color]"
	if status_name == "paralysis":
		return "[color=#FBC02D][PAR][/color]"
	if status_name == "sleep":
		return "[color=#5C6BC0][SLP][/color]"
	if status_name == "freeze":
		return "[color=#4FC3F7][FRZ][/color]"
	if status_name == "poison":
		if int(mon.get("toxic_counter", 0)) > 0:
			return "[color=#8E24AA][TOX][/color]"
		return "[color=#AB47BC][PSN][/color]"
	return "[color=#9AA0A6][OK][/color]"


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
	current_weather = ""
	weather_turns_remaining = 0
	current_terrain = ""
	terrain_turns_remaining = 0
	player_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	enemy_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
	player_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	enemy_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
	player_protect_active = false
	enemy_protect_active = false
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
	current_weather = str(parsed.get("current_weather", ""))
	weather_turns_remaining = int(parsed.get("weather_turns_remaining", 0))
	current_terrain = str(parsed.get("current_terrain", ""))
	terrain_turns_remaining = int(parsed.get("terrain_turns_remaining", 0))
	player_side_barriers = parsed.get("player_side_barriers", {"reflect": 0, "light_screen": 0, "aurora_veil": 0})
	enemy_side_barriers = parsed.get("enemy_side_barriers", {"reflect": 0, "light_screen": 0, "aurora_veil": 0})
	player_side_hazards = parsed.get("player_side_hazards", {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false})
	enemy_side_hazards = parsed.get("enemy_side_hazards", {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false})
	player_protect_active = bool(parsed.get("player_protect_active", false))
	enemy_protect_active = bool(parsed.get("enemy_protect_active", false))
	battle_log_lines.clear()
	var loaded_battle_log: Array = parsed.get("battle_log_lines", [])
	for idx in range(loaded_battle_log.size()):
		battle_log_lines.append(str(loaded_battle_log[idx]))
	locked_pokedex_ids = []
	for value in parsed.get("locked_pokedex_ids", []):
		locked_pokedex_ids.append(int(value))
	current_offer = parsed.get("current_offer", {})
	run_in_progress = bool(parsed.get("run_in_progress", false))
	for idx in range(active_team.size()):
		var mon: Dictionary = active_team[idx]
		_ensure_status_state(mon)
		active_team[idx] = mon
	_ensure_status_state(current_enemy)
	if run_in_progress and current_enemy.is_empty() and current_offer.is_empty():
		_spawn_enemy_for_current_floor()
	if not run_in_progress:
		awaiting_move_choice = false
		awaiting_switch_choice = false
		forced_switch_pending = false
		switches_used_this_floor = 0
		current_weather = ""
		weather_turns_remaining = 0
		current_terrain = ""
		terrain_turns_remaining = 0
		player_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
		enemy_side_barriers = {"reflect": 0, "light_screen": 0, "aurora_veil": 0}
		player_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
		enemy_side_hazards = {"stealth_rock": false, "spikes": 0, "toxic_spikes": 0, "sticky_web": false}
		player_protect_active = false
		enemy_protect_active = false
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
		"current_weather": current_weather,
		"weather_turns_remaining": weather_turns_remaining,
		"current_terrain": current_terrain,
		"terrain_turns_remaining": terrain_turns_remaining,
		"player_side_barriers": player_side_barriers,
		"enemy_side_barriers": enemy_side_barriers,
		"player_side_hazards": player_side_hazards,
		"enemy_side_hazards": enemy_side_hazards,
		"player_protect_active": player_protect_active,
		"enemy_protect_active": enemy_protect_active,
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


func _sanitize_loaded_abilities() -> void:
	for idx in range(active_team.size()):
		var mon: Dictionary = active_team[idx]
		_ensure_status_state(mon)
		_sanitize_mon_ability(mon)
		active_team[idx] = mon
	for idx in range(unlocked_roster.size()):
		var mon: Dictionary = unlocked_roster[idx]
		_ensure_status_state(mon)
		_sanitize_mon_ability(mon)
		unlocked_roster[idx] = mon
	if current_enemy.is_empty() == false:
		_ensure_status_state(current_enemy)
		_sanitize_mon_ability(current_enemy)
	if current_offer.is_empty() == false:
		_ensure_status_state(current_offer)
		_sanitize_mon_ability(current_offer)


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
	_ensure_move_pp_state(active_summary)
	var moves_list: Array = active_summary.get("moves", [])
	var pp_now: Array = active_summary.get("move_pp", [])
	var pp_max: Array = active_summary.get("move_pp_max", [])
	for idx in range(moves_list.size()):
		var move_data: Dictionary = moves_list[idx]
		var cur_pp: int = 0
		var max_pp: int = int(move_data.get("pp", 1))
		if idx < pp_now.size():
			cur_pp = int(pp_now[idx])
		if idx < pp_max.size():
			max_pp = int(pp_max[idx])
		result.append(_move_tooltip_text(move_data, cur_pp, max_pp))
	return result


func _move_tooltip_text(move_data: Dictionary, current_pp: int, max_pp: int) -> String:
	var move_name_text: String = str(move_data.get("name", "Move"))
	var move_type: String = str(move_data.get("type", "Normal"))
	var category: String = str(move_data.get("category", "Status"))
	var power: int = int(move_data.get("power", 0))
	var accuracy: int = int(move_data.get("accuracy", 100))
	var effect_chance: int = int(move_data.get("effect_chance", 100))
	var changes: Array = move_data.get("stat_changes", [])
	var stat_parts: Array[String] = []
	for idx in range(changes.size()):
		var entry: Dictionary = changes[idx]
		var stat_key: String = _stage_stat_label(str(entry.get("stat", "")))
		var delta: int = int(entry.get("change", 0))
		var sign_prefix: String = "+"
		if delta < 0:
			sign_prefix = ""
		stat_parts.append("%s %s%d" % [stat_key, sign_prefix, delta])
	var stat_text: String = "-"
	if stat_parts.is_empty() == false:
		stat_text = ", ".join(stat_parts)
	return "%s\nType: %s | Category: %s\nPower: %d | Accuracy: %d | PP: %d/%d\nEffect Chance: %d%%\nStat Changes: %s" % [
		move_name_text,
		move_type,
		category,
		power,
		accuracy,
		current_pp,
		max_pp,
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
		var stage_sign := "+"
		if value < 0:
			stage_sign = ""
		parts.append("%s %s%d" % [_stage_stat_label(key), stage_sign, value])

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


func _pick_wild_species_id_for_floor(floor_level_value: int) -> int:
	if floor_level_value <= BASIC_ONLY_FLOOR_LIMIT and not basic_species_ids.is_empty():
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
