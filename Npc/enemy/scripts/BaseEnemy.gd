extends BaseNPC
class_name BaseEnemy

const SPAWN_TAG_RANGED := &"ranged"
const SPAWN_TAG_ELITE := &"elite"

@export var damage := 0
@export var is_boss: bool = false
@export_enum("melee", "ranged") var combat_role: String = "melee"
@export var loot_value_multiplier: float = 1.0
@export_group("Spawn Metadata")
@export var spawn_cost: int = 3
@export var spawn_tags: Array[StringName] = []
@export var spawn_alive_cap: int = 0
@export var spawn_batch_cap: int = 0
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
@onready var coin_preload = preload("res://Objects/loots/coin.tscn")
@onready var drop_preload = preload("res://Objects/loots/drop.tscn")

signal enemy_death(was_killed: bool)

@onready var hit_box_dot: HitBoxDot = $HitBoxDot
@onready var enable_collision_timer: Timer = $EnableCollisionTimer
var stun_remaining: float = 0.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var _is_knockback_overlap_mode: bool = false
var _ranged_wander_dir: Vector2 = Vector2.ZERO
var _ranged_wander_time_left: float = 0.0
var _board_generator_ref: Node = null
var _constraint_pending_physics_tick: bool = true
var body_push_velocity: Vector2 = Vector2.ZERO
var _body_push_collision_velocity: Vector2 = Vector2.ZERO
var _crowd_breakthrough_active: bool = false
var _crowd_breakthrough_is_overlapping_enemies: bool = false

func _enter_tree() -> void:
	var enemy_registry := get_node_or_null("/root/EnemyRegistry")
	if enemy_registry != null and enemy_registry.has_method("register_enemy"):
		enemy_registry.call("register_enemy", self)

func _ready() -> void:
	hit_box_dot.hitbox_owner = self

func _exit_tree() -> void:
	var enemy_registry := get_node_or_null("/root/EnemyRegistry")
	if enemy_registry != null and enemy_registry.has_method("unregister_enemy"):
		enemy_registry.call("unregister_enemy", self)

func _process(delta: float) -> void:
	if stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_multiplier = 1.0
	_update_knockback_overlap_mode()

func _notification(what: int) -> void:
	if what != NOTIFICATION_PHYSICS_PROCESS:
		return
	if _constraint_pending_physics_tick:
		_constraint_pending_physics_tick = false
		return
	_constrain_to_board_traversable_area()

func death(killing_attack: Attack = null) -> void:
	var death_position := global_position
	var drop_value := _roll_kill_gold_drop_value()
	if drop_value > 0:
		var drop = drop_preload.instantiate()
		drop.drop = coin_preload
		drop.value = drop_value
		drop.spawn_global_position = global_position
		self.call_deferred("add_sibling",drop)
	if killing_attack != null and killing_attack.is_from_player():
		PlayerData.run_enemy_kills += 1
		if self is EliteEnemy:
			PlayerData.run_elite_kills += 1
		_notify_player_enemy_killed(killing_attack, death_position)
	_try_trigger_elite_kill_impact(killing_attack)
	enemy_death.emit(true)
	queue_free()

func _roll_kill_gold_drop_value() -> int:
	if GlobalVariables.enemy_spawner and is_instance_valid(GlobalVariables.enemy_spawner):
		if GlobalVariables.enemy_spawner.has_method("ensure_kill_gold_budget_active"):
			GlobalVariables.enemy_spawner.call("ensure_kill_gold_budget_active")
		if GlobalVariables.enemy_spawner.has_method("is_kill_gold_budget_active") and bool(GlobalVariables.enemy_spawner.call("is_kill_gold_budget_active")):
			return maxi(int(GlobalVariables.enemy_spawner.roll_enemy_kill_gold()), 0)
		if GlobalVariables.enemy_spawner.has_method("warn_inactive_kill_gold_budget"):
			GlobalVariables.enemy_spawner.call("warn_inactive_kill_gold_budget")
		return 0
	if GlobalVariables.economy_data:
		return max(1, int(GlobalVariables.economy_data.enemy_coin_drop_value))
	return max(1, int(EconomyConfig.new().enemy_coin_drop_value))

