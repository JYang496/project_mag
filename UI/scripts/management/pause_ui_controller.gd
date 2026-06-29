extends RefCounted
class_name PauseUiController

var owner_ui: UI
var pause_menu_panel: Panel
var resume_button: Button
var pause_language_label: Label
var pause_language_option: OptionButton
var temporary_module_confirm_toggle: CheckButton
var auto_aim_continuous_fire_toggle: CheckButton
var auto_reload_switch_toggle: CheckButton
var controls_hint_label: Label
var controls_hint_option: OptionButton

func bind(ui: UI, panel: Panel, resume: Button) -> void:
	owner_ui = ui
	pause_menu_panel = panel
	resume_button = resume

func ensure_language_controls() -> void:
	if pause_menu_panel == null:
		return
	var pause_label := pause_menu_panel.get_node_or_null("Paused") as Label
	if pause_label:
		pause_label.text = LocalizationManager.tr_key("ui.panel.pause", "Paused")
	if resume_button:
		resume_button.text = LocalizationManager.tr_key("ui.panel.resume", "Resume")
	var existing_label := pause_menu_panel.get_node_or_null("LanguageLabel")
	if existing_label is Label:
		pause_language_label = existing_label as Label
	else:
		pause_language_label = Label.new()
		pause_language_label.name = "LanguageLabel"
		pause_menu_panel.add_child(pause_language_label)
	var existing_option := pause_menu_panel.get_node_or_null("LanguageOption")
	if existing_option is OptionButton:
		pause_language_option = existing_option as OptionButton
	else:
		pause_language_option = OptionButton.new()
		pause_language_option.name = "LanguageOption"
		pause_menu_panel.add_child(pause_language_option)
	if not pause_language_option.is_connected("item_selected", Callable(self, "on_language_option_item_selected")):
		pause_language_option.connect("item_selected", Callable(self, "on_language_option_item_selected"))
	temporary_module_confirm_toggle = pause_menu_panel.get_node_or_null("TemporaryModuleConfirmToggle") as CheckButton
	if temporary_module_confirm_toggle == null:
		temporary_module_confirm_toggle = CheckButton.new()
		temporary_module_confirm_toggle.name = "TemporaryModuleConfirmToggle"
		pause_menu_panel.add_child(temporary_module_confirm_toggle)
	if not temporary_module_confirm_toggle.toggled.is_connected(on_temporary_module_confirm_toggled):
		temporary_module_confirm_toggle.toggled.connect(on_temporary_module_confirm_toggled)
	auto_aim_continuous_fire_toggle = _ensure_assist_toggle(
		"AutoAimContinuousFireToggle",
		on_auto_aim_continuous_fire_toggled
	)
	auto_reload_switch_toggle = _ensure_assist_toggle(
		"AutoReloadSwitchToggle",
		on_auto_reload_switch_toggled
	)
	controls_hint_label = pause_menu_panel.get_node_or_null("ControlsHintLabel") as Label
	if controls_hint_label == null:
		controls_hint_label = Label.new()
		controls_hint_label.name = "ControlsHintLabel"
		pause_menu_panel.add_child(controls_hint_label)
	controls_hint_option = pause_menu_panel.get_node_or_null("ControlsHintOption") as OptionButton
	if controls_hint_option == null:
		controls_hint_option = OptionButton.new()
		controls_hint_option.name = "ControlsHintOption"
		pause_menu_panel.add_child(controls_hint_option)
	if not controls_hint_option.item_selected.is_connected(on_controls_hint_option_selected):
		controls_hint_option.item_selected.connect(on_controls_hint_option_selected)
	refresh_language_options()
	_sync_public_fields_to_owner()

func refresh_texts() -> void:
	var pause_label := pause_menu_panel.get_node_or_null("Paused") as Label if pause_menu_panel else null
	if pause_label:
		pause_label.text = LocalizationManager.tr_key("ui.panel.pause", "Paused")
	if resume_button:
		resume_button.text = LocalizationManager.tr_key("ui.panel.resume", "Resume")
	refresh_language_options()

