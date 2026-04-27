extends Control

const SETTINGS_PATH := "user://ui_settings.cfg"
const BG_PRESETS := [
	{"name": "Forest Blue", "color": Color(0.24, 0.4, 0.52, 1.0)},
	{"name": "Sky Blue", "color": Color(0.33, 0.52, 0.66, 1.0)},
	{"name": "Light Cyan", "color": Color(0.42, 0.62, 0.72, 1.0)},
	{"name": "Classic Green", "color": Color(0.23, 0.42, 0.29, 1.0)}
]

@onready var run_manager: RunManager = $RunManager
@onready var sprite_service: SpriteService = $SpriteService
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var music_player_b: AudioStreamPlayer = $MusicPlayerB

@onready var start_screen: Control = $StartScreen
@onready var continue_button: Button = $StartScreen/Panel/VBox/Buttons/ContinueButton
@onready var new_run_button: Button = $StartScreen/Panel/VBox/Buttons/NewRunButton
@onready var start_status_label: Label = $StartScreen/Panel/VBox/StatusLabel

@onready var team_select_screen: Control = $TeamSelectScreen
@onready var team_select_grid: GridContainer = $TeamSelectScreen/Margin/VBox/Scroll/Grid
@onready var team_select_chosen_label: Label = $TeamSelectScreen/Margin/VBox/ChosenLabel
@onready var team_select_start_button: Button = $TeamSelectScreen/Margin/VBox/Buttons/StartButton
@onready var team_select_cancel_button: Button = $TeamSelectScreen/Margin/VBox/Buttons/CancelButton

@onready var switch_screen: Control = $SwitchScreen
@onready var switch_grid: GridContainer = $SwitchScreen/Margin/VBox/Scroll/Grid
@onready var switch_cancel_button: Button = $SwitchScreen/Margin/VBox/Buttons/CancelButton

@onready var battle_root: Control = $BattleRoot
@onready var background_rect: ColorRect = $BattleRoot/Background
@onready var bottom_bar: PanelContainer = $BattleRoot/BottomBar
@onready var flash_overlay: ColorRect = $BattleRoot/FlashOverlay
@onready var move_hover_panel: PanelContainer = $BattleRoot/MoveHoverPanel
@onready var move_hover_text: Label = $BattleRoot/MoveHoverPanel/MoveHoverText
@onready var settings_button: Button = $BattleRoot/SettingsButton
@onready var settings_screen: Control = $SettingsScreen
@onready var settings_background_picker: OptionButton = $SettingsScreen/Panel/VBox/BackgroundPicker
@onready var settings_music_picker: OptionButton = $SettingsScreen/Panel/VBox/MusicPicker
@onready var settings_music_toggle: CheckButton = $SettingsScreen/Panel/VBox/MusicToggle
@onready var settings_close_button: Button = $SettingsScreen/Panel/VBox/CloseButton
@onready var floor_label: Label = $BattleRoot/FloorLabel
@onready var enemy_sprite: TextureRect = $BattleRoot/EnemySprite
@onready var player_sprite: TextureRect = $BattleRoot/PlayerSprite
@onready var enemy_status: RichTextLabel = $BattleRoot/EnemyStatus/VBox/Info
@onready var enemy_hp: ProgressBar = $BattleRoot/EnemyStatus/VBox/HP
@onready var enemy_stages: Label = $BattleRoot/EnemyStatus/VBox/Stages
@onready var player_status: RichTextLabel = $BattleRoot/PlayerStatus/VBox/Info
@onready var player_hp: ProgressBar = $BattleRoot/PlayerStatus/VBox/HP
@onready var player_stages: Label = $BattleRoot/PlayerStatus/VBox/Stages