func erase() -> void:
	enemy_death.emit(false)
	queue_free()

func _try_trigger_elite_kill_impact(killing_attack: Attack) -> void:
	if not (self is EliteEnemy):
		return
	if killing_attack == null or not killing_attack.is_from_player():
		return
	var controller := get_tree().root.get_node_or_null("TimeImpactController")
	if controller and controller.has_method("trigger_elite_kill_impact"):
		controller.trigger_elite_kill_impact()

func _notify_player_enemy_killed(killing_attack: Attack, death_position: Vector2) -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	if not PlayerData.player.has_method("_broadcast_weapon_passive_event"):
		return
	PlayerData.player.call("_broadcast_weapon_passive_event", &"on_enemy_killed", {
		"enemy": self,
		"source_weapon": _resolve_killing_weapon(killing_attack),
		"position": death_position,
		"_suppress_default_emit": true,
	})

func _resolve_killing_weapon(killing_attack: Attack) -> Weapon:
	if killing_attack == null:
		return null
	var source := killing_attack.source_node
	if source == null or not is_instance_valid(source):
		return null
	if source is Weapon:
		return source as Weapon
	var source_weapon: Variant = source.get("source_weapon")
	if source_weapon is Weapon and is_instance_valid(source_weapon):
		return source_weapon as Weapon
	var current := source
	while current != null:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	return null

func _on_enable_collision_timer_timeout() -> void:
	self.set_collision_mask_value(6,true)
	self.set_collision_mask_value(3,true)

func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	var adjusted_duration := duration
	if self is EliteEnemy or is_boss or is_in_group("boss"):
		adjusted_duration *= 0.5
	stun_remaining = maxf(stun_remaining, adjusted_duration)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var clamped_multiplier: float = clampf(multiplier, 0.05, 1.0)
	if slow_remaining > 0.0:
		slow_multiplier = minf(slow_multiplier, clamped_multiplier)
	else:
		slow_multiplier = clamped_multiplier
	slow_remaining = maxf(slow_remaining, duration)

func is_slowed() -> bool:
	return slow_remaining > 0.0 and slow_multiplier < 1.0

func get_current_movement_speed() -> float:
	if has_method("is_quest_movement_locked") and is_quest_movement_locked():
		return 0.0
	return movement_speed * slow_multiplier

func move_with_body_push(desired_velocity: Vector2, delta: float) -> void:
	var knockback_velocity: Vector2 = knockback.amount * knockback.angle
	var safe_push_velocity := body_push_velocity if body_push_enabled else Vector2.ZERO
	_body_push_collision_velocity = desired_velocity + safe_push_velocity
	var previous_position := global_position
	_update_crowd_breakthrough_collision_mask(_body_push_collision_velocity)
	velocity = _body_push_collision_velocity + knockback_velocity
	move_and_slide()
	_apply_crowd_breakthrough_path_push(previous_position, global_position, _body_push_collision_velocity)
	_apply_body_push_from_slide_collisions()
	_decay_body_push_velocity(delta)

func apply_body_push(push_velocity: Vector2) -> void:
	if not body_push_enabled:
		return
	if push_velocity.length_squared() <= 0.01:
		return
	body_push_velocity += push_velocity
	var max_speed := maxf(body_push_max_speed, 0.0)
	if max_speed > 0.0 and body_push_velocity.length() > max_speed:
		body_push_velocity = body_push_velocity.normalized() * max_speed

func get_body_push_collision_velocity() -> Vector2:
	return _body_push_collision_velocity

