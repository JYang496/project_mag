extends RefCounted
class_name ModuleManagementCardFactory

const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const WAREHOUSE_DRAG_CONTROLS := preload("res://UI/scripts/management/warehouse_drag_controls.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")
const INVENTORY_CARD_SCENE := preload("res://UI/components/ManagementInventoryCard/ManagementInventoryCard.tscn")
const MODULE_SOCKET_SCENE := preload("res://UI/components/ModuleManagementSocket/ModuleManagementSocket.tscn")
const MODULE_WEAPON_CARD_SCENE := preload("res://UI/components/ModuleManagementWeaponCard/ModuleManagementWeaponCard.tscn")
const MANAGEMENT_DRAG_PREVIEW_SCENE := preload("res://UI/components/ManagementDragPreview/ManagementDragPreview.tscn")

var view: Node
var owner_ui: Node

func bind(module_view: Node, ui: Node) -> void:
	view = module_view
	owner_ui = ui

func make_weapon_button(weapon: Weapon, location: String, selected: bool, pressed_callback: Callable) -> Button:
	var button := INVENTORY_CARD_SCENE.instantiate() as Button
	var drag_payload: Dictionary
	var drop_payload: Dictionary
	if location == "stored":
		drag_payload = {"kind": "stored_weapon", "weapon": weapon}
	else:
		drag_payload = {"kind": "equipped_weapon", "weapon": weapon}
		drop_payload = {"kind": "equipped_weapon", "weapon": weapon}
	button.call("set_drag_interface", drag_payload, drop_payload, Callable(view, "build_drag_data"), Callable(view, "can_drop_payload"), Callable(view, "drop_payload"))
	button.pressed.connect(pressed_callback)
	_populate_weapon_button(button, weapon, selected)
	_style_button(button, selected)
	return button

func make_empty_weapon_slot_button(slot_index: int) -> Button:
	var button := WAREHOUSE_DRAG_CONTROLS.WarehouseDragDropButton.new()
	button.view = view
	button.drop_payload = {"kind": "held_empty_slot", "slot_index": slot_index}
	button.custom_minimum_size = Vector2(0, 70)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = LocalizationManager.tr_format("ui.weapon.warehouse.empty_slot", {"index": slot_index + 1}, "Empty weapon slot %d" % (slot_index + 1))
	button.tooltip_text = LocalizationManager.tr_key("ui.weapon.warehouse.drop_to_equip", "Drop a stored weapon here to equip it.")
	_style_button(button, false)
	return button

func make_module_button(module_instance: Module, selected: bool, pressed_callback: Callable) -> Button:
	var button := INVENTORY_CARD_SCENE.instantiate() as Button
	button.call("set_drag_interface", {"kind": "temporary_module", "module": module_instance}, {}, Callable(view, "build_drag_data"), Callable(), Callable())
	button.pressed.connect(pressed_callback)
	button.call("set_data", {"icon": _get_module_texture(module_instance), "name": LocalizationManager.get_module_name(module_instance), "accent": RARITY_UTIL.get_color(module_instance.get_rarity()), "meta": _format_module_meta(module_instance), "detail": "%s: %s" % [
		LocalizationManager.tr_key("ui.module.install_targets", "Install Targets"),
		_format_module_install_targets(module_instance),
	], "height": 112.0})
	var effect_chips := MODULE_FIT_FORMATTER.build_effect_chips(module_instance, 3)
	if not effect_chips.is_empty():
		var chip_row := BUILD_TAG_DISPLAY.make_chip_row(effect_chips, 3)
		button.call("add_chips", chip_row)
	_style_button(button, selected)
	return button

func make_module_weapon_card(weapon: Weapon, active_drag_module: Module, socket_callback_builder: Callable) -> PanelContainer:
	var panel := MODULE_WEAPON_CARD_SCENE.instantiate() as PanelContainer
	panel.name = "ModuleWeaponCard"
	panel.set_meta("weapon", weapon)
	panel.call("set_data", {"icon": weapon.sprite.texture if weapon.sprite else null, "name": LocalizationManager.get_weapon_instance_display_name(weapon), "level": "Lv.%d" % int(weapon.level), "accent": _get_weapon_rarity_color(weapon)})
	apply_module_weapon_card_style(panel, weapon, active_drag_module)
	var slot_row := panel.call("get_socket_container") as HBoxContainer
	var installed: Array[Module] = []
	if weapon.modules:
		for child in weapon.modules.get_children():
			var module_instance := child as Module
			if module_instance:
				installed.append(module_instance)
	var max_slots := weapon.module_slot_capacity
	for index in range(max_slots):
		var existing: Module = installed[index] if index < installed.size() else null
		slot_row.add_child(make_module_socket_button(weapon, existing, index, socket_callback_builder.call(weapon, existing)))
	return panel

