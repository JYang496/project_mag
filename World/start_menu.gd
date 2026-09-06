extends Node2D

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const START_UI_THEME := preload("res://UI/themes/start_menu_theme.tres")
const WORLD_SCENE_PATH := "res://World/world.tscn"
const WEAPON_SKILL_LAB_SCENE_PATH := "res://tests/showcases/weapon/weapon_active_skill_gameplay_lab.tscn"
const WORLD_ENTRY_PREPARE_GATE_SCRIPT := preload("res://World/world_entry_prepare_gate.gd")
const WORLD_SCENE_LOADER_SCRIPT := preload("res://World/world_scene_loader.gd")
const MODAL_UI_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/modal_ui_controller.gd")
const AUDIO_SETTINGS_CONTROLS_SCENE := preload("res://UI/components/AudioSettingsControls/AudioSettingsControls.tscn")
const INPUT_PROMPT_TEXTURE_FACTORY := preload("res://UI/scripts/components/input_prompt_texture_factory.gd")
const DISPLAY_SETTINGS_SCRIPT := preload("res://autoload/DisplaySettings.gd")

enum PrewarmState { NOT_STARTED, RUNNING, SUCCEEDED, FAILED }

@onready var gui_root: Control = $CanvasLayer/GUI
@onready var safe_area: MarginContainer = $CanvasLayer/GUI/SafeArea
@onready var main_column: VBoxContainer = $CanvasLayer/GUI/SafeArea/MainColumn
@onready var title_label: Label = $CanvasLayer/GUI/SafeArea/MainColumn/Title
@onready var subtitle_label: Label = $CanvasLayer/GUI/SafeArea/MainColumn/Subtitle
@onready var tagline_label: Label = $CanvasLayer/GUI/SafeArea/MainColumn/Tagline
@onready var start_button: Button = $CanvasLayer/GUI/SafeArea/MainColumn/Navigation/Continue
@onready var continue_status: Label = $CanvasLayer/GUI/SafeArea/MainColumn/Navigation/ContinueStatus
@onready var new_game_button: Button = $CanvasLayer/GUI/SafeArea/MainColumn/Navigation/NewGame
@onready var weapon_skill_lab_button: Button = $CanvasLayer/GUI/SafeArea/MainColumn/Navigation/WeaponSkillLab
@onready var settings_button: Button = $CanvasLayer/GUI/SafeArea/MainColumn/Navigation/Settings
@onready var exit_button: Button = $CanvasLayer/GUI/SafeArea/MainColumn/Navigation/Exit
@onready var navigation_hint: Label = $CanvasLayer/GUI/SafeArea/MainColumn/InputHint/Navigation/Label
@onready var confirm_prompt: TextureRect = $CanvasLayer/GUI/SafeArea/MainColumn/InputHint/Confirm/Prompt
@onready var confirm_hint: Label = $CanvasLayer/GUI/SafeArea/MainColumn/InputHint/Confirm/Label
@onready var back_hint: Label = $CanvasLayer/GUI/SafeArea/MainColumn/InputHint/Back/Label
@onready var build_info: Label = $CanvasLayer/GUI/BuildInfo
@onready var settings_scrim: ColorRect = $CanvasLayer/GUI/SettingsScrim
@onready var settings_panel: PanelContainer = $CanvasLayer/GUI/SettingsPanel
@onready var settings_title: Label = $CanvasLayer/GUI/SettingsPanel/Margin/Content/Header/Title
@onready var settings_close_button: Button = $CanvasLayer/GUI/SettingsPanel/Margin/Content/Header/Close
@onready var display_header: Label = $CanvasLayer/GUI/SettingsPanel/Margin/Content/DisplayHeader
@onready var resolution_label: Label = $CanvasLayer/GUI/SettingsPanel/Margin/Content/ResolutionRow/Label
@onready var resolution_option: OptionButton = $CanvasLayer/GUI/SettingsPanel/Margin/Content/ResolutionRow/Option
@onready var language_label: Label = $CanvasLayer/GUI/SettingsPanel/Margin/Content/LanguageRow/Label
@onready var language_option: OptionButton = $CanvasLayer/GUI/SettingsPanel/Margin/Content/LanguageRow/Option
@onready var audio_header: Label = $CanvasLayer/GUI/SettingsPanel/Margin/Content/AudioHeader
@onready var audio_slot: VBoxContainer = $CanvasLayer/GUI/SettingsPanel/Margin/Content/AudioSlot
@onready var assist_header: Label = $CanvasLayer/GUI/SettingsPanel/Margin/Content/AssistHeader
@onready var auto_aim_continuous_fire_toggle: CheckButton = $CanvasLayer/GUI/SettingsPanel/Margin/Content/AutoAim
@onready var auto_reload_switch_toggle: CheckButton = $CanvasLayer/GUI/SettingsPanel/Margin/Content/AutoReload
@onready var settings_footer: Label = $CanvasLayer/GUI/SettingsPanel/Margin/Content/SettingsFooter

