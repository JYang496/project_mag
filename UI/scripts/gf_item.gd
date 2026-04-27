extends MarginContainer

@onready var image: TextureRect = $ColorRect/Image
@onready var color_rect: ColorRect = $ColorRect

var item : Weapon
@export var item_index : int = 0

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var hover_over_color: Color = Color(1,1,0)
var hover_off_color: Color = Color(0,0,0,0)
var hover_over_width : float = 4.0
var hover_off_width : float = 0

var hover_over : bool = false

func _ready() -> void:
	if color_rect:
		CursorManager.register_control_rule(color_rect, Callable(self, "_cursor_can_click"))

func _exit_tree() -> void:
	if color_rect:
		CursorManager.unregister_control_rule(color_rect)

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

func update():
	if item_index < InventoryData.ready_to_fuse_list.size():
		item = InventoryData.ready_to_fuse_list[item_index]
		if item:
			image.texture = item.get_node("%Sprite").texture
	else:
		item = null
		image.texture = null
	queue_redraw()

func _on_color_rect_mouse_entered() -> void:
	hover_over = true
	update()


func _on_color_rect_mouse_exited() -> void:
	hover_over = false
	update()


func _on_color_rect_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK") and item != null:
		InventoryData.remove_fuse_item(item)

func _cursor_can_click() -> bool:
	return item != null and is_instance_valid(item)
