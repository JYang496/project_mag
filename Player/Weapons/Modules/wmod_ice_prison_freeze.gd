extends Module
# High frost-stack targets can be briefly rooted on hit.

var ITEM_NAME := "Ice Prison"

@export var required_frost_stacks_lv1: int = 3
@export var required_frost_stacks_lv2: int = 3
@export var required_frost_stacks_lv3: int = 2
@export var root_chance_lv1: float = 0.22
@export var root_chance_lv2: float = 0.30
@export var root_chance_lv3: float = 0.38
@export var root_duration_lv1: float = 0.55
@export var root_duration_lv2: float = 0.75
@export var root_duration_lv3: float = 0.95
@export var target_icd_sec: float = 1.1

var _target_last_proc_msec: Dictionary = {}

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_target_last_proc_msec.clear()

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_meta("_incoming_damage_state"):
		return
	var state_variant: Variant = target.get_meta("_incoming_damage_state", {})
	if not (state_variant is Dictionary):
		return
	var state: Dictionary = state_variant
	var frost_stacks: int = max(0, int(state.get("frost_stacks", 0)))
	if frost_stacks < _get_required_frost_stacks():
		return
	var target_id: int = target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_target_last_proc_msec.get(target_id, 0))
	if now_msec - last_msec < int(maxf(target_icd_sec, 0.0) * 1000.0):
		return
	if randf() > _get_root_chance():
		return
	_target_last_proc_msec[target_id] = now_msec
	_apply_root_like_slow(target)

func _apply_root_like_slow(target: Node) -> void:
	var duration: float = maxf(_get_root_duration(), 0.05)
	if target.has_method("apply_status_payload"):
		target.call("apply_status_payload", &"slow", {
			"multiplier": 0.05,
			"duration": duration,
		})
		return
	if target.has_method("apply_slow"):
		target.call("apply_slow", 0.05, duration)

func _get_required_frost_stacks() -> int:
	match module_level:
		3:
			return max(1, required_frost_stacks_lv3)
		2:
			return max(1, required_frost_stacks_lv2)
		_:
			return max(1, required_frost_stacks_lv1)

func _get_root_chance() -> float:
	match module_level:
		3:
			return clampf(root_chance_lv3, 0.0, 1.0)
		2:
			return clampf(root_chance_lv2, 0.0, 1.0)
		_:
			return clampf(root_chance_lv1, 0.0, 1.0)

func _get_root_duration() -> float:
	match module_level:
		3:
			return maxf(0.0, root_duration_lv3)
		2:
			return maxf(0.0, root_duration_lv2)
		_:
			return maxf(0.0, root_duration_lv1)
