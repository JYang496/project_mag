extends MarginContainer
class_name MechaSelect

@export var mecha_id :int = 1
var on_select : bool = false
var on_hover : bool = false
@onready var mech_texture: TextureRect = $MechTexture

signal update_on_select(id)

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var select_color: Color = Color(0, 1, 0)
@export var border_width: float = 4.0

func _ready() -> void:
	var mech_data = ImportData.read_mecha_data(str(mecha_id))
	var ins : Player = load(mech_data["res"]).instantiate()
	mech_texture.texture = ins.get_node("MechaSprite").texture
	ins.queue_free()
	

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var color = border_color if on_select else select_color
	var width = border_width if on_hover or on_select else 0.0
	draw_rect(rect, color, false, width)

func update() -> void:
	queue_redraw()

func _on_texture_rect_mouse_entered() -> void:
	on_hover = true
	update()


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		on_select = true
		PlayerData.select_mecha_id = mecha_id
		update_on_select.emit(mecha_id)


func _on_texture_rect_mouse_exited() -> void:
	on_hover = false
	update()