@onready var message_label: RichTextLabel = $BattleRoot/BottomBar/VBox/Message
@onready var message_timer: Timer = $BattleRoot/BottomBar/VBox/MessageTimer
@onready var fight_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Fight
@onready var switch_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Switch
@onready var run_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Run
@onready var status_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Status
@onready var quit_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Quit
@onready var move_grid: GridContainer = $BattleRoot/BottomBar/VBox/MoveGrid
@onready var move_buttons: Array[Button] = [
	$BattleRoot/BottomBar/VBox/MoveGrid/Move1 as Button,
	$BattleRoot/BottomBar/VBox/MoveGrid/Move2 as Button,
	$BattleRoot/BottomBar/VBox/MoveGrid/Move3 as Button,
	$BattleRoot/BottomBar/VBox/MoveGrid/Move4 as Button
]

@onready var status_popup: Control = $StatusPopup
@onready var status_text: RichTextLabel = $StatusPopup/Panel/VBox/Text
@onready var status_close_button: Button = $StatusPopup/Panel/VBox/CloseButton

@onready var unlock_popup: Control = $UnlockPopup
@onready var unlock_sprite: TextureRect = $UnlockPopup/Panel/VBox/Sprite
@onready var unlock_text: RichTextLabel = $UnlockPopup/Panel/VBox/Text
@onready var unlock_add_button: Button = $UnlockPopup/Panel/VBox/Buttons/AddButton
@onready var unlock_skip_button: Button = $UnlockPopup/Panel/VBox/Buttons/SkipButton

@onready var evolution_popup: Control = $EvolutionPopup
@onready var evolution_text: RichTextLabel = $EvolutionPopup/Panel/VBox/Text
@onready var evolution_yes_button: Button = $EvolutionPopup/Panel/VBox/Buttons/YesButton
@onready var evolution_no_button: Button = $EvolutionPopup/Panel/VBox/Buttons/NoButton

var fallback_texture: Texture2D
var selected_team_ids: Array[int] = []
var team_select_preview_by_id: Dictionary = {}
var team_select_buttons_by_id: Dictionary = {}
var switch_buttons_by_sprite_id: Dictionary = {}
var last_team_snapshot: Array = []
var last_battle_state: Dictionary = {}
var current_enemy_id: int = 0
var current_active_id: int = 0
var selected_background_preset: int = 0
var selected_music_theme: int = 2
var music_enabled: bool = true
var active_music_player: AudioStreamPlayer
var inactive_music_player: AudioStreamPlayer
var music_fade_tween: Tween
var music_transitioning: bool = false
var flash_tween: Tween
var pending_unlock_sprite_id: int = 0
var move_hover_details: Array[String] = []


