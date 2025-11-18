extends FriendlyNPC

#@onready var test_augment = preload("res://Player/Augments/ricochet.tscn")

func _ready():
	pass


#func panel_move_in() -> void:
	#is_interacting = true
	#var test_augment_ins = test_augment.instantiate()
	#var paths = get_child_path(PlayerData.player.equppied_augments)
	#if not paths.has(test_augment_ins.get_script().resource_path):
		#PlayerData.player.equppied_augments.add_child(test_augment_ins)

func get_child_path(parent) -> Array:
	var output_array : Array = []
	var augments = parent.get_children()
	for aug in augments:
		output_array.append(aug.get_script().resource_path)
	return output_array

func panel_move_out() -> void:
	is_interacting = false
