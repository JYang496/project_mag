extends Node2D
class_name BonusManager

#@onready var player = get_tree().get_first_node_in_group("player")
const LOOT_BOX = preload("res://Objects/loots/loot_box.tscn")
var instance_list: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rebuild_rewards_cache()
	if not PhaseManager.is_connected("pre_enter_prepare_loot",Callable(self,"create_loot_box")):
		PhaseManager.connect("pre_enter_prepare_loot",Callable(self,"create_loot_box"))

func create_loot_box() -> void:
	create_loot_box_for_level(int(PhaseManager.current_level))

func rebuild_rewards_cache() -> void:
	instance_list.clear()
	for level_config in SpawnData.level_list:
		if level_config == null:
			instance_list.append([])
			continue
		var ins: LevelSpawnConfig = level_config.duplicate(true)
		instance_list.append(ins.rewards.duplicate(true))

func create_loot_box_for_level(level_index: int) -> int:
	if level_index < 0 or level_index >= instance_list.size():
		push_warning("create_loot_box_for_level ignored invalid level index: %d" % level_index)
		return 0
	var spawned_count := 0
	var rewards_at_level: Array = instance_list[level_index]
	for reward_entry in rewards_at_level:
		if not (reward_entry is RewardInfo):
			push_warning("Reward entry is invalid and was skipped at level index %d." % level_index)
			continue
		var reward: RewardInfo = reward_entry
		var lb_ins: Node2D = LOOT_BOX.instantiate() as Node2D
		if lb_ins == null:
			continue
		if PlayerData.player and is_instance_valid(PlayerData.player):
			lb_ins.position = PlayerData.player.position
		else:
			lb_ins.position = Vector2.ZERO
		lb_ins.item_id = reward.item_id
		lb_ins.item_lvl = max(0, int(reward.item_level))
		lb_ins.module_scene = reward.module_scene
		lb_ins.module_level = _sanitize_module_level(int(reward.module_level))
		lb_ins.total_value = max(0, int(reward.total_chip_value))
		self.add_child(lb_ins)
		spawned_count += 1
	return spawned_count

func _sanitize_module_level(level_value: int) -> int:
	return clampi(level_value, 1, Module.MAX_LEVEL)
