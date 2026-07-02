extends Control
class_name RewardSelectionPanel

signal reward_confirmed(reward: RewardInfo)
signal selection_cancelled

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const PREVIEW_FORMATTER := preload("res://UI/scripts/weapon_obtain_preview_formatter.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: BoxContainer = $Panel/VBox/Options
@onready var detail_title_label: Label = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailVBox/DetailTitle") as Label
@onready var detail_vbox: VBoxContainer = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailVBox") as VBoxContainer
@onready var detail_body_label: Label = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailVBox/DetailBody") as Label
@onready var detail_outcome_label: Label = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailVBox/DetailOutcome") as Label
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
var _progress_index_cache: int = 0
var _progress_total_cache: int = 0
var _detail_chip_row: HBoxContainer

func _ready() -> void:
	visible = false
	if not confirm_button.is_connected("pressed", Callable(self, "_on_confirm_pressed")):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func _input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if not ModalUiController.is_cancel_input(event):
		return
	cancel_visible_modal()
	get_viewport().set_input_as_handled()

func open_for_rewards(
	route_display_name: String,
	reward_options: Array[RewardInfo],
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable(),
	allow_cancel: bool = true,
	title_override: String = "",
	subtitle_override: String = "",
	progress_index: int = 0,
	progress_total: int = 0
) -> bool:
	if reward_options.is_empty():
		return false
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	_allow_cancel = allow_cancel
	_route_display_name_cache = route_display_name
	_title_override_cache = title_override
	_subtitle_override_cache = subtitle_override
	_progress_index_cache = progress_index
	_progress_total_cache = progress_total
	_selected_index = -1
	_reward_options.clear()
	title_label.text = title_override if title_override != "" else LocalizationManager.tr_key("ui.reward.title", "Choose Reward")
	subtitle_label.text = _build_subtitle_text(route_display_name, subtitle_override, progress_index, progress_total)
	confirm_button.text = LocalizationManager.tr_key("ui.reward.confirm", "Confirm Reward")
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	cancel_button.visible = _allow_cancel
	cancel_button.disabled = not _allow_cancel
	_update_detail_panel({})
	for child in options_box.get_children():
		child.queue_free()
	var incoming_options := reward_options.duplicate()
	for reward in incoming_options:
		if reward == null:
			continue
		_reward_options.append(reward)
	if _reward_options.is_empty():
		return false
	for idx in range(_reward_options.size()):
		var button := _build_reward_card_button(_reward_options[idx])
		button.pressed.connect(Callable(self, "_on_reward_button_pressed").bind(idx, button))
		options_box.add_child(button)
	if options_box.get_child_count() > 0:
		var first := options_box.get_child(0) as Button
		if first:
			_on_reward_button_pressed(0, first)
	_confirm_button_state()
	visible = true
	return true

func _build_subtitle_text(
	route_display_name: String,
	subtitle_override: String,
	progress_index: int,
	progress_total: int
) -> String:
	var subtitle := subtitle_override if subtitle_override != "" else LocalizationManager.tr_format(
		"ui.reward.subtitle",
		{"route": route_display_name},
		"%s - pick one reward." % route_display_name
	)
	if progress_index <= 0 or progress_total <= 0:
		return subtitle
	var progress_text := LocalizationManager.tr_format(
		"ui.task_reward.progress",
		{"current": progress_index, "total": progress_total},
		"Reward %d/%d" % [progress_index, progress_total]
	)
	return "%s\n%s" % [subtitle, progress_text]

func close_panel() -> void:
	visible = false
	_reward_options.clear()
	_selected_index = -1
	_on_confirm = Callable()
	_on_cancel = Callable()
	_allow_cancel = true
	_title_override_cache = ""
	_subtitle_override_cache = ""
	_progress_index_cache = 0
	_progress_total_cache = 0
	_update_detail_panel({})

func is_modal_open() -> bool:
	return visible

func can_cancel_modal() -> bool:
	return _allow_cancel

func cancel_visible_modal() -> bool:
	if not is_modal_open() or not can_cancel_modal():
		return false
	_on_cancel_pressed()
	return true

func _on_reward_button_pressed(index: int, source_button: Button) -> void:
	_selected_index = index
	if index >= 0 and index < _reward_options.size():
		_update_detail_panel(_build_reward_display_data(_reward_options[index]))
	else:
		_update_detail_panel({})
	var child_index := 0
	for child in options_box.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button == source_button
		button.button_pressed = selected
		if child_index < _reward_options.size():
			_apply_reward_card_style(button, _reward_options[child_index], selected)
		child_index += 1
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

func _build_reward_card_button(reward: RewardInfo) -> Button:
	var card_data: Dictionary = _build_reward_display_data(reward)
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(210, 168)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	button.tooltip_text = str(card_data.get("title", "Reward"))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

	var rarity_bar := ColorRect.new()
	rarity_bar.color = RARITY_UTIL.get_color(reward.get_rarity())
	rarity_bar.custom_minimum_size = Vector2(0, 5)
	rarity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rarity_bar)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)

	header.add_child(_make_reward_icon(card_data))

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	header.add_child(text_box)

	var type_label := _make_card_label(str(card_data.get("type_label", "Reward")), 11, Color(0.72, 0.82, 0.9, 1.0))
	type_label.clip_text = true
	text_box.add_child(type_label)

	var name_label := _make_card_label(str(card_data.get("title", "Reward")), 16, Color(0.94, 0.97, 1.0, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0.0, 38.0)
	text_box.add_child(name_label)

	var meta_text := str(card_data.get("meta_text", "")).strip_edges()
	if meta_text != "":
		var meta_label := _make_card_label(meta_text, 11, Color(0.74, 0.84, 0.88, 1.0))
		meta_label.clip_text = true
		text_box.add_child(meta_label)

	var tag_text := str(card_data.get("short_tag", "")).strip_edges()
	var chips: Array = card_data.get("chips", [])
	if not chips.is_empty():
		var chip_row := BUILD_TAG_DISPLAY.make_chip_row(chips, 4)
		body.add_child(chip_row)
	elif tag_text != "":
		var tag_label := _make_card_label(tag_text, 12, Color(0.78, 0.86, 0.92, 1.0))
		tag_label.clip_text = true
		body.add_child(tag_label)

	_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_reward_card_style(button, reward, false)
	return button

func _build_reward_card_data(reward: RewardInfo) -> Dictionary:
	var data := {
		"type": "Economy",
		"name": LocalizationManager.tr_key("ui.reward.default", "Reward"),
		"tag": "",
	}
	if reward == null:
		return data
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon_name := reward.target_weapon_name.strip_edges()
		if weapon_name.strip_edges() == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		data["type"] = _format_reward_type_label(reward, "Weapon")
		data["name"] = weapon_name
		data["tag"] = "Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		return data
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		var definition := CellEffectRuntime.get_definition(reward.cell_effect_id)
		data["name"] = definition.get_display_name() if definition != null else "Cell Effect"
		data["type"] = _format_reward_type_label(reward, "Terrain")
		data["tag"] = "Cell Effect"
		return data
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var task_definition := CellTaskModuleRuntime.get_definition(reward.task_module_id)
		if task_definition != null:
			data["name"] = task_definition.get_display_name()
			data["tag"] = task_definition.get_task_label()
		else:
			data["name"] = "Task Module"
			data["tag"] = "Task"
		data["type"] = "Task"
		return data
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var base_weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		var weapon_text := base_weapon_text
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("predict_auto_fuse_weapon_obtain"):
			var outcome: Dictionary = PlayerData.player.predict_auto_fuse_weapon_obtain(reward.item_id)
			weapon_text = _format_weapon_obtain_prediction(base_weapon_text, weapon_name, outcome)
		data["type"] = _format_reward_type_label(reward, "Weapon")
		data["name"] = weapon_name
		data["tag"] = weapon_text if weapon_text != base_weapon_text else "Lv.%d" % int(reward.item_level)
		return data
	if reward.module_scene:
		var module_name := _extract_scene_name(reward.module_scene.resource_path)
		var module_id := reward.module_scene.resource_path.get_file().get_basename()
		if module_id != "":
			module_name = LocalizationManager.tr_key("module.%s.name" % module_id, module_name)
		data["type"] = _format_reward_type_label(reward, "Module")
		data["name"] = module_name
		data["tag"] = "Lv.%d" % max(1, reward.module_level)
		return data
	var economy_lines: PackedStringArray = []
	if reward.total_chip_value > 0:
		economy_lines.append(LocalizationManager.tr_format(
			"ui.reward.exp",
			{"value": reward.total_chip_value},
			"EXP +%d" % reward.total_chip_value
		))
	if reward.gold_value > 0:
		economy_lines.append(LocalizationManager.tr_format(
			"ui.reward.gold",
			{"value": reward.gold_value},
			"Gold +%d" % reward.gold_value
		))
	if not economy_lines.is_empty():
		var category := "Economy" if reward.gold_value > 0 or reward.reward_kind == RewardInfo.KIND_ECONOMY else "Supply"
		data["type"] = _format_reward_type_label(reward, category)
		data["name"] = economy_lines[0]
		if economy_lines.size() > 1:
			data["tag"] = economy_lines[1]
	return data

func _format_reward_type_label(_reward: RewardInfo, category: String) -> String:
	if _reward == null:
		return category
	if _reward.reward_kind == RewardInfo.KIND_CELL_EFFECT or _reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return category
	var rarity_label := RARITY_UTIL.get_display_name(_reward.get_rarity())
	if rarity_label == "" or rarity_label == RARITY_UTIL.get_display_name(RARITY_UTIL.COMMON):
		return category
	return "%s %s" % [rarity_label, category]

func _build_reward_display_data(reward: RewardInfo) -> Dictionary:
	var data := {
		"title": LocalizationManager.tr_key("ui.reward.default", "Reward"),
		"type_label": "Supply",
		"short_tag": "",
		"detail_text": "",
		"outcome_text": "",
		"rarity": RARITY_UTIL.COMMON,
		"chips": [],
		"meta_text": "",
		"icon_texture": null,
		"fallback_icon_key": "reward",
	}
	if reward == null:
		return data
	data["rarity"] = reward.get_rarity()
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon_name := reward.target_weapon_name.strip_edges()
		if weapon_name == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		data["title"] = weapon_name
		data["type_label"] = _format_reward_type_label(reward, "Weapon Upgrade")
		data["short_tag"] = "Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		data["meta_text"] = "%s · %s" % [str(data["short_tag"]), LocalizationManager.tr_key("ui.branch.weapon", "Weapon")]
		data["fallback_icon_key"] = "weapon"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"weapon", "Weapon")]
		var upgrade_detail := PackedStringArray([str(data["short_tag"])])
		var target_definition := DataHandler.read_weapon_data(reward.target_weapon_id) as WeaponDefinition
		if target_definition != null:
			data["icon_texture"] = target_definition.icon
			var description := LocalizationManager.get_weapon_description_from_definition(target_definition).strip_edges()
			if description != "":
				upgrade_detail.append(description)
		data["detail_text"] = "\n".join(upgrade_detail)
		data["outcome_text"] = "Upgrades the equipped weapon immediately"
		return data
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		var definition := CellEffectRuntime.get_definition(reward.cell_effect_id)
		if definition != null:
			data["title"] = definition.get_display_name()
			data["detail_text"] = definition.description.strip_edges()
			data["icon_texture"] = definition.icon_texture
		else:
			data["title"] = "Cell Effect"
		data["type_label"] = _format_reward_type_label(reward, "Terrain")
		data["short_tag"] = "Cell Effect"
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.cell_effect_meta", "Terrain Effect")
		data["fallback_icon_key"] = "terrain"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"terrain", "Terrain")]
		data["outcome_text"] = "Added to Cell Effects inventory"
		return data
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var task_definition := CellTaskModuleRuntime.get_definition(reward.task_module_id)
		if task_definition != null:
			data["title"] = task_definition.get_display_name()
			data["short_tag"] = "Task: %s" % task_definition.get_task_label()
			data["detail_text"] = task_definition.description.strip_edges()
			data["icon_texture"] = task_definition.icon_texture
			data["meta_text"] = "%s Task Module" % task_definition.get_task_label()
		else:
			data["title"] = "Task Module"
			data["short_tag"] = "Task: Unknown"
			data["meta_text"] = "Task Module"
		data["type_label"] = "Task Module"
		data["fallback_icon_key"] = "task"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"task", "Task")]
		data["outcome_text"] = "Added to Ready To Install. Deploy it from Board > Task Management before the next battle."
		return data
	var summary_chunks: PackedStringArray = []
	var detail_chunks: PackedStringArray = []
	data["type_label"] = _format_reward_type_label(reward, "Reward")
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var weapon_definition := DataHandler.read_weapon_data(reward.item_id) as WeaponDefinition
		var base_weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		var weapon_text := base_weapon_text
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("predict_auto_fuse_weapon_obtain"):
			var outcome: Dictionary = PlayerData.player.predict_auto_fuse_weapon_obtain(reward.item_id)
			weapon_text = _format_weapon_obtain_prediction(base_weapon_text, weapon_name, outcome)
		summary_chunks.append(weapon_name)
		detail_chunks.append(weapon_text)
		if weapon_definition != null:
			data["icon_texture"] = weapon_definition.icon
			var weapon_description := LocalizationManager.get_weapon_description_from_definition(weapon_definition).strip_edges()
			if weapon_description != "":
				detail_chunks.append(weapon_description)
		data["type_label"] = _format_reward_type_label(reward, "Weapon")
		data["meta_text"] = "Lv.%d · %s" % [int(reward.item_level), LocalizationManager.tr_key("ui.branch.weapon", "Weapon")]
		data["fallback_icon_key"] = "weapon"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"weapon", "Weapon")]
		data["outcome_text"] = "Obtained weapon is equipped, fused, stored, or converted based on current ownership"
	if reward.module_scene:
		var module_data := _build_module_reward_display_data(reward.module_scene, reward.module_level)
		var module_name := str(module_data.get("name", _extract_scene_name(reward.module_scene.resource_path)))
		var module_summary := LocalizationManager.tr_format(
			"ui.reward.module",
			{"name": module_name, "level": max(1, reward.module_level)},
			"Module %s Lv.%d" % [module_name, max(1, reward.module_level)]
		)
		summary_chunks.append(module_name)
		detail_chunks.append(module_summary)
		var module_short_tag := str(module_data.get("short_tag", "")).strip_edges()
		if module_short_tag != "":
			summary_chunks.append(module_short_tag)
		var module_detail := str(module_data.get("detail_text", "")).strip_edges()
		if module_detail != "":
			detail_chunks.append(module_detail)
		data["chips"] = module_data.get("chips", [])
		data["icon_texture"] = module_data.get("icon_texture", null)
		data["fallback_icon_key"] = "module"
		data["meta_text"] = "Lv.%d · %s" % [max(1, reward.module_level), _format_reward_type_label(reward, "Module")]
		data["type_label"] = _format_reward_type_label(reward, "Module")
		data["outcome_text"] = "Added to Temporary Modules; equip it now or manage it in the Rest Area"
	if reward.total_chip_value > 0:
		summary_chunks.append(LocalizationManager.tr_format(
			"ui.reward.exp",
			{"value": reward.total_chip_value},
			"EXP +%d" % reward.total_chip_value
		))
		data["chips"] = _append_display_chip(data.get("chips", []), BUILD_TAG_DISPLAY.build_tag_chip(&"economy", "Economy"))
		data["type_label"] = _format_reward_type_label(reward, "Economy")
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
		data["fallback_icon_key"] = "economy"
		data["outcome_text"] = "Added immediately to run resources"
	if reward.gold_value > 0:
		summary_chunks.append(LocalizationManager.tr_format(
			"ui.reward.gold",
			{"value": reward.gold_value},
			"Gold +%d" % reward.gold_value
		))
		data["chips"] = _append_display_chip(data.get("chips", []), BUILD_TAG_DISPLAY.build_tag_chip(&"economy", "Economy"))
		data["type_label"] = _format_reward_type_label(reward, "Economy")
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
		data["fallback_icon_key"] = "economy"
		data["outcome_text"] = "Added immediately to run resources"
	if not summary_chunks.is_empty():
		data["title"] = summary_chunks[0]
		if summary_chunks.size() > 1:
			data["short_tag"] = " + ".join(summary_chunks.slice(1))
		var detail_source: PackedStringArray = detail_chunks if not detail_chunks.is_empty() else summary_chunks
		data["detail_text"] = " + ".join(detail_source)
	return data