func set_crowd_breakthrough_active(active: bool) -> void:
	if _crowd_breakthrough_active == active:
		return
	_crowd_breakthrough_active = active
	if not active:
		_set_crowd_breakthrough_enemy_overlap(false)

func _apply_body_push_from_slide_collisions() -> void:
	if not body_push_enabled:
		return
	var own_speed := _body_push_collision_velocity.length()
	if own_speed <= maxf(body_push_min_speed_delta, 0.0):
		return
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if collision == null:
			continue
		var other := collision.get_collider() as BaseEnemy
		if other == null or other == self or not is_instance_valid(other):
			continue
		if not other.body_push_enabled:
			continue
		var push_dir := -collision.get_normal()
		if push_dir.length_squared() <= 0.001:
			push_dir = global_position.direction_to(other.global_position)
		if push_dir.length_squared() <= 0.001:
			continue
		push_dir = push_dir.normalized()
		var incoming_speed := _body_push_collision_velocity.dot(push_dir)
		if incoming_speed <= 0.0:
			continue
		var other_forward_speed := maxf(other.get_body_push_collision_velocity().dot(push_dir), 0.0)
		var speed_delta := incoming_speed - other_forward_speed
		if speed_delta <= maxf(body_push_min_speed_delta, 0.0):
			continue
		other.apply_body_push(push_dir * speed_delta * maxf(body_push_strength, 0.0))

func _decay_body_push_velocity(delta: float) -> void:
	if body_push_velocity.length_squared() <= 0.01:
		body_push_velocity = Vector2.ZERO
		return
	body_push_velocity = body_push_velocity.move_toward(Vector2.ZERO, maxf(body_push_decay, 0.0) * maxf(delta, 0.0))

func _update_crowd_breakthrough_collision_mask(move_velocity: Vector2) -> void:
	if not _crowd_breakthrough_active:
		_set_crowd_breakthrough_enemy_overlap(false)
		return
	if move_velocity.length_squared() <= 1.0:
		_set_crowd_breakthrough_enemy_overlap(false)
		return
	_set_crowd_breakthrough_enemy_overlap(not _has_crowd_breakthrough_blocker(move_velocity))

func _set_crowd_breakthrough_enemy_overlap(enabled: bool) -> void:
	if _crowd_breakthrough_is_overlapping_enemies == enabled:
		return
	self.set_collision_mask_value(3, not enabled)
	_crowd_breakthrough_is_overlapping_enemies = enabled

func _has_crowd_breakthrough_blocker(move_velocity: Vector2) -> bool:
	var move_dir := move_velocity.normalized()
	var half_width := _get_crowd_breakthrough_half_width()
	var lookahead := maxf(half_width * 2.0, move_velocity.length() * 0.18)
	for enemy in _get_crowd_breakthrough_candidates(lookahead + half_width):
		if enemy == self or not _is_crowd_breakthrough_blocker(enemy):
			continue
		var to_enemy := enemy.global_position - global_position
		var forward_distance := to_enemy.dot(move_dir)
		if forward_distance < 0.0 or forward_distance > lookahead:
			continue
		var lateral_distance := absf(to_enemy.dot(Vector2(-move_dir.y, move_dir.x)))
		if lateral_distance <= half_width:
			return true
	return false

