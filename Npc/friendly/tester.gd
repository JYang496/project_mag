extends FriendlyNPC

@onready var test_augment = preload("res://Player/Augments/ricochet.tscn")
# This NPC provides weapons
func _ready():
	pass


func panel_move_in() -> void:
	is_interacting = true
	var test_augment_ins = test_augment.instantiate()
	player.equppied_augments.add_child(test_augment_ins)


func panel_move_out() -> void:
	is_interacting = false