func _build_module_reward_display_data(module_scene: PackedScene, module_level: int) -> Dictionary:
	var data := {
		"name": "",
		"short_tag": "",
		"detail_text": "",
		"chips": [],
		"icon_texture": null,
	}
	if module_scene == null:
		return data
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		return data
	module_instance.set_module_level(max(1, module_level))
	data["name"] = LocalizationManager.get_module_name(module_instance)
	data["icon_texture"] = _get_module_texture(module_instance)
	var fit_data: Dictionary = MODULE_FIT_FORMATTER.build_display_data(module_instance, MODULE_FIT_FORMATTER.get_current_weapon())
	var effect_chips: Array = fit_data.get("effect_chips", [])
	var chips: Array = []
	chips.append(fit_data.get("fit_badge", {}))
	for chip in effect_chips:
		chips.append(chip)
	data["chips"] = chips
	var tag_parts := PackedStringArray()
	var fit_label := str(fit_data.get("fit_label", "")).strip_edges()
	if fit_label != "":
		tag_parts.append(fit_label)
	for label in BUILD_TAG_DISPLAY.chip_labels(effect_chips, 3):
		tag_parts.append(str(label))
	if not tag_parts.is_empty():
		data["short_tag"] = " / ".join(tag_parts)
	var descriptions := PackedStringArray()
	for detail_line in fit_data.get("detail_lines", PackedStringArray()):
		var fit_line := str(detail_line).strip_edges()
		if fit_line != "":
			descriptions.append(fit_line)
	var chip_labels := BUILD_TAG_DISPLAY.chip_labels(effect_chips, 4)
	if not chip_labels.is_empty():
		descriptions.append("Effect Tags: %s" % " / ".join(chip_labels))
	for description in module_instance.get_effect_descriptions():
		var line := str(description).strip_edges()
		if MODULE_FIT_FORMATTER.filter_effect_description(line):
			descriptions.append(line)
	data["detail_text"] = "\n".join(descriptions)
	module_instance.queue_free()
	return data

