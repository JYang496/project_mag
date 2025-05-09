extends HBoxContainer

@onready var on_select_id : int = 1
func _ready() -> void:
	for mechaselect : MechaSelect in self.get_children():
		mechaselect.on_select = true if mechaselect.mecha_id == on_select_id else false
		mechaselect.update()

func _on_mecha_select_update_on_select(id) -> void:
	on_select_id = id
	for mechaselect : MechaSelect in self.get_children():
		mechaselect.on_select = true if mechaselect.mecha_id == on_select_id else false
		mechaselect.update()
	
