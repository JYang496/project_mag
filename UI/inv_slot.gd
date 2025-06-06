extends MarginContainer
class_name InvSlot

# Properties
@onready var background: ColorRect = $Background
@onready var image: TextureRect = $Background/Image
@onready var equip_name: Label = $Background/EquipName
@onready var socket_1: Label = $Background/Socket1
@onready var socket_2: Label = $Background/Socket2
@onready var socket_3: Label = $Background/Socket3
@export var inventory_index : int = 0
var item : Weapon


# Border properties
@export var border_color: Color = Color(1,1,0)
@export var border_width: float = 4.0

var hover_over_color: Color = Color(1,1,0)
var hover_off_color: Color = Color(0,0,0,0)
var hover_over_width : float = 4.0
var hover_off_width : float = 0

# UI and player data
#@onready var ui = get_tree().get_first_node_in_group("ui")
#@onready var player = get_tree().get_first_node_in_group("player")

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
	queue_redraw()
	if len(InventoryData.inventory_slots) > inventory_index :
		item = InventoryData.inventory_slots[inventory_index]
		image.texture = item.get_node("%Sprite").texture
		equip_name.text = item.ITEM_NAME

	else:
		item = null
		image.texture = null
		equip_name.text = "Empty"

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass

func _on_color_rect_mouse_entered() -> void:
	hover_over = true
	update()

func _on_color_rect_mouse_exited() -> void:
	hover_over = false
	update()


func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		InventoryData.on_select_slot = item
			
