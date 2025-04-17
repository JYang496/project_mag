extends MarginContainer
class_name EquipmentSlot

# Properties
@onready var background: ColorRect = $Background
@onready var image: TextureRect = $Background/Image
@onready var equip_name: Label = $Background/EquipName
@onready var stars: HBoxContainer = $Background/Stars
@onready var star_preload = preload("res://UI/star.tscn")

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
@onready var ui = get_tree().get_first_node_in_group("ui")
@onready var player_weapon_list = PlayerData.player_weapon_list
@onready var player = get_tree().get_first_node_in_group("player")

var hover_over : bool = false

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
		border_color = hover_over_color
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
		image.texture = item.sprite.texture
		equip_name.text = item.ITEM_NAME
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
		equip_name.text = "Empty"
	queue_redraw()


func _on_color_rect_mouse_entered() -> void:
	hover_over = true
	update()

func _on_color_rect_mouse_exited() -> void:
	hover_over = false
	update()

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		InventoryData.on_select_eqp = item
