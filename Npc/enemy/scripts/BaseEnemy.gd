extends BaseNPC
class_name BaseEnemy

const SPAWN_TAG_RANGED := &"ranged"
const SPAWN_TAG_ELITE := &"elite"
const SPAWN_TAG_SUPPORT := &"support"
const SPAWN_TAG_INTERCEPTOR := &"interceptor"
const QUEST_OUTLINE_SHADER: Shader = preload("res://Shaders/quest_outline.gdshader") as Shader

@export var damage := 0
@export var is_boss: bool = false
@export_enum("melee", "ranged") var combat_role: String = "melee"
@export var loot_value_multiplier: float = 1.0
@export_group("Spawn Metadata")
@export var spawn_cost: int = 3
@export var spawn_tags: Array[StringName] = []
@export var spawn_alive_cap: int = 0
@export var spawn_batch_cap: int = 0
@export_group("Support")
@export var support_role: StringName = &""
@export_group("")
@export_group("Body Push")
@export var body_push_enabled: bool = true
@export var body_push_strength: float = 0.45
@export var body_push_decay: float = 900.0
@export var body_push_max_speed: float = 260.0
@export var body_push_min_speed_delta: float = 18.0
@export_group("Crowd Breakthrough")
@export var crowd_breakthrough_width_multiplier: float = 1.5
@export var crowd_breakthrough_side_push_strength: float = 0.6
@export_group("")
signal enemy_death(was_killed: bool)

@onready var hit_box_dot: HitBoxDot = $HitBoxDot
@onready var enable_collision_timer: Timer = $EnableCollisionTimer
var stun_remaining: float:
	get: return movement_runtime.stun_remaining
	set(value): movement_runtime.stun_remaining = value
var slow_remaining: float:
	get: return movement_runtime.slow_remaining
	set(value): movement_runtime.slow_remaining = value
var slow_multiplier: float:
	get: return movement_runtime.slow_multiplier
	set(value): movement_runtime.slow_multiplier = value
var _ranged_wander_dir: Vector2 = Vector2.ZERO
var _ranged_wander_time_left: float = 0.0
var _board_generator_ref: Node = null
var _constraint_pending_physics_tick: bool = true
var movement_runtime: EnemyMovementRuntime = EnemyMovementRuntime.new()
var death_runtime: EnemyDeathRuntime = EnemyDeathRuntime.new()
var _quest_lock_active := false
var _quest_lock_damage_mul := 1.0
var _quest_freeze_movement := false
var _quest_outline_enabled := false
var _quest_outline_original_material: Material
var _quest_outline_material: ShaderMaterial
var _support_damage_reduction_sources: Dictionary = {}

func _init() -> void:
	super._init()
	movement_runtime.setup(self)
	death_runtime.setup(self)

func _enter_tree() -> void:
	var enemy_registry := get_node_or_null("/root/EnemyRegistry")
	if enemy_registry != null and enemy_registry.has_method("register_enemy"):
		enemy_registry.call("register_enemy", self)

func _ready() -> void:
	_incoming_damage_max_hp = max(1, int(hp))
	hit_box_dot.hitbox_owner = self

func _exit_tree() -> void:
	var enemy_registry := get_node_or_null("/root/EnemyRegistry")
	if enemy_registry != null and enemy_registry.has_method("unregister_enemy"):
		enemy_registry.call("unregister_enemy", self)

func _process(delta: float) -> void:
	movement_runtime.update_statuses(delta)
	if FixedObliqueProjectionType.is_enabled():
		z_index = int(round(FixedObliqueProjectionType.get_projected_depth(global_position) / 16.0))

func _notification(what: int) -> void:
	if what != NOTIFICATION_PHYSICS_PROCESS:
		return
	if _constraint_pending_physics_tick:
		_constraint_pending_physics_tick = false
		return
	_constrain_to_board_traversable_area()

func death(killing_attack: Attack = null) -> void:
	_before_death(killing_attack)
	death_runtime.finalize_death(killing_attack, _grants_standard_death_rewards())

func _before_death(_killing_attack: Attack) -> void:
	pass