func _apply_crowd_breakthrough_path_push(start_position: Vector2, end_position: Vector2, move_velocity: Vector2) -> void:
	if not _crowd_breakthrough_active or move_velocity.length_squared() <= 1.0:
		return
	var segment := end_position - start_position
	if segment.length_squared() <= 1.0:
		segment = move_velocity.normalized() * maxf(_get_crowd_breakthrough_half_width(), 1.0)
	var segment_length := segment.length()
	var move_dir := segment / segment_length
	var side_dir := Vector2(-move_dir.y, move_dir.x)
	var half_width := _get_crowd_breakthrough_half_width()
	var search_radius := segment_length + half_width * 2.0
	var base_push_speed := move_velocity.length() * maxf(crowd_breakthrough_side_push_strength, 0.0)
	if base_push_speed <= 0.0:
		return
	for enemy in _get_crowd_breakthrough_candidates(search_radius):
		if enemy == self or not _is_crowd_breakthrough_push_target(enemy):
			continue
		var to_enemy := enemy.global_position - start_position
		var along := clampf(to_enemy.dot(move_dir), 0.0, segment_length)
		var closest_point := start_position + move_dir * along
		var offset := enemy.global_position - closest_point
		if offset.length() > half_width:
			continue
		var side_sign := 1.0
		var lateral := offset.dot(side_dir)
		if absf(lateral) > 0.001:
			side_sign = signf(lateral)
		elif enemy.get_instance_id() % 2 == 0:
			side_sign = -1.0
		enemy.apply_body_push(side_dir * side_sign * base_push_speed)

func _get_crowd_breakthrough_candidates(radius: float) -> Array[BaseEnemy]:
	var output: Array[BaseEnemy] = []
	var tree := get_tree()
	if tree == null:
		return output
	var registry := tree.root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("get_enemies_in_radius"):
		var registered_enemies: Variant = registry.call("get_enemies_in_radius", global_position, maxf(radius, 1.0), self)
		if registered_enemies is Array:
			for enemy_ref in registered_enemies:
				var enemy := enemy_ref as BaseEnemy
				if enemy != null and is_instance_valid(enemy):
					output.append(enemy)
			return output
	for enemy_ref in tree.get_nodes_in_group("enemies"):
		var enemy := enemy_ref as BaseEnemy
		if enemy == null or enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		output.append(enemy)
	return output

func _is_crowd_breakthrough_push_target(enemy: BaseEnemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.body_push_enabled:
		return false
	return not _is_crowd_breakthrough_blocker(enemy)

func _is_crowd_breakthrough_blocker(enemy: BaseEnemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.is_boss or enemy.is_in_group("boss"):
		return true
	if enemy is EliteEnemy:
		return true
	if enemy.has_method("is_quest_movement_locked") and enemy.is_quest_movement_locked():
		return true
	return false

func _get_crowd_breakthrough_half_width() -> float:
	var radius := 16.0
	var collision_shape := get_node_or_null("NPCCollision") as CollisionShape2D
	if collision_shape != null and collision_shape.shape != null:
		var shape := collision_shape.shape
		if shape is CircleShape2D:
			radius = (shape as CircleShape2D).radius
		elif shape is RectangleShape2D:
			var size := (shape as RectangleShape2D).size
			radius = maxf(size.x, size.y) * 0.5
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			radius = maxf(capsule.radius, capsule.height * 0.5)
	return maxf(radius * maxf(crowd_breakthrough_width_multiplier, 0.1), 1.0)

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
	if _crowd_breakthrough_is_overlapping_enemies:
		return
	var is_being_knocked_back: bool = float(knockback.get("amount", 0.0)) > 0.01
	if is_being_knocked_back:
		if not _is_knockback_overlap_mode:
			# During knockback, disable enemy-vs-enemy body collision to allow overlap.
			self.set_collision_mask_value(3, false)
			_is_knockback_overlap_mode = true
		return
	if _is_knockback_overlap_mode:
		# Restore normal enemy collision behavior after knockback ends.
		self.set_collision_mask_value(3, true)
		_is_knockback_overlap_mode = false

func set_quest_highlight(enabled: bool, color: Color = Color.WHITE) -> void:
	if self is EliteEnemy:
		var elite := self as EliteEnemy
		if elite.has_method("set_quest_highlight"):
			elite.set_quest_highlight(enabled, color)
		else:
			elite.highlight(enabled)
			if enabled:
				elite.set_highlight_color(color)
		return
	if has_method("set_outline_highlight"):
		set_outline_highlight(enabled, color, 1.0)

func has_spawn_tag(tag: StringName) -> bool:
	return spawn_tags.has(tag)

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
