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

@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

func _ready() -> void:
	if background:
		CursorManager.register_control_rule(background, Callable(self, "_cursor_can_click"))
	new_item()

func _exit_tree() -> void:
	if background:
		CursorManager.unregister_control_rule(background)
	if preview_module and is_instance_valid(preview_module):
		preview_module.queue_free()

func _draw() -> void:
	var width := 0.0
	if hover_over:
		width = border_width
	elif preview_module != null and is_instance_valid(preview_module):
		width = 2.0
		border_color = RARITY_UTIL.get_color(preview_module.get_rarity())
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, width)

func new_item() -> void:
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
	add_child(preview_module)
	preview_module.visible = false
	price = _get_module_purchase_price(preview_module)
	_refresh_labels()
	queue_redraw()

func empty_item(message: String = "") -> void:
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
	if event.is_action_pressed("CLICK") and module_scene != null and purchasable:
		var result := InventoryData.purchase_module(module_scene)
		if result.get("ok", false):
			empty_item()

func _on_background_mouse_entered() -> void:
	hover_over = true
	queue_redraw()

func _on_background_mouse_exited() -> void:
	hover_over = false
	queue_redraw()

func _cursor_can_click() -> bool:
	return module_scene != null and purchasable

func _refresh_labels() -> void:
	if preview_module == null or not is_instance_valid(preview_module):
		return
	var sprite := preview_module.get_node_or_null("%Sprite") as Sprite2D
	image.texture = sprite.texture if sprite else null
	item_name.text = "[%s] %s Lv.1" % [
		RARITY_UTIL.get_display_name(preview_module.get_rarity()),
		LocalizationManager.get_module_name(preview_module),
	]
	item_name.set("theme_override_colors/font_color", RARITY_UTIL.get_color(preview_module.get_rarity()))
	price_label.text = LocalizationManager.tr_format("ui.shop.module.price", {"value": price}, "Price: %s" % price)
	var effects := preview_module.get_effect_descriptions()
	effect_label.text = effects[0] if effects.size() > 0 else ""
	detail_label.text = LocalizationManager.tr_key("ui.shop.module.buy_hint", "Buy module")

func _clear_preview() -> void:
	if preview_module and is_instance_valid(preview_module):
		preview_module.queue_free()
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