func refresh_language_options() -> void:
	if pause_language_label:
		pause_language_label.text = LocalizationManager.tr_key("ui.settings.language", "Language")
		pause_language_label.position = Vector2(72.0, 324.0)
		pause_language_label.size = Vector2(110.0, 28.0)
	if pause_language_option == null:
		_sync_public_fields_to_owner()
		return
	pause_language_option.position = Vector2(184.0, 320.0)
	pause_language_option.size = Vector2(148.0, 30.0)
	pause_language_option.clear()
	var locales := LocalizationManager.available_locales()
	var selected_idx := -1
	var current_locale := LocalizationManager.get_locale()
	for i in range(locales.size()):
		var locale := str(locales[i])
		pause_language_option.add_item(LocalizationManager.locale_display_name(locale))
		pause_language_option.set_item_metadata(i, locale)
		if locale == current_locale:
			selected_idx = i
	if selected_idx >= 0:
		pause_language_option.select(selected_idx)
	if temporary_module_confirm_toggle:
		temporary_module_confirm_toggle.position = Vector2(72.0, 366.0)
		temporary_module_confirm_toggle.size = Vector2(310.0, 30.0)
		temporary_module_confirm_toggle.text = LocalizationManager.tr_key(
			"ui.settings.confirm_temporary_module_sale",
			"Confirm temporary module sale before battle"
		)
		temporary_module_confirm_toggle.button_pressed = _is_temporary_module_confirmation_enabled()
	if auto_aim_continuous_fire_toggle:
		auto_aim_continuous_fire_toggle.position = Vector2(72.0, 404.0)
		auto_aim_continuous_fire_toggle.size = Vector2(310.0, 30.0)
		auto_aim_continuous_fire_toggle.text = LocalizationManager.tr_key(
			"ui.settings.auto_aim_continuous_fire",
			"Auto aim continuous fire"
		)
		auto_aim_continuous_fire_toggle.button_pressed = bool(PlayerAssistSettings.auto_aim_continuous_fire)
	if auto_reload_switch_toggle:
		auto_reload_switch_toggle.position = Vector2(72.0, 442.0)
		auto_reload_switch_toggle.size = Vector2(310.0, 30.0)
		auto_reload_switch_toggle.text = LocalizationManager.tr_key(
			"ui.settings.auto_reload_switch",
			"Auto reload and switch weapon"
		)
		auto_reload_switch_toggle.button_pressed = bool(PlayerAssistSettings.auto_reload_switch)
	if controls_hint_label:
		controls_hint_label.position = Vector2(72.0, 482.0)
		controls_hint_label.size = Vector2(110.0, 30.0)
		controls_hint_label.text = LocalizationManager.tr_key("ui.settings.controls_hint", "Controls")
	if controls_hint_option:
		controls_hint_option.position = Vector2(184.0, 480.0)
		controls_hint_option.size = Vector2(148.0, 30.0)
		controls_hint_option.clear()
		var modes: Array[StringName] = [
			PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE,
			PlayerAssistSettings.CONTROLS_HINT_ALWAYS,
			PlayerAssistSettings.CONTROLS_HINT_HIDDEN,
		]
		var selected_mode_index := 0
		for index in range(modes.size()):
			var mode := modes[index]
			controls_hint_option.add_item(_controls_hint_mode_label(mode))
			controls_hint_option.set_item_metadata(index, mode)
			if mode == PlayerAssistSettings.controls_hint_mode:
				selected_mode_index = index
		controls_hint_option.select(selected_mode_index)
	_sync_public_fields_to_owner()

func on_language_option_item_selected(index: int) -> void:
	if pause_language_option == null:
		return
	var locale := str(pause_language_option.get_item_metadata(index))
	if locale != "":
		LocalizationManager.set_locale(locale)

func on_temporary_module_confirm_toggled(enabled: bool) -> void:
	_set_temporary_module_confirmation_enabled(enabled)
	_sync_public_fields_to_owner()

func on_auto_aim_continuous_fire_toggled(enabled: bool) -> void:
	PlayerAssistSettings.set_auto_aim_continuous_fire(enabled)
	_sync_public_fields_to_owner()

func on_auto_reload_switch_toggled(enabled: bool) -> void:
	PlayerAssistSettings.set_auto_reload_switch(enabled)
	_sync_public_fields_to_owner()

func on_controls_hint_option_selected(index: int) -> void:
	if controls_hint_option == null or index < 0 or index >= controls_hint_option.item_count:
		return
	var mode := StringName(str(controls_hint_option.get_item_metadata(index)))
	PlayerAssistSettings.set_controls_hint_mode(mode)

func _controls_hint_mode_label(mode: StringName) -> String:
	match mode:
		PlayerAssistSettings.CONTROLS_HINT_ALWAYS:
			return LocalizationManager.tr_key("ui.settings.controls_hint.always", "Always Expanded")
		PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
			return LocalizationManager.tr_key("ui.settings.controls_hint.hidden", "Hidden")
		_:
			return LocalizationManager.tr_key("ui.settings.controls_hint.adaptive", "Adaptive")

func _ensure_assist_toggle(node_name: String, callback: Callable) -> CheckButton:
	var toggle := pause_menu_panel.get_node_or_null(node_name) as CheckButton
	if toggle == null:
		toggle = CheckButton.new()
		toggle.name = node_name
		pause_menu_panel.add_child(toggle)
	if not toggle.toggled.is_connected(callback):
		toggle.toggled.connect(callback)
	return toggle

func _is_temporary_module_confirmation_enabled() -> bool:
	if owner_ui != null:
		return bool(owner_ui.call("_is_temporary_module_confirmation_enabled"))
	return true

func _set_temporary_module_confirmation_enabled(enabled: bool) -> void:
	if owner_ui != null:
		owner_ui.call("_set_temporary_module_confirmation_enabled", enabled)

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui.pause_language_label = pause_language_label
	owner_ui.pause_language_option = pause_language_option
	owner_ui.temporary_module_confirm_toggle = temporary_module_confirm_toggle
