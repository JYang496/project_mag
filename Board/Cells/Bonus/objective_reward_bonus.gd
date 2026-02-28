extends CellBonusModule
class_name ObjectiveRewardBonus

# ========== 战斗奖励 (Combat Rewards) ==========
@export_group("Combat Rewards")

@export var combat_bonus_speed: float = 20.0
@export var combat_bonus_duration: float = 10.0
@export var combat_heal_hp: int = 1
@export var combat_bonus_armor: int = 0
@export var combat_bonus_crit_rate: float = 0.0
@export var combat_bonus_crit_damage: float = 0.0
@export var combat_bonus_shield: int = 0
@export var combat_bonus_damage_reduction: float = 1.0

# ========== 经济奖励 (Economy Rewards) ==========
@export_group("Economy Rewards")

@export var economy_gold: int = 20
@export var economy_exp: int = 0
@export var economy_drop_coin: int = 0
@export var economy_drop_chip: int = 0
@export var economy_drop_coin_value: int = 1
@export var economy_drop_chip_value: int = 1

# Preloads for loot spawning (lazy load)
var _coin_preload: PackedScene:
	get:
		if _coin_preload == null:
			_coin_preload = preload("res://Objects/loots/coin.tscn")
		return _coin_preload
var _chip_preload: PackedScene:
	get:
		if _chip_preload == null:
			_chip_preload = preload("res://Objects/loots/chip.tscn")
		return _chip_preload
var _drop_preload: PackedScene:
	get:
		if _drop_preload == null:
			_drop_preload = preload("res://Objects/loots/drop.tscn")
		return _drop_preload

var _combat_reward_active := false
var _combat_reward_timer: Timer

# Track active bonuses for reset
var _active_bonuses: Dictionary = {}

func apply_parameters(params: Dictionary) -> void:
	# Combat rewards
	if params.has("combat_heal_hp"):
		combat_heal_hp = params["combat_heal_hp"]
	if params.has("combat_bonus_speed"):
		combat_bonus_speed = params["combat_bonus_speed"]
	if params.has("combat_bonus_duration"):
		combat_bonus_duration = params["combat_bonus_duration"]
	if params.has("combat_bonus_armor"):
		combat_bonus_armor = params["combat_bonus_armor"]
	if params.has("combat_bonus_crit_rate"):
		combat_bonus_crit_rate = params["combat_bonus_crit_rate"]
	if params.has("combat_bonus_crit_damage"):
		combat_bonus_crit_damage = params["combat_bonus_crit_damage"]
	if params.has("combat_bonus_shield"):
		combat_bonus_shield = params["combat_bonus_shield"]
	if params.has("combat_bonus_damage_reduction"):
		combat_bonus_damage_reduction = params["combat_bonus_damage_reduction"]

	# Economy rewards
	if params.has("economy_gold"):
		economy_gold = params["economy_gold"]
	if params.has("economy_exp"):
		economy_exp = params["economy_exp"]
	if params.has("economy_drop_coin"):
		economy_drop_coin = params["economy_drop_coin"]
	if params.has("economy_drop_chip"):
		economy_drop_chip = params["economy_drop_chip"]
	if params.has("economy_drop_coin_value"):
		economy_drop_coin_value = params["economy_drop_coin_value"]
	if params.has("economy_drop_chip_value"):
		economy_drop_chip_value = params["economy_drop_chip_value"]

func grant_reward(reward_type: int) -> void:
	if reward_type == Cell.RewardType.COMBAT:
		_grant_combat_reward()
	elif reward_type == Cell.RewardType.ECONOMY:
		_grant_economy_reward()

