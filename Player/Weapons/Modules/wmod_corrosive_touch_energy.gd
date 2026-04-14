extends Module
# Applies corrosion on hit: lowers armor and raises damage taken for a short duration.

var ITEM_NAME := "Corrosive Touch"

@export var duration_lv1: float = 2.8
@export var duration_lv2: float = 3.5
@export var duration_lv3: float = 4.2
@export var armor_reduce_per_stack_lv1: int = 1
@export var armor_reduce_per_stack_lv2: int = 1
@export var armor_reduce_per_stack_lv3: int = 2
@export var damage_taken_bonus_per_stack_lv1: float = 0.04
@export var damage_taken_bonus_per_stack_lv2: float = 0.06
@export var damage_taken_bonus_per_stack_lv3: float = 0.08
@export var max_stacks: int = 4

var _runtime: Dictionary = {}

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_clear_all_corrosion()

func _physics_process(_delta: float) -> void:
	if _runtime.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var remove_ids: Array[int] = []
	for target_id_variant in _runtime.keys():
		var target_id: int = int(target_id_variant)
		var entry_variant: Variant = _runtime.get(target_id, null)
		if not (entry_variant is Dictionary):
			remove_ids.append(target_id)
			continue
		var entry: Dictionary = entry_variant
		var target_ref: WeakRef = entry.get("target_ref", null)
		var target: Node = target_ref.get_ref() as Node if target_ref != null else null
		if target == null or not is_instance_valid(target):
			remove_ids.append(target_id)
			continue
		if now_msec < int(entry.get("expires_at_msec", 0)):
			continue
		_restore_target_corrosion(target, entry)
		remove_ids.append(target_id)
	for target_id in remove_ids:
		_runtime.erase(target_id)

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	var now_msec: int = Time.get_ticks_msec()
	var target_id: int = target.get_instance_id()
	var entry: Dictionary = _runtime.get(target_id, {
		"target_ref": weakref(target),
		"stacks": 0,
		"expires_at_msec": 0,
		"applied_mul": 1.0,
		"applied_armor_reduction": 0,
	})
	entry["stacks"] = mini(max(1, max_stacks), int(entry.get("stacks", 0)) + 1)
	entry["expires_at_msec"] = now_msec + int(maxf(_get_duration(), 0.1) * 1000.0)
	_runtime[target_id] = entry
	_apply_target_corrosion(target, entry)
	_runtime[target_id] = entry

func _apply_target_corrosion(target: Node, entry: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	var old_mul: float = maxf(0.05, float(entry.get("applied_mul", 1.0)))
	var old_armor_reduction: int = max(0, int(entry.get("applied_armor_reduction", 0)))
	var stacks: int = max(1, int(entry.get("stacks", 1)))
	var next_mul: float = maxf(0.05, 1.0 + float(stacks) * _get_damage_taken_bonus_per_stack())
	var next_armor_reduction: int = max(0, int(round(float(stacks * _get_armor_reduction_per_stack()))))
	if target.get("damage_taken_multiplier") != null:
		var current_mul: float = maxf(0.05, float(target.get("damage_taken_multiplier")))
		var base_mul: float = current_mul / old_mul
		target.set("damage_taken_multiplier", maxf(0.05, base_mul * next_mul))
	if target.get("armor") != null:
		var current_armor: int = int(target.get("armor"))
		var base_armor: int = current_armor + old_armor_reduction
		target.set("armor", max(0, base_armor - next_armor_reduction))
	entry["applied_mul"] = next_mul
	entry["applied_armor_reduction"] = next_armor_reduction

func _restore_target_corrosion(target: Node, entry: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	var old_mul: float = maxf(0.05, float(entry.get("applied_mul", 1.0)))
	var old_armor_reduction: int = max(0, int(entry.get("applied_armor_reduction", 0)))
	if target.get("damage_taken_multiplier") != null:
		var current_mul: float = maxf(0.05, float(target.get("damage_taken_multiplier")))
		target.set("damage_taken_multiplier", maxf(0.05, current_mul / old_mul))
	if target.get("armor") != null:
		target.set("armor", max(0, int(target.get("armor")) + old_armor_reduction))

func _clear_all_corrosion() -> void:
	for entry_variant in _runtime.values():
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var target_ref: WeakRef = entry.get("target_ref", null)
		var target: Node = target_ref.get_ref() as Node if target_ref != null else null
		if target == null or not is_instance_valid(target):
			continue
		_restore_target_corrosion(target, entry)
	_runtime.clear()

func _get_duration() -> float:
	match module_level:
		3:
			return maxf(0.0, duration_lv3)
		2:
			return maxf(0.0, duration_lv2)
		_:
			return maxf(0.0, duration_lv1)

func _get_armor_reduction_per_stack() -> int:
	match module_level:
		3:
			return max(0, armor_reduce_per_stack_lv3)
		2:
			return max(0, armor_reduce_per_stack_lv2)
		_:
			return max(0, armor_reduce_per_stack_lv1)

func _get_damage_taken_bonus_per_stack() -> float:
	match module_level:
		3:
			return maxf(0.0, damage_taken_bonus_per_stack_lv3)
		2:
			return maxf(0.0, damage_taken_bonus_per_stack_lv2)
		_:
			return maxf(0.0, damage_taken_bonus_per_stack_lv1)
