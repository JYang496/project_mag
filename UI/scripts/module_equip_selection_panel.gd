extends PanelContainer
class_name ModuleEquipSelectionPanel

signal selection_completed(assigned: bool)

@export var incompatible_slot_color: Color = Color(0.25, 0.25, 0.25, 1.0)
@export var occupied_slot_color: Color = Color(0.45, 0.45, 0.45, 1.0)
@export var available_slot_color: Color = Color(0.18, 0.42, 0.18, 1.0)
@export var feedback_text_color: Color = Color(0.95, 0.75, 0.35, 1.0)
@export var stat_up_color: Color = Color(0.65, 0.95, 0.65, 1.0)
@export var stat_down_color: Color = Color(0.95, 0.65, 0.65, 1.0)

@onready var title_label: Label = $Margin/Root/TitleLabel
@onready var module_label: Label = $Margin/Root/ModuleLabel
@onready var equipped_list: VBoxContainer = $Margin/Root/Columns/EquippedPanel/EquippedList
@onready var inventory_list: VBoxContainer = $Margin/Root/Columns/InventoryPanel/InventoryList
@onready var cancel_button: Button = $Margin/Root/Footer/CancelButton

var _module_instance: Module
var _on_complete: Callable = Callable()
var _tracked_stat_keys: PackedStringArray = [
	"damage",
	"attack_cooldown",
	"projectile_hits",
	"speed",
	"size",
	"hp",
	"dash_speed",
	"return_speed",
	"attack_range",
]

func _ready() -> void:
	visible = false
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func open_for_module(module_instance: Module, on_complete: Callable = Callable()) -> bool:
	if module_instance == null:
		return false
	_module_instance = module_instance
	_on_complete = on_complete
	title_label.text = LocalizationManager.tr_key("ui.module.title", "Equip Module")
	var effect_lines := _module_instance.get_effect_descriptions()
	var effect_summary := LocalizationManager.tr_key("ui.module.no_effect", "No direct stat changes.")
	if not effect_lines.is_empty():
		effect_summary = LocalizationManager.tr_format("ui.module.effects", {"effects": ", ".join(effect_lines)}, "Effects: %s" % ", ".join(effect_lines))
	module_label.text = "%s Lv.%d - %s" % [
		LocalizationManager.get_module_name(_module_instance),
		_module_instance.module_level,
		effect_summary
	]
	_rebuild_lists()
	visible = true
	return true

func _rebuild_lists() -> void:
	_clear_list(equipped_list)
	_clear_list(inventory_list)
	_build_weapon_section(equipped_list, _collect_equipped_weapons(), true)
	_build_weapon_section(inventory_list, _collect_inventory_weapons(), false)

func _collect_equipped_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon: Weapon = weapon_ref as Weapon
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func _collect_inventory_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon_ref in InventoryData.inventory_slots:
		var weapon: Weapon = weapon_ref as Weapon
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func _build_weapon_section(parent: VBoxContainer, weapons: Array[Weapon], is_equipped_section: bool) -> void:
	var section_header: Label = Label.new()
	section_header.text = LocalizationManager.tr_key(
		"ui.module.section.equipped" if is_equipped_section else "ui.module.section.inventory",
		"Equipped Weapons" if is_equipped_section else "Inventory Weapons"
	)
	parent.add_child(section_header)
	if weapons.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = LocalizationManager.tr_key("ui.module.none", "(none)")
		parent.add_child(empty_label)
		return
	for weapon in weapons:
		_build_weapon_row(parent, weapon)