func _ready() -> void:
	_configure_window_behavior()
	fallback_texture = load("res://icon.svg") as Texture2D
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	bottom_bar.add_theme_stylebox_override("panel", bar_style)
	active_music_player = music_player
	inactive_music_player = music_player_b
	music_player.finished.connect(_on_music_player_finished.bind(music_player))
	music_player_b.finished.connect(_on_music_player_finished.bind(music_player_b))
	_set_bottom_panel_text_white()
	_setup_settings_menu()
	_load_user_settings()
	_force_all_text_white(self)
	_setup_move_hover_panel_style()

	run_manager.run_started.connect(_on_run_started)
	run_manager.run_ended.connect(_on_run_ended)
	run_manager.floor_changed.connect(_on_floor_changed)
	run_manager.team_changed.connect(_on_team_changed)
	run_manager.enemy_changed.connect(_on_enemy_changed)
	run_manager.battle_log_changed.connect(_on_battle_log_changed)
	run_manager.battle_state_changed.connect(_on_battle_state_changed)
	run_manager.unlock_offer_created.connect(_on_unlock_offer_created)
	run_manager.unlock_offer_closed.connect(_on_unlock_offer_closed)
	run_manager.evolution_offer_created.connect(_on_evolution_offer_created)
	run_manager.evolution_offer_closed.connect(_on_evolution_offer_closed)
	run_manager.permanent_unlocks_changed.connect(_on_permanent_unlocks_changed)

	sprite_service.sprite_ready.connect(_on_front_sprite_ready)
	sprite_service.back_sprite_ready.connect(_on_back_sprite_ready)

	continue_button.pressed.connect(_on_continue_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	team_select_start_button.pressed.connect(_on_team_select_start_pressed)
	team_select_cancel_button.pressed.connect(_on_team_select_cancel_pressed)
	switch_cancel_button.pressed.connect(_on_switch_cancel_pressed)
	fight_button.pressed.connect(func() -> void: run_manager.begin_fight_choice())
	switch_button.pressed.connect(func() -> void: run_manager.begin_switch_choice())
	run_button.pressed.connect(func() -> void: run_manager.run_from_encounter())
	status_button.pressed.connect(_on_status_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_button.pressed.connect(func() -> void: settings_screen.visible = true)
	settings_close_button.pressed.connect(func() -> void: settings_screen.visible = false)
	settings_background_picker.item_selected.connect(_on_background_preset_selected)
	settings_music_picker.item_selected.connect(_on_music_theme_selected)
	settings_music_toggle.toggled.connect(_on_music_enabled_toggled)
	status_close_button.pressed.connect(func() -> void: status_popup.visible = false)
	unlock_add_button.pressed.connect(func() -> void: run_manager.resolve_unlock_offer(true))
	unlock_skip_button.pressed.connect(func() -> void: run_manager.resolve_unlock_offer(false))
	evolution_yes_button.pressed.connect(func() -> void: run_manager.resolve_evolution_offer(true))
	evolution_no_button.pressed.connect(func() -> void: run_manager.resolve_evolution_offer(false))
	for idx in range(move_buttons.size()):
		move_buttons[idx].pressed.connect(_on_move_pressed.bind(idx))
		move_buttons[idx].mouse_entered.connect(_on_move_hover_entered.bind(idx))
		move_buttons[idx].mouse_exited.connect(_on_move_hover_exited)
	message_timer.timeout.connect(func() -> void: message_label.text = "")

	_show_only_screen("start")
	_refresh_start_status()
	run_manager.emit_current_state()


func _show_only_screen(mode: String) -> void:
	start_screen.visible = mode == "start"
	team_select_screen.visible = mode == "team_select"
	switch_screen.visible = mode == "switch"
	battle_root.visible = mode == "battle"
	if mode != "battle":
		settings_screen.visible = false


func _on_continue_pressed() -> void:
	if not run_manager.has_active_run():
		start_status_label.text = "No run to continue."
		return
	_show_only_screen("battle")


func _on_new_run_pressed() -> void:
	selected_team_ids.clear()
	_populate_team_select_grid()
	_refresh_team_select_ui()
	_show_only_screen("team_select")


func _on_team_select_cancel_pressed() -> void:
	_show_only_screen("start")


func _on_team_select_start_pressed() -> void:
	if selected_team_ids.size() < 2:
		return
	var selected_team: Array = []
	for idx in range(selected_team_ids.size()):
		var dex_id: int = selected_team_ids[idx]
		if team_select_preview_by_id.has(dex_id):
			selected_team.append(team_select_preview_by_id[dex_id].duplicate(true))
	run_manager.start_new_run_with_pokemon(selected_team)
	_show_only_screen("battle")


func _on_switch_cancel_pressed() -> void:
	_show_only_screen("battle")


func _on_run_started() -> void:
	_show_only_screen("battle")
	_refresh_start_status()


func _on_run_ended(_message: String) -> void:
	_show_only_screen("start")
	_refresh_start_status()


func _on_floor_changed(new_floor: int) -> void:
	floor_label.text = "Floor %d" % new_floor
	last_battle_state["floor"] = new_floor


func _on_team_changed(team: Array) -> void:
	last_team_snapshot = team
	if team.is_empty():
		current_active_id = 0
		player_sprite.texture = fallback_texture
		return
	var active_idx: int = clamp(run_manager.get_active_team_index(), 0, team.size() - 1)
	var active_mon: Dictionary = team[active_idx]
	current_active_id = int(active_mon.get("id", 0))
	player_sprite.texture = fallback_texture
	sprite_service.request_back_sprite(current_active_id)
	_refresh_status_popup()


func _on_enemy_changed(summary: String) -> void:
	enemy_status.text = _plain_text(summary)
	var state: Dictionary = run_manager.get_battle_state()
	current_enemy_id = int(state.get("enemy_id", 0))
	if current_enemy_id > 0:
		enemy_sprite.texture = fallback_texture
		sprite_service.request_sprite(current_enemy_id)
	_refresh_status_popup()


func _on_battle_log_changed(text: String) -> void:
	var newest := ""
	if not text.is_empty():
		newest = text.split("\n")[0]
	var cleaned: String = _plain_text(newest)
	message_label.text = cleaned
	if not newest.is_empty():
		message_timer.start()
	var lower: String = cleaned.to_lower()
	if lower.find("critical hit") >= 0:
		_trigger_battle_flash(Color(1.0, 0.35, 0.2, 1.0), 0.42, 0.14)
	if lower.find("super effective") >= 0:
		_trigger_battle_flash(Color(1.0, 1.0, 0.2, 1.0), 0.34, 0.12)


func _on_battle_state_changed(state: Dictionary) -> void:
	last_battle_state = state
	current_active_id = int(state.get("active_id", 0))
	current_enemy_id = int(state.get("enemy_id", 0))
	if current_active_id > 0:
		sprite_service.request_back_sprite(current_active_id)
	if current_enemy_id > 0:
		sprite_service.request_sprite(current_enemy_id)
	var in_run: bool = bool(state.get("run_in_progress", false))
	var waiting_move: bool = bool(state.get("awaiting_move_choice", false))
	var waiting_switch: bool = bool(state.get("awaiting_switch_choice", false))

	move_grid.visible = waiting_move
	if not waiting_move:
		move_hover_panel.visible = false
	if waiting_switch:
		_populate_switch_grid()
		_show_only_screen("switch")
	elif switch_screen.visible:
		_show_only_screen("battle")

	fight_button.disabled = (not in_run) or waiting_move
	switch_button.disabled = not in_run
	run_button.disabled = not in_run
	status_button.disabled = not in_run
	quit_button.disabled = false

	var move_names: Array = state.get("move_names", [])
	var move_tooltips: Array = state.get("move_tooltips", [])
	move_hover_details.clear()
	for i in range(move_tooltips.size()):
		move_hover_details.append(str(move_tooltips[i]))
	for idx in range(move_buttons.size()):
		var btn: Button = move_buttons[idx]
		if idx < move_names.size():
			btn.visible = true
			btn.text = str(move_names[idx])
			if idx < move_tooltips.size():
				btn.tooltip_text = str(move_tooltips[idx])
			else:
				btn.tooltip_text = ""
		else:
			btn.visible = false
			btn.tooltip_text = ""

	player_status.text = "Active %s Lv.%d | HP %d/%d | %s/%s | %s" % [
		str(state.get("active_name", "-")),
		int(state.get("active_level", 0)),
		int(state.get("active_hp", 0)),
		int(state.get("active_hp_max", 0)),
		_colorize_type(str(state.get("active_type_1", "Normal"))),
		_colorize_type(str(state.get("active_type_2", "Normal"))),
		str(state.get("active_ability", "-"))
	]
	player_hp.max_value = max(1, int(state.get("active_hp_max", 1)))
	player_hp.value = int(state.get("active_hp", 0))
	player_stages.text = "Your stages: %s" % str(state.get("active_stage_text", "-"))

	enemy_hp.max_value = max(1, int(state.get("enemy_hp_max", 1)))
	enemy_hp.value = int(state.get("enemy_hp", 0))
	enemy_stages.text = "Enemy stages: %s" % str(state.get("enemy_stage_text", "-"))
	_refresh_status_popup()


func _on_unlock_offer_created(summary: String) -> void:
	unlock_text.text = _plain_text(summary)
	pending_unlock_sprite_id = run_manager.get_current_offer_id()
	unlock_sprite.texture = fallback_texture
	if pending_unlock_sprite_id > 0:
		sprite_service.request_sprite(pending_unlock_sprite_id)
	unlock_popup.visible = true


func _on_unlock_offer_closed() -> void:
	pending_unlock_sprite_id = 0
	unlock_sprite.texture = fallback_texture
	unlock_popup.visible = false


func _on_evolution_offer_created(summary: String) -> void:
	evolution_text.text = _plain_text(summary)
	evolution_popup.visible = true


func _on_evolution_offer_closed() -> void:
	evolution_popup.visible = false


func _on_permanent_unlocks_changed(_unlocks: Array[int]) -> void:
	if team_select_screen.visible:
		_populate_team_select_grid()
		_refresh_team_select_ui()


func _on_front_sprite_ready(pokedex_id: int, texture: Texture2D) -> void:
	if pokedex_id == current_enemy_id:
		enemy_sprite.texture = texture
	if team_select_buttons_by_id.has(pokedex_id):
		var btn: Button = team_select_buttons_by_id[pokedex_id]
		btn.icon = texture
	if switch_buttons_by_sprite_id.has(pokedex_id):
		var sbtn: Button = switch_buttons_by_sprite_id[pokedex_id]
		sbtn.icon = texture
	if pending_unlock_sprite_id == pokedex_id:
		unlock_sprite.texture = texture


func _on_back_sprite_ready(pokedex_id: int, texture: Texture2D) -> void:
	if pokedex_id == current_active_id:
		player_sprite.texture = texture


func _on_move_pressed(move_index: int) -> void:
	move_hover_panel.visible = false
	run_manager.use_move(move_index)


func _on_move_hover_entered(move_index: int) -> void:
	if move_grid.visible == false:
		return
	if move_index < 0 or move_index >= move_hover_details.size():
		move_hover_panel.visible = false
		return
	move_hover_text.text = move_hover_details[move_index]
	move_hover_panel.visible = true


func _on_move_hover_exited() -> void:
	move_hover_panel.visible = false


func _on_status_pressed() -> void:
	status_popup.visible = true
	_refresh_status_popup()


func _on_quit_pressed() -> void:
	_show_only_screen("start")
	_refresh_start_status()


func _on_background_preset_selected(item_index: int) -> void:
	selected_background_preset = item_index
	_apply_background_preset(selected_background_preset)
	_save_user_settings()


func _on_music_theme_selected(item_index: int) -> void:
	selected_music_theme = settings_music_picker.get_item_id(item_index)
	_play_theme(selected_music_theme, true)
	_save_user_settings()


func _on_music_enabled_toggled(enabled: bool) -> void:
	music_enabled = enabled
	_refresh_music_player()
	_save_user_settings()


func _populate_team_select_grid() -> void:
	for child in team_select_grid.get_children():
		child.queue_free()
	team_select_buttons_by_id.clear()
	team_select_preview_by_id.clear()
	var unlocked_ids: Array[int] = run_manager.get_permanent_unlock_ids_sorted()
	for idx in range(unlocked_ids.size()):
		var dex_id: int = unlocked_ids[idx]
		var preview: Dictionary = run_manager.get_randomized_preview_for_species(dex_id)
		team_select_preview_by_id[dex_id] = preview
		var button := Button.new()
		button.custom_minimum_size = Vector2(86, 86)
		button.text = "#%03d" % dex_id
		button.tooltip_text = run_manager.get_randomized_pokemon_tooltip(preview)
		button.pressed.connect(_on_team_select_species_pressed.bind(dex_id))
		team_select_grid.add_child(button)
		_force_control_white(button)
		team_select_buttons_by_id[dex_id] = button
		sprite_service.request_sprite(dex_id)


func _on_team_select_species_pressed(dex_id: int) -> void:
	if selected_team_ids.has(dex_id):
		selected_team_ids.erase(dex_id)
	else:
		if selected_team_ids.size() >= 6:
			return
		selected_team_ids.append(dex_id)
	_refresh_team_select_ui()


func _refresh_team_select_ui() -> void:
	var selected_names: Array[String] = []
	for idx in range(selected_team_ids.size()):
		selected_names.append(run_manager.get_species_name(selected_team_ids[idx]))
	team_select_chosen_label.text = "Selected: %d/6\n%s" % [selected_team_ids.size(), ", ".join(selected_names)]
	team_select_start_button.disabled = selected_team_ids.size() < 2
	for key in team_select_buttons_by_id.keys():
		var dex_id: int = int(key)
		var button: Button = team_select_buttons_by_id[dex_id]
		if selected_team_ids.has(dex_id):
			button.modulate = Color(0.65, 1.0, 0.65, 1.0)
		else:
			button.modulate = Color(1, 1, 1, 1)


func _populate_switch_grid() -> void:
	for child in switch_grid.get_children():
		child.queue_free()
	switch_buttons_by_sprite_id.clear()
	var targets: Array = last_battle_state.get("switch_targets", [])
	for idx in range(targets.size()):
		var team_idx: int = int(targets[idx])
		if team_idx < 0 or team_idx >= last_team_snapshot.size():
			continue
		var mon: Dictionary = last_team_snapshot[team_idx]
		var mon_id: int = int(mon.get("id", 0))
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 90)
		button.text = "%s\nHP %d/%d" % [str(mon.get("name", "Pokemon")), int(mon.get("current_hp", 0)), int(mon.get("stats", {}).get("hp", 1))]
		button.tooltip_text = _pokemon_tooltip(mon)
		button.pressed.connect(_on_switch_target_pressed.bind(team_idx))
		switch_grid.add_child(button)
		_force_control_white(button)
		switch_buttons_by_sprite_id[mon_id] = button
		sprite_service.request_sprite(mon_id)


func _refresh_status_popup() -> void:
	if not status_popup.visible:
		return
	var state: Dictionary = run_manager.get_battle_state()
	status_text.text = "Floor: %d\nEnemy: %s HP %d/%d\nEnemy stages: %s\n\nActive: %s HP %d/%d\nYour stages: %s\n\nSwitches this floor: %d\nRuns this stretch: %d" % [
		int(state.get("floor", 0)),
		str(state.get("enemy_name", "-")),
		int(state.get("enemy_hp", 0)),
		int(state.get("enemy_hp_max", 0)),
		str(state.get("enemy_stage_text", "-")),
		str(state.get("active_name", "-")),
		int(state.get("active_hp", 0)),
		int(state.get("active_hp_max", 0)),
		str(state.get("active_stage_text", "-")),
		int(state.get("switches_used_this_floor", 0)),
		int(state.get("runs_in_current_stretch", 0))
	]


func _on_switch_target_pressed(team_idx: int) -> void:
	run_manager.switch_to_member(team_idx)


func _pokemon_tooltip(mon: Dictionary) -> String:
	var move_names: Array[String] = []
	var moves_list: Array = mon.get("moves", [])
	for idx in range(moves_list.size()):
		move_names.append(str(moves_list[idx].get("name", "Move")))
	return "%s Lv.%d\nType: %s/%s\nHP: %d/%d\nAbility: %s\nNature: %s\nMoves: %s" % [
		str(mon.get("name", "Pokemon")),
		int(mon.get("level", 1)),
		str(mon.get("types", ["", ""])[0]),
		str(mon.get("types", ["", ""])[1]),
		int(mon.get("current_hp", 0)),
		int(mon.get("stats", {}).get("hp", 0)),
		str(mon.get("ability", "Unknown")),
		str(mon.get("nature", "Unknown")),
		", ".join(move_names)
	]


func _colorize_type(type_name: String) -> String:
	return type_name


func _configure_window_behavior() -> void:
	var window: Window = get_window()
	window.unresizable = false
	window.min_size = Vector2i(1280, 720)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(1280, 720)


func _setup_settings_menu() -> void:
	settings_background_picker.clear()
	for idx in range(BG_PRESETS.size()):
		var preset: Dictionary = BG_PRESETS[idx]
		settings_background_picker.add_item(str(preset.get("name", "Preset")), idx)
	settings_music_picker.clear()
	for theme_id in range(2, 8):
		var label := "menu_theme_%d" % theme_id
		if not ResourceLoader.exists(_music_path(theme_id)):
			label += " (missing)"
		settings_music_picker.add_item(label, theme_id)


func _load_user_settings() -> void:
	var config := ConfigFile.new()
	var load_err: int = config.load(SETTINGS_PATH)
	if load_err == OK:
		selected_background_preset = int(config.get_value("ui", "background_preset", 0))
		selected_music_theme = int(config.get_value("audio", "music_theme", 2))
		music_enabled = bool(config.get_value("audio", "music_enabled", true))
	selected_background_preset = int(clamp(selected_background_preset, 0, BG_PRESETS.size() - 1))
	_apply_background_preset(selected_background_preset)
	settings_background_picker.select(selected_background_preset)
	settings_music_toggle.button_pressed = music_enabled
	var target_music_idx: int = 0
	for idx in range(settings_music_picker.item_count):
		if settings_music_picker.get_item_id(idx) == selected_music_theme:
			target_music_idx = idx
			break
	settings_music_picker.select(target_music_idx)
	_refresh_music_player()


func _save_user_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "background_preset", selected_background_preset)
	config.set_value("audio", "music_theme", selected_music_theme)
	config.set_value("audio", "music_enabled", music_enabled)
	config.save(SETTINGS_PATH)


