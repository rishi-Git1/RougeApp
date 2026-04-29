extends Control

const SETTINGS_PATH := "user://ui_settings.cfg"
const PROJECT_STATE_PATH := "user://project_mode_state.json"
const CUSTOM_BG_TEXTURE_PATH := "res://assets/backgrounds/battle_bg.png"
const LOCKED_THEME_ID := 3
const PROJECT_WORLD_SIZE := Vector2(2600, 1900)
const PROJECT_PATH_WIDTH := 42.0
const PROJECT_PLAYER_SPEED := 280.0
const PROJECT_ENCOUNTER_STEP_DISTANCE := 18.0
const PROJECT_GRASS_ENCOUNTER_CHANCE := 0.06
const PALLET_TOWN_SIZE := Vector2(760, 560)
const ROUTE_ONE_SIZE := Vector2(260, 700)
const PROJECT_STARTER_IDS: Array[int] = [1, 4, 7, 152, 155, 158, 252, 255, 258, 387, 390, 393, 495, 498, 501, 650, 653, 656, 722, 725, 728, 810, 813, 816, 906, 909, 912]
const PROJECT_MENU_PAGES: Array[String] = ["Party", "Box", "Save", "Items", "KeyItems"]
const PROJECT_LOCATION_POSITIONS := {
	"Indigo Plateau": Vector2(220, 120),
	"Victory Road": Vector2(220, 260),
	"Route 23": Vector2(220, 430),
	"Route 22": Vector2(360, 560),
	"Viridian City": Vector2(520, 300),
	"Viridian Forest": Vector2(520, 200),
	"Pewter City": Vector2(700, 300),
	"Route 3": Vector2(900, 420),
	"Mt. Moon": Vector2(1100, 420),
	"Route 4": Vector2(1300, 420),
	"Cerulean City": Vector2(1500, 420),
	"Route 24": Vector2(1500, 250),
	"Route 25": Vector2(1680, 160),
	"Bill's House": Vector2(1860, 160),
	"Route 5": Vector2(1500, 610),
	"Saffron City": Vector2(1500, 820),
	"Route 6": Vector2(1500, 1010),
	"Vermillion City": Vector2(1500, 1220),
	"Route 11": Vector2(1720, 1220),
	"Route 8": Vector2(1720, 820),
	"Lavender Town": Vector2(1940, 820),
	"Route 9": Vector2(1940, 610),
	"Rock Tunnel": Vector2(2140, 610),
	"Route 10": Vector2(2140, 820),
	"Route 12": Vector2(1940, 1080),
	"Route 13": Vector2(1820, 1290),
	"Route 14": Vector2(1650, 1380),
	"Route 15": Vector2(1450, 1380),
	"Fuschia City": Vector2(1220, 1380),
	"Route 18": Vector2(980, 1380),
	"Route 17": Vector2(980, 1180),
	"Route 16": Vector2(980, 980),
	"Celadon City": Vector2(1220, 980),
	"Route 7": Vector2(1360, 820),
	"Route 19": Vector2(1220, 1560),
	"Route 20": Vector2(1020, 1660),
	"Seafoam Islands": Vector2(760, 1760),
	"Cinnabar Island": Vector2(500, 1760),
	"Route 21": Vector2(500, 1700),
	"Pallet Town": Vector2(500, 1360),
	"Route 1": Vector2(520, 740)
}
const PROJECT_CONNECTIONS := [
	["Pallet Town", "Route 1"],
	["Pallet Town", "Route 21"],
	["Route 1", "Viridian City"],
	["Viridian City", "Viridian Forest"],
	["Viridian City", "Route 22"],
	["Viridian Forest", "Pewter City"],
	["Pewter City", "Route 3"],
	["Route 3", "Mt. Moon"],
	["Mt. Moon", "Route 4"],
	["Route 4", "Cerulean City"],
	["Cerulean City", "Route 24"],
	["Cerulean City", "Route 5"],
	["Route 24", "Route 25"],
	["Route 25", "Bill's House"],
	["Route 5", "Saffron City"],
	["Cerulean City", "Vermillion City"],
	["Saffron City", "Route 6"],
	["Saffron City", "Route 7"],
	["Saffron City", "Route 8"],
	["Route 7", "Celadon City"],
	["Celadon City", "Route 16"],
	["Route 16", "Route 17"],
	["Route 17", "Route 18"],
	["Route 18", "Fuschia City"],
	["Route 8", "Lavender Town"],
	["Lavender Town", "Route 9"],
	["Lavender Town", "Route 12"],
	["Route 9", "Rock Tunnel"],
	["Rock Tunnel", "Route 10"],
	["Route 10", "Lavender Town"],
	["Route 6", "Vermillion City"],
	["Vermillion City", "Route 11"],
	["Route 11", "Route 12"],
	["Route 12", "Route 13"],
	["Route 13", "Route 14"],
	["Route 14", "Route 15"],
	["Route 15", "Fuschia City"],
	["Fuschia City", "Route 19"],
	["Route 19", "Route 20"],
	["Route 20", "Seafoam Islands"],
	["Seafoam Islands", "Cinnabar Island"],
	["Cinnabar Island", "Route 21"],
	["Route 22", "Route 23"],
	["Route 23", "Victory Road"],
	["Victory Road", "Indigo Plateau"]
]
const BG_PRESETS := [
	{"name": "Custom PNG", "texture_path": CUSTOM_BG_TEXTURE_PATH},
	{"name": "Forest Blue", "color": Color(0.24, 0.4, 0.52, 1.0)},
	{"name": "Sky Blue", "color": Color(0.33, 0.52, 0.66, 1.0)},
	{"name": "Light Cyan", "color": Color(0.42, 0.62, 0.72, 1.0)},
	{"name": "Classic Green", "color": Color(0.23, 0.42, 0.29, 1.0)}
]

@onready var run_manager: RunManager = $RunManager
@onready var sprite_service: SpriteService = $SpriteService
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var music_player_b: AudioStreamPlayer = $MusicPlayerB

@onready var mode_select_screen: Control = $ModeSelectScreen
@onready var roguelike_mode_button: Button = $ModeSelectScreen/Panel/VBox/Buttons/RoguelikeButton
@onready var project_mode_button: Button = $ModeSelectScreen/Panel/VBox/Buttons/ProjectButton

@onready var start_screen: Control = $StartScreen
@onready var continue_button: Button = $StartScreen/Panel/VBox/Buttons/ContinueButton
@onready var new_run_button: Button = $StartScreen/Panel/VBox/Buttons/NewRunButton
@onready var start_status_label: Label = $StartScreen/Panel/VBox/StatusLabel
@onready var project_screen: Control = $ProjectScreen
@onready var project_map_area: Control = $ProjectScreen/Panel/VBox/MapFrame/MapArea
@onready var project_player_rect: ColorRect = $ProjectScreen/Panel/VBox/MapFrame/MapArea/PlayerRect
@onready var project_back_button: Button = $ProjectScreen/Panel/VBox/BackButton

@onready var team_select_screen: Control = $TeamSelectScreen
@onready var team_select_scroll: ScrollContainer = $TeamSelectScreen/Margin/VBox/Scroll
@onready var team_select_grid: GridContainer = $TeamSelectScreen/Margin/VBox/Scroll/Grid
@onready var team_select_chosen_label: Label = $TeamSelectScreen/Margin/VBox/ChosenLabel
@onready var team_select_start_button: Button = $TeamSelectScreen/Margin/VBox/Buttons/StartButton
@onready var team_select_cancel_button: Button = $TeamSelectScreen/Margin/VBox/Buttons/CancelButton

@onready var switch_screen: Control = $SwitchScreen
@onready var switch_grid: GridContainer = $SwitchScreen/Margin/VBox/Scroll/Grid
@onready var switch_cancel_button: Button = $SwitchScreen/Margin/VBox/Buttons/CancelButton

@onready var battle_root: Control = $BattleRoot
@onready var background_rect: ColorRect = $BattleRoot/Background
@onready var background_image: TextureRect = $BattleRoot/BackgroundImage
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
@onready var enemy_status_panel: PanelContainer = $BattleRoot/EnemyStatus
@onready var player_status: RichTextLabel = $BattleRoot/PlayerStatus/VBox/Info
@onready var player_hp: ProgressBar = $BattleRoot/PlayerStatus/VBox/HP
@onready var player_stages: Label = $BattleRoot/PlayerStatus/VBox/Stages
@onready var player_status_panel: PanelContainer = $BattleRoot/PlayerStatus

