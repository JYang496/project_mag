extends Module
# Hitting frosted targets triggers bonus shatter damage scaling with current frost stacks.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Shatter Strike"

@export var ratio_per_stack_lv1: float = 0.06
@export var ratio_per_stack_lv2: float = 0.08
@export var ratio_per_stack_lv3: float = 0.10
@export var max_stack_scale: int = 5
@export var target_icd_sec: float = 0.35

var _target_last_proc_msec: Dictionary = {}

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_target_last_proc_msec.clear()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_meta("_incoming_damage_state"):
		return
	var state_variant: Variant = target.get_meta("_incoming_damage_state", {})
	if not (state_variant is Dictionary):
		return
	var state: Dictionary = state_variant
	var frost_stacks: int = max(0, int(state.get("frost_stacks", 0)))
	if frost_stacks <= 0:
		return
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_target_last_proc_msec.get(target_id, 0))
	if now_msec - last_msec < int(maxf(target_icd_sec, 0.0) * 1000.0):
		return
	_target_last_proc_msec[target_id] = now_msec
	var stack_scale: int = mini(max(1, max_stack_scale), frost_stacks)
	var base_damage: int = UTILS.get_runtime_weapon_damage(source_weapon)
	var bonus_damage: int = max(1, int(round(float(base_damage) * float(stack_scale) * _get_ratio_per_stack())))
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var damage_data := DamageData.new().setup(
		bonus_damage,
		Attack.TYPE_PHYSICAL,
		{"amount": 0, "angle": Vector2.ZERO},
		source_weapon,
		owner_player
	)
	DamageManager.apply_to_target(target, damage_data)

func _get_ratio_per_stack() -> float:
	match module_level:
		3:
			return maxf(0.0, ratio_per_stack_lv3)
		2:
			return maxf(0.0, ratio_per_stack_lv2)
		_:
			return maxf(0.0, ratio_per_stack_lv1)
