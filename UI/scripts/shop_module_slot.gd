extends MarginContainer
class_name ShopModuleSlot

const MODULE_DIRECTORY_PATH := "res://Player/Weapons/Modules/"
const RARITY_UTIL := preload("res://data/LootRarity.gd")

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

@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

func _ready() -> void:
	if background:
		CursorManager.register_control_rule(background, Callable(self, "_cursor_can_click"))
	new_item()

func _exit_tree() -> void:
	if background:
		CursorManager.unregister_control_rule(background)
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
	queue_redraw()

func _physics_process(_delta: float) -> void:
	purchasable = module_scene != null and PlayerData.player_gold >= price
	price_label.set("theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0) if purchasable else Color(1.0, 0.0, 0.0, 1.0))

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
	price_label.text = LocalizationManager.tr_format("ui.shop.module.price", {"value": price}, "价格: %s" % price)
	var effects := preview_module.get_effect_descriptions()
	effect_label.text = effects[0] if effects.size() > 0 else ""
	detail_label.text = _build_module_requirement_summary(preview_module)

func _clear_preview() -> void:
	if preview_module and is_instance_valid(preview_module):
		if preview_module.is_inside_tree():
			preview_module.queue_free()
		else:
			preview_module.free()
	preview_module = null

func _build_module_candidates() -> Array[PackedScene]:
	var candidates: Array[PackedScene] = []
	var dir := DirAccess.open(MODULE_DIRECTORY_PATH)
	if dir == null:
		return candidates
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".tscn") and file_name != "wmod_base.tscn":
			var scene_path := MODULE_DIRECTORY_PATH + file_name
			if not _is_owned_full_level(scene_path):
				var scene := load(scene_path) as PackedScene
				if scene:
					candidates.append(scene)
		file_name = dir.get_next()
	dir.list_dir_end()
	return candidates

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
		return LocalizationManager.tr_key("ui.shop.module.any_weapon", "任意武器")
	return LocalizationManager.tr_format("ui.shop.module.requires", {"value": " / ".join(parts)}, "适配: {value}")

func _notify_shop_hover() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("set_shop_hover_item"):
		ui.call("set_shop_hover_item", _build_shop_item_data())

func _notify_shop_hover_clear() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("clear_shop_hover_item"):
		ui.call("clear_shop_hover_item", _build_shop_item_data())

func _notify_shop_selected() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("set_shop_selected_item"):
		ui.call("set_shop_selected_item", _build_shop_item_data())

func _notify_shop_clear() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui):
		var data := _build_shop_item_data()
		if ui.has_method("clear_shop_hover_item"):
			ui.call("clear_shop_hover_item", data)
		if ui.has_method("clear_shop_selected_item"):
			ui.call("clear_shop_selected_item", data)
