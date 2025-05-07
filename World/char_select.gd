extends MarginContainer

@export var mecha_id :int = 1
var on_select : bool = false
var on_hover : bool = false

func _on_texture_rect_mouse_entered() -> void:
	on_hover = true


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK"):
		on_select = true
		PlayerData.select_mecha_id = mecha_id
		print(mecha_id)


func _on_texture_rect_mouse_exited() -> void:
	on_hover = false