func _grant_combat_reward() -> void:
	if PlayerData.player == null:
		return

	# 血量回复
	if combat_heal_hp > 0:
		PlayerData.player_hp = min(PlayerData.player_hp + combat_heal_hp, PlayerData.player_max_hp)

	# 护盾加成
	if combat_bonus_shield > 0:
		PlayerData.bonus_shield += combat_bonus_shield
		_active_bonuses["shield"] = combat_bonus_shield

	# 护甲加成
	if combat_bonus_armor > 0:
		PlayerData.bonus_armor += combat_bonus_armor
		_active_bonuses["armor"] = combat_bonus_armor

	# 暴击率加成
	if combat_bonus_crit_rate > 0:
		PlayerData.bonus_crit_rate += combat_bonus_crit_rate
		_active_bonuses["crit_rate"] = combat_bonus_crit_rate

	# 暴击伤害加成
	if combat_bonus_crit_damage > 0:
		PlayerData.bonus_crit_damage += combat_bonus_crit_damage
		_active_bonuses["crit_damage"] = combat_bonus_crit_damage

	# 伤害减免加成
	if combat_bonus_damage_reduction < 1.0:
		PlayerData.bonus_damage_reduction *= combat_bonus_damage_reduction
		_active_bonuses["damage_reduction"] = combat_bonus_damage_reduction

	# 速度加成（临时）
	if combat_bonus_speed > 0:
		PlayerData.player_bonus_speed += combat_bonus_speed
		_combat_reward_active = true
		_active_bonuses["speed"] = combat_bonus_speed
		if combat_bonus_duration > 0.0:
			if _combat_reward_timer == null:
				_combat_reward_timer = Timer.new()
				_combat_reward_timer.one_shot = true
				add_child(_combat_reward_timer)
				_combat_reward_timer.timeout.connect(_clear_combat_reward)
			_combat_reward_timer.start(combat_bonus_duration)

func _grant_economy_reward() -> void:
	# 直接增加金币
	if economy_gold > 0:
		PlayerData.player_gold += economy_gold

	# 直接增加经验值
	if economy_exp > 0:
		PlayerData.player_exp += economy_exp

	# 掉落金币
	if economy_drop_coin > 0:
		_spawn_loot(_coin_preload, economy_drop_coin, economy_drop_coin_value)

	# 掉落经验值(Chip)
	if economy_drop_chip > 0:
		_spawn_loot(_chip_preload, economy_drop_chip, economy_drop_chip_value)

func _spawn_loot(loot_preload: PackedScene, count: int, value: int) -> void:
	if loot_preload == null:
		return

	# 获取玩家位置，如果玩家不存在则使用格子位置
	var spawn_position: Vector2
	if PlayerData.player != null:
		spawn_position = PlayerData.player.global_position
	else:
		spawn_position = _cell.global_position if _cell != null else Vector2.ZERO

	for i in range(count):
		var drop = _drop_preload.instantiate()
		drop.drop = loot_preload
		drop.value = value
		drop.spawn_global_position = spawn_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		if _cell != null:
			_cell.get_parent().add_child(drop)
		else:
			get_tree().current_scene.add_child(drop)

func on_phase_changed(new_phase: String) -> void:
	if new_phase != PhaseManager.BATTLE:
		_clear_combat_reward()

func reset_runtime() -> void:
	_clear_combat_reward()
	_active_bonuses.clear()

func _exit_tree() -> void:
	_clear_combat_reward()
	_active_bonuses.clear()

func _clear_combat_reward() -> void:
	# 清除速度加成
	if _combat_reward_active and combat_bonus_speed > 0:
		PlayerData.player_bonus_speed -= combat_bonus_speed
	_combat_reward_active = false

	# 清除护盾加成
	if _active_bonuses.has("shield"):
		PlayerData.bonus_shield -= _active_bonuses["shield"]

	# 清除护甲加成
	if _active_bonuses.has("armor"):
		PlayerData.bonus_armor -= _active_bonuses["armor"]

	# 清除暴击率加成
	if _active_bonuses.has("crit_rate"):
		PlayerData.bonus_crit_rate -= _active_bonuses["crit_rate"]

	# 清除暴击伤害加成
	if _active_bonuses.has("crit_damage"):
		PlayerData.bonus_crit_damage -= _active_bonuses["crit_damage"]

	# 清除伤害减免加成
	if _active_bonuses.has("damage_reduction"):
		PlayerData.bonus_damage_reduction /= _active_bonuses["damage_reduction"]
