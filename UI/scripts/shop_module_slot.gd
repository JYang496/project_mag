extends MarginContainer
class_name ShopModuleSlot

const MODULE_DIRECTORY_PATH := "res://Player/Weapons/Modules/"
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

@onready var background: ColorRect = $Background
@onready var image: TextureRect = $Background/Image
@onready var item_name: Label = $Background/EquipName
@onready var price_label: Label = $Background/Socket1
@onready var effect_label: Label = $Background/Socket2
@onready var detail_label: Label = $Background/Socket3

var module_scene: PackedScene
var preview_module: Module
var price := 0
var purchasable := false
var hover_over := false
var selected := false
var _effect_chip_row: HBoxContainer

static var _module_scene_cache_built := false
static var _module_scene_cache: Array[PackedScene] = []

@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

func _ready() -> void:
	if background:
		CursorManager.register_control_rule(background, Callable(self, "_cursor_can_click"))
	_connect_gold_signal()
	new_item()

func _exit_tree() -> void:
	if background:
		CursorManager.unregister_control_rule(background)
	_disconnect_gold_signal()
	_clear_preview()

func _draw() -> void:
	var width := 0.0
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.78, 0.22, 0.14), true)
	if hover_over:
		width = border_width
		border_color = Color(0.95, 0.98, 1.0, 1.0)
	elif selected:
		width = border_width + 1.0
		border_color = Color(1.0, 0.78, 0.22, 1.0)
	elif preview_module != null and is_instance_valid(preview_module):
		width = 2.0
		border_color = RARITY_UTIL.get_color(preview_module.get_rarity())
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, width)
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-4.0), Color(1.0, 0.92, 0.45, 0.65), false, 1.0)

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func new_item() -> void:
	_notify_shop_clear()
	set_selected(false)
	_clear_preview()
	var candidates := _build_module_candidates()
	if candidates.is_empty():
		empty_item(LocalizationManager.tr_key("ui.shop.no_valid_modules", "No modules available"))
		return
	module_scene = candidates.pick_random()
	preview_module = module_scene.instantiate() as Module
	if preview_module == null:
		empty_item(LocalizationManager.tr_key("ui.shop.no_valid_modules", "No modules available"))
		return
	preview_module.set_module_level(1)
	preview_module.process_mode = Node.PROCESS_MODE_DISABLED
	preview_module.visible = false
	price = _get_module_purchase_price(preview_module)
	_refresh_labels()
	refresh_affordability()
	queue_redraw()

func empty_item(message: String = "") -> void:
	_notify_shop_clear()
	set_selected(false)
	_clear_preview()
	module_scene = null
	price = 0
	item_name.text = message if message != "" else LocalizationManager.tr_key("ui.module.sold", "Sold")
	image.texture = null
	price_label.text = ""
	effect_label.text = ""
	detail_label.text = ""
	detail_label.visible = true
	_clear_effect_chips()
	refresh_affordability()
	queue_redraw()

func refresh_affordability(_value: int = 0) -> void:
	purchasable = module_scene != null and PlayerData.player_gold >= price
	price_label.set("theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0) if purchasable else Color(1.0, 0.0, 0.0, 1.0))

func _connect_gold_signal() -> void:
	var callback := Callable(self, "refresh_affordability")
	if not PlayerData.player_gold_changed.is_connected(callback):
		PlayerData.player_gold_changed.connect(callback)

func _disconnect_gold_signal() -> void:
	var callback := Callable(self, "refresh_affordability")
	if PlayerData.player_gold_changed.is_connected(callback):
		PlayerData.player_gold_changed.disconnect(callback)

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK") and module_scene != null:
		_notify_shop_selected()

func can_purchase() -> bool:
	return module_scene != null and purchasable

func try_purchase() -> bool:
	if module_scene == null:
		return false
	if not purchasable:
		var message_ui := GlobalVariables.ui
		if message_ui and is_instance_valid(message_ui) and message_ui.has_method("show_item_message"):
			message_ui.show_item_message(LocalizationManager.tr_key("ui.shop.not_enough_gold", "Not enough gold."), 1.4)
		return false
	var result := InventoryData.purchase_module(module_scene)
	if result.get("ok", false):
		empty_item()
		return true
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
		ui.show_item_message(str(result.get("reason", "")), 1.6)
	return false

func _on_background_mouse_entered() -> void:
	hover_over = true
	_notify_shop_hover()
	queue_redraw()

func _on_background_mouse_exited() -> void:
	hover_over = false
	_notify_shop_hover_clear()
	queue_redraw()

func _cursor_can_click() -> bool:
	return module_scene != null

func _refresh_labels() -> void:
	if preview_module == null or not is_instance_valid(preview_module):
		return
	var sprite := preview_module.get_node_or_null("%Sprite") as Sprite2D
	image.texture = sprite.texture if sprite else null
	item_name.text = "%s Lv.1" % LocalizationManager.get_module_name(preview_module)
	item_name.set("theme_override_colors/font_color", RARITY_UTIL.get_color(preview_module.get_rarity()))
	price_label.text = LocalizationManager.tr_format("ui.shop.module.price", {"value": price}, "Price: %s" % price)
	var effects := preview_module.get_effect_descriptions()
	effect_label.text = effects[0] if effects.size() > 0 else ""
	var fit_data: Dictionary = MODULE_FIT_FORMATTER.build_display_data(preview_module, MODULE_FIT_FORMATTER.get_current_weapon())
	var chips: Array = []
	chips.append(fit_data.get("fit_badge", {}))
	for chip in fit_data.get("effect_chips", []):
		chips.append(chip)
	_refresh_effect_chips(chips)
	var requirement_summary := _build_module_requirement_summary(preview_module)
	detail_label.text = requirement_summary
	detail_label.visible = chips.is_empty()
	tooltip_text = requirement_summary

func _clear_preview() -> void:
	if preview_module and is_instance_valid(preview_module):
		if preview_module.is_inside_tree():
			preview_module.queue_free()
		else:
			preview_module.free()
	preview_module = null

func _build_module_candidates() -> Array[PackedScene]:
	var candidates: Array[PackedScene] = []
	_ensure_module_scene_cache()
	for scene in _module_scene_cache:
		if scene == null:
			continue
		if not _is_owned_full_level(scene.resource_path):
			candidates.append(scene)
	return candidates

static func clear_module_scene_cache() -> void:
	_module_scene_cache_built = false
	_module_scene_cache.clear()

static func _ensure_module_scene_cache() -> void:
	if _module_scene_cache_built:
		return
	_module_scene_cache_built = true
	_module_scene_cache.clear()
	var dir := DirAccess.open(MODULE_DIRECTORY_PATH)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".tscn") and file_name != "wmod_base.tscn":
			var scene_path := MODULE_DIRECTORY_PATH + file_name
			var scene := load(scene_path) as PackedScene
			if scene:
				_module_scene_cache.append(scene)
		file_name = dir.get_next()
	dir.list_dir_end()

