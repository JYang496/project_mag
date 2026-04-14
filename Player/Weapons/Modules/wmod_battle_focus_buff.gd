extends Module
# Consecutive hits on the same target grant temporary crit rate; changing target or timeout resets stacks.

var ITEM_NAME := "Battle Focus"

@export var crit_per_stack_lv1: float = 0.015
@export var crit_per_stack_lv2: float = 0.020
@export var crit_per_stack_lv3: float = 0.025
@export var max_stacks: int = 6
@export var streak_timeout_sec: float = 1.8

var _tracked_target_id: int = 0
var _current_stacks: int = 0
var _streak_expires_at_msec: int = 0
var _applied_crit_bonus: float = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_reset_focus(true)

func _physics_process(_delta: float) -> void:
	if _current_stacks <= 0:
		return
	if Time.get_ticks_msec() < _streak_expires_at_msec:
		return
	_reset_focus(true)

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	if target_id == _tracked_target_id and now_msec < _streak_expires_at_msec:
		_current_stacks = mini(max(1, max_stacks), _current_stacks + 1)
	else:
		_tracked_target_id = target_id
		_current_stacks = 1
	_streak_expires_at_msec = now_msec + int(maxf(streak_timeout_sec, 0.1) * 1000.0)
	_refresh_crit_bonus()

func _refresh_crit_bonus() -> void:
	var next_bonus: float = float(_current_stacks) * _get_crit_per_stack()
	var delta: float = next_bonus - _applied_crit_bonus
	if is_zero_approx(delta):
		return
	PlayerData.bonus_crit_rate = maxf(0.0, float(PlayerData.bonus_crit_rate) + delta)
	_applied_crit_bonus = next_bonus

func _reset_focus(clear_target: bool) -> void:
	if _applied_crit_bonus > 0.0:
		PlayerData.bonus_crit_rate = maxf(0.0, float(PlayerData.bonus_crit_rate) - _applied_crit_bonus)
	_applied_crit_bonus = 0.0
	_current_stacks = 0
	_streak_expires_at_msec = 0
	if clear_target:
		_tracked_target_id = 0

func _get_crit_per_stack() -> float:
	match module_level:
		3:
			return maxf(0.0, crit_per_stack_lv3)
		2:
			return maxf(0.0, crit_per_stack_lv2)
		_:
			return maxf(0.0, crit_per_stack_lv1)
