extends Node2D
class_name ConeSprayVfx

@export var sprite_frames: SpriteFrames = preload("res://asset/images/effects/flame_spray/flame_spray_frames.tres")
@export var animation_name: StringName = &"spray"
@export var linger_sec: float = 0.16
@export var fade_out_sec: float = 0.1
@export var muzzle_offset_px: float = 20.0
@export var base_range_px: float = 512.0
@export var base_half_angle_deg: float = 40.0
@export var min_width_scale: float = 0.45
@export var max_width_scale: float = 1.35
@export var visual_width_multiplier: float = 1.08
@export var playback_speed: float = 1.0
@export var visible_modulate: Color = Color(1.0, 1.0, 1.0, 0.88)

@onready var spray_root: Node2D = $SprayRoot
@onready var sprite: AnimatedSprite2D = $SprayRoot/Sprite

var _linger_remaining_sec: float = 0.0
var _fade_remaining_sec: float = 0.0
var _last_direction: Vector2 = Vector2.RIGHT
var _last_range: float = 1.0
var _last_half_angle_deg: float = 1.0


func _ready() -> void:
	_configure_sprite()
	_hide_now()


func start_or_refresh(source_global_position: Vector2, direction: Vector2, spray_range: float, half_angle_deg: float) -> void:
	if direction == Vector2.ZERO:
		direction = _last_direction
	_last_direction = direction.normalized()
	_last_range = maxf(spray_range, 1.0)
	_last_half_angle_deg = maxf(half_angle_deg, 1.0)
	_linger_remaining_sec = maxf(linger_sec, 0.01)
	_fade_remaining_sec = maxf(fade_out_sec, 0.01)
	visible = true
	modulate = visible_modulate
	_update_transform(source_global_position)
	if sprite != null and not sprite.is_playing():
		sprite.play()


func update_aim(source_global_position: Vector2, direction: Vector2, spray_range: float, half_angle_deg: float) -> void:
	if not is_visible_or_fading():
		return
	if direction != Vector2.ZERO:
		_last_direction = direction.normalized()
	_last_range = maxf(spray_range, 1.0)
	_last_half_angle_deg = maxf(half_angle_deg, 1.0)
	_update_transform(source_global_position)


func is_visible_or_fading() -> bool:
	return visible and (_linger_remaining_sec > 0.0 or _fade_remaining_sec > 0.0)


func stop() -> void:
	if not visible:
		return
	if _linger_remaining_sec <= 0.0 and _fade_remaining_sec > 0.0:
		return
	_linger_remaining_sec = 0.0
	_fade_remaining_sec = maxf(fade_out_sec, 0.01)


func _physics_process(delta: float) -> void:
	if not visible:
		return
	var step: float = maxf(delta, 0.0)
	if _linger_remaining_sec > 0.0:
		_linger_remaining_sec = maxf(_linger_remaining_sec - step, 0.0)
		modulate = visible_modulate
		return
	_fade_remaining_sec = maxf(_fade_remaining_sec - step, 0.0)
	var fade_duration: float = maxf(fade_out_sec, 0.001)
	var alpha_ratio: float = clampf(_fade_remaining_sec / fade_duration, 0.0, 1.0)
	var next_modulate: Color = visible_modulate
	next_modulate.a *= alpha_ratio
	modulate = next_modulate
	if _fade_remaining_sec <= 0.0:
		_hide_now()


func _configure_sprite() -> void:
	if sprite == null:
		return
	sprite.sprite_frames = sprite_frames
	sprite.speed_scale = maxf(playback_speed, 0.01)
	var resolved_animation := _resolve_animation_name()
	if resolved_animation != StringName():
		sprite.animation = resolved_animation
		sprite.play()


func _resolve_animation_name() -> StringName:
	if sprite_frames == null:
		return StringName()
	if sprite_frames.has_animation(animation_name):
		return animation_name
	var names: PackedStringArray = sprite_frames.get_animation_names()
	if names.is_empty():
		return StringName()
	return StringName(names[0])


func _update_transform(source_global_position: Vector2) -> void:
	global_position = source_global_position + _last_direction * muzzle_offset_px
	global_rotation = _last_direction.angle()
	var length_scale: float = _last_range / maxf(base_range_px, 1.0)
	var angle_scale: float = _last_half_angle_deg / maxf(base_half_angle_deg, 1.0)
	var width_scale: float = clampf(angle_scale * maxf(visual_width_multiplier, 0.01), min_width_scale, max_width_scale)
	spray_root.scale = Vector2(maxf(length_scale, 0.01), maxf(width_scale, 0.01))


func _hide_now() -> void:
	visible = false
	_linger_remaining_sec = 0.0
	_fade_remaining_sec = 0.0
	if sprite != null:
		sprite.stop()
