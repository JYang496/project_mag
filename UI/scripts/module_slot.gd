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
	else:
		module = null
	if module:
		var sprite_node := module.get_node_or_null("%Sprite")
		if sprite_node:
			image.texture = sprite_node.texture
		else:
			image.texture = null
		var module_name = module.get("ITEM_NAME")
		if module_name == null or module_name == "":
			module_name = module.name
		item_name.text = str(module_name)
	else:
		image.texture = null
		item_name.text = "Empty"
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
