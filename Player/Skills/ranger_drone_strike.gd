extends Skills
class_name RangerDroneStrike

@export var active_duration_sec: float = 6.0
@export var strike_interval_sec: float = 0.45
@export var base_cooldown: float = 10.0
@export var base_hit_damage: int = 100
@export var level_bonus_per_three_levels: int = 3
@export var damage_type: StringName = Attack.TYPE_ENERGY
@export var orbit_radius: float = 30.0
@export var orbit_speed: float = 4.0
@export var orbit_height_offset: float = -12.0
@export var drone_move_speed: float = 320.0
@export var laser_width: float = 28.0
@export var laser_visual_width: float = 2.5
@export var laser_visual_duration_sec: float = 0.08
@export var laser_max_length: float = 360.0

const DRONE_VISUAL_TEXTURE: Texture2D = preload("res://Textures/test/star.png")

var _is_active: bool = false
var _active_left_sec: float = 0.0
var _drone_node: Node2D
var _laser_node: Line2D
var _laser_show_left_sec: float = 0.0
var _strike_accum: float = 0.0
var _current_target: Node

func on_skill_ready() -> void:
	cooldown = maxf(base_cooldown, 0.1)

func can_activate() -> bool:
	return not _is_active

func activate_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_is_active = true
	_active_left_sec = maxf(active_duration_sec, 0.1)
	_strike_accum = 0.0
	_current_target = _pick_nearest_enemy()
	_spawn_drones()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _is_active:
		return
	if _player == null or not is_instance_valid(_player):
		_end_skill()
		return
	var step := maxf(delta, 0.0)
	_active_left_sec = maxf(0.0, _active_left_sec - step)
	var interval := maxf(strike_interval_sec, 0.05)
	if not _is_target_valid(_current_target):
		_current_target = _pick_nearest_enemy()
	_update_drone_position(step)
	_update_laser_visual(step)
	_strike_accum += step
	while _strike_accum >= interval:
		_strike_accum -= interval
		_fire_target_hit()
	if _active_left_sec <= 0.0:
		_end_skill()

func _spawn_drones() -> void:
	_clear_drones()
	var drone := Node2D.new()
	drone.name = "RangerDrone"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = DRONE_VISUAL_TEXTURE
	sprite.scale = Vector2(0.75, 0.75)
	drone.add_child(sprite)
	_player.add_child(drone)
	drone.global_position = _player.global_position + Vector2(0.0, orbit_height_offset)
	_drone_node = drone
	_ensure_laser_visual()

func _ensure_laser_visual() -> void:
	if _laser_node != null and is_instance_valid(_laser_node):
		return
	var laser := Line2D.new()
	laser.name = "RangerDroneLaser"
	laser.width = maxf(laser_visual_width, 1.0)
	laser.default_color = Color(0.35, 0.95, 1.0, 0.9)
	laser.z_index = 50
	laser.visible = false
	_player.add_child(laser)
	_laser_node = laser

func _update_drone_position(delta: float) -> void:
	if _drone_node == null or not is_instance_valid(_drone_node):
		return
	var center := _player.global_position
	if _is_target_valid(_current_target):
		center = _current_target.global_position
	center += Vector2(0.0, orbit_height_offset)
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	var angle := time_sec * maxf(orbit_speed, 0.1)
	var desired_pos := center + Vector2(cos(angle), sin(angle)) * maxf(orbit_radius, 0.0)
	_drone_node.global_position = _drone_node.global_position.move_toward(desired_pos, maxf(drone_move_speed, 1.0) * maxf(delta, 0.0))

func _update_laser_visual(delta: float) -> void:
	if _laser_node == null or not is_instance_valid(_laser_node):
		return
	_laser_show_left_sec = maxf(0.0, _laser_show_left_sec - maxf(delta, 0.0))
	if _laser_show_left_sec <= 0.0:
		_laser_node.visible = false

func _fire_target_hit() -> void:
	if _drone_node == null or not is_instance_valid(_drone_node):
		return
	if not _is_target_valid(_current_target):
		_current_target = _pick_nearest_enemy()
	var beam_start := _drone_node.global_position
	var beam_end := _resolve_laser_end(beam_start)
	if beam_end == beam_start:
		return
	_show_laser(beam_start, beam_end)
	_apply_laser_damage(beam_start, beam_end)