var audio_settings_controls: VBoxContainer
var display_settings: Node
var prewarm_state := PrewarmState.NOT_STARTED
var prewarm_error := ""
var _settings_open := false
var _panel_tween: Tween


func _ready() -> void:
	display_settings = DISPLAY_SETTINGS_SCRIPT.new()
	add_child(display_settings)
	gui_root.theme = START_UI_THEME
	confirm_prompt.texture = INPUT_PROMPT_TEXTURE_FACTORY.space_prompt_texture()
	_ensure_audio_settings_controls()
	_wire_controls()
	_refresh_save_state()
	_populate_resolution_options()
	_populate_language_options()
	_apply_localized_text()
	_play_intro_animation()
	LoadingPerformance.begin_menu_session()
	call_deferred("_prewarm_world_entry")


func _unhandled_input(event: InputEvent) -> void:
	var is_right_click: bool = event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ESC") \
			or event.is_action_pressed("CANCEL") or is_right_click:
		if _settings_open:
			_close_settings()
			get_viewport().set_input_as_handled()
		return
	if not _settings_open and not event.is_echo():
		if event.is_action_pressed("UP") or event.is_action_pressed("LEFT"):
			_move_main_menu_focus(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("DOWN") or event.is_action_pressed("RIGHT"):
			_move_main_menu_focus(1)
			get_viewport().set_input_as_handled()


func _move_main_menu_focus(direction: int) -> void:
	var buttons: Array[Button] = [start_button, new_game_button, weapon_skill_lab_button, settings_button, exit_button]
	var available: Array[Button] = []
	for button in buttons:
		if button.visible and not button.disabled:
			available.append(button)
	if available.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var current_index := available.find(focused)
	if current_index == -1:
		current_index = 0 if direction > 0 else available.size() - 1
	else:
		current_index = wrapi(current_index + direction, 0, available.size())
	available[current_index].grab_focus()


func _wire_controls() -> void:
	if not weapon_skill_lab_button.pressed.is_connected(_on_weapon_skill_lab_pressed):
		weapon_skill_lab_button.pressed.connect(_on_weapon_skill_lab_pressed)
	if not settings_button.pressed.is_connected(_open_settings):
		settings_button.pressed.connect(_open_settings)
	if not settings_close_button.pressed.is_connected(_close_settings):
		settings_close_button.pressed.connect(_close_settings)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	if not settings_scrim.gui_input.is_connected(_on_settings_scrim_input):
		settings_scrim.gui_input.connect(_on_settings_scrim_input)
	if not resolution_option.item_selected.is_connected(_on_resolution_option_item_selected):
		resolution_option.item_selected.connect(_on_resolution_option_item_selected)
	if not language_option.item_selected.is_connected(_on_language_option_item_selected):
		language_option.item_selected.connect(_on_language_option_item_selected)
	if not auto_aim_continuous_fire_toggle.toggled.is_connected(_on_auto_aim_continuous_fire_toggled):
		auto_aim_continuous_fire_toggle.toggled.connect(_on_auto_aim_continuous_fire_toggled)
	if not auto_reload_switch_toggle.toggled.is_connected(_on_auto_reload_switch_toggled):
		auto_reload_switch_toggle.toggled.connect(_on_auto_reload_switch_toggled)
	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)
	auto_aim_continuous_fire_toggle.button_pressed = bool(PlayerAssistSettings.auto_aim_continuous_fire)
	auto_reload_switch_toggle.button_pressed = bool(PlayerAssistSettings.auto_reload_switch)
	exit_button.visible = not OS.has_feature("web")


func _refresh_save_state() -> void:
	var has_run := SaveManager.has_run()
	start_button.disabled = not has_run
	continue_status.visible = not has_run
	if has_run:
		start_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _open_settings() -> void:
	if _settings_open:
		return
	_settings_open = true
	settings_scrim.visible = true
	settings_panel.visible = true
	settings_panel.modulate.a = 0.0
	settings_panel.position.x += 28.0
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_panel_tween.tween_property(settings_panel, "modulate:a", 1.0, 0.20)
	_panel_tween.tween_property(settings_panel, "position:x", settings_panel.position.x - 28.0, 0.20)
	settings_close_button.grab_focus()