func make_module_socket_button(weapon: Weapon, existing: Module, index: int, pressed_callback: Callable) -> Button:
	var button := MODULE_SOCKET_SCENE.instantiate() as Button
	var drop_payload := {"kind": "module_slot", "weapon": weapon, "existing": existing, "slot_index": index}
	var drag_payload := {}
	if existing != null and is_instance_valid(existing):
		drag_payload = {"kind": "equipped_module", "module": existing, "weapon": weapon}
	button.call("set_drag_interface", drag_payload, drop_payload, Callable(view, "build_drag_data"), Callable(view, "can_drop_payload"), Callable(view, "drop_payload"))
	var feedback := _get_slot_feedback(weapon, existing)
	button.pressed.connect(pressed_callback)
	var tooltip := str(feedback.get("reason", ""))
	if tooltip.strip_edges() == "":
		tooltip = LocalizationManager.get_module_name(existing) if existing else LocalizationManager.tr_format("ui.module.slot_empty", {"index": index + 1}, "Slot %d" % (index + 1))
	button.call("set_data", {"occupied": existing != null, "icon": _get_module_texture(existing) if existing else null, "badge": "Lv.%d" % int(existing.module_level) if existing else str(index + 1), "accent": RARITY_UTIL.get_color(existing.get_rarity()) if existing else Color(0.58, 0.72, 0.8), "tooltip": tooltip, "feedback_ok": bool(feedback.get("ok", true))})
	_style_button(button, bool(feedback.get("ok", true)) and _get_selected_module() != null)
	return button

func apply_module_weapon_card_style(panel: PanelContainer, weapon: Weapon, active_drag_module: Module) -> void:
	var accent := _get_weapon_rarity_color(weapon)
	var state := &""
	if active_drag_module != null and is_instance_valid(active_drag_module):
		var compatible := _can_drag_module_install_on_weapon(active_drag_module, weapon)
		accent = Color.WHITE if compatible else Color(1.0, 0.18, 0.14)
		state = &"compatible" if compatible else &"blocked"
	panel.call("set_highlight", accent, state)

func build_drag_preview(payload: Dictionary) -> Control:
	var panel := MANAGEMENT_DRAG_PREVIEW_SCENE.instantiate() as Control
	var data := {"icon": null, "name": "", "accent": Color.WHITE, "detail": ""}
	var payload_kind := str(payload.get("kind", ""))
	var module_instance := payload.get("module", null) as Module
	var weapon := payload.get("weapon", null) as Weapon
	if _is_module_drag_kind(payload_kind) and module_instance != null and is_instance_valid(module_instance):
		data = {"icon": _get_module_texture(module_instance), "name": LocalizationManager.get_module_name(module_instance), "accent": RARITY_UTIL.get_color(module_instance.get_rarity()), "detail": _format_module_meta(module_instance)}
	elif weapon != null and is_instance_valid(weapon):
		data = {"icon": weapon.sprite.texture if weapon.sprite else null, "name": LocalizationManager.get_weapon_instance_display_name(weapon), "accent": _get_weapon_rarity_color(weapon), "detail": _format_weapon_meta(weapon)}
	elif module_instance != null and is_instance_valid(module_instance):
		data = {"icon": _get_module_texture(module_instance), "name": LocalizationManager.get_module_name(module_instance), "accent": RARITY_UTIL.get_color(module_instance.get_rarity()), "detail": _format_module_meta(module_instance)}
	panel.call("set_data", data)
	return panel

func _is_module_drag_kind(payload_kind: String) -> bool:
	return payload_kind == "temporary_module" or payload_kind == "equipped_module"

func _populate_weapon_button(button: Button, weapon: Weapon, selected: bool) -> void:
	var display_model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
	button.call("set_data", {"icon": weapon.sprite.texture if weapon.sprite else null, "name": display_model.display_name, "accent": _get_weapon_rarity_color(weapon), "meta": _format_weapon_meta(weapon), "selected": selected, "selected_text": LocalizationManager.tr_key("ui.common.selected", "Selected"), "height": 86.0})

func _style_button(button: Button, selected: bool) -> void:
	if owner_ui:
		owner_ui.call("_style_management_button", button, selected)

func _get_selected_module() -> Module:
	return view.get("selected_module") as Module if view != null else null

func _get_slot_feedback(weapon: Weapon, existing: Module) -> Dictionary:
	return view.call("_get_slot_feedback", weapon, existing) if view != null else {}

func _get_module_texture(module_instance: Module) -> Texture2D:
	return view.call("_get_module_texture", module_instance) as Texture2D if view != null else null

func _get_weapon_rarity_color(weapon: Weapon) -> Color:
	return view.call("_get_weapon_rarity_color", weapon) if view != null else Color.WHITE

func _format_module_install_targets(module_instance: Module) -> String:
	return str(view.call("_format_module_install_targets", module_instance)) if view != null else ""

func _can_drag_module_install_on_weapon(module_instance: Module, weapon: Weapon) -> bool:
	return bool(view.call("_can_drag_module_install_on_weapon", module_instance, weapon)) if view != null else false

func _format_module_meta(module_instance: Module) -> String:
	return LocalizationManager.tr_format(
		"ui.module.meta.level_rarity",
		{
			"level": int(module_instance.module_level),
			"rarity": RARITY_UTIL.get_display_name(module_instance.get_rarity()),
		},
		"Lv.%d  %s" % [int(module_instance.module_level), RARITY_UTIL.get_display_name(module_instance.get_rarity())]
	)

func _format_weapon_meta(weapon: Weapon) -> String:
	var display_model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
	return LocalizationManager.tr_format(
		"ui.weapon.meta.level_fuse",
		{
			"level": display_model.level,
			"max": display_model.max_level,
			"fuse": display_model.fuse,
		},
		"Lv.%d/%d  Fuse %d" % [display_model.level, display_model.max_level, display_model.fuse]
	)