func _apply_background_preset(preset_index: int) -> void:
	var preset: Dictionary = BG_PRESETS[preset_index]
	background_rect.color = preset.get("color", Color(0.24, 0.4, 0.52, 1.0))


func _refresh_music_player() -> void:
	if not music_enabled:
		_stop_music_players()
		return
	_play_theme(selected_music_theme, false)


func _music_path(theme_id: int) -> String:
	return "res://assets/audio/menu_theme_%d.mp3" % theme_id


func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	if not music_enabled:
		return
	if player != active_music_player:
		return
	var next_theme: int = _next_theme_id(selected_music_theme)
	selected_music_theme = next_theme
	_select_music_picker_theme(next_theme)
	_play_theme(next_theme, true)
	_save_user_settings()


func _next_theme_id(theme_id: int) -> int:
	var next_theme := theme_id + 1
	if next_theme > 7:
		next_theme = 2
	return next_theme


func _select_music_picker_theme(theme_id: int) -> void:
	for idx in range(settings_music_picker.item_count):
		if settings_music_picker.get_item_id(idx) == theme_id:
			settings_music_picker.select(idx)
			return


func _play_theme(theme_id: int, use_crossfade: bool) -> void:
	var resolved_theme: int = _resolve_available_theme(theme_id)
	if resolved_theme == -1:
		_stop_music_players()
		message_label.text = "No menu_theme_2..7 mp3 files found."
		return
	selected_music_theme = resolved_theme
	_select_music_picker_theme(resolved_theme)
	var stream: AudioStream = load(_music_path(resolved_theme)) as AudioStream
	if stream == null:
		_stop_music_players()
		message_label.text = "Failed loading music file: menu_theme_%d.mp3" % resolved_theme
		return

	if music_fade_tween != null and music_fade_tween.is_running():
		music_fade_tween.kill()
		music_fade_tween = null
	music_transitioning = false

	if use_crossfade and active_music_player.playing:
		inactive_music_player.stream = stream
		inactive_music_player.volume_db = -40.0
		inactive_music_player.play()
		music_transitioning = true
		music_fade_tween = create_tween()
		music_fade_tween.set_parallel(true)
		music_fade_tween.tween_property(active_music_player, "volume_db", -40.0, 1.0)
		music_fade_tween.tween_property(inactive_music_player, "volume_db", -10.0, 1.0)
		music_fade_tween.finished.connect(_on_music_crossfade_finished)
		return

	if use_crossfade and not active_music_player.playing:
		active_music_player.stop()
		active_music_player.stream = stream
		active_music_player.volume_db = -40.0
		active_music_player.play()
		music_transitioning = true
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(active_music_player, "volume_db", -10.0, 1.0)
		music_fade_tween.finished.connect(_on_music_fade_in_finished)
		return

	active_music_player.stop()
	active_music_player.stream = stream
	active_music_player.volume_db = -10.0
	active_music_player.play()
	inactive_music_player.stop()
	inactive_music_player.volume_db = -40.0


