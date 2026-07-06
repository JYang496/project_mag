extends BaseEnemy
class_name EnemyBomber

const AREA_EFFECT_SCENE := preload("res://Combat/area_effect/area_effect.tscn")

@export var chase_acceleration: float = 34.0
@export var max_speed_multiplier: float = 2.0
@export var trigger_radius: float = 72.0
@export var fuse_time: float = 1.0
@export var blast_radius: float = 74.0
@export var blast_damage_multiplier: float = 2.4
@export var fuse_warning_color: Color = Color(1.0, 0.04, 0.02, 1.0)
@export_range(0.0, 1.0, 0.01) var fuse_warning_peak_alpha: float = 0.92
@export var fuse_warning_pulse_sec: float = 0.11

var _current_speed: float = 0.0
var _is_fusing: bool = false
var _fuse_remaining: float = 0.0

func _physics_process(delta: float) -> void:
	if is_stunned():
		decay_knockback()
		move_with_body_push(Vector2.ZERO, delta)
		return
	if _is_fusing:
		_fuse_remaining -= maxf(delta, 0.0)
		decay_knockback()
		move_with_body_push(Vector2.ZERO, delta)
		if _fuse_remaining <= 0.0:
			_explode()
		return
	if PlayerData.player == null:
		return
	var base_speed := get_current_movement_speed()
	var max_speed := base_speed * maxf(max_speed_multiplier, 1.0)
	_current_speed = minf(_current_speed + chase_acceleration * delta, max_speed)
	var direction := global_position.direction_to(PlayerData.player.global_position)
	decay_knockback()
	move_with_body_push(direction * _current_speed, delta)
	if global_position.distance_to(PlayerData.player.global_position) <= trigger_radius:
		_start_fuse()

func _start_fuse() -> void:
	if _is_fusing:
		return
	_is_fusing = true
	_fuse_remaining = maxf(fuse_time, 0.1)
	_current_speed = 0.0
	damage_feedback.start_warning_flash(
		fuse_warning_color,
		fuse_warning_peak_alpha,
		fuse_warning_pulse_sec
	)

func _explode() -> void:
	if not is_inside_tree():
		return
	damage_feedback.stop_warning_flash()
	if sprite_body != null:
		sprite_body.modulate = Color.WHITE
	var area := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	if area:
		area.global_position = global_position
		area.duration = 0.22
		area.radius = maxf(blast_radius, 8.0)
		area.target_group = AreaEffect.TargetGroup.ALLIES
		area.one_shot_damage = max(1, int(round(float(max(1, damage)) * maxf(blast_damage_multiplier, 1.0))))
		area.tick_damage = 0
		area.visual_enabled = false
		area.draw_enabled = true
		area.debug_fill_color = Color(1.0, 0.35, 0.15, 0.24)
		area.debug_line_color = Color(1.0, 0.7, 0.25, 1.0)
		area.apply_once_per_target = true
		area.source_node = self
		call_deferred("add_sibling", area)
	death(null)

func _before_death(_killing_attack: Attack) -> void:
	damage_feedback.stop_warning_flash()
	if sprite_body != null:
		sprite_body.modulate = Color.WHITE