func _make_reward_icon(card_data: Dictionary) -> Control:
	var fallback_key := str(card_data.get("fallback_icon_key", "reward")).strip_edges()
	var chip := BUILD_TAG_DISPLAY.build_tag_chip(fallback_key)
	var accent: Color = chip.get("color", Color(0.54, 0.64, 0.72, 1.0))
	var frame := PanelContainer.new()
	frame.name = "RewardIconFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(56.0, 56.0)
	frame.add_theme_stylebox_override("panel", _make_icon_frame_style(accent))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	frame.add_child(margin)

	var texture := card_data.get("icon_texture", null) as Texture2D
	if texture != null:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = texture
		margin.add_child(icon)
	else:
		var fallback := Label.new()
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.text = _fallback_icon_text(fallback_key)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 17)
		fallback.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 1.0))
		margin.add_child(fallback)
	return frame

func _make_icon_frame_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.64)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _fallback_icon_text(icon_key: String) -> String:
	match icon_key:
		"weapon":
			return "W"
		"module":
			return "M"
		"terrain":
			return "T"
		"task":
			return "Q"
		"economy":
			return "$"
		_:
			return "R"

func _get_module_texture(module_instance: Module) -> Texture2D:
	if module_instance == null or not is_instance_valid(module_instance):
		return null
	var sprite_node := module_instance.get_node_or_null("%Sprite")
	if sprite_node and sprite_node is Sprite2D:
		return (sprite_node as Sprite2D).texture
	if module_instance.get("sprite") is Sprite2D:
		return (module_instance.get("sprite") as Sprite2D).texture
	return null