func _on_music_crossfade_finished() -> void:
	if not music_transitioning:
		return
	active_music_player.stop()
	active_music_player.volume_db = -40.0
	var temp: AudioStreamPlayer = active_music_player
	active_music_player = inactive_music_player
	inactive_music_player = temp
	active_music_player.volume_db = -10.0
	music_transitioning = false
	music_fade_tween = null


func _on_music_fade_in_finished() -> void:
	music_transitioning = false
	music_fade_tween = null


func _resolve_available_theme(requested_theme: int) -> int:
	var probe_theme: int = requested_theme
	for _idx in range(6):
		if ResourceLoader.exists(_music_path(probe_theme)):
			return probe_theme
		probe_theme = _next_theme_id(probe_theme)
	return -1


func _stop_music_players() -> void:
	if music_fade_tween != null and music_fade_tween.is_running():
		music_fade_tween.kill()
	music_fade_tween = null
	music_transitioning = false
	active_music_player.stop()
	inactive_music_player.stop()
	active_music_player.volume_db = -10.0
	inactive_music_player.volume_db = -40.0


func _trigger_battle_flash(flash_color: Color, peak_alpha: float, half_duration: float) -> void:
	if flash_tween != null and flash_tween.is_running():
		flash_tween.kill()
	flash_overlay.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	flash_tween = create_tween()
	flash_tween.tween_property(flash_overlay, "color:a", peak_alpha, half_duration)
	flash_tween.tween_property(flash_overlay, "color:a", 0.0, half_duration)


