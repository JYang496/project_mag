extends Node2D
class_name MovingWallAttack

const ENEMY_HURTBOX_MASK := 1 << 2
const WALL_VISUAL := preload("res://Player/Weapons/Geometry/plasma_wall_visual.gd")
const DISSOLVE_DURATION := 0.18

var source_weapon: Weapon
var move_direction := Vector2.RIGHT
var wall_width := 150.0
var wall_thickness := 20.0
var travel_speed := 520.0
var travel_distance := 700.0
var damage := 1
var damage_type: StringName = Attack.TYPE_ENERGY
var _spawn_position := Vector2.ZERO
var _distance_travelled := 0.0
var _hit_target_ids: Dictionary = {}
var _wall_visual: MeshInstance2D
var _visual_age := 0.0
var _dissolve_age := 0.0
var _finished := false

func setup(weapon: Weapon, config: Dictionary) -> MovingWallAttack:
	source_weapon = weapon
	move_direction = (config.get("direction", Vector2.RIGHT) as Vector2).normalized()
	wall_width = maxf(float(config.get("width", 150.0)), 1.0)
	wall_thickness = maxf(float(config.get("thickness", 20.0)), 1.0)
	travel_speed = maxf(float(config.get("speed", 520.0)), 1.0)
	travel_distance = maxf(float(config.get("travel_distance", 700.0)), 1.0)
	damage = maxi(int(config.get("damage", 1)), 1)
	damage_type = Attack.normalize_damage_type(config.get("damage_type", Attack.TYPE_ENERGY))
	_spawn_position = config.get("origin", weapon.global_position) as Vector2
	rotation = move_direction.angle()
	return self

func _ready() -> void:
	global_position = _spawn_position
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	_wall_visual = WALL_VISUAL.new()
	_wall_visual.name = "PlasmaWallVisual"
	_wall_visual.setup(wall_width, wall_thickness, bool(get_meta(Weapon.ENERGY_RELEASE_ATTACK_META, false)))
	add_child(_wall_visual)
	_check_hits()

func _physics_process(delta: float) -> void:
	_visual_age += maxf(delta, 0.0)
	if _finished:
		_dissolve_age += maxf(delta, 0.0)
		_wall_visual.animate(_visual_age, clampf(_dissolve_age / DISSOLVE_DURATION, 0.0, 1.0))
		if _dissolve_age >= DISSOLVE_DURATION:
			queue_free()
		return
	var step_distance := minf(travel_speed * maxf(delta, 0.0), travel_distance - _distance_travelled)
	if step_distance > 0.0:
		global_position += move_direction * step_distance
		_distance_travelled += step_distance
		_check_hits(step_distance)
	_wall_visual.animate(_visual_age, 0.0)
	if _distance_travelled >= travel_distance - 0.001:
		_finished = true

func cleanup_for_battle_end() -> void:
	queue_free()

func _check_hits(swept_distance: float = 0.0) -> void:
	if source_weapon == null or not is_instance_valid(source_weapon) or not is_inside_tree():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(wall_thickness + maxf(swept_distance, 0.0), wall_width)
	var center := global_position - move_direction * maxf(swept_distance, 0.0) * 0.5
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(move_direction.angle(), center)
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var collider: Variant = hit.get("collider", null)
		if not collider is HurtBox:
			continue
		var target := _resolve_target(collider as HurtBox)
		if target == null or not is_instance_valid(target):
			continue
		var target_id := target.get_instance_id()
		if _hit_target_ids.has(target_id):
			continue
		_hit_target_ids[target_id] = true
		_apply_damage(target)

func _apply_damage(target: Node) -> void:
	var data := DamageManager.build_damage_data(
		self, damage, damage_type,
		{"amount": 45.0, "angle": move_direction},
		DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.AREA,
		get_meta(Weapon.HEAT_SNAPSHOT_META) if has_meta(Weapon.HEAT_SNAPSHOT_META) else null
	)
	data.dedupe_token = StringName("plasma_wall_%d_%d" % [get_instance_id(), target.get_instance_id()])
	data.dedupe_window_sec = 0.05
	var result := DamageManager.apply_to_target_result(target, data)
	if not result.applied:
		return
	if source_weapon.has_method("on_plasma_wall_damage_dealt"):
		source_weapon.call("on_plasma_wall_damage_dealt", self, target, damage_type, result.final_damage)
	if source_weapon.has_method("on_hit_target_with_damage_type"):
		source_weapon.call("on_hit_target_with_damage_type", target, damage_type)

func _resolve_target(hurt_box: HurtBox) -> Node:
	var target: Node = hurt_box.get_damage_target() if hurt_box.has_method("get_damage_target") else null
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_owner()
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_parent()
	return target

func get_hit_target_count() -> int:
	return _hit_target_ids.size()
