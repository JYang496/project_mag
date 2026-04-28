extends BaseNPC
class_name BaseEnemy
@export var damage := 0
@export var is_boss: bool = false
@export_enum("melee", "ranged") var combat_role: String = "melee"
@export var loot_value_multiplier: float = 1.0
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

func _ready() -> void:
	hit_box_dot.hitbox_owner = self

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
	var drop = drop_preload.instantiate()
	drop.drop = coin_preload
	var drop_value := 1
	if GlobalVariables.economy_data:
		drop_value = max(1, int(GlobalVariables.economy_data.enemy_coin_drop_value))
	drop.value = drop_value
	drop.spawn_global_position = global_position
	self.call_deferred("add_sibling",drop)
	if killing_attack != null and killing_attack.is_from_player():
		PlayerData.run_enemy_kills += 1
		if self is EliteEnemy:
			PlayerData.run_elite_kills += 1
	_try_trigger_elite_kill_impact(killing_attack)
	enemy_death.emit(true)
	queue_free()

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

func is_ranged_enemy() -> bool:
	return combat_role == "ranged"

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