func _make_card_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _update_detail_panel(display_data: Dictionary) -> void:
	if detail_title_label == null or detail_body_label == null or detail_outcome_label == null:
		return
	var title := str(display_data.get("title", "")).strip_edges()
	var detail_text := str(display_data.get("detail_text", "")).strip_edges()
	var outcome_text := str(display_data.get("outcome_text", "")).strip_edges()
	detail_title_label.text = title if title != "" else LocalizationManager.tr_key("ui.reward.detail.title", "Reward Details")
	_update_detail_chip_row(display_data.get("chips", []))
	detail_body_label.text = detail_text if detail_text != "" else LocalizationManager.tr_key("ui.reward.detail.empty", "Select a reward to view details.")
	detail_outcome_label.text = outcome_text
	detail_outcome_label.visible = outcome_text != ""

func _update_detail_chip_row(chips: Array) -> void:
	if detail_vbox == null:
		return
	if _detail_chip_row == null or not is_instance_valid(_detail_chip_row):
		_detail_chip_row = BUILD_TAG_DISPLAY.make_chip_row([], 5)
		detail_vbox.add_child(_detail_chip_row)
		if detail_body_label != null:
			detail_vbox.move_child(_detail_chip_row, detail_body_label.get_index())
	BUILD_TAG_DISPLAY.populate_chip_row(_detail_chip_row, chips, 5)

