extends Node2D
class_name BonusManager

#@onready var player = get_tree().get_first_node_in_group("player")
const LOOT_BOX = preload("res://Objects/loots/loot_box.tscn")
var instance_list : Array
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_rng.randomize()
	for level_config in SpawnData.level_list:
		if level_config == null:
			continue
		var ins : LevelSpawnConfig = level_config.duplicate(true)
		instance_list.append(ins.rewards)
	if not PhaseManager.is_connected("pre_enter_prepare_loot",Callable(self,"create_loot_box")):
		PhaseManager.connect("pre_enter_prepare_loot",Callable(self,"create_loot_box"))

func create_loot_box() -> void:
	for reward : RewardInfo in instance_list[PhaseManager.current_level]:
		var lb_ins: Node2D = LOOT_BOX.instantiate() as Node2D
		if lb_ins == null:
			continue
		lb_ins.position = PlayerData.player.position
		lb_ins.item_id = reward.item_id
		lb_ins.item_lvl = reward.item_level
		var module_payload: Dictionary = _resolve_reward_module_payload(reward)
		lb_ins.module_scene = module_payload.get("module_scene", reward.module_scene) as PackedScene
		lb_ins.module_level = int(module_payload.get("module_level", reward.module_level))
		lb_ins.total_value = reward.total_coin_value
		self.add_child(lb_ins)

func _resolve_reward_module_payload(reward: RewardInfo) -> Dictionary:
	if reward == null:
		return {}
	if reward.module_options.is_empty():
		return {
			"module_scene": reward.module_scene,
			"module_level": reward.module_level,
		}
	var picked_option: ModuleRewardOption = _pick_weighted_module_option(reward.module_options)
	if picked_option == null or picked_option.module_scene == null:
		return {
			"module_scene": reward.module_scene,
			"module_level": reward.module_level,
		}
	var min_level: int = picked_option.get_clamped_min_level()
	var max_level: int = picked_option.get_clamped_max_level()
	var rolled_level: int = _rng.randi_range(min_level, max_level)
	return {
		"module_scene": picked_option.module_scene,
		"module_level": rolled_level,
	}

func _pick_weighted_module_option(options: Array[ModuleRewardOption]) -> ModuleRewardOption:
	var valid_options: Array[ModuleRewardOption] = []
	var total_weight: float = 0.0
	for option in options:
		if option == null:
			continue
		if option.module_scene == null:
			continue
		var option_weight: float = maxf(0.0, option.weight)
		if option_weight <= 0.0:
			continue
		valid_options.append(option)
		total_weight += option_weight
	if valid_options.is_empty():
		return null
	var roll: float = _rng.randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for option in valid_options:
		cumulative += maxf(0.0, option.weight)
		if roll <= cumulative:
			return option
	return valid_options[valid_options.size() - 1]
