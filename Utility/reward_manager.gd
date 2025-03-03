extends Node2D
class_name BonusManager

@onready var player = get_tree().get_first_node_in_group("player")
const LOOT_BOX = preload("res://Objects/loots/loot_box.tscn")
var instance_list : Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in SpawnData.level_list:
		var ins = i.instantiate()
		instance_list.append(ins.rewards)
	if not PhaseManager.is_connected("enter_reward_signal",Callable(self,"create_loot_box")):
		PhaseManager.connect("enter_reward_signal",Callable(self,"create_loot_box"))

func create_loot_box() -> void:
	for reward : RewardInfo in instance_list[PhaseManager.current_level]:
		var lb_ins = LOOT_BOX.instantiate()
		lb_ins.position = player.position
		lb_ins.item_id = reward.item_id
		lb_ins.item_lvl = reward.item_level
		lb_ins.total_value = reward.total_coin_value
		self.add_child(lb_ins)