func _append_display_chip(existing: Variant, chip: Dictionary) -> Array:
	var chips: Array = existing if existing is Array else []
	if chip.is_empty():
		return chips
	var source_key := str(chip.get("source_key", "")).strip_edges()
	for existing_chip in chips:
		if str((existing_chip as Dictionary).get("source_key", "")) == source_key:
			return chips
	chips.append(chip)
	return chips

func _apply_reward_card_style(button: Button, reward: RewardInfo, selected: bool) -> void:
	if button == null or reward == null:
		return
	var rarity_color: Color = RARITY_UTIL.get_color(reward.get_rarity())
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.085, 0.1, 0.95)
		if selected:
			style.bg_color = Color(0.13, 0.17, 0.2, 0.98)
		elif state == "hover" or state == "focus":
			style.bg_color = Color(0.1, 0.12, 0.14, 0.97)
		elif state == "pressed":
			style.bg_color = Color(0.12, 0.15, 0.18, 0.98)
		style.border_color = rarity_color
		style.set_border_width_all(4 if selected else 2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)

func _set_mouse_filter_recursive(root: Control, mouse_filter_value: Control.MouseFilter) -> void:
	for child in root.get_children():
		var control := child as Control
		if control == null:
			continue
		control.mouse_filter = mouse_filter_value
		_set_mouse_filter_recursive(control, mouse_filter_value)

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
			_subtitle_override_cache,
			_progress_index_cache,
			_progress_total_cache
		)