func _build_weapon_row(parent: VBoxContainer, weapon: Weapon) -> void:
	var card: VBoxContainer = VBoxContainer.new()
	parent.add_child(card)

	var header_row: HBoxContainer = HBoxContainer.new()
	card.add_child(header_row)

	var weapon_name_label: Label = Label.new()
	weapon_name_label.text = _get_weapon_display_name(weapon)
	weapon_name_label.custom_minimum_size = Vector2(170, 0)
	header_row.add_child(weapon_name_label)

	var slot_state_label: Label = Label.new()
	slot_state_label.text = LocalizationManager.tr_format(
		"ui.module.slots",
		{"used": weapon.get_module_count(), "max": int(weapon.MAX_MODULE_NUMBER)},
		"Slots: %d/%d" % [weapon.get_module_count(), int(weapon.MAX_MODULE_NUMBER)]
	)
	slot_state_label.custom_minimum_size = Vector2(100, 0)
	header_row.add_child(slot_state_label)

	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(116, 28)
	header_row.add_child(action_button)

	var feedback := InventoryData.get_weapon_module_assignment_feedback(_module_instance, weapon)
	var can_equip: bool = bool(feedback.get("ok", false))
	if can_equip:
		action_button.text = LocalizationManager.tr_key("ui.module.action.equip", "Equip")
		action_button.disabled = false
		action_button.modulate = available_slot_color
		action_button.pressed.connect(_on_slot_selected.bind(weapon))
	else:
		action_button.text = LocalizationManager.tr_key("ui.module.action.blocked", "Blocked")
		action_button.disabled = true
		action_button.modulate = incompatible_slot_color

	var modules_line := Label.new()
	modules_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modules_line.text = _build_equipped_modules_line(weapon)
	card.add_child(modules_line)

	var stats_line := Label.new()
	stats_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_line.text = _build_stat_preview_line(weapon)
	card.add_child(stats_line)

	var feedback_line := Label.new()
	feedback_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if can_equip:
		feedback_line.text = LocalizationManager.tr_key("ui.module.compatible", "Compatible")
		feedback_line.modulate = stat_up_color
	else:
		var reason := LocalizationManager.localize_module_reason(str(feedback.get("reason", "Unknown reason")))
		feedback_line.text = LocalizationManager.tr_format("ui.module.cannot_equip", {"reason": reason}, "Cannot equip: %s" % reason)
		feedback_line.modulate = feedback_text_color
	card.add_child(feedback_line)

func _on_slot_selected(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon) or _module_instance == null:
		_complete(false)
		return
	var result := InventoryData.equip_module_to_weapon(_module_instance, weapon)
	if not result.get("ok", false):
		var ui_fail = GlobalVariables.ui
		if ui_fail and is_instance_valid(ui_fail) and ui_fail.has_method("show_item_message"):
			var reason := LocalizationManager.localize_module_reason(str(result.get("reason", "")))
			ui_fail.show_item_message(
				LocalizationManager.tr_format("ui.module.cannot_equip", {"reason": reason}, "Cannot equip: %s" % reason),
				1.8
			)
		_complete(false)
		return
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui):
		if ui.has_method("show_item_message"):
			ui.show_item_message(
				LocalizationManager.tr_format("ui.module.equipped_message", {
					"module": LocalizationManager.get_module_name(_module_instance),
					"level": _module_instance.module_level,
					"weapon": _get_weapon_display_name(weapon)
				}, "Equipped %s Lv.%d to %s" % [
					LocalizationManager.get_module_name(_module_instance),
					_module_instance.module_level,
					_get_weapon_display_name(weapon)
				]),
				2.0
			)
	_complete(true)

func _on_cancel_pressed() -> void:
	_complete(false)

func _complete(assigned: bool) -> void:
	visible = false
	emit_signal("selection_completed", assigned)
	if _on_complete.is_valid():
		_on_complete.call_deferred(assigned)
	_on_complete = Callable()

func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _get_weapon_display_name(weapon: Weapon) -> String:
	return LocalizationManager.get_weapon_name_from_node(weapon)

func _build_equipped_modules_line(weapon: Weapon) -> String:
	var equipped_names: PackedStringArray = []
	for module_instance in weapon.get_equipped_modules():
		equipped_names.append("%s Lv.%d" % [
			LocalizationManager.get_module_name(module_instance),
			int(module_instance.module_level)
		])
	if equipped_names.is_empty():
		return LocalizationManager.tr_key("ui.module.equipped_modules_none", "Equipped modules: none")
	return LocalizationManager.tr_format("ui.module.equipped_modules", {"modules": ", ".join(equipped_names)}, "Equipped modules: %s" % ", ".join(equipped_names))

func _build_stat_preview_line(weapon: Weapon) -> String:
	var current: Dictionary = weapon.build_stat_snapshot()
	var projected: Dictionary = weapon.get_projected_stats_with_module(_module_instance)
	var deltas: PackedStringArray = []
	for stat_key in _tracked_stat_keys:
		if not current.has(stat_key) or not projected.has(stat_key):
			continue
		var before := float(current[stat_key])
		var after := float(projected[stat_key])
		if is_equal_approx(before, after):
			continue
		deltas.append("%s %.2f -> %.2f" % [_format_stat_label(stat_key), before, after])
	if deltas.is_empty():
		return LocalizationManager.tr_key("ui.module.stat_changes_none", "Stat changes: none")
	return LocalizationManager.tr_format("ui.module.stat_changes", {"changes": ", ".join(deltas)}, "Stat changes: %s" % ", ".join(deltas))

func _format_stat_label(stat_key: String) -> String:
	return stat_key.replace("_", " ").capitalize()

func _on_language_changed(_locale: String) -> void:
	if visible and _module_instance != null and is_instance_valid(_module_instance):
		open_for_module(_module_instance, _on_complete)
