extends Node2D

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const GLOBAL_UI_THEME := preload("res://UI/themes/global_ui_theme.tres")

@onready var gui_root: Control = $CanvasLayer/GUI
@onready var background: ColorRect = $CanvasLayer/GUI/Background
@onready var margin_root: MarginContainer = $CanvasLayer/GUI/Background/HBoxMargin
@onready var title_label: Label = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/Title
@onready var start_button: Button = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/Start
@onready var new_game_button: Button = $"CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/New Game"
@onready var hp_safety_button: Button = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/HpSafetyToggle
@onready var resolution_label: Label = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/ResolutionLabel
@onready var mechas_label: Label = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MechaContainer/Mechas/CharTitile
@onready var menu_vbox: VBoxContainer = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer
@onready var resolution_option: OptionButton = $CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/ResolutionOption
var language_label: Label
var language_option: OptionButton

func _ready() -> void:
	gui_root.theme = GLOBAL_UI_THEME
	_set_full_rect(gui_root)
	_set_full_rect(background)
	_set_full_rect(margin_root)
	_ensure_language_option()
	_apply_localized_text()
	_populate_resolution_options()
	_populate_language_options()
	if not get_viewport().is_connected("size_changed", Callable(self, "_on_viewport_size_changed")):
		get_viewport().connect("size_changed", Callable(self, "_on_viewport_size_changed"))
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func _set_full_rect(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _populate_resolution_options() -> void:
	resolution_option.clear()
	for resolution: Vector2i in RESOLUTION_PRESETS:
		resolution_option.add_item("%sx%s" % [resolution.x, resolution.y])
	var selected_index: int = _find_resolution_index(DisplaySettings.resolution)
	if selected_index == -1:
		selected_index = _find_resolution_index(Vector2i(DisplayServer.window_get_size()))
	if selected_index >= 0:
		resolution_option.select(selected_index)
	if not resolution_option.is_connected("item_selected", Callable(self, "_on_resolution_option_item_selected")):
		resolution_option.connect("item_selected", Callable(self, "_on_resolution_option_item_selected"))
	if not DisplaySettings.can_apply_window_changes():
		resolution_option.disabled = true
		resolution_option.tooltip_text = LocalizationManager.tr_key(
			"ui.start.resolution_tooltip",
			"Run standalone or exported build to change window resolution."
		)

func _ensure_language_option() -> void:
	var existing_label := menu_vbox.get_node_or_null("LanguageLabel")
	if existing_label is Label:
		language_label = existing_label as Label
	else:
		language_label = Label.new()
		language_label.name = "LanguageLabel"
		menu_vbox.add_child(language_label)
	var existing_option := menu_vbox.get_node_or_null("LanguageOption")
	if existing_option is OptionButton:
		language_option = existing_option as OptionButton
	else:
		language_option = OptionButton.new()
		language_option.name = "LanguageOption"
		menu_vbox.add_child(language_option)
	if not language_option.is_connected("item_selected", Callable(self, "_on_language_option_item_selected")):
		language_option.connect("item_selected", Callable(self, "_on_language_option_item_selected"))

func _populate_language_options() -> void:
	if language_option == null:
		return
	language_option.clear()
	var locales := LocalizationManager.available_locales()
	for locale in locales:
		language_option.add_item(LocalizationManager.locale_display_name(locale))
		language_option.set_item_metadata(language_option.item_count - 1, locale)
	for i in range(language_option.item_count):
		if str(language_option.get_item_metadata(i)) == LocalizationManager.get_locale():
			language_option.select(i)
			return
	if language_option.item_count > 0:
		language_option.select(0)

func _on_language_option_item_selected(index: int) -> void:
	if language_option == null:
		return
	if index < 0 or index >= language_option.item_count:
		return
	var locale := str(language_option.get_item_metadata(index))
	if locale == "":
		return
	LocalizationManager.set_locale(locale)

func _on_language_changed(_locale: String) -> void:
	_apply_localized_text()
	_populate_language_options()

func _apply_localized_text() -> void:
	title_label.text = LocalizationManager.tr_key("ui.start.title", title_label.text)
	start_button.text = LocalizationManager.tr_key("ui.start.continue", start_button.text)
	new_game_button.text = LocalizationManager.tr_key("ui.start.new_game", new_game_button.text)
	resolution_label.text = LocalizationManager.tr_key("ui.start.resolution", resolution_label.text)
	mechas_label.text = LocalizationManager.tr_key("ui.start.mechas", mechas_label.text)
	if language_label:
		language_label.text = LocalizationManager.tr_key("ui.start.language", "Language")
	if hp_safety_button and hp_safety_button.has_method("_update_text"):
		hp_safety_button.call("_update_text")

func _find_resolution_index(resolution: Vector2i) -> int:
	for i: int in range(RESOLUTION_PRESETS.size()):
		if RESOLUTION_PRESETS[i] == resolution:
			return i
	return -1

func _on_resolution_option_item_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTION_PRESETS.size():
		return
	DisplaySettings.set_resolution(RESOLUTION_PRESETS[index])

func _on_viewport_size_changed() -> void:
	# Keep explicit full-rect layout when viewport changes in editor/runtime.
	_set_full_rect(gui_root)
	_set_full_rect(background)
	_set_full_rect(margin_root)
