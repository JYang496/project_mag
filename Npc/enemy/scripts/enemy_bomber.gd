extends BaseEnemy
class_name EnemyBomber

const AREA_EFFECT_SCENE := preload("res://Utility/area_effect/area_effect.tscn")

@export var chase_acceleration: float = 34.0
@export var max_speed_multiplier: float = 2.0
@export var trigger_radius: float = 72.0
@export var fuse_time: float = 1.0
@export var blast_radius: float = 74.0
@export var blast_damage_multiplier: float = 2.4

var _current_speed: float = 0.0
var _is_fusing: bool = false
var _fuse_remaining: float = 0.0
var _fuse_elapsed: float = 0.0

func _physics_process(delta: float) -> void:
	if is_stunned():
		knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	if _is_fusing:
		_fuse_elapsed += maxf(delta, 0.0)
		_update_fuse_flash()
		_fuse_remaining -= maxf(delta, 0.0)
		knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		if _fuse_remaining <= 0.0:
			_explode()
		return
	if PlayerData.player == null:
		return
	var base_speed := get_current_movement_speed()
	var max_speed := base_speed * maxf(max_speed_multiplier, 1.0)
	_current_speed = minf(_current_speed + chase_acceleration * delta, max_speed)
	var direction := global_position.direction_to(PlayerData.player.global_position)
	knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
	velocity = direction * _current_speed + knockback.amount * knockback.angle
	move_and_slide()
	if global_position.distance_to(PlayerData.player.global_position) <= trigger_radius:
		_start_fuse()

func _start_fuse() -> void:
	if _is_fusing:
		return
	_is_fusing = true
	_fuse_remaining = maxf(fuse_time, 0.1)
	_fuse_elapsed = 0.0
	_current_speed = 0.0

func _update_fuse_flash() -> void:
	if sprite_body == null:
		return
	var flash_step: int = int(floor(_fuse_elapsed * 10.0))
	if flash_step % 2 == 0:
		sprite_body.modulate = Color(1.0, 0.45, 0.45, 1.0)
	else:
		sprite_body.modulate = Color.WHITE

func _explode() -> void:
	if not is_inside_tree():
		return
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

func death(killing_attack: Attack = null) -> void:
	if sprite_body != null:
		sprite_body.modulate = Color.WHITE
	super.death(killing_attack)