func _is_owned_full_level(scene_path: String) -> bool:
	for module_instance in InventoryData.get_all_owned_modules():
		if str(module_instance.scene_file_path) == scene_path and int(module_instance.module_level) >= Module.MAX_LEVEL:
			return true
	return false

func _get_module_purchase_price(module_instance: Module) -> int:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_module_purchase_gold(int(module_instance.cost))
	return EconomyConfig.new().get_module_purchase_gold(int(module_instance.cost))

func _build_shop_item_data() -> Dictionary:
	if preview_module == null or not is_instance_valid(preview_module):
		return {}
	var rarity := preview_module.get_rarity()
	return {
		"type": "module",
		"id": str(preview_module.scene_file_path),
		"name": LocalizationManager.get_module_name(preview_module),
		"description": "\n".join(preview_module.get_effect_descriptions()),
		"price": price,
		"module": preview_module,
		"scene": module_scene,
		"slot": self,
		"rarity": rarity,
		"rarity_color": RARITY_UTIL.get_color(rarity),
		"effect_chips": MODULE_FIT_FORMATTER.build_display_data(preview_module, MODULE_FIT_FORMATTER.get_current_weapon()).get("effect_chips", []),
	}

func _build_module_requirement_summary(module_instance: Module) -> String:
	var parts := PackedStringArray()
	for value in module_instance.get_normalized_required_weapon_traits():
		parts.append(str(value))
	for value in module_instance.get_normalized_required_delivery_types():
		parts.append(str(value))
	for value in module_instance.get_normalized_required_weapon_capabilities():
		parts.append(str(value))
	if parts.is_empty():
		return LocalizationManager.tr_key("ui.shop.module.any_weapon", "Any Weapon")
	return LocalizationManager.tr_format(
		"ui.shop.module.requires",
		{"value": " / ".join(parts)},
		"Fits: %s" % " / ".join(parts)
	)

func _notify_shop_hover() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		ui.purchase_management_controller.set_hover_item(_build_shop_item_data())

func _notify_shop_hover_clear() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		ui.purchase_management_controller.clear_hover_item(_build_shop_item_data())

func _notify_shop_selected() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		ui.purchase_management_controller.set_selected_item(_build_shop_item_data())
		ui.purchase_management_controller.mark_purchase_action_dirty()

func _notify_shop_clear() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		var data := _build_shop_item_data()
		ui.purchase_management_controller.clear_hover_item(data)
		ui.purchase_management_controller.clear_selected_item(data)
		ui.purchase_management_controller.mark_purchase_action_dirty()

func _refresh_effect_chips(chips: Array) -> void:
	if background == null:
		return
	var row := _ensure_effect_chip_row()
	BUILD_TAG_DISPLAY.populate_chip_row(row, chips, 4)

func _clear_effect_chips() -> void:
	if _effect_chip_row != null and is_instance_valid(_effect_chip_row):
		BUILD_TAG_DISPLAY.populate_chip_row(_effect_chip_row, [], 0)

func _ensure_effect_chip_row() -> HBoxContainer:
	if _effect_chip_row != null and is_instance_valid(_effect_chip_row):
		return _effect_chip_row
	_effect_chip_row = BUILD_TAG_DISPLAY.make_chip_row([], 4)
	_effect_chip_row.name = "EffectChipRow"
	_effect_chip_row.position = Vector2(90.0, 60.0)
	_effect_chip_row.size = Vector2(398.0, 24.0)
	background.add_child(_effect_chip_row)
	return _effect_chip_row