@onready var message_label: RichTextLabel = $BattleRoot/BottomBar/VBox/Message
@onready var message_timer: Timer = $BattleRoot/BottomBar/VBox/MessageTimer
@onready var fight_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Fight
@onready var switch_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Switch
@onready var run_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Run
@onready var status_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Status
@onready var quit_button: Button = $BattleRoot/BottomBar/VBox/ActionButtons/Quit
@onready var action_buttons_row: HBoxContainer = $BattleRoot/BottomBar/VBox/ActionButtons
@onready var move_grid: GridContainer = $BattleRoot/BottomBar/VBox/MoveGrid
@onready var move_back_button: Button = $BattleRoot/BottomBar/VBox/MoveBackButton
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
var hp_tween: Tween
var pending_unlock_sprite_id: int = 0
var move_hover_details: Array[String] = []
var battle_message_queue: Array[String] = []
var last_battle_log_lines: Array[String] = []
var current_game_mode: String = "roguelike"
var project_player_step: float = 16.0
var encounter_database: RefCounted
var project_world: Control
var project_interior_root: Control
var project_walkable_rects: Array[Rect2] = []
var project_blocked_rects: Array[Rect2] = []
var project_one_way_ledge_rects: Array[Rect2] = []
var project_route_one_grass_rects: Array[Rect2] = []
var project_location_centers: Dictionary = {}
var project_overworld_doors: Array[Dictionary] = []
var project_current_interior: String = ""
var project_return_overworld_pos: Vector2 = Vector2.ZERO
var project_interior_bounds: Rect2 = Rect2()
var project_interior_exit_rect: Rect2 = Rect2()
var project_door_cooldown: float = 0.0
var project_npcs: Array[Dictionary] = []
var project_dialog_overlay: Control
var project_dialog_label: Label
var project_dialog_lines: Array[String] = []
var project_dialog_index: int = 0
var project_dialog_completion_action: String = ""
var project_starter_overlay: Control
var project_starter_grid: GridContainer
var project_story_stage: String = "none"
var project_player_starter_id: int = 0
var project_rival_battle_completed: bool = false
var project_battle_return_context: String = ""
var project_step_distance_accum: float = 0.0
var project_menu_overlay: Control
var project_menu_content_label: Label
var project_menu_buttons_by_page: Dictionary = {}
var project_menu_current_page: String = "Party"
var project_menu_save_button: Button
var project_menu_clear_button: Button
var project_menu_save_status_label: Label
var project_menu_party_scroll: ScrollContainer
var project_menu_party_list: VBoxContainer
var project_menu_detail_overlay: Control
var project_menu_detail_label: Label
var battle_end_overlay: Control
var battle_end_label: Label
var pending_battle_end_action: String = ""
var music_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var project_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	music_rng.randomize()
	project_rng.randomize()
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
	_setup_move_hover_panel_style()
	_apply_pretty_styles()
	encounter_database = (load("res://scripts/managers/EncounterDatabase.gd") as GDScript).new()
	encounter_database.load_database(run_manager.factory.pokedex)
	_build_project_story_ui()
	_build_project_menu_ui()
	_build_battle_end_ui()
	_build_project_world()

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
	run_manager.single_battle_finished.connect(_on_single_battle_finished)

	sprite_service.sprite_ready.connect(_on_front_sprite_ready)
	sprite_service.back_sprite_ready.connect(_on_back_sprite_ready)

	continue_button.pressed.connect(_on_continue_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	roguelike_mode_button.pressed.connect(_on_mode_roguelike_pressed)
	project_mode_button.pressed.connect(_on_mode_project_pressed)
	project_back_button.pressed.connect(_on_project_back_pressed)
	team_select_start_button.pressed.connect(_on_team_select_start_pressed)
	team_select_cancel_button.pressed.connect(_on_team_select_cancel_pressed)
	team_select_scroll.resized.connect(_update_team_select_grid_columns)
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
	move_back_button.pressed.connect(_on_move_back_pressed)
	message_timer.timeout.connect(_on_message_timer_timeout)

	_show_only_screen("mode_select")
	_refresh_start_status()
	call_deferred("_configure_team_select_scroll_behavior")


func _show_only_screen(mode: String) -> void:
	mode_select_screen.visible = mode == "mode_select"
	start_screen.visible = mode == "start"
	project_screen.visible = mode == "project"
	team_select_screen.visible = mode == "team_select"
	switch_screen.visible = mode == "switch"
	battle_root.visible = mode == "battle"
	var roguelike_battle: bool = mode == "battle" and current_game_mode == "roguelike"
	floor_label.visible = roguelike_battle
	settings_button.visible = roguelike_battle
	if not roguelike_battle:
		settings_screen.visible = false
	if mode != "battle":
		settings_screen.visible = false


func _on_mode_roguelike_pressed() -> void:
	current_game_mode = "roguelike"
	battle_message_queue.clear()
	last_battle_log_lines.clear()
	_show_only_screen("start")
	_refresh_start_status()
	run_manager.emit_current_state()


func _on_mode_project_pressed() -> void:
	current_game_mode = "project"
	battle_message_queue.clear()
	last_battle_log_lines.clear()
	_show_only_screen("project")
	if not _load_project_mode_state():
		project_story_stage = "lab_intro"
		project_player_starter_id = 0
		project_rival_battle_completed = false
		_reset_project_player_position()
		project_return_overworld_pos = _overworld_return_for_interior("player_house")
		_enter_project_interior("player_house")
		project_door_cooldown = 0.35
	if encounter_database != null and encounter_database.is_loaded():
		var total_slots: int = encounter_database.get_location_methods().size()
		$ProjectScreen/Panel/VBox/Message.text = "Prototype map view (Pokemon Red style).\nMove with Arrow Keys or WASD.\nPress E to interact with doors.\nEncounter slots loaded: %d" % total_slots


func _on_project_back_pressed() -> void:
	_close_project_dialog()
	_hide_project_starter_select()
	_hide_project_menu()
	_show_only_screen("mode_select")


func _process(delta: float) -> void:
	if not project_screen.visible:
		return
	if _project_menu_is_open():
		return
	project_door_cooldown = max(0.0, project_door_cooldown - delta)
	var direction: Vector2 = _project_input_direction()
	if direction != Vector2.ZERO:
		_move_project_player(direction.normalized() * PROJECT_PLAYER_SPEED * delta)
	_update_project_camera()


func _unhandled_input(event: InputEvent) -> void:
	if battle_end_overlay != null and battle_end_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E:
				_on_battle_end_continue_pressed()
				get_viewport().set_input_as_handled()
		return
	if not project_screen.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_toggle_project_menu()
		get_viewport().set_input_as_handled()
		return
	if _project_menu_is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _project_dialog_is_open():
			_advance_project_dialog()
		elif project_starter_overlay != null and project_starter_overlay.visible:
			pass
		else:
			_try_project_interact()
		get_viewport().set_input_as_handled()


func _move_project_player(delta: Vector2) -> void:
	var start_pos: Vector2 = project_player_rect.position
	var next_pos: Vector2 = project_player_rect.position + delta
	var next_rect: Rect2 = Rect2(next_pos, project_player_rect.size)
	var current_center: Vector2 = project_player_rect.position + (project_player_rect.size * 0.5)
	var next_center: Vector2 = next_pos + (project_player_rect.size * 0.5)
	if _is_project_rect_walkable(next_rect) and _can_cross_one_way_ledges(current_center, next_center):
		project_player_rect.position = next_pos
		return
	var split_x_pos: Vector2 = Vector2(next_pos.x, project_player_rect.position.y)
	var split_x_rect: Rect2 = Rect2(split_x_pos, project_player_rect.size)
	var split_x_center: Vector2 = split_x_pos + (project_player_rect.size * 0.5)
	if _is_project_rect_walkable(split_x_rect) and _can_cross_one_way_ledges(current_center, split_x_center):
		project_player_rect.position.x = split_x_pos.x
	var split_y_pos: Vector2 = Vector2(project_player_rect.position.x, next_pos.y)
	var split_y_rect: Rect2 = Rect2(split_y_pos, project_player_rect.size)
	var split_y_center: Vector2 = split_y_pos + (project_player_rect.size * 0.5)
	var updated_center: Vector2 = project_player_rect.position + (project_player_rect.size * 0.5)
	if _is_project_rect_walkable(split_y_rect) and _can_cross_one_way_ledges(updated_center, split_y_center):
		project_player_rect.position.y = split_y_pos.y
	var moved_distance: float = start_pos.distance_to(project_player_rect.position)
	if moved_distance > 0.0:
		_maybe_trigger_project_grass_encounter(moved_distance)


func _reset_project_player_position() -> void:
	if project_location_centers.has("Pallet Town"):
		var center: Vector2 = project_location_centers["Pallet Town"]
		project_player_rect.position = center - (project_player_rect.size * 0.5)
	else:
		project_player_rect.position = Vector2(16, 16)
	_update_project_camera()


func _project_input_direction() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		y += 1.0
	return Vector2(x, y)


func _build_project_world() -> void:
	project_map_area.clip_contents = true
	project_walkable_rects.clear()
	project_blocked_rects.clear()
	project_one_way_ledge_rects.clear()
	project_route_one_grass_rects.clear()
	project_location_centers.clear()
	project_overworld_doors.clear()
	project_current_interior = ""
	project_door_cooldown = 0.0
	project_step_distance_accum = 0.0
	project_world = Control.new()
	project_world.name = "GeneratedWorld"
	project_world.custom_minimum_size = PROJECT_WORLD_SIZE
	project_world.size = PROJECT_WORLD_SIZE
	project_map_area.add_child(project_world)
	project_map_area.move_child(project_world, project_map_area.get_child_count() - 1)
	project_interior_root = Control.new()
	project_interior_root.name = "ProjectInterior"
	project_interior_root.visible = false
	project_interior_root.anchors_preset = Control.PRESET_FULL_RECT
	project_interior_root.anchor_right = 1.0
	project_interior_root.anchor_bottom = 1.0
	project_map_area.add_child(project_interior_root)
	project_map_area.move_child(project_interior_root, project_map_area.get_child_count() - 1)
	_reparent_project_player()
	_add_project_background()
	_add_project_paths()
	_add_project_locations()
	_reset_project_player_position()


func _reparent_project_player() -> void:
	var old_parent: Node = project_player_rect.get_parent()
	if old_parent != project_world:
		old_parent.remove_child(project_player_rect)
		project_world.add_child(project_player_rect)
	project_player_rect.size = Vector2(18, 18)
	project_player_rect.color = Color(0, 0, 0, 1)


func _add_project_background() -> void:
	var bg := ColorRect.new()
	bg.name = "WorldBackground"
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.color = Color(0.05, 0.05, 0.05, 1.0)
	project_world.add_child(bg)
	project_world.move_child(bg, 0)


func _add_project_paths() -> void:
	for idx in range(PROJECT_CONNECTIONS.size()):
		var pair: Array = PROJECT_CONNECTIONS[idx]
		var a_name: String = str(pair[0])
		var b_name: String = str(pair[1])
		if not PROJECT_LOCATION_POSITIONS.has(a_name) or not PROJECT_LOCATION_POSITIONS.has(b_name):
			continue
		var a: Vector2 = PROJECT_LOCATION_POSITIONS[a_name]
		var b: Vector2 = PROJECT_LOCATION_POSITIONS[b_name]
		var corner: Vector2 = Vector2(b.x, a.y)
		_add_path_segment(a, corner)
		_add_path_segment(corner, b)


func _add_path_segment(start_pos: Vector2, end_pos: Vector2) -> void:
	if start_pos.distance_to(end_pos) < 1.0:
		return
	var horizontal: bool = abs(start_pos.x - end_pos.x) >= abs(start_pos.y - end_pos.y)
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 1)
	if horizontal:
		var left: float = min(start_pos.x, end_pos.x)
		rect.position = Vector2(left, start_pos.y - PROJECT_PATH_WIDTH * 0.5)
		rect.size = Vector2(abs(end_pos.x - start_pos.x), PROJECT_PATH_WIDTH)
	else:
		var top: float = min(start_pos.y, end_pos.y)
		rect.position = Vector2(start_pos.x - PROJECT_PATH_WIDTH * 0.5, top)
		rect.size = Vector2(PROJECT_PATH_WIDTH, abs(end_pos.y - start_pos.y))
	project_world.add_child(rect)
	project_walkable_rects.append(Rect2(rect.position, rect.size))


