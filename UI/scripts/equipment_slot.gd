extends MarginContainer
class_name EquipmentSlot

const RARITY_UTIL := preload("res://data/LootRarity.gd")

# Properties
@onready var background: ColorRect = $Background
@onready var image: TextureRect = $Background/Image
@onready var equip_name: Label = $Background/EquipName
@onready var stars: HBoxContainer = $Background/Stars
@onready var star_preload = preload("res://UI/scenes/star.tscn")

@export var equipment_index : int = 0
var item : Weapon

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var hover_over_color: Color = Color(1,1,0)
var hover_off_color: Color = Color(0,0,0,0)
var hover_over_width : float = 4.0
var hover_off_width : float = 0

# Module Sockets
@onready var sockets : Array = $Background/Sockets.get_children()

# UI and player data
#@onready var ui = get_tree().get_first_node_in_group("ui")
@onready var player_weapon_list = PlayerData.player_weapon_list
#@onready var player = get_tree().get_first_node_in_group("player")

var hover_over : bool = false

func _ready() -> void:
	if background:
		CursorManager.register_control_rule(background, Callable(self, "_cursor_can_click"))

func _exit_tree() -> void:
	if background:
		CursorManager.unregister_control_rule(background)

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
		border_color = hover_over_color
	elif item != null and is_instance_valid(item):
		width = 2.0
		border_color = _get_weapon_rarity_color(item)
	else:
		width = hover_off_width
		border_color = hover_off_color
	draw_rect(rect, border_color, false, width)

func update() -> void:
	player_weapon_list = PlayerData.player_weapon_list
	# Clear modules
	for s in sockets:
		s.module = null
	for s in stars.get_children():
		s.queue_free()
	# Update information
	if len(player_weapon_list) > equipment_index :
		item = player_weapon_list[equipment_index]
		if is_instance_valid(item):
			image.texture = item.sprite.texture
			var rarity: String = _get_weapon_rarity(item)
			equip_name.text = "[%s] %s" % [
				RARITY_UTIL.get_display_name(rarity),
				LocalizationManager.get_weapon_instance_display_name(item)
			]
			equip_name.set("theme_override_colors/font_color", RARITY_UTIL.get_color(rarity))
			for s in range(item.fuse):
				var star_ins = star_preload.instantiate()
				stars.add_child(star_ins)
			var i = 0
			for module : Module in item.modules.get_children():
				if i >= sockets.size():
					break
				sockets[i].module = module
				i += 1
		else:
			item = null
			image.texture = null
			equip_name.text = LocalizationManager.tr_key("ui.inventory.slot.empty", "Empty")
			equip_name.remove_theme_color_override("font_color")
	else:
		item = null
		image.texture = null
		equip_name.text = LocalizationManager.tr_key("ui.inventory.slot.empty", "Empty")
		equip_name.remove_theme_color_override("font_color")
	queue_redraw()


func _on_color_rect_mouse_entered() -> void:
	hover_over = true
	update()

func _on_color_rect_mouse_exited() -> void:
	hover_over = false
	update()

func _on_background_gui_input(_event: InputEvent) -> void:
	pass

func _cursor_can_click() -> bool:
	return _is_click_actionable()

func _is_click_actionable() -> bool:
	return item != null and is_instance_valid(item)

func _get_weapon_rarity(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return RARITY_UTIL.COMMON
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return RARITY_UTIL.COMMON
	return weapon_def.get_rarity()

func _get_weapon_rarity_color(weapon: Weapon) -> Color:
	return RARITY_UTIL.get_color(_get_weapon_rarity(weapon))
