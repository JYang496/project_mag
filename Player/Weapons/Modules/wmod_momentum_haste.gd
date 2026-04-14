extends Module
# Each hit grants short movement and attack speed stacks, up to a cap.

var ITEM_NAME := "Momentum Haste"

@export var move_speed_per_stack_lv1: float = 0.04
@export var move_speed_per_stack_lv2: float = 0.055
@export var move_speed_per_stack_lv3: float = 0.07
@export var attack_speed_per_stack_lv1: float = 0.03
@export var attack_speed_per_stack_lv2: float = 0.045
@export var attack_speed_per_stack_lv3: float = 0.06
@export var max_stacks: int = 6
@export var stack_duration_sec: float = 2.0

var _stacks: int = 0
var _expires_at_msec: int = 0

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_clear_buffs()

func _physics_process(_delta: float) -> void:
	if _stacks <= 0:
		return
	if Time.get_ticks_msec() < _expires_at_msec:
		return
	_clear_buffs()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	_stacks = mini(max(1, max_stacks), _stacks + 1)
	_expires_at_msec = Time.get_ticks_msec() + int(maxf(stack_duration_sec, 0.1) * 1000.0)
	_apply_buffs(source_weapon)

func _apply_buffs(source_weapon: Weapon) -> void:
	var player := WeaponModuleRuntimeUtils.resolve_player_node(source_weapon)
	if player != null and is_instance_valid(player) and player.has_method("apply_move_speed_mul"):
		player.call("apply_move_speed_mul", _get_source_id(), 1.0 + float(_stacks) * _get_move_speed_per_stack())
	if source_weapon != null and is_instance_valid(source_weapon) and source_weapon.has_method("set_external_attack_speed_multiplier"):
		source_weapon.call("set_external_attack_speed_multiplier", 1.0 + float(_stacks) * _get_attack_speed_per_stack())

func _clear_buffs() -> void:
	if weapon == null:
		weapon = _resolve_weapon()
	var player := WeaponModuleRuntimeUtils.resolve_player_node(weapon)
	if player != null and is_instance_valid(player) and player.has_method("remove_move_speed_mul"):
		player.call("remove_move_speed_mul", _get_source_id())
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("set_external_attack_speed_multiplier"):
		weapon.call("set_external_attack_speed_multiplier", 1.0)
	_stacks = 0
	_expires_at_msec = 0

func _get_move_speed_per_stack() -> float:
	match module_level:
		3:
			return maxf(0.0, move_speed_per_stack_lv3)
		2:
			return maxf(0.0, move_speed_per_stack_lv2)
		_:
			return maxf(0.0, move_speed_per_stack_lv1)

func _get_attack_speed_per_stack() -> float:
	match module_level:
		3:
			return maxf(0.0, attack_speed_per_stack_lv3)
		2:
			return maxf(0.0, attack_speed_per_stack_lv2)
		_:
			return maxf(0.0, attack_speed_per_stack_lv1)

func _get_source_id() -> StringName:
	return StringName("wmod_momentum_haste_%s" % str(get_instance_id()))
