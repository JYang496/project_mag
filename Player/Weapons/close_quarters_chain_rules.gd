extends RefCounted

const CLOSE_VULNERABILITY_STATUS_ID := &"close_vulnerability"


static func apply_slow_to_target(target: Node, slow_multiplier: float, duration_sec: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_slow"):
		return
	target.call(
		"apply_slow",
		clampf(slow_multiplier, 0.05, 1.0),
		maxf(duration_sec, 0.1)
	)


static func apply_dash_slow(target: Node, slow_multiplier: float, duration_sec: float) -> void:
	apply_slow_to_target(target, slow_multiplier, duration_sec)


static func apply_chainsaw_vulnerability(target: Node, vulnerability_multiplier: float, duration_sec: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("is_slowed") or not bool(target.call("is_slowed")):
		return
	if not target.has_method("apply_damage_taken_multiplier_status"):
		return
	target.call(
		"apply_damage_taken_multiplier_status",
		CLOSE_VULNERABILITY_STATUS_ID,
		maxf(vulnerability_multiplier, 1.0),
		maxf(duration_sec, 0.1)
	)


static func apply_final_bonus_damage(
	source_node: Node,
	target: Node,
	damage_type: StringName,
	final_damage: int,
	bonus_ratio: float,
	dedupe_id: StringName = StringName()
) -> void:
	if target == null or not is_instance_valid(target):
		return
	var ratio := maxf(bonus_ratio, 0.0)
	if ratio <= 0.0:
		return
	var bonus_damage: int = max(1, int(round(float(maxi(final_damage, 0)) * ratio)))
	if bonus_damage <= 0:
		return
	var damage_manager := _get_damage_manager()
	if damage_manager == null:
		return
	var damage_data = damage_manager.call(
		"build_final_damage_data",
		source_node,
		bonus_damage,
		damage_type,
		{"amount": 0, "angle": Vector2.ZERO}
	)
	if dedupe_id != StringName():
		damage_data.dedupe_token = dedupe_id
		damage_data.dedupe_window_sec = 0.05
	damage_manager.call("apply_to_target", target, damage_data)


static func _get_damage_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/DamageManager")
