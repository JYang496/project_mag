extends MarginContainer
class_name ModuleSlot

var module : Module
@export var module_index : int = 0

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var hover_over_color: Color = Color(1,1,0)
var hover_off_color: Color = Color(0,0,0,0)
var hover_over_width : float = 4.0
var hover_off_width : float = 0

var hover_over : bool = false
@onready var image: TextureRect = $Background/Image
@onready var item_name: Label = $Background/Name

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
	if len(InventoryData.moddule_slots) > module_index :
		module = InventoryData.moddule_slots[module_index]
	if module:
		image.texture = module.get_node("%Sprite").texture
		item_name.text = module.ITEM_NAME
	queue_redraw()

func _on_background_mouse_entered() -> void:
	hover_over = true
	update()

func _on_background_mouse_exited() -> void:
	hover_over = false
	update()


func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		InventoryData.on_select_inventory_module = module
