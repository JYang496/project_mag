extends RefCounted
class_name PauseUiController

const AUDIO_SETTINGS_CONTROLS_SCENE := preload("res://UI/components/AudioSettingsControls/AudioSettingsControls.tscn")

var owner_ui: UI
var pause_menu_panel: PanelContainer
var resume_button: Button
var pause_language_label: Label
var pause_language_option: OptionButton
var temporary_module_confirm_toggle: CheckButton
var auto_aim_continuous_fire_toggle: CheckButton
var auto_reload_switch_toggle: CheckButton
var controls_hint_label: Label
var controls_hint_option: OptionButton
var audio_settings_controls: VBoxContainer

func bind(ui: UI, panel: PanelContainer, resume: Button) -> void:
	owner_ui = ui
	pause_menu_panel = panel
	resume_button = resume

func ensure_language_controls() -> void:
	if pause_menu_panel == null:
		return
	var pause_label := pause_menu_panel.find_child("Paused", true, false) as Label
	if pause_label:
		pause_label.text = LocalizationManager.tr_key("ui.panel.pause", "Paused")
	if resume_button:
		resume_button.text = LocalizationManager.tr_key("ui.panel.resume", "Resume")
	_ensure_audio_settings_controls()
	var existing_label := pause_menu_panel.find_child("LanguageLabel", true, false)
	if existing_label is Label:
		pause_language_label = existing_label as Label
	var existing_option := pause_menu_panel.find_child("LanguageOption", true, false)
	if existing_option is OptionButton:
		pause_language_option = existing_option as OptionButton
	if pause_language_option != null and not pause_language_option.is_connected("item_selected", Callable(self, "on_language_option_item_selected")):
		pause_language_option.connect("item_selected", Callable(self, "on_language_option_item_selected"))
	temporary_module_confirm_toggle = pause_menu_panel.find_child("TemporaryModuleConfirmToggle", true, false) as CheckButton
	if temporary_module_confirm_toggle != null and not temporary_module_confirm_toggle.toggled.is_connected(on_temporary_module_confirm_toggled):
		temporary_module_confirm_toggle.toggled.connect(on_temporary_module_confirm_toggled)
	auto_aim_continuous_fire_toggle = _ensure_assist_toggle(
		"AutoAimContinuousFireToggle",
		on_auto_aim_continuous_fire_toggled
	)
	auto_reload_switch_toggle = _ensure_assist_toggle(
		"AutoReloadSwitchToggle",
		on_auto_reload_switch_toggled
	)
	controls_hint_label = pause_menu_panel.find_child("ControlsHintLabel", true, false) as Label
	controls_hint_option = pause_menu_panel.find_child("ControlsHintOption", true, false) as OptionButton
	if controls_hint_option != null and not controls_hint_option.item_selected.is_connected(on_controls_hint_option_selected):
		controls_hint_option.item_selected.connect(on_controls_hint_option_selected)
	refresh_texts()
	_sync_public_fields_to_owner()

func refresh_texts() -> void:
	var pause_label := pause_menu_panel.find_child("Paused", true, false) as Label if pause_menu_panel else null
	if pause_label:
		pause_label.text = LocalizationManager.tr_key("ui.panel.pause", "Paused")
	if resume_button:
		resume_button.text = LocalizationManager.tr_key("ui.panel.resume", "Resume")
	_set_section_text("AudioHeader", LocalizationManager.tr_key("ui.start.audio", "Audio"))
	_set_section_text("InterfaceHeader", LocalizationManager.tr_key("ui.start.display_language", "Display & Language"))
	_set_section_text("AssistHeader", LocalizationManager.tr_key("ui.start.combat_assist", "Combat Assist"))
	_set_section_text("SettingsFooter", LocalizationManager.tr_key("ui.start.settings_saved", "Changes are saved immediately"))
	refresh_language_options()

func refresh_language_options() -> void:
	if audio_settings_controls:
		audio_settings_controls.call("refresh_texts")
		audio_settings_controls.call("refresh_values")
	if pause_language_label:
		pause_language_label.text = LocalizationManager.tr_key("ui.settings.language", "Language")
	if pause_language_option == null:
		_sync_public_fields_to_owner()
		return
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
		temporary_module_confirm_toggle.text = LocalizationManager.tr_key(
			"ui.settings.confirm_temporary_module_sale",
			"Confirm temporary module sale before battle"
		)
		temporary_module_confirm_toggle.button_pressed = _is_temporary_module_confirmation_enabled()
	if auto_aim_continuous_fire_toggle:
		auto_aim_continuous_fire_toggle.text = LocalizationManager.tr_key(
			"ui.settings.auto_aim_continuous_fire",
			"Auto aim continuous fire"
		)
		auto_aim_continuous_fire_toggle.button_pressed = bool(PlayerAssistSettings.auto_aim_continuous_fire)
	if auto_reload_switch_toggle:
		auto_reload_switch_toggle.text = LocalizationManager.tr_key(
			"ui.settings.auto_reload_switch",
			"Auto reload and switch weapon"
		)
		auto_reload_switch_toggle.button_pressed = bool(PlayerAssistSettings.auto_reload_switch)
	if controls_hint_label:
		controls_hint_label.text = LocalizationManager.tr_key("ui.settings.controls_hint", "Controls")
		controls_hint_label.tooltip_text = LocalizationManager.tr_key(
			"ui.settings.controls_hint.tooltip",
			"Adaptive opens new hints and lets F1 collapse them. Always Expanded keeps hints open. Hidden hides the panel."
		)
	if controls_hint_option:
		controls_hint_option.tooltip_text = LocalizationManager.tr_key(
			"ui.settings.controls_hint.tooltip",
			"Adaptive opens new hints and lets F1 collapse them. Always Expanded keeps hints open. Hidden hides the panel."
		)
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
	var toggle := pause_menu_panel.find_child(node_name, true, false) as CheckButton
	if toggle != null and not toggle.toggled.is_connected(callback):
		toggle.toggled.connect(callback)
	return toggle

func _ensure_audio_settings_controls() -> void:
	var existing := pause_menu_panel.find_child("AudioSettingsControls", true, false)
	if existing is VBoxContainer:
		audio_settings_controls = existing as VBoxContainer
	else:
		audio_settings_controls = AUDIO_SETTINGS_CONTROLS_SCENE.instantiate() as VBoxContainer
		audio_settings_controls.name = "AudioSettingsControls"
		var audio_slot := pause_menu_panel.find_child("AudioSlot", true, false) as Control
		var target_parent := audio_slot if audio_slot != null else _get_content_root()
		target_parent.add_child(audio_settings_controls)

func _get_content_root() -> Control:
	var content := pause_menu_panel.find_child("Content", true, false) as Control if pause_menu_panel else null
	return content if content != null else pause_menu_panel

func _set_section_text(node_name: String, text: String) -> void:
	var label := pause_menu_panel.find_child(node_name, true, false) as Label if pause_menu_panel else null
	if label != null:
		label.text = text

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