func _close_settings() -> void:
	if not _settings_open:
		return
	_settings_open = false
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_panel_tween.tween_property(settings_panel, "modulate:a", 0.0, 0.14)
	_panel_tween.tween_property(settings_panel, "position:x", settings_panel.position.x + 20.0, 0.14)
	await _panel_tween.finished
	settings_panel.position.x -= 20.0
	settings_panel.visible = false
	settings_scrim.visible = false
	settings_button.grab_focus()


func _on_settings_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_settings()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_weapon_skill_lab_pressed() -> void:
	if weapon_skill_lab_button.disabled:
		return
	weapon_skill_lab_button.disabled = true
	var original_text := weapon_skill_lab_button.text
	weapon_skill_lab_button.text = LocalizationManager.tr_key("ui.start.loading_test_lab", "Loading Test Lab...")
	var prepare_result: Dictionary = WORLD_ENTRY_PREPARE_GATE_SCRIPT.prepare_world_entry()
	SpawnData.ensure_loaded()
	DataHandler.prewarm_mecha_default_weapon(str(PlayerData.select_mecha_id))
	if not bool(prepare_result.get("ok", false)):
		push_error("Weapon skill lab prepare failed: %s" % WORLD_ENTRY_PREPARE_GATE_SCRIPT.format_errors(prepare_result))
		weapon_skill_lab_button.text = original_text
		weapon_skill_lab_button.disabled = false
		return
	var packed_scene := load(WEAPON_SKILL_LAB_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Weapon skill gameplay lab scene could not be loaded.")
		weapon_skill_lab_button.text = original_text
		weapon_skill_lab_button.disabled = false
		return
	get_tree().change_scene_to_packed(packed_scene)


func _ensure_audio_settings_controls() -> void:
	var existing := audio_slot.get_node_or_null("AudioSettingsControls")
	if existing is VBoxContainer:
		audio_settings_controls = existing as VBoxContainer
	else:
		audio_settings_controls = AUDIO_SETTINGS_CONTROLS_SCENE.instantiate() as VBoxContainer
		audio_settings_controls.name = "AudioSettingsControls"
		audio_slot.add_child(audio_settings_controls)


func _populate_resolution_options() -> void:
	resolution_option.clear()
	for resolution: Vector2i in RESOLUTION_PRESETS:
		resolution_option.add_item("%s × %s" % [resolution.x, resolution.y])
	var selected_index := _find_resolution_index(display_settings.resolution)
	if selected_index == -1:
		selected_index = _find_resolution_index(Vector2i(DisplayServer.window_get_size()))
	if selected_index >= 0:
		resolution_option.select(selected_index)
	if not display_settings.can_apply_window_changes():
		resolution_option.disabled = true
		resolution_option.tooltip_text = LocalizationManager.tr_key(
			"ui.start.resolution_tooltip",
			"Run standalone or exported build to change window resolution."
		)


func _populate_language_options() -> void:
	language_option.clear()
	for locale in LocalizationManager.available_locales():
		language_option.add_item(LocalizationManager.locale_display_name(locale))
		language_option.set_item_metadata(language_option.item_count - 1, locale)
	for i in range(language_option.item_count):
		if str(language_option.get_item_metadata(i)) == LocalizationManager.get_locale():
			language_option.select(i)
			return
	if language_option.item_count > 0:
		language_option.select(0)


func _on_language_option_item_selected(index: int) -> void:
	if index < 0 or index >= language_option.item_count:
		return
	var locale := str(language_option.get_item_metadata(index))
	if not locale.is_empty():
		LocalizationManager.set_locale(locale)


func _on_language_changed(_locale: String) -> void:
	_apply_localized_text()
	_populate_language_options()


func _apply_localized_text() -> void:
	title_label.text = LocalizationManager.tr_key("ui.start.brand_title", "MAG ARENA")
	subtitle_label.text = LocalizationManager.tr_key("ui.start.brand_subtitle", "MAGNETIC CORE COMBAT PROTOCOL")
	tagline_label.text = LocalizationManager.tr_key("ui.start.tagline", "LINK YOUR CORE. ENTER THE ARENA.")
	start_button.text = LocalizationManager.tr_key("ui.start.continue", "Continue Game")
	continue_status.text = LocalizationManager.tr_key("ui.start.no_save", "NO OPERATION RECORD FOUND")
	new_game_button.text = LocalizationManager.tr_key("ui.start.new_game", "New Game")
	weapon_skill_lab_button.text = LocalizationManager.tr_key("ui.start.weapon_skill_lab", "Weapon Skill Test Lab")
	settings_button.text = LocalizationManager.tr_key("ui.start.settings", "Settings")
	exit_button.text = LocalizationManager.tr_key("ui.start.exit", "Exit Game")
	var navigation_copy := LocalizationManager.tr_key("ui.start.navigation_hint", "WASD / ARROWS  SELECT")
	var action_separator := navigation_copy.rfind("  ")
	navigation_hint.text = navigation_copy.substr(action_separator + 2) \
			if action_separator >= 0 else navigation_copy
	confirm_hint.text = LocalizationManager.tr_key("ui.start.confirm_hint", "CONFIRM")
	back_hint.text = LocalizationManager.tr_key("ui.start.back_hint", "BACK")
	settings_title.text = LocalizationManager.tr_key("ui.start.settings", "Settings")
	settings_close_button.text = LocalizationManager.tr_key("ui.start.back", "Back")
	display_header.text = LocalizationManager.tr_key("ui.start.display_language", "DISPLAY & LANGUAGE")
	resolution_label.text = LocalizationManager.tr_key("ui.start.resolution", "Resolution")
	language_label.text = LocalizationManager.tr_key("ui.start.language", "Language")
	audio_header.text = LocalizationManager.tr_key("ui.start.audio", "AUDIO")
	assist_header.text = LocalizationManager.tr_key("ui.start.combat_assist", "COMBAT ASSIST")
	auto_aim_continuous_fire_toggle.text = LocalizationManager.tr_key("ui.settings.auto_aim_continuous_fire", "Auto aim continuous fire")
	auto_reload_switch_toggle.text = LocalizationManager.tr_key("ui.settings.auto_reload_switch", "Auto reload and switch weapon")
	settings_footer.text = LocalizationManager.tr_key("ui.start.settings_saved", "Changes are saved immediately")
	if audio_settings_controls and audio_settings_controls.has_method("refresh_texts"):
		audio_settings_controls.call("refresh_texts")


func _find_resolution_index(resolution: Vector2i) -> int:
	for i in range(RESOLUTION_PRESETS.size()):
		if RESOLUTION_PRESETS[i] == resolution:
			return i
	return -1


func _on_resolution_option_item_selected(index: int) -> void:
	if index >= 0 and index < RESOLUTION_PRESETS.size():
		display_settings.set_resolution(RESOLUTION_PRESETS[index])


func _on_auto_aim_continuous_fire_toggled(enabled: bool) -> void:
	PlayerAssistSettings.set_auto_aim_continuous_fire(enabled)


func _on_auto_reload_switch_toggled(enabled: bool) -> void:
	PlayerAssistSettings.set_auto_reload_switch(enabled)


func _play_intro_animation() -> void:
	main_column.modulate.a = 0.0
	build_info.modulate.a = 0.0
	var intro := create_tween().set_parallel(true)
	intro.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	intro.tween_property(main_column, "modulate:a", 1.0, 0.28)
	intro.tween_property(build_info, "modulate:a", 1.0, 0.42).set_delay(0.10)


func _prewarm_world_entry() -> void:
	if prewarm_state == PrewarmState.RUNNING or prewarm_state == PrewarmState.SUCCEEDED:
		return
	prewarm_state = PrewarmState.RUNNING
	prewarm_error = ""
	LoadingPerformance.mark("prewarm_started")
	var result: Dictionary = WORLD_ENTRY_PREPARE_GATE_SCRIPT.prepare_world_entry()
	await get_tree().process_frame
	SpawnData.ensure_loaded()
	DataHandler.prewarm_mecha_default_weapon(str(PlayerData.select_mecha_id))
	MODAL_UI_CONTROLLER_SCRIPT.prewarm_controls_hint_scene()
	var world_request_error := WORLD_SCENE_LOADER_SCRIPT.preload_world(WORLD_SCENE_PATH)
	if bool(result.get("ok", false)) and SpawnData.spawn_combat_profile != null and world_request_error == OK:
		prewarm_state = PrewarmState.SUCCEEDED
	else:
		prewarm_state = PrewarmState.FAILED
		prewarm_error = WORLD_ENTRY_PREPARE_GATE_SCRIPT.format_errors(result)
		if prewarm_error.is_empty():
			prewarm_error = "World entry resources failed to prewarm."
		push_error("World entry prewarm failed: %s" % prewarm_error)
	LoadingPerformance.mark("prewarm_finished")
	if OS.get_cmdline_user_args().has("--loading-benchmark"):
		if OS.get_cmdline_user_args().has("--loading-benchmark-idle"):
			await get_tree().create_timer(1.5).timeout
		new_game_button.call_deferred("_on_pressed")
