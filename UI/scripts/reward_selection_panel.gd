extends Control
class_name RewardSelectionPanel

signal reward_confirmed(reward: RewardInfo)
signal selection_cancelled

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const PREVIEW_FORMATTER := preload("res://UI/scripts/weapon_obtain_preview_formatter.gd")

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: VBoxContainer = $Panel/VBox/Options
@onready var confirm_button: Button = $Panel/VBox/Footer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/Footer/CancelButton

var _reward_options: Array[RewardInfo] = []
var _selected_index: int = -1
var _on_confirm: Callable = Callable()
var _on_cancel: Callable = Callable()
var _route_display_name_cache: String = ""
var _allow_cancel: bool = true
var _title_override_cache: String = ""
var _subtitle_override_cache: String = ""

func _ready() -> void:
	visible = false
	if not confirm_button.is_connected("pressed", Callable(self, "_on_confirm_pressed")):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func open_for_rewards(
	route_display_name: String,
	reward_options: Array[RewardInfo],
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable(),
	allow_cancel: bool = true,
	title_override: String = "",
	subtitle_override: String = ""
) -> bool:
	if reward_options.is_empty():
		return false
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	_allow_cancel = allow_cancel
	_route_display_name_cache = route_display_name
	_title_override_cache = title_override
	_subtitle_override_cache = subtitle_override
	_selected_index = -1
	_reward_options.clear()
	title_label.text = title_override if title_override != "" else LocalizationManager.tr_key("ui.reward.title", "Choose Reward")
	subtitle_label.text = subtitle_override if subtitle_override != "" else LocalizationManager.tr_format(
		"ui.reward.subtitle",
		{"route": route_display_name},
		"%s - pick one reward." % route_display_name
	)
	confirm_button.text = LocalizationManager.tr_key("ui.reward.confirm", "Confirm Reward")
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	cancel_button.visible = _allow_cancel
	cancel_button.disabled = not _allow_cancel
	for child in options_box.get_children():
		child.queue_free()
	for reward in reward_options:
		if reward == null:
			continue
		_reward_options.append(reward)
	if _reward_options.is_empty():
		return false
	for idx in range(_reward_options.size()):
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 58)
		button.text = _build_reward_summary(_reward_options[idx])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_reward_button_rarity_style(button, _reward_options[idx])
		button.pressed.connect(Callable(self, "_on_reward_button_pressed").bind(idx, button))
		options_box.add_child(button)
	if options_box.get_child_count() > 0:
		var first := options_box.get_child(0) as Button
		if first:
			_on_reward_button_pressed(0, first)
	_confirm_button_state()
	visible = true
	return true

func close_panel() -> void:
	visible = false
	_reward_options.clear()
	_selected_index = -1
	_on_confirm = Callable()
	_on_cancel = Callable()
	_allow_cancel = true
	_title_override_cache = ""
	_subtitle_override_cache = ""

func _on_reward_button_pressed(index: int, source_button: Button) -> void:
	_selected_index = index
	for child in options_box.get_children():
		var button := child as Button
		if button == null:
			continue
		button.button_pressed = (button == source_button)
	_confirm_button_state()

func _confirm_button_state() -> void:
	confirm_button.disabled = _selected_index < 0 or _selected_index >= _reward_options.size()

func _on_confirm_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _reward_options.size():
		return
	var reward := _reward_options[_selected_index]
	reward_confirmed.emit(reward)
	if _on_confirm.is_valid():
		_on_confirm.call_deferred(reward)
	close_panel()

func _on_cancel_pressed() -> void:
	if not _allow_cancel:
		return
	selection_cancelled.emit()
	if _on_cancel.is_valid():
		_on_cancel.call_deferred()
	close_panel()

func _build_reward_summary(reward: RewardInfo) -> String:
	var chunks: PackedStringArray = []
	chunks.append("[%s]" % RARITY_UTIL.get_display_name(reward.get_rarity()))
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon_name := reward.target_weapon_name
		if weapon_name.strip_edges() == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		chunks.append(LocalizationManager.tr_format(
			"ui.reward.weapon_upgrade",
			{
				"name": weapon_name,
				"from": int(reward.target_weapon_from_level),
				"to": int(reward.target_weapon_to_level),
			},
			"Upgrade %s Lv.%d -> Lv.%d" % [
				weapon_name,
				int(reward.target_weapon_from_level),
				int(reward.target_weapon_to_level),
			]
		))
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("predict_auto_fuse_weapon_obtain"):
			var outcome: Dictionary = PlayerData.player.predict_auto_fuse_weapon_obtain(reward.item_id)
			weapon_text = _format_weapon_obtain_prediction(weapon_text, weapon_name, outcome)
		chunks.append(weapon_text)
	if reward.module_scene:
		var module_name := _extract_scene_name(reward.module_scene.resource_path)
		var module_id := reward.module_scene.resource_path.get_file().get_basename()
		if module_id != "":
			module_name = LocalizationManager.tr_key("module.%s.name" % module_id, module_name)
		chunks.append(LocalizationManager.tr_format(
			"ui.reward.module",
			{"name": module_name, "level": max(1, reward.module_level)},
			"Module %s Lv.%d" % [module_name, max(1, reward.module_level)]
		))
	if reward.total_chip_value > 0:
		chunks.append(LocalizationManager.tr_format(
			"ui.reward.exp",
			{"value": reward.total_chip_value},
			"EXP +%d" % reward.total_chip_value
		))
	if reward.gold_value > 0:
		chunks.append(LocalizationManager.tr_format(
			"ui.reward.gold",
			{"value": reward.gold_value},
			"Gold +%d" % reward.gold_value
		))
	if chunks.is_empty():
		return LocalizationManager.tr_key("ui.reward.default", "Reward")
	return " + ".join(chunks)

func _apply_reward_button_rarity_style(button: Button, reward: RewardInfo) -> void:
	if button == null or reward == null:
		return
	var rarity_color: Color = RARITY_UTIL.get_color(reward.get_rarity())
	button.add_theme_color_override("font_color", rarity_color)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.08, 0.92)
		if state == "hover" or state == "pressed":
			style.bg_color = Color(0.14, 0.14, 0.14, 0.96)
		style.border_color = rarity_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)

func _extract_scene_name(scene_path: String) -> String:
	if scene_path == "":
		return "Unknown"
	var file_name := scene_path.get_file().get_basename()
	if file_name == "":
		return "Unknown"
	return file_name.replace("_", " ").capitalize()

func _format_weapon_obtain_prediction(base_text: String, weapon_name: String, outcome: Dictionary) -> String:
	return PREVIEW_FORMATTER.format_obtain_preview(base_text, weapon_name, outcome)

func _on_language_changed(_locale: String) -> void:
	if visible:
		open_for_rewards(
			_route_display_name_cache,
			_reward_options,
			_on_confirm,
			_on_cancel,
			_allow_cancel,
			_title_override_cache,
			_subtitle_override_cache
		)