func _add_project_locations() -> void:
	for location_name in PROJECT_LOCATION_POSITIONS.keys():
		var center: Vector2 = PROJECT_LOCATION_POSITIONS[location_name]
		project_location_centers[location_name] = center
		if location_name == "Pallet Town":
			_add_pallet_town_layout(center)
			continue
		if location_name == "Route 1":
			_add_route_one_layout(center)
			continue
		var location_size: Vector2 = _project_location_size(location_name)
		var panel := Panel.new()
		panel.position = center - location_size * 0.5
		panel.size = location_size
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 1)
		style.border_color = Color(0, 0, 0, 1)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		panel.add_theme_stylebox_override("panel", style)
		project_world.add_child(panel)
		project_walkable_rects.append(Rect2(panel.position, panel.size))
		if _is_town_like_location(location_name):
			var label := Label.new()
			label.text = location_name
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.position = panel.position
			label.size = panel.size
			label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
			project_world.add_child(label)
	project_world.move_child(project_player_rect, project_world.get_child_count() - 1)


func _project_location_size(location_name: String) -> Vector2:
	if location_name == "Pallet Town":
		return PALLET_TOWN_SIZE
	if _is_town_like_location(location_name):
		return Vector2(170, 102)
	if location_name.find("Route") != -1:
		return Vector2(84, 56)
	return Vector2(128, 80)


func _is_town_like_location(location_name: String) -> bool:
	return location_name.find("City") != -1 or location_name.find("Town") != -1 or location_name.find("Plateau") != -1 or location_name.find("House") != -1 or location_name.find("Island") != -1


func _is_project_walkable(world_point: Vector2) -> bool:
	if not project_current_interior.is_empty():
		return project_interior_bounds.has_point(world_point)
	if world_point.x < 1.0 or world_point.y < 1.0:
		return false
	if world_point.x > PROJECT_WORLD_SIZE.x - 1.0 or world_point.y > PROJECT_WORLD_SIZE.y - 1.0:
		return false
	if not _is_route_one_unlocked() and _route_one_gate_rect().has_point(world_point):
		return false
	for idx in range(project_blocked_rects.size()):
		var blocked: Rect2 = project_blocked_rects[idx]
		if blocked.has_point(world_point):
			return false
	for idx in range(project_walkable_rects.size()):
		var rect: Rect2 = project_walkable_rects[idx]
		if rect.has_point(world_point):
			return true
	return false


func _is_project_rect_walkable(world_rect: Rect2) -> bool:
	if not project_current_interior.is_empty():
		return project_interior_bounds.encloses(world_rect)
	var world_bounds: Rect2 = Rect2(Vector2.ZERO, PROJECT_WORLD_SIZE)
	if not world_bounds.encloses(world_rect):
		return false
	if not _is_route_one_unlocked() and world_rect.intersects(_route_one_gate_rect()):
		return false
	for idx in range(project_blocked_rects.size()):
		var blocked: Rect2 = project_blocked_rects[idx]
		if blocked.intersects(world_rect):
			return false
	var corners: Array[Vector2] = [
		world_rect.position + Vector2(1, 1),
		world_rect.position + Vector2(world_rect.size.x - 1, 1),
		world_rect.position + Vector2(1, world_rect.size.y - 1),
		world_rect.position + Vector2(world_rect.size.x - 1, world_rect.size.y - 1)
	]
	for corner_idx in range(corners.size()):
		var corner: Vector2 = corners[corner_idx]
		if not _is_project_walkable(corner):
			return false
	return true


func _update_project_camera() -> void:
	if project_world == null:
		return
	if not project_current_interior.is_empty():
		return
	var player_center: Vector2 = project_player_rect.position + project_player_rect.size * 0.5
	var viewport_center: Vector2 = project_map_area.size * 0.5
	var target: Vector2 = viewport_center - player_center
	var min_x: float = min(0.0, project_map_area.size.x - PROJECT_WORLD_SIZE.x)
	var min_y: float = min(0.0, project_map_area.size.y - PROJECT_WORLD_SIZE.y)
	target.x = clamp(target.x, min_x, 0.0)
	target.y = clamp(target.y, min_y, 0.0)
	project_world.position = target


func _add_pallet_town_layout(center: Vector2) -> void:
	var town_size: Vector2 = PALLET_TOWN_SIZE
	var top_left: Vector2 = center - town_size * 0.5
	var town_panel := Panel.new()
	town_panel.position = top_left
	town_panel.size = town_size
	var town_style := StyleBoxFlat.new()
	town_style.bg_color = Color(1, 1, 1, 1)
	town_style.border_color = Color(0, 0, 0, 1)
	town_style.border_width_left = 4
	town_style.border_width_top = 4
	town_style.border_width_right = 4
	town_style.border_width_bottom = 4
	town_panel.add_theme_stylebox_override("panel", town_style)
	project_world.add_child(town_panel)
	project_walkable_rects.append(Rect2(town_panel.position, town_panel.size))

	var pond := ColorRect.new()
	pond.position = top_left + Vector2(72, 360)
	pond.size = Vector2(170, 130)
	pond.color = Color(0.9, 0.9, 0.9, 1.0)
	project_world.add_child(pond)
	project_blocked_rects.append(Rect2(pond.position, pond.size).grow(2))

	var house_rect: Rect2 = Rect2(top_left + Vector2(120, 190), Vector2(170, 130))
	var lab_rect: Rect2 = Rect2(top_left + Vector2(430, 170), Vector2(240, 150))
	_add_project_building(house_rect, "Our House")
	_add_project_building(lab_rect, "Oak Lab")

	var house_door: Rect2 = Rect2(Vector2(house_rect.position.x + house_rect.size.x * 0.5 - 10, house_rect.position.y + house_rect.size.y - 12), Vector2(20, 12))
	var lab_door: Rect2 = Rect2(Vector2(lab_rect.position.x + lab_rect.size.x * 0.5 - 10, lab_rect.position.y + lab_rect.size.y - 12), Vector2(20, 12))
	_add_door_marker(house_door)
	_add_door_marker(lab_door)
	_add_building_collision(house_rect, house_door)
	_add_building_collision(lab_rect, lab_door)
	project_overworld_doors.append({"rect": house_door, "interior": "player_house", "return_pos": house_door.position + Vector2(2, 22)})
	project_overworld_doors.append({"rect": lab_door, "interior": "oak_lab", "return_pos": lab_door.position + Vector2(2, 22)})

	var town_label := Label.new()
	town_label.text = "Pallet Town"
	town_label.position = top_left + Vector2(20, 18)
	town_label.size = Vector2(280, 42)
	town_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	town_label.add_theme_font_size_override("font_size", 28)
	project_world.add_child(town_label)


