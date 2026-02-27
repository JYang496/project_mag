extends CellBonusModule
class_name ObjectiveRewardBonus

@export var combat_bonus_speed: float = 20.0
@export var combat_bonus_duration: float = 10.0
@export var economy_bonus_gold: int = 20

var _combat_reward_active := false
var _combat_reward_timer: Timer

func grant_reward(reward_type: int) -> void:
	if reward_type == Cell.RewardType.COMBAT:
		if PlayerData.player == null:
			return
		PlayerData.player_bonus_speed += combat_bonus_speed
		_combat_reward_active = true
		if combat_bonus_duration > 0.0:
			if _combat_reward_timer == null:
				_combat_reward_timer = Timer.new()
				_combat_reward_timer.one_shot = true
				add_child(_combat_reward_timer)
				_combat_reward_timer.timeout.connect(_clear_combat_reward)
			_combat_reward_timer.start(combat_bonus_duration)
	elif reward_type == Cell.RewardType.ECONOMY:
		PlayerData.player_gold += economy_bonus_gold

func on_phase_changed(new_phase: String) -> void:
	if new_phase != PhaseManager.BATTLE:
		_clear_combat_reward()

func reset_runtime() -> void:
	_clear_combat_reward()

func _exit_tree() -> void:
	_clear_combat_reward()

func _clear_combat_reward() -> void:
	if not _combat_reward_active:
		return
	PlayerData.player_bonus_speed -= combat_bonus_speed
	_combat_reward_active = false