func _grants_standard_death_rewards() -> bool:
	return true

func erase() -> void:
	enemy_death.emit(false)
	queue_free()

func _on_enable_collision_timer_timeout() -> void:
	self.set_collision_mask_value(6,true)
	self.set_collision_mask_value(3,true)

func apply_stun(duration: float) -> void:
	movement_runtime.apply_stun(duration)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func apply_slow(multiplier: float, duration: float) -> void:
	movement_runtime.apply_slow(multiplier, duration)

func is_slowed() -> bool:
	return slow_remaining > 0.0 and slow_multiplier < 1.0

func get_current_movement_speed() -> float:
	if is_quest_movement_locked():
		return 0.0
	return movement_speed * slow_multiplier

func decay_knockback() -> void:
	knockback.amount = clampf(float(knockback.amount) - maxf(float(knockback_recover), 0.0), 0.0, float(knockback.amount))

func move_with_body_push(desired_velocity: Vector2, delta: float) -> void:
	movement_runtime.move_with_body_push(desired_velocity, delta)

func apply_body_push(push_velocity: Vector2) -> void:
	movement_runtime.apply_body_push(push_velocity)

func get_body_push_collision_velocity() -> Vector2:
	return movement_runtime.body_push_collision_velocity

func set_crowd_breakthrough_active(active: bool) -> void:
	movement_runtime.set_crowd_breakthrough_active(active)

func interrupt_movement() -> void:
	if has_method("_finish_dash"):
		call_deferred("_finish_dash")
	if has_method("apply_stun"):
		apply_stun(0.2)

func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	super.apply_status_payload(status_name, status_data)
	if not (status_data is Dictionary):
		return
	var payload := status_data as Dictionary
	match status_name:
		&"stun":
			apply_stun(float(payload.get("duration", 0.0)))
		&"slow":
			apply_slow(
				float(payload.get("multiplier", 1.0)),
				float(payload.get("duration", 0.0))
			)

func _update_knockback_overlap_mode() -> void:
	movement_runtime.update_knockback_overlap_mode()

func set_quest_highlight(enabled: bool, color: Color = Color.WHITE) -> void:
	set_outline_highlight(enabled, color, 1.0)

func set_quest_lock(active: bool, damage_mul: float = 0.5, freeze_movement: bool = true) -> void:
	if active:
		if _quest_lock_active:
			return
		_quest_lock_active = true
		_quest_lock_damage_mul = damage_taken_multiplier
		_quest_freeze_movement = freeze_movement
		damage_taken_multiplier = minf(damage_taken_multiplier, maxf(damage_mul, 0.05))
		return
	if not _quest_lock_active:
		return
	_quest_lock_active = false
	_quest_freeze_movement = false
	damage_taken_multiplier = _quest_lock_damage_mul

func is_quest_movement_locked() -> bool:
	return _quest_lock_active and _quest_freeze_movement

func set_outline_highlight(enabled: bool, color: Color = Color.WHITE, width: float = 1.0) -> void:
	if sprite_body == null:
		return
	if enabled:
		if not _quest_outline_enabled:
			_quest_outline_original_material = sprite_body.material
			_quest_outline_material = _build_quest_outline_material(color, width)
			_quest_outline_enabled = true
		if _quest_outline_material:
			_quest_outline_material.set_shader_parameter("outline_color", color)
			_quest_outline_material.set_shader_parameter("outline_width", width)
			sprite_body.material = _quest_outline_material
		return
	if not _quest_outline_enabled:
		return
	_quest_outline_enabled = false
	sprite_body.material = _quest_outline_original_material

func _build_quest_outline_material(color: Color, width: float) -> ShaderMaterial:
	var outline_material := ShaderMaterial.new()
	outline_material.shader = QUEST_OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_color", color)
	outline_material.set_shader_parameter("outline_width", width)
	return outline_material

func has_spawn_tag(tag: StringName) -> bool:
	return spawn_tags.has(tag)

func get_source_damage_taken_multiplier(attack: Attack) -> float:
	var base_multiplier := super.get_source_damage_taken_multiplier(attack)
	if attack == null or not _attack_is_from_player_weapon_source(attack):
		return base_multiplier
	return base_multiplier * get_support_damage_taken_multiplier()