func _resolve_laser_end(beam_start: Vector2) -> Vector2:
	if _is_target_valid(_current_target):
		var target := _current_target as Node2D
		return _clamp_laser_end(beam_start, target.global_position)
	var fallback_target := _pick_nearest_enemy()
	if _is_target_valid(fallback_target):
		_current_target = fallback_target
		return _clamp_laser_end(beam_start, (fallback_target as Node2D).global_position)
	return beam_start

func _clamp_laser_end(beam_start: Vector2, desired_end: Vector2) -> Vector2:
	var to_end := desired_end - beam_start
	var length := to_end.length()
	if length <= 0.0001:
		return beam_start
	var max_length := maxf(laser_max_length, 1.0)
	if length <= max_length:
		return desired_end
	return beam_start + to_end / length * max_length

func _show_laser(beam_start: Vector2, beam_end: Vector2) -> void:
	_ensure_laser_visual()
	if _laser_node == null or not is_instance_valid(_laser_node):
		return
	_laser_node.clear_points()
	_laser_node.add_point(_player.to_local(beam_start))
	_laser_node.add_point(_player.to_local(beam_end))
	_laser_node.visible = true
	_laser_show_left_sec = maxf(laser_visual_duration_sec, 0.01)

func _apply_laser_damage(beam_start: Vector2, beam_end: Vector2) -> void:
	var beam_vector := beam_end - beam_start
	var beam_len_sq := beam_vector.length_squared()
	if beam_len_sq <= 0.0001:
		return
	var beam_half_width := maxf(laser_width, 1.0) * 0.5
	var damage_data := DamageManager.build_damage_data(
		_player,
		_get_hit_damage(),
		damage_type,
		{"amount": 0, "angle": Vector2.ZERO}
	)
	var tree := get_tree()
	if tree == null:
		return
	for enemy_variant in tree.get_nodes_in_group("enemies"):
		if not _is_target_valid(enemy_variant):
			continue
		var enemy := enemy_variant as Node2D
		var distance := _distance_point_to_segment(enemy.global_position, beam_start, beam_end)
		if distance > beam_half_width:
			continue
		DamageManager.apply_to_target(enemy, damage_data)
		if _player.has_method("apply_bonus_hit_if_needed"):
			_player.call("apply_bonus_hit_if_needed", enemy)

func _distance_point_to_segment(point: Vector2, segment_a: Vector2, segment_b: Vector2) -> float:
	var segment: Vector2 = segment_b - segment_a
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(segment_a)
	var t: float = clampf((point - segment_a).dot(segment) / length_sq, 0.0, 1.0)
	var projection: Vector2 = segment_a + segment * t
	return point.distance_to(projection)

func _pick_nearest_enemy() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: Node2D = null
	var nearest_dist_sq := INF
	var player_pos := _player.global_position
	for enemy_variant in tree.get_nodes_in_group("enemies"):
		var enemy := enemy_variant as Node2D
		if not _is_target_valid(enemy):
			continue
		var dist_sq := player_pos.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest = enemy
			nearest_dist_sq = dist_sq
	return nearest

func _is_target_valid(target_variant: Variant) -> bool:
	if target_variant == null:
		return false
	if not is_instance_valid(target_variant):
		return false
	if not (target_variant is Node2D):
		return false
	var target := target_variant as Node2D
	if target == null:
		return false
	if target.is_queued_for_deletion():
		return false
	if not target.has_method("damaged"):
		return false
	if "is_dead" in target and bool(target.get("is_dead")):
		return false
	return true

func _get_hit_damage() -> int:
	var level: int = max(1, int(PlayerData.player_level))
	var bonus_steps := int(floor(float(level) / 3.0))
	return max(1, base_hit_damage + bonus_steps * max(0, level_bonus_per_three_levels))

func _end_skill() -> void:
	_is_active = false
	_active_left_sec = 0.0
	_clear_drones()

func _clear_drones() -> void:
	if _drone_node != null and is_instance_valid(_drone_node):
		_drone_node.queue_free()
	_drone_node = null
	if _laser_node != null and is_instance_valid(_laser_node):
		_laser_node.queue_free()
	_laser_node = null
	_laser_show_left_sec = 0.0

func _exit_tree() -> void:
	_end_skill()
