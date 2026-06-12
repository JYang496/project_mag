extends Projectile
class_name PlasmaLanceProjectile

const RIFT_VFX_SCRIPT := preload("res://Player/Weapons/Effects/plasma_lance_rift_vfx.gd")
const ENEMY_HURTBOX_MASK: int = 1 << 2

@export var damage_gain_per_pierce: int = 3
@export var rift_damage_ratio: float = 0.5
@export var rift_width: float = 24.0
@export var rift_visual_duration: float = 0.2

var _rift_hit_positions: Array[Vector2] = []
var _rift_anchor_target_ref: WeakRef
var _rift_sequence: int = 0


func on_hit_target(target: Node) -> void:
	_record_rift_hit_and_apply(target)
	super.on_hit_target(target)


func on_hit_target_with_damage_type(target: Node, hit_damage_type: StringName) -> void:
	_record_rift_hit_and_apply(target)
	super.on_hit_target_with_damage_type(target, hit_damage_type)

func enemy_hit(charge: int = 1):
	hp -= charge
	if hp > 0:
		damage += max(0, damage_gain_per_pierce)
	if hp <= 0:
		call_deferred("despawn")


func despawn() -> void:
	_clear_rift_hits()
	super.despawn()


func _on_before_pooled() -> void:
	_clear_rift_hits()
	super._on_before_pooled()


func _record_rift_hit_and_apply(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target2d := target as Node2D
	if target2d == null:
		return
	var hit_position := target2d.global_position
	if _rift_hit_positions.is_empty():
		_rift_hit_positions.append(hit_position)
		_rift_anchor_target_ref = weakref(target)
		return
	var anchor_position := _resolve_rift_anchor_position()
	_rift_hit_positions.append(hit_position)
	_apply_rift_segment(anchor_position, hit_position)


func _resolve_rift_anchor_position() -> Vector2:
	var fallback_position := Vector2.ZERO
	if not _rift_hit_positions.is_empty():
		fallback_position = _rift_hit_positions[0]
	var anchor_target := _resolve_rift_anchor_target()
	if anchor_target == null:
		return fallback_position
	var anchor_target2d := anchor_target as Node2D
	if anchor_target2d == null:
		return fallback_position
	var current_position := anchor_target2d.global_position
	_rift_hit_positions[0] = current_position
	return current_position


func _resolve_rift_anchor_target() -> Node:
	if _rift_anchor_target_ref == null:
		return null
	var target := _rift_anchor_target_ref.get_ref() as Node
	if target == null or not is_instance_valid(target):
		return null
	if not target.is_inside_tree():
		return null
	if target.get("is_dead") != null and bool(target.get("is_dead")):
		return null
	return target


func _apply_rift_segment(from_pos: Vector2, to_pos: Vector2) -> void:
	var segment := to_pos - from_pos
	var length := segment.length()
	if length <= 1.0:
		return
	_rift_sequence += 1
	_spawn_rift_visual(from_pos, to_pos)
	var targets := _collect_enemy_targets_on_segment(from_pos, to_pos, length)
	if targets.is_empty():
		return
	var rift_damage := maxi(1, int(round(float(damage) * maxf(rift_damage_ratio, 0.0))))
	for target in targets:
		_apply_rift_damage(target, rift_damage)


func _collect_enemy_targets_on_segment(from_pos: Vector2, to_pos: Vector2, length: float) -> Array[Node]:
	var result: Array[Node] = []
	if not is_inside_tree():
		return result
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, maxf(rift_width, 1.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((to_pos - from_pos).angle(), from_pos.lerp(to_pos, 0.5))
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 64)
	var seen_targets: Dictionary = {}
	for hit in hits:
		var collider: Variant = hit.get("collider", null)
		if not collider is HurtBox:
			continue
		var target := _resolve_hurt_box_target(collider as HurtBox)
		if target == null or not is_instance_valid(target):
			continue
		if not target.is_in_group("enemies"):
			continue
		var target_id := target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		result.append(target)
	return result


func _resolve_hurt_box_target(hurt_box: HurtBox) -> Node:
	var target: Node = null
	if hurt_box.has_method("get_damage_target"):
		target = hurt_box.call("get_damage_target")
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_owner()
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_parent()
	return target


func _apply_rift_damage(target: Node, amount: int) -> void:
	var damage_data := DamageManager.build_damage_data(
		self,
		maxi(1, amount),
		Attack.normalize_damage_type(damage_type),
		knock_back,
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.AREA
	)
	damage_data.dedupe_token = StringName("plasma_lance_rift_%d_%d_%d" % [
		get_instance_id(),
		_rift_sequence,
		target.get_instance_id(),
	])
	damage_data.dedupe_window_sec = 0.02
	DamageManager.apply_to_target(target, damage_data)


func _spawn_rift_visual(from_pos: Vector2, to_pos: Vector2) -> void:
	var vfx := RIFT_VFX_SCRIPT.new() as Node
	if vfx == null:
		return
	vfx.setup(from_pos, to_pos, maxf(rift_width, 1.0), maxf(rift_visual_duration, 0.01))
	var parent := get_tree().current_scene if is_inside_tree() else null
	if parent == null and is_inside_tree():
		parent = get_tree().root
	if parent == null:
		return
	parent.add_child(vfx)


func _clear_rift_hits() -> void:
	_rift_hit_positions.clear()
	_rift_anchor_target_ref = null