func set_support_damage_reduction(source: Node, multiplier: float) -> void:
	if source == null or source == self:
		return
	_support_damage_reduction_sources[source.get_instance_id()] = {
		"source": weakref(source),
		"multiplier": clampf(multiplier, 0.0, 1.0),
	}

func clear_support_damage_reduction(source: Node) -> void:
	if source != null:
		_support_damage_reduction_sources.erase(source.get_instance_id())

func get_support_damage_taken_multiplier() -> float:
	var strongest := 1.0
	for source_id in _support_damage_reduction_sources.keys():
		var entry: Dictionary = _support_damage_reduction_sources[source_id]
		var source_ref := entry.get("source") as WeakRef
		if source_ref == null or source_ref.get_ref() == null:
			_support_damage_reduction_sources.erase(source_id)
			continue
		strongest = minf(strongest, float(entry.get("multiplier", 1.0)))
	return strongest

func is_support_unit() -> bool:
	return support_role != &""

func can_receive_support_from(source: BaseEnemy) -> bool:
	if source == null or source == self:
		return false
	return support_role == &"" or support_role != source.support_role

func compute_ranged_navigation(
	delta: float,
	detect_range: float,
	attack_range: float,
	approach_speed_mul: float = 1.0,
	wander_speed_mul: float = 0.75,
	wander_change_interval_sec: float = 3.0
) -> Vector2:
	if PlayerData.player == null:
		return Vector2.ZERO
	var to_player: Vector2 = PlayerData.player.global_position - global_position
	var distance: float = to_player.length()
	var to_player_dir: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.RIGHT
	var safe_detect := maxf(detect_range, 1.0)
	var safe_attack := clampf(attack_range, 1.0, safe_detect)
	var base_speed := get_current_movement_speed()
	if distance > safe_detect:
		_ranged_wander_time_left = 0.0
		return to_player_dir * base_speed * maxf(approach_speed_mul, 0.05)
	_ranged_wander_time_left -= maxf(delta, 0.0)
	if _ranged_wander_time_left <= 0.0 or _ranged_wander_dir == Vector2.ZERO:
		_ranged_wander_time_left = maxf(wander_change_interval_sec, 0.1)
		var tangent := Vector2(-to_player_dir.y, to_player_dir.x)
		var random_dir := Vector2.RIGHT.rotated(randf() * TAU)
		var tangent_sign := -1.0 if randf() < 0.5 else 1.0
		var blended := tangent * tangent_sign + random_dir * 0.35
		_ranged_wander_dir = blended.normalized() if blended.length() > 0.001 else tangent.normalized()
	var desired_dir := _ranged_wander_dir
	if distance > safe_attack:
		desired_dir = (desired_dir * 0.65 + to_player_dir * 0.35).normalized()
	else:
		desired_dir = (desired_dir * 0.8 - to_player_dir * 0.2).normalized()
	return desired_dir * base_speed * maxf(wander_speed_mul, 0.05)

func is_world_position_in_player_screen(world_pos: Vector2, margin: float = 0.0) -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var visible_rect := viewport.get_visible_rect().grow(maxf(margin, 0.0))
	var canvas_pos := viewport.get_canvas_transform() * world_pos
	return visible_rect.has_point(canvas_pos)

func _get_board_generator() -> Node:
	if _board_generator_ref != null and is_instance_valid(_board_generator_ref):
		return _board_generator_ref
	var scene_root := get_tree().current_scene
	if scene_root:
		_board_generator_ref = scene_root.get_node_or_null("Board")
	return _board_generator_ref

func _constrain_to_board_traversable_area() -> void:
	var board := _get_board_generator()
	if board == null:
		return
	if not board.has_method("project_point_to_enemy_traversable_area"):
		return
	var projected: Variant = board.call("project_point_to_enemy_traversable_area", global_position)
	if not (projected is Vector2):
		return
	var projected_pos: Vector2 = projected as Vector2
	if projected_pos.distance_squared_to(global_position) <= 0.25:
		return
	global_position = projected_pos