func _add_project_building(rect: Rect2, label_text: String) -> void:
	var building := Panel.new()
	building.position = rect.position
	building.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1.0)
	style.border_color = Color(0, 0, 0, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	building.add_theme_stylebox_override("panel", style)
	project_world.add_child(building)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.position = rect.position + Vector2(12, 10)
	name_label.size = Vector2(rect.size.x - 24, 26)
	name_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	project_world.add_child(name_label)
	project_walkable_rects.append(rect)


func _add_door_marker(door_rect: Rect2) -> void:
	var door := ColorRect.new()
	door.position = door_rect.position
	door.size = door_rect.size
	door.color = Color(0, 0, 0, 1)
	project_world.add_child(door)


func _add_building_collision(building_rect: Rect2, door_rect: Rect2) -> void:
	# Block building footprint except the door opening.
	var top_height: float = max(0.0, door_rect.position.y - building_rect.position.y)
	if top_height > 0.0:
		project_blocked_rects.append(Rect2(building_rect.position, Vector2(building_rect.size.x, top_height)))
	var bottom_y: float = door_rect.position.y + door_rect.size.y
	var bottom_height: float = (building_rect.position.y + building_rect.size.y) - bottom_y
	if bottom_height > 0.0:
		project_blocked_rects.append(Rect2(Vector2(building_rect.position.x, bottom_y), Vector2(building_rect.size.x, bottom_height)))
	var left_width: float = max(0.0, door_rect.position.x - building_rect.position.x)
	if left_width > 0.0:
		project_blocked_rects.append(Rect2(Vector2(building_rect.position.x, door_rect.position.y), Vector2(left_width, door_rect.size.y)))
	var right_x: float = door_rect.position.x + door_rect.size.x
	var right_width: float = (building_rect.position.x + building_rect.size.x) - right_x
	if right_width > 0.0:
		project_blocked_rects.append(Rect2(Vector2(right_x, door_rect.position.y), Vector2(right_width, door_rect.size.y)))


func _add_route_one_layout(center: Vector2) -> void:
	var route_size: Vector2 = ROUTE_ONE_SIZE
	var top_left: Vector2 = center - route_size * 0.5
	var route_panel := Panel.new()
	route_panel.position = top_left
	route_panel.size = route_size
	var route_style := StyleBoxFlat.new()
	route_style.bg_color = Color(0.79, 0.86, 0.74, 1.0)
	route_style.border_color = Color(0, 0, 0, 1)
	route_style.border_width_left = 4
	route_style.border_width_top = 4
	route_style.border_width_right = 4
	route_style.border_width_bottom = 4
	route_panel.add_theme_stylebox_override("panel", route_style)
	project_world.add_child(route_panel)
	project_walkable_rects.append(Rect2(route_panel.position, route_panel.size).grow(6))

	var path_color := Color(0.9, 0.88, 0.78, 1.0)
	_add_route_one_decor(Rect2(top_left + Vector2(route_size.x * 0.5 - 28, 22), Vector2(56, route_size.y - 44)), path_color)

	var grass_color := Color(0.12, 0.36, 0.14, 1.0)
	_add_route_one_grass(Rect2(top_left + Vector2(24, 108), Vector2(84, 118)), grass_color)
	_add_route_one_grass(Rect2(top_left + Vector2(152, 122), Vector2(82, 112)), grass_color)
	_add_route_one_grass(Rect2(top_left + Vector2(22, 296), Vector2(86, 110)), grass_color)
	_add_route_one_grass(Rect2(top_left + Vector2(150, 318), Vector2(84, 104)), grass_color)
	_add_route_one_grass(Rect2(top_left + Vector2(22, 486), Vector2(90, 122)), grass_color)
	_add_route_one_grass(Rect2(top_left + Vector2(150, 512), Vector2(84, 112)), grass_color)

	var label := Label.new()
	label.text = "Route 1"
	label.position = top_left + Vector2(12, 10)
	label.size = Vector2(130, 28)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	project_world.add_child(label)


func _add_route_one_grass(rect: Rect2, color: Color) -> void:
	var grass := ColorRect.new()
	grass.position = rect.position
	grass.size = rect.size
	grass.color = color
	project_world.add_child(grass)
	project_route_one_grass_rects.append(rect)


func _add_route_one_decor(rect: Rect2, color: Color) -> void:
	var deco := ColorRect.new()
	deco.position = rect.position
	deco.size = rect.size
	deco.color = color
	project_world.add_child(deco)


func _add_route_one_barrier(rect: Rect2, color: Color) -> void:
	var barrier := ColorRect.new()
	barrier.position = rect.position
	barrier.size = rect.size
	barrier.color = color
	project_world.add_child(barrier)
	project_blocked_rects.append(rect)


func _add_route_one_ledge(rect: Rect2) -> void:
	var ledge := ColorRect.new()
	ledge.position = rect.position
	ledge.size = rect.size
	ledge.color = Color(0.12, 0.12, 0.12, 1.0)
	project_world.add_child(ledge)
	project_one_way_ledge_rects.append(rect)


func _can_cross_one_way_ledges(from_center: Vector2, to_center: Vector2) -> bool:
	if not project_current_interior.is_empty():
		return true
	for idx in range(project_one_way_ledge_rects.size()):
		var ledge: Rect2 = project_one_way_ledge_rects[idx]
		var min_x: float = ledge.position.x
		var max_x: float = ledge.position.x + ledge.size.x
		if max(from_center.x, to_center.x) < min_x or min(from_center.x, to_center.x) > max_x:
			continue
		var ledge_y: float = ledge.position.y + ledge.size.y * 0.5
		var crosses_up: bool = from_center.y >= ledge_y and to_center.y < ledge_y
		if crosses_up:
			return false
	return true


func _route_one_gate_rect() -> Rect2:
	var route_center: Vector2 = PROJECT_LOCATION_POSITIONS.get("Route 1", Vector2.ZERO)
	var top_left: Vector2 = route_center - (ROUTE_ONE_SIZE * 0.5)
	return Rect2(top_left + Vector2(0, ROUTE_ONE_SIZE.y - 24), Vector2(ROUTE_ONE_SIZE.x, 24))


func _is_route_one_unlocked() -> bool:
	return project_rival_battle_completed


func _is_player_in_route_one_grass() -> bool:
	if not project_current_interior.is_empty():
		return false
	var player_rect: Rect2 = Rect2(project_player_rect.position, project_player_rect.size)
	for idx in range(project_route_one_grass_rects.size()):
		var grass_rect: Rect2 = project_route_one_grass_rects[idx]
		if player_rect.intersects(grass_rect):
			return true
	return false


func _project_living_party_snapshot() -> Array:
	var team: Array = run_manager.get_active_team_snapshot()
	var living: Array = []
	for idx in range(team.size()):
		var mon_value = team[idx]
		if typeof(mon_value) != TYPE_DICTIONARY:
			continue
		var mon: Dictionary = mon_value
		if int(mon.get("current_hp", 0)) <= 0:
			continue
		living.append(mon.duplicate(true))
	return living


func _maybe_trigger_project_grass_encounter(moved_distance: float) -> void:
	if not _is_route_one_unlocked():
		return
	if not _is_player_in_route_one_grass():
		project_step_distance_accum = 0.0
		return
	if encounter_database == null or not encounter_database.is_loaded():
		return
	project_step_distance_accum += moved_distance
	while project_step_distance_accum >= PROJECT_ENCOUNTER_STEP_DISTANCE:
		project_step_distance_accum -= PROJECT_ENCOUNTER_STEP_DISTANCE
		if project_rng.randf() > PROJECT_GRASS_ENCOUNTER_CHANCE:
			continue
		var encounter: Dictionary = encounter_database.roll_encounter("Route 1", "Grass")
		var species_id: int = int(encounter.get("pokedex_id", 0))
		if species_id <= 0:
			continue
		var party: Array = _project_living_party_snapshot()
		if party.is_empty():
			return
		var lead_level: int = int((party[0] as Dictionary).get("level", 5))
		var wild_level: int = clamp(lead_level, 2, 100)
		var enemy_mon: Dictionary = run_manager.factory.build_randomized_pokemon(species_id, wild_level)
		if enemy_mon.is_empty():
			return
		enemy_mon["trainer_owned"] = false
		project_battle_return_context = "overworld"
		project_step_distance_accum = 0.0
		run_manager.start_single_battle(party, enemy_mon, false, "A wild %s appeared!" % str(enemy_mon.get("name", "Pokemon")))
		_show_only_screen("battle")
		return


func _try_project_interact() -> void:
	if project_door_cooldown > 0.0:
		return
	if _try_project_story_interact():
		return
	var player_rect: Rect2 = Rect2(project_player_rect.position, project_player_rect.size)
	if project_current_interior.is_empty():
		for idx in range(project_overworld_doors.size()):
			var door: Dictionary = project_overworld_doors[idx]
			var door_rect: Rect2 = door.get("rect", Rect2())
			var interact_rect: Rect2 = _door_interact_rect(door_rect)
			if player_rect.intersects(interact_rect):
				project_return_overworld_pos = Vector2(door.get("return_pos", project_player_rect.position))
				_enter_project_interior(str(door.get("interior", "")))
				project_door_cooldown = 0.45
				return
	else:
		var exit_interact_rect: Rect2 = _door_interact_rect(project_interior_exit_rect)
		if player_rect.intersects(exit_interact_rect):
			_exit_project_interior()
			project_door_cooldown = 0.45


func _door_interact_rect(door_rect: Rect2) -> Rect2:
	# Larger invisible interaction zone while keeping the visible door marker unchanged.
	return door_rect.grow_individual(12.0, 20.0, 12.0, 8.0)


func _try_project_story_interact() -> bool:
	if project_current_interior != "oak_lab" and project_current_interior != "player_house":
		return false
	var player_rect: Rect2 = Rect2(project_player_rect.position, project_player_rect.size)
	for idx in range(project_npcs.size()):
		var npc: Dictionary = project_npcs[idx]
		var npc_rect: Rect2 = npc.get("rect", Rect2())
		if not player_rect.grow(18).intersects(npc_rect):
			continue
		var role: String = str(npc.get("role", ""))
		if role == "oak" and project_current_interior == "oak_lab" and project_story_stage == "lab_intro":
			_begin_project_dialog(["What starter would you like?"], "open_starter_select")
			project_story_stage = "starter_prompted"
			return true
		if role == "rival" and project_current_interior == "oak_lab" and project_story_stage == "starter_chosen":
			_begin_project_dialog(["You have a Pokemon? Let's Batttle!"], "start_rival_battle")
			project_story_stage = "rival_challenge"
			return true
		if role == "mom" and project_current_interior == "player_house" and project_rival_battle_completed:
			_begin_project_dialog(["Good job son, you should rest here for the night"], "mom_heal")
			return true
	return false


func _overworld_return_for_interior(interior_id: String) -> Vector2:
	for idx in range(project_overworld_doors.size()):
		var door: Dictionary = project_overworld_doors[idx]
		if str(door.get("interior", "")) == interior_id:
			return Vector2(door.get("return_pos", Vector2.ZERO))
	return project_player_rect.position


func _enter_project_interior(interior_id: String) -> void:
	project_current_interior = interior_id
	project_npcs.clear()
	project_world.visible = false
	project_interior_root.visible = true
	var old_parent: Node = project_player_rect.get_parent()
	if old_parent != project_interior_root:
		old_parent.remove_child(project_player_rect)
		project_interior_root.add_child(project_player_rect)
	_build_project_interior(interior_id)
	var spawn: Vector2 = project_interior_exit_rect.position + Vector2(1, -52)
	project_player_rect.position = spawn


func _exit_project_interior() -> void:
	project_current_interior = ""
	var old_parent: Node = project_player_rect.get_parent()
	if old_parent != project_world:
		old_parent.remove_child(project_player_rect)
		project_world.add_child(project_player_rect)
	project_world.visible = true
	project_interior_root.visible = false
	project_player_rect.position = project_return_overworld_pos
	_update_project_camera()


func _build_project_interior(interior_id: String) -> void:
	for child in project_interior_root.get_children():
		if child != project_player_rect:
			child.queue_free()
	var room := Panel.new()
	var room_size: Vector2 = Vector2(project_map_area.size.x - 120, project_map_area.size.y - 110)
	room.position = Vector2(60, 45)
	room.size = room_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_color = Color(0, 0, 0, 1)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	room.add_theme_stylebox_override("panel", style)
	project_interior_root.add_child(room)
	project_interior_bounds = Rect2(room.position + Vector2(10, 10), room.size - Vector2(20, 20))

	var title := Label.new()
	title.text = "Oak's Lab"
	if interior_id == "player_house":
		title.text = "Your House"
	title.position = room.position + Vector2(16, 10)
	title.size = Vector2(260, 40)
	title.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	title.add_theme_font_size_override("font_size", 26)
	project_interior_root.add_child(title)

	if interior_id == "player_house":
		_add_player_house_layout(room.position, room.size)
		if project_rival_battle_completed:
			_add_house_mom_npc(room.position)
	else:
		_add_oak_lab_layout(room.position, room.size)
		_add_lab_story_npcs(room.position)

	project_interior_exit_rect = Rect2(Vector2(room.position.x + room.size.x * 0.5 - 10, room.position.y + room.size.y - 14), Vector2(20, 12))
	var exit_marker := ColorRect.new()
	exit_marker.position = project_interior_exit_rect.position
	exit_marker.size = project_interior_exit_rect.size
	exit_marker.color = Color(0, 0, 0, 1)
	project_interior_root.add_child(exit_marker)
	project_interior_root.move_child(project_player_rect, project_interior_root.get_child_count() - 1)


func _add_lab_story_npcs(room_pos: Vector2) -> void:
	var oak_rect: Rect2 = Rect2(room_pos + Vector2(420, 92), Vector2(22, 22))
	var rival_rect: Rect2 = Rect2(room_pos + Vector2(458, 92), Vector2(22, 22))
	var oak := ColorRect.new()
	oak.position = oak_rect.position
	oak.size = oak_rect.size
	oak.color = Color(0.95, 0.85, 0.2, 1.0)
	project_interior_root.add_child(oak)
	var rival := ColorRect.new()
	rival.position = rival_rect.position
	rival.size = rival_rect.size
	rival.color = Color(0.9, 0.2, 0.2, 1.0)
	project_interior_root.add_child(rival)
	project_npcs.append({"role": "oak", "rect": oak_rect})
	project_npcs.append({"role": "rival", "rect": rival_rect})


func _add_house_mom_npc(room_pos: Vector2) -> void:
	var mom_rect: Rect2 = Rect2(room_pos + Vector2(320, 130), Vector2(22, 22))
	var mom := ColorRect.new()
	mom.position = mom_rect.position
	mom.size = mom_rect.size
	mom.color = Color(0.95, 0.85, 0.2, 1.0)
	project_interior_root.add_child(mom)
	project_npcs.append({"role": "mom", "rect": mom_rect})


func _add_player_house_layout(room_pos: Vector2, room_size: Vector2) -> void:
	# Indoor-only props: bed, table, and cabinet.
	_add_interior_furniture(room_pos + Vector2(80, 96), Vector2(170, 74))
	_add_interior_furniture(room_pos + Vector2(room_size.x - 260, 92), Vector2(180, 64))
	_add_interior_furniture(room_pos + Vector2(room_size.x - 190, room_size.y - 130), Vector2(100, 56))


func _add_oak_lab_layout(room_pos: Vector2, room_size: Vector2) -> void:
	# Lab shelves and center table; kept fully inside room bounds.
	_add_interior_furniture(room_pos + Vector2(70, room_size.y - 132), Vector2(220, 70))
	_add_interior_furniture(room_pos + Vector2(room_size.x - 290, room_size.y - 132), Vector2(220, 70))
	_add_interior_furniture(room_pos + Vector2(room_size.x * 0.5 - 95, 120), Vector2(190, 82))


func _add_interior_furniture(pos: Vector2, size: Vector2) -> void:
	var block := ColorRect.new()
	block.position = pos
	block.size = size
	block.color = Color(0.85, 0.85, 0.85, 1)
	project_interior_root.add_child(block)


func _build_project_story_ui() -> void:
	project_dialog_overlay = Control.new()
	project_dialog_overlay.visible = false
	project_dialog_overlay.anchors_preset = Control.PRESET_FULL_RECT
	project_dialog_overlay.anchor_right = 1.0
	project_dialog_overlay.anchor_bottom = 1.0
	project_screen.add_child(project_dialog_overlay)
	var dialog_panel := PanelContainer.new()
	dialog_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	dialog_panel.anchor_top = 1.0
	dialog_panel.anchor_right = 1.0
	dialog_panel.anchor_bottom = 1.0
	dialog_panel.offset_left = 24.0
	dialog_panel.offset_top = -170.0
	dialog_panel.offset_right = -24.0
	dialog_panel.offset_bottom = -24.0
	project_dialog_overlay.add_child(dialog_panel)
	project_dialog_label = Label.new()
	project_dialog_label.custom_minimum_size = Vector2(0, 120)
	project_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	project_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	project_dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	project_dialog_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	project_dialog_label.text = ""
	dialog_panel.add_child(project_dialog_label)

	project_starter_overlay = Control.new()
	project_starter_overlay.visible = false
	project_starter_overlay.anchors_preset = Control.PRESET_FULL_RECT
	project_starter_overlay.anchor_right = 1.0
	project_starter_overlay.anchor_bottom = 1.0
	project_screen.add_child(project_starter_overlay)
	var fade := ColorRect.new()
	fade.anchors_preset = Control.PRESET_FULL_RECT
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.color = Color(0, 0, 0, 0.75)
	project_starter_overlay.add_child(fade)
	var starter_panel := PanelContainer.new()
	starter_panel.anchors_preset = Control.PRESET_CENTER
	starter_panel.anchor_left = 0.5
	starter_panel.anchor_top = 0.5
	starter_panel.anchor_right = 0.5
	starter_panel.anchor_bottom = 0.5
	starter_panel.offset_left = -460
	starter_panel.offset_top = -280
	starter_panel.offset_right = 460
	starter_panel.offset_bottom = 280
	project_starter_overlay.add_child(starter_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	starter_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Choose Your Starter"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 460)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)
	project_starter_grid = GridContainer.new()
	project_starter_grid.columns = 3
	project_starter_grid.add_theme_constant_override("h_separation", 8)
	project_starter_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(project_starter_grid)
	_populate_project_starter_buttons()


func _build_project_menu_ui() -> void:
	project_menu_overlay = Control.new()
	project_menu_overlay.visible = false
	project_menu_overlay.anchors_preset = Control.PRESET_FULL_RECT
	project_menu_overlay.anchor_right = 1.0
	project_menu_overlay.anchor_bottom = 1.0
	project_screen.add_child(project_menu_overlay)
	var fade := ColorRect.new()
	fade.anchors_preset = Control.PRESET_FULL_RECT
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.color = Color(0, 0, 0, 0.7)
	project_menu_overlay.add_child(fade)
	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -520
	panel.offset_top = -290
	panel.offset_right = 520
	panel.offset_bottom = 290
	project_menu_overlay.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	var title := Label.new()
	title.text = "Menu (M to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	root.add_child(title)
	var pages_row := HBoxContainer.new()
	pages_row.add_theme_constant_override("separation", 8)
	root.add_child(pages_row)
	project_menu_buttons_by_page.clear()
	for idx in range(PROJECT_MENU_PAGES.size()):
		var page_name: String = PROJECT_MENU_PAGES[idx]
		var button := Button.new()
		button.text = page_name
		button.custom_minimum_size = Vector2(140, 42)
		button.pressed.connect(_on_project_menu_page_pressed.bind(page_name))
		pages_row.add_child(button)
		project_menu_buttons_by_page[page_name] = button
	project_menu_content_label = Label.new()
	project_menu_content_label.custom_minimum_size = Vector2(980, 420)
	project_menu_content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	project_menu_content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	project_menu_content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	project_menu_content_label.add_theme_font_size_override("font_size", 22)
	project_menu_content_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	root.add_child(project_menu_content_label)
	project_menu_save_button = Button.new()
	project_menu_save_button.text = "Save Game"
	project_menu_save_button.custom_minimum_size = Vector2(220, 46)
	project_menu_save_button.visible = false
	project_menu_save_button.pressed.connect(_on_project_save_pressed)
	root.add_child(project_menu_save_button)
	project_menu_clear_button = Button.new()
	project_menu_clear_button.text = "Clear Save Data"
	project_menu_clear_button.custom_minimum_size = Vector2(220, 46)
	project_menu_clear_button.visible = false
	project_menu_clear_button.pressed.connect(_on_project_clear_save_pressed)
	root.add_child(project_menu_clear_button)
	project_menu_save_status_label = Label.new()
	project_menu_save_status_label.custom_minimum_size = Vector2(980, 32)
	project_menu_save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	project_menu_save_status_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	project_menu_save_status_label.visible = false
	project_menu_save_status_label.text = ""
	root.add_child(project_menu_save_status_label)
	project_menu_party_scroll = ScrollContainer.new()
	project_menu_party_scroll.custom_minimum_size = Vector2(980, 420)
	project_menu_party_scroll.visible = false
	root.add_child(project_menu_party_scroll)
	project_menu_party_list = VBoxContainer.new()
	project_menu_party_list.add_theme_constant_override("separation", 8)
	project_menu_party_scroll.add_child(project_menu_party_list)
	project_menu_detail_overlay = Control.new()
	project_menu_detail_overlay.visible = false
	project_menu_detail_overlay.anchors_preset = Control.PRESET_FULL_RECT
	project_menu_detail_overlay.anchor_right = 1.0
	project_menu_detail_overlay.anchor_bottom = 1.0
	project_menu_overlay.add_child(project_menu_detail_overlay)
	var detail_fade := ColorRect.new()
	detail_fade.anchors_preset = Control.PRESET_FULL_RECT
	detail_fade.anchor_right = 1.0
	detail_fade.anchor_bottom = 1.0
	detail_fade.color = Color(0, 0, 0, 0.72)
	project_menu_detail_overlay.add_child(detail_fade)
	var detail_panel := PanelContainer.new()
	detail_panel.anchors_preset = Control.PRESET_CENTER
	detail_panel.anchor_left = 0.5
	detail_panel.anchor_top = 0.5
	detail_panel.anchor_right = 0.5
	detail_panel.anchor_bottom = 0.5
	detail_panel.offset_left = -410
	detail_panel.offset_top = -250
	detail_panel.offset_right = 410
	detail_panel.offset_bottom = 250
	project_menu_detail_overlay.add_child(detail_panel)
	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 12)
	detail_panel.add_child(detail_vbox)
	project_menu_detail_label = Label.new()
	project_menu_detail_label.custom_minimum_size = Vector2(780, 410)
	project_menu_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	project_menu_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	project_menu_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	project_menu_detail_label.add_theme_font_size_override("font_size", 20)
	project_menu_detail_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	detail_vbox.add_child(project_menu_detail_label)
	var detail_close := Button.new()
	detail_close.text = "Back"
	detail_close.custom_minimum_size = Vector2(140, 42)
	detail_close.pressed.connect(_hide_project_menu_detail)
	detail_vbox.add_child(detail_close)
	_set_project_menu_page("Party")


func _project_menu_is_open() -> bool:
	return project_menu_overlay != null and project_menu_overlay.visible


func _toggle_project_menu() -> void:
	if _project_menu_is_open():
		_hide_project_menu()
	else:
		_show_project_menu()


func _show_project_menu() -> void:
	if project_menu_overlay == null:
		return
	project_menu_overlay.visible = true
	_set_project_menu_page(project_menu_current_page)


func _hide_project_menu() -> void:
	if project_menu_overlay == null:
		return
	project_menu_overlay.visible = false
	_hide_project_menu_detail()


func _on_project_menu_page_pressed(page_name: String) -> void:
	_hide_project_menu_detail()
	_set_project_menu_page(page_name)


func _set_project_menu_page(page_name: String) -> void:
	project_menu_current_page = page_name
	var is_party_page: bool = project_menu_current_page == "Party"
	var is_save_page: bool = project_menu_current_page == "Save"
	if project_menu_content_label != null:
		project_menu_content_label.visible = not is_party_page
		if is_save_page:
			project_menu_content_label.text = "Save your current progress."
		else:
			project_menu_content_label.text = "%s page\n(placeholder for now)" % page_name
	if project_menu_save_button != null:
		project_menu_save_button.visible = is_save_page
	if project_menu_clear_button != null:
		project_menu_clear_button.visible = is_save_page
	if project_menu_save_status_label != null:
		project_menu_save_status_label.visible = is_save_page
	if project_menu_party_scroll != null:
		project_menu_party_scroll.visible = is_party_page
	if is_party_page:
		_populate_project_party_page()
	for idx in range(PROJECT_MENU_PAGES.size()):
		var name: String = PROJECT_MENU_PAGES[idx]
		if not project_menu_buttons_by_page.has(name):
			continue
		var button: Button = project_menu_buttons_by_page[name]
		button.disabled = name == project_menu_current_page


func _project_party_members() -> Array:
	var members: Array = run_manager.get_active_team_snapshot()
	if members.is_empty():
		members = last_team_snapshot.duplicate(true)
	return members


func _populate_project_party_page() -> void:
	if project_menu_party_list == null:
		return
	for child in project_menu_party_list.get_children():
		child.queue_free()
	var members: Array = _project_party_members()
	var shown: int = min(6, members.size())
	if shown <= 0:
		var empty_label := Label.new()
		empty_label.custom_minimum_size = Vector2(940, 56)
		empty_label.text = "No Pokemon in party yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		project_menu_party_list.add_child(empty_label)
		return
	for idx in range(shown):
		var mon: Dictionary = members[idx]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(940, 58)
		btn.text = "%d. %s Lv.%d | HP %d/%d | %s" % [
			idx + 1,
			str(mon.get("name", "Pokemon")),
			int(mon.get("level", 1)),
			int(mon.get("current_hp", 0)),
			int(mon.get("stats", {}).get("hp", 0)),
			str(mon.get("status", ""))
		]
		btn.pressed.connect(_on_project_party_member_pressed.bind(idx))
		project_menu_party_list.add_child(btn)


func _on_project_party_member_pressed(member_index: int) -> void:
	var members: Array = _project_party_members()
	if member_index < 0 or member_index >= members.size():
		return
	var mon: Dictionary = members[member_index]
	var type_parts: Array[String] = []
	var mon_types: Array = mon.get("types", [])
	for idx in range(mon_types.size()):
		type_parts.append(str(mon_types[idx]))
	var types_text: String = "Unknown"
	if type_parts.is_empty() == false:
		types_text = "/".join(type_parts)
	var move_names: Array[String] = []
	var moves: Array = mon.get("moves", [])
	var move_pp: Array = mon.get("move_pp", [])
	var move_pp_max: Array = mon.get("move_pp_max", [])
	for idx in range(moves.size()):
		var move_data: Dictionary = moves[idx]
		var name: String = str(move_data.get("name", "Move"))
		var cur_pp: int = int(move_data.get("pp", 0))
		var max_pp: int = int(move_data.get("pp", 0))
		if idx < move_pp.size():
			cur_pp = int(move_pp[idx])
		if idx < move_pp_max.size():
			max_pp = int(move_pp_max[idx])
		move_names.append("- %s (%d/%d PP)" % [name, cur_pp, max_pp])
	var stats: Dictionary = mon.get("stats", {})
	var details: String = "%s Lv.%d\nType: %s\nAbility: %s\nNature: %s\nStatus: %s\nHP: %d/%d\n\nStats\nATK %d  DEF %d  SPA %d  SPD %d  SPE %d\n\nMoves\n%s" % [
		str(mon.get("name", "Pokemon")),
		int(mon.get("level", 1)),
		types_text,
		str(mon.get("ability", "Unknown")),
		str(mon.get("nature", "Unknown")),
		str(mon.get("status", "OK")),
		int(mon.get("current_hp", 0)),
		int(stats.get("hp", 0)),
		int(stats.get("atk", 0)),
		int(stats.get("def", 0)),
		int(stats.get("spa", 0)),
		int(stats.get("spd", 0)),
		int(stats.get("spe", 0)),
		"\n".join(move_names)
	]
	if project_menu_detail_label != null:
		project_menu_detail_label.text = details
	if project_menu_detail_overlay != null:
		project_menu_detail_overlay.visible = true


func _hide_project_menu_detail() -> void:
	if project_menu_detail_overlay != null:
		project_menu_detail_overlay.visible = false


func _on_project_save_pressed() -> void:
	run_manager.force_save_to_disk()
	var saved: bool = _save_project_mode_state()
	if project_menu_save_status_label == null:
		return
	if saved:
		project_menu_save_status_label.text = "Saved: %s" % Time.get_datetime_string_from_system()
	else:
		project_menu_save_status_label.text = "Save failed."


func _on_project_clear_save_pressed() -> void:
	run_manager.clear_all_save_data()
	_clear_project_mode_state_file()
	project_story_stage = "lab_intro"
	project_player_starter_id = 0
	project_rival_battle_completed = false
	project_return_overworld_pos = _overworld_return_for_interior("player_house")
	_enter_project_interior("player_house")
	project_door_cooldown = 0.35
	if project_menu_save_status_label != null:
		project_menu_save_status_label.text = "Save data cleared."


func _save_project_mode_state() -> bool:
	var payload: Dictionary = {
		"story_stage": project_story_stage,
		"player_starter_id": project_player_starter_id,
		"rival_battle_completed": project_rival_battle_completed,
		"current_interior": project_current_interior,
		"return_overworld_x": project_return_overworld_pos.x,
		"return_overworld_y": project_return_overworld_pos.y,
		"player_x": project_player_rect.position.x,
		"player_y": project_player_rect.position.y
	}
	var file := FileAccess.open(PROJECT_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true


func _clear_project_mode_state_file() -> void:
	if not FileAccess.file_exists(PROJECT_STATE_PATH):
		return
	DirAccess.remove_absolute(PROJECT_STATE_PATH)


func _load_project_mode_state() -> bool:
	if not FileAccess.file_exists(PROJECT_STATE_PATH):
		return false
	var file := FileAccess.open(PROJECT_STATE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = parsed
	project_story_stage = str(payload.get("story_stage", "lab_intro"))
	project_player_starter_id = int(payload.get("player_starter_id", 0))
	project_rival_battle_completed = bool(payload.get("rival_battle_completed", false))
	project_return_overworld_pos = Vector2(
		float(payload.get("return_overworld_x", 0.0)),
		float(payload.get("return_overworld_y", 0.0))
	)
	var player_pos := Vector2(
		float(payload.get("player_x", 0.0)),
		float(payload.get("player_y", 0.0))
	)
	var saved_interior: String = str(payload.get("current_interior", ""))
	if saved_interior.is_empty():
		project_current_interior = ""
		project_world.visible = true
		project_interior_root.visible = false
		var old_parent: Node = project_player_rect.get_parent()
		if old_parent != project_world:
			old_parent.remove_child(project_player_rect)
			project_world.add_child(project_player_rect)
		project_player_rect.position = player_pos
		_update_project_camera()
		project_door_cooldown = 0.25
		return true
	_enter_project_interior(saved_interior)
	project_player_rect.position = player_pos
	project_door_cooldown = 0.25
	return true


func _populate_project_starter_buttons() -> void:
	for child in project_starter_grid.get_children():
		child.queue_free()
	for idx in range(PROJECT_STARTER_IDS.size()):
		var starter_id: int = PROJECT_STARTER_IDS[idx]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(260, 54)
		btn.text = run_manager.get_species_name(starter_id)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.pressed.connect(_on_project_starter_selected.bind(starter_id))
		project_starter_grid.add_child(btn)


func _show_project_starter_select() -> void:
	if project_starter_overlay != null:
		project_starter_overlay.visible = true


func _hide_project_starter_select() -> void:
	if project_starter_overlay != null:
		project_starter_overlay.visible = false


func _begin_project_dialog(lines: Array[String], completion_action: String = "") -> void:
	project_dialog_lines.clear()
	for idx in range(lines.size()):
		project_dialog_lines.append(str(lines[idx]))
	project_dialog_index = 0
	project_dialog_completion_action = completion_action
	if project_dialog_overlay != null:
		project_dialog_overlay.visible = true
	if project_dialog_label != null:
		if project_dialog_lines.is_empty():
			project_dialog_label.text = ""
		else:
			project_dialog_label.text = project_dialog_lines[0]


func _project_dialog_is_open() -> bool:
	return project_dialog_overlay != null and project_dialog_overlay.visible


func _close_project_dialog() -> void:
	if project_dialog_overlay != null:
		project_dialog_overlay.visible = false
	project_dialog_lines.clear()
	project_dialog_index = 0
	project_dialog_completion_action = ""


func _advance_project_dialog() -> void:
	if project_dialog_lines.is_empty():
		_close_project_dialog()
		return
	project_dialog_index += 1
	if project_dialog_index < project_dialog_lines.size():
		project_dialog_label.text = project_dialog_lines[project_dialog_index]
		return
	var action: String = project_dialog_completion_action
	_close_project_dialog()
	if action == "open_starter_select":
		_show_project_starter_select()
	elif action == "start_rival_battle":
		_start_project_rival_battle()
	elif action == "oak_post_battle_heal":
		run_manager.heal_active_team_full()
		project_story_stage = "parcel_quest"
		project_rival_battle_completed = true
	elif action == "mom_heal":
		run_manager.heal_active_team_full()


func _on_project_starter_selected(starter_id: int) -> void:
	project_player_starter_id = starter_id
	project_story_stage = "starter_chosen"
	_hide_project_starter_select()
	_begin_project_dialog(["You have a Pokemon? Let's Batttle!"], "start_rival_battle")


func _start_project_rival_battle() -> void:
	if project_player_starter_id <= 0:
		return
	var rival_id: int = _rival_starter_for_player(project_player_starter_id)
	var player_mon: Dictionary = run_manager.factory.build_randomized_pokemon(project_player_starter_id, 5)
	var rival_mon: Dictionary = run_manager.factory.build_randomized_pokemon(rival_id, 5)
	project_battle_return_context = "lab_story"
	run_manager.start_single_battle([player_mon], rival_mon)
	_show_only_screen("battle")


func _rival_starter_for_player(starter_id: int) -> int:
	var entry: Dictionary = run_manager.factory.build_randomized_pokemon(starter_id, 5)
	var starter_type: String = "Grass"
	if entry.is_empty() == false:
		var types: Array = entry.get("types", [])
		if not types.is_empty():
			starter_type = str(types[0])
	if starter_type == "Grass":
		return 4
	if starter_type == "Fire":
		return 7
	return 1


func _on_single_battle_finished(_result: String) -> void:
	if current_game_mode != "project":
		return
	var result_text: String = "Battle ended."
	if _result == "win":
		result_text = "You won the battle!"
	elif _result == "lose":
		result_text = "You lost the battle."
	if project_battle_return_context == "lab_story":
		_show_battle_end_message(result_text, "project_return_lab")
	else:
		_show_battle_end_message(result_text, "project_return_overworld")


func _build_battle_end_ui() -> void:
	battle_end_overlay = Control.new()
	battle_end_overlay.visible = false
	battle_end_overlay.anchors_preset = Control.PRESET_FULL_RECT
	battle_end_overlay.anchor_right = 1.0
	battle_end_overlay.anchor_bottom = 1.0
	battle_root.add_child(battle_end_overlay)
	var fade := ColorRect.new()
	fade.anchors_preset = Control.PRESET_FULL_RECT
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.color = Color(0, 0, 0, 0.7)
	battle_end_overlay.add_child(fade)
	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_top = -110
	panel.offset_right = 320
	panel.offset_bottom = 110
	battle_end_overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	battle_end_label = Label.new()
	battle_end_label.custom_minimum_size = Vector2(600, 80)
	battle_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	battle_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	battle_end_label.add_theme_font_size_override("font_size", 26)
	battle_end_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(battle_end_label)
	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(160, 44)
	continue_btn.pressed.connect(_on_battle_end_continue_pressed)
	vbox.add_child(continue_btn)


func _show_battle_end_message(message: String, action: String) -> void:
	pending_battle_end_action = action
	if battle_end_label != null:
		battle_end_label.text = message
	if battle_end_overlay != null:
		battle_end_overlay.visible = true
	_show_only_screen("battle")


func _on_battle_end_continue_pressed() -> void:
	if battle_end_overlay != null:
		battle_end_overlay.visible = false
	var action: String = pending_battle_end_action
	pending_battle_end_action = ""
	if action == "project_return_lab":
		_show_only_screen("project")
		_enter_project_interior("oak_lab")
		project_door_cooldown = 0.35
		project_story_stage = "post_rival_battle"
		_begin_project_dialog(["Good battle boys. I'll heal your team. Now can you go get me my parcel from Viridian City?"], "oak_post_battle_heal")
		project_battle_return_context = ""
		return
	if action == "project_return_overworld":
		_show_only_screen("project")
		project_battle_return_context = ""
		return
	_show_only_screen("start")
	_refresh_start_status()


func _on_continue_pressed() -> void:
	if not run_manager.has_active_run():
		start_status_label.text = "No run to continue."
		return
	_show_only_screen("battle")


func _on_new_run_pressed() -> void:
	selected_team_ids.clear()
	_populate_team_select_grid()
	_refresh_team_select_ui()
	_update_team_select_grid_columns()
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
	if current_game_mode != "roguelike":
		return
	if mode_select_screen.visible or start_screen.visible:
		return
	_show_only_screen("battle")
	_refresh_start_status()


func _on_run_ended(_message: String) -> void:
	if current_game_mode == "project":
		return
	_show_battle_end_message(_message, "roguelike_start")


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
	enemy_status.text = summary
	var state: Dictionary = run_manager.get_battle_state()
	current_enemy_id = int(state.get("enemy_id", 0))
	if current_enemy_id > 0:
		enemy_sprite.texture = fallback_texture
		sprite_service.request_sprite(current_enemy_id)
	_refresh_status_popup()


func _on_battle_log_changed(text: String) -> void:
	var cleaned_lines: Array[String] = []
	if not text.is_empty():
		var raw_lines: PackedStringArray = text.split("\n")
		for idx in range(raw_lines.size()):
			var cleaned_line: String = _plain_text(str(raw_lines[idx]))
			if cleaned_line.is_empty():
				continue
			cleaned_lines.append(cleaned_line)

	if current_game_mode == "project":
		_queue_project_battle_messages(cleaned_lines)
		last_battle_log_lines = cleaned_lines.duplicate()
		return

	var newest: String = ""
	if not cleaned_lines.is_empty():
		newest = cleaned_lines[0]
	message_label.text = newest
	if not newest.is_empty():
		message_timer.start()
		_apply_battle_flash_for_message(newest)


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
	move_back_button.visible = waiting_move
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
	action_buttons_row.visible = not waiting_move
	_set_bottom_bar_mode(waiting_move)

	var move_names: Array = state.get("move_names", [])
	var move_can_use: Array = state.get("move_can_use", [])
	var move_types: Array = state.get("move_types", [])
	var move_tooltips: Array = state.get("move_tooltips", [])
	move_hover_details.clear()
	for i in range(move_tooltips.size()):
		move_hover_details.append(str(move_tooltips[i]))
	for idx in range(move_buttons.size()):
		var btn: Button = move_buttons[idx]
		if idx < move_names.size():
			btn.visible = true
			btn.text = str(move_names[idx])
			var has_pp: bool = true
			if idx < move_can_use.size():
				has_pp = bool(move_can_use[idx])
			btn.disabled = not has_pp
			var move_type: String = "Normal"
			if idx < move_types.size():
				move_type = str(move_types[idx])
			var move_color := Color.from_string(run_manager.get_type_color_hex(move_type), Color.WHITE)
			btn.add_theme_color_override("font_color", move_color)
			btn.add_theme_color_override("font_hover_color", move_color)
			btn.add_theme_color_override("font_pressed_color", move_color)
			btn.add_theme_color_override("font_disabled_color", move_color)
			if idx < move_tooltips.size():
				btn.tooltip_text = str(move_tooltips[idx])
			else:
				btn.tooltip_text = ""
		else:
			btn.visible = false
			btn.disabled = false
			btn.tooltip_text = ""

	player_status.text = "Active %s Lv.%d %s | HP %d/%d | %s/%s | %s" % [
		str(state.get("active_name", "-")),
		int(state.get("active_level", 0)),
		str(state.get("active_status", "[OK]")),
		int(state.get("active_hp", 0)),
		int(state.get("active_hp_max", 0)),
		_colorize_type(str(state.get("active_type_1", "Normal"))),
		_colorize_type(str(state.get("active_type_2", "Normal"))),
		str(state.get("active_ability", "-"))
	]
	var next_player_hp_max: int = max(1, int(state.get("active_hp_max", 1)))
	var next_player_hp: int = int(state.get("active_hp", 0))
	var next_enemy_hp_max: int = max(1, int(state.get("enemy_hp_max", 1)))
	var next_enemy_hp: int = int(state.get("enemy_hp", 0))
	_apply_hp_values(next_player_hp_max, next_player_hp, next_enemy_hp_max, next_enemy_hp, current_game_mode == "project")
	player_stages.text = "Your stages: %s" % str(state.get("active_stage_text", "-"))

	enemy_stages.text = "Enemy stages: %s" % str(state.get("enemy_stage_text", "-"))
	_refresh_status_popup()


func _queue_project_battle_messages(cleaned_lines: Array[String]) -> void:
	var max_overlap: int = min(last_battle_log_lines.size(), cleaned_lines.size())
	var overlap: int = 0
	for size_check in range(max_overlap, -1, -1):
		var matches: bool = true
		for idx in range(size_check):
			if str(last_battle_log_lines[idx]) != str(cleaned_lines[cleaned_lines.size() - size_check + idx]):
				matches = false
				break
		if matches:
			overlap = size_check
			break

	var added_prefix_size: int = cleaned_lines.size() - overlap
	for idx in range(added_prefix_size - 1, -1, -1):
		var line_text: String = str(cleaned_lines[idx])
		if line_text.is_empty():
			continue
		battle_message_queue.append(line_text)

	if not message_timer.is_stopped():
		return
	_show_next_project_battle_message()


func _show_next_project_battle_message() -> void:
	if battle_message_queue.is_empty():
		message_label.text = ""
		return
	var next_line: String = str(battle_message_queue.pop_front())
	message_label.text = next_line
	_apply_battle_flash_for_message(next_line)
	message_timer.start()


func _on_message_timer_timeout() -> void:
	if current_game_mode == "project":
		_show_next_project_battle_message()
		return
	message_label.text = ""


func _apply_battle_flash_for_message(message: String) -> void:
	var lower: String = message.to_lower()
	if lower.find("critical hit") >= 0:
		_trigger_battle_flash(Color(1.0, 0.35, 0.2, 1.0), 0.42, 0.14)
	if lower.find("super effective") >= 0:
		_trigger_battle_flash(Color(1.0, 1.0, 0.2, 1.0), 0.34, 0.12)


func _apply_hp_values(player_max: int, player_value: int, enemy_max: int, enemy_value: int, animate: bool) -> void:
	player_hp.max_value = max(1, player_max)
	enemy_hp.max_value = max(1, enemy_max)
	var clamped_player: int = clamp(player_value, 0, int(player_hp.max_value))
	var clamped_enemy: int = clamp(enemy_value, 0, int(enemy_hp.max_value))
	if not animate:
		player_hp.value = clamped_player
		enemy_hp.value = clamped_enemy
		return
	if hp_tween != null and hp_tween.is_valid():
		hp_tween.kill()
	hp_tween = create_tween()
	hp_tween.set_parallel(true)
	hp_tween.tween_property(player_hp, "value", float(clamped_player), 0.35)
	hp_tween.tween_property(enemy_hp, "value", float(clamped_enemy), 0.35)


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


func _on_move_back_pressed() -> void:
	move_hover_panel.visible = false
	run_manager.cancel_fight_choice()


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
	_update_team_select_grid_columns()


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


func _configure_team_select_scroll_behavior() -> void:
	# Vertical-only scrolling in team selection.
	team_select_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	team_select_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_update_team_select_grid_columns()


func _update_team_select_grid_columns() -> void:
	team_select_grid.columns = 7


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
	var type_parts: Array[String] = []
	var mon_types: Array = mon.get("types", [])
	for idx in range(mon_types.size()):
		type_parts.append(str(mon_types[idx]))
	var type_text: String = "Unknown"
	if type_parts.is_empty() == false:
		type_text = "/".join(type_parts)
	return "%s Lv.%d\nType: %s\nHP: %d/%d\nAbility: %s\nNature: %s\nMoves: %s" % [
		str(mon.get("name", "Pokemon")),
		int(mon.get("level", 1)),
		type_text,
		int(mon.get("current_hp", 0)),
		int(mon.get("stats", {}).get("hp", 0)),
		str(mon.get("ability", "Unknown")),
		str(mon.get("nature", "Unknown")),
		", ".join(move_names)
	]


func _colorize_type(type_name: String) -> String:
	return "[color=%s]%s[/color]" % [run_manager.get_type_color_hex(type_name), type_name]


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
		var label: String = str(preset.get("name", "Preset"))
		if preset.has("texture_path"):
			var texture_path: String = str(preset.get("texture_path", ""))
			if not ResourceLoader.exists(texture_path):
				label += " (missing)"
		settings_background_picker.add_item(label, idx)
	settings_music_picker.clear()
	for theme_id in range(2, 8):
		var label := "menu_theme_%d" % theme_id
		if not ResourceLoader.exists(_music_path(theme_id)):
			label += " (missing)"
		settings_music_picker.add_item(label, theme_id)
	settings_music_picker.disabled = false


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
	if preset.has("texture_path"):
		var texture_path: String = str(preset.get("texture_path", ""))
		if ResourceLoader.exists(texture_path):
			var texture: Texture2D = load(texture_path) as Texture2D
			if texture != null:
				background_image.texture = texture
				background_image.visible = true
				background_rect.visible = false
				return
	background_image.visible = false
	background_image.texture = null
	background_rect.visible = true
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
	selected_music_theme = _pick_random_available_theme(selected_music_theme)
	_select_music_picker_theme(selected_music_theme)
	_play_theme(selected_music_theme, true)
	_save_user_settings()


func _next_theme_id(theme_id: int) -> int:
	var next_theme: int = theme_id + 1
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


func _available_theme_ids() -> Array[int]:
	var ids: Array[int] = []
	for theme_id in range(2, 8):
		if ResourceLoader.exists(_music_path(theme_id)):
			ids.append(theme_id)
	return ids


func _pick_random_available_theme(exclude_theme: int = -1) -> int:
	var available: Array[int] = _available_theme_ids()
	if available.is_empty():
		return -1
	if available.size() == 1:
		return int(available[0])
	var filtered: Array[int] = []
	for idx in range(available.size()):
		var theme_id: int = int(available[idx])
		if theme_id == exclude_theme:
			continue
		filtered.append(theme_id)
	if filtered.is_empty():
		filtered = available.duplicate()
	var pick_idx: int = music_rng.randi_range(0, filtered.size() - 1)
	return int(filtered[pick_idx])


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
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 10
	panel_style.border_color = Color(0, 0, 0, 1)
	move_hover_panel.add_theme_stylebox_override("panel", panel_style)
	move_hover_text.add_theme_color_override("font_color", Color(0, 0, 0, 1))


func _set_bottom_bar_mode(waiting_move: bool) -> void:
	var bar_style := StyleBoxFlat.new()
	bar_style.corner_radius_top_left = 18
	bar_style.corner_radius_top_right = 18
	bar_style.corner_radius_bottom_left = 0
	bar_style.corner_radius_bottom_right = 0
	bar_style.border_width_left = 2
	bar_style.border_width_top = 2
	bar_style.border_width_right = 2
	bar_style.border_width_bottom = 0
	bar_style.content_margin_left = 18
	bar_style.content_margin_top = 14
	bar_style.content_margin_right = 18
	bar_style.content_margin_bottom = 14
	bar_style.border_color = Color(0.2, 0.2, 0.25, 1)
	if waiting_move:
		bar_style.bg_color = Color(0.82, 0.82, 0.9, 0.95)
	else:
		bar_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	bottom_bar.add_theme_stylebox_override("panel", bar_style)


func _apply_pretty_styles() -> void:
	_apply_rounded_panel(enemy_status_panel, Color(0.07, 0.07, 0.1, 0.85))
	_apply_rounded_panel(player_status_panel, Color(0.07, 0.07, 0.1, 0.85))
	_apply_rounded_panel($SettingsScreen/Panel, Color(0.1, 0.1, 0.13, 0.96))
	_apply_rounded_panel($UnlockPopup/Panel, Color(0.1, 0.1, 0.13, 0.96))
	_apply_rounded_panel($EvolutionPopup/Panel, Color(0.1, 0.1, 0.13, 0.96))
	_apply_rounded_panel($StatusPopup/Panel, Color(0.1, 0.1, 0.13, 0.96))
	_set_bottom_bar_mode(false)
	var action_buttons: Array[Button] = [fight_button, switch_button, run_button, status_button, quit_button]
	for idx in range(action_buttons.size()):
		_apply_rounded_button(action_buttons[idx], Color(0.16, 0.16, 0.2, 1.0))
	for idx in range(move_buttons.size()):
		_apply_rounded_button(move_buttons[idx], Color(0.93, 0.93, 0.98, 0.98))
	_apply_rounded_button(move_back_button, Color(0.16, 0.16, 0.2, 1.0))


func _apply_rounded_panel(panel: PanelContainer, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	style.border_color = Color(0.22, 0.22, 0.27, 1)
	panel.add_theme_stylebox_override("panel", style)


func _apply_rounded_button(btn: Button, bg_color: Color) -> void:
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_left = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.content_margin_left = 12
	style_normal.content_margin_top = 8
	style_normal.content_margin_right = 12
	style_normal.content_margin_bottom = 8
	style_normal.border_color = Color(0.2, 0.2, 0.25, 1)
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)


func _force_control_white(control_node: Control) -> void:
	var white := Color(1, 1, 1, 1)
	control_node.add_theme_color_override("font_color", white)
	control_node.add_theme_color_override("font_hover_color", white)
	control_node.add_theme_color_override("font_pressed_color", white)
	control_node.add_theme_color_override("font_disabled_color", white)


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
	move_back_button.add_theme_color_override("font_color", white)
	move_back_button.add_theme_color_override("font_hover_color", white)
	move_back_button.add_theme_color_override("font_pressed_color", white)
	move_back_button.add_theme_color_override("font_disabled_color", white)


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
