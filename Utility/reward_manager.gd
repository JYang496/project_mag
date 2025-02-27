extends Node2D
class_name BonusManager

@onready var player = get_tree().get_first_node_in_group("player")
const LOOT_BOX = preload("res://Objects/loots/loot_box.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not PhaseManager.is_connected("enter_reward_signal",Callable(self,"test_create_loot_box")):
		PhaseManager.connect("enter_reward_signal",Callable(self,"test_create_loot_box"))

func test_create_loot_box() -> void:
	# TODO: test only, need dev
	var lb_ins = LOOT_BOX.instantiate()
	lb_ins.position = player.position
	lb_ins.item_id = "6"
	lb_ins.item_lvl = 2
	lb_ins.coin_value = 100
	self.add_child(lb_ins)