func _setup_move_hover_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0, 0, 0, 1)
	move_hover_panel.add_theme_stylebox_override("panel", panel_style)
	move_hover_text.add_theme_color_override("font_color", Color(0, 0, 0, 1))


func _set_bottom_panel_text_white() -> void:
	var white := Color(1, 1, 1, 1)
	var action_buttons: Array[Button] = [fight_button, switch_button, run_button, status_button, quit_button]
	for idx in range(action_buttons.size()):
		var btn: Button = action_buttons[idx]
		btn.add_theme_color_override("font_color", white)
		btn.add_theme_color_override("font_hover_color", white)
		btn.add_theme_color_override("font_pressed_color", white)
		btn.add_theme_color_override("font_disabled_color", white)
	for idx in range(move_buttons.size()):
		var move_btn: Button = move_buttons[idx]
		move_btn.add_theme_color_override("font_color", white)
		move_btn.add_theme_color_override("font_hover_color", white)
		move_btn.add_theme_color_override("font_pressed_color", white)
		move_btn.add_theme_color_override("font_disabled_color", white)


func _force_all_text_white(node: Node) -> void:
	var white := Color(1, 1, 1, 1)
	if node is Control:
		_force_control_white(node as Control)
	for child in node.get_children():
		_force_all_text_white(child)


func _force_control_white(control_node: Control) -> void:
	var white := Color(1, 1, 1, 1)
	control_node.add_theme_color_override("font_color", white)
	control_node.add_theme_color_override("font_hover_color", white)
	control_node.add_theme_color_override("font_pressed_color", white)
	control_node.add_theme_color_override("font_disabled_color", white)
	control_node.add_theme_color_override("font_focus_color", white)
	control_node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	control_node.add_theme_color_override("default_color", white)


func _plain_text(value: String) -> String:
	var regex := RegEx.new()
	var compile_err: int = regex.compile("\\[[^\\]]+\\]")
	if compile_err != OK:
		return value
	return regex.sub(value, "", true)


func _refresh_start_status() -> void:
	if run_manager.has_active_run():
		start_status_label.text = "Saved run found. Continue or start a fresh run."
		continue_button.disabled = false
	else:
		start_status_label.text = "No saved run. Start a new run."
		continue_button.disabled = true
