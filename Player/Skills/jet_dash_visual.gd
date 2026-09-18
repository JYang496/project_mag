extends "res://Visual/Oblique/billboard_visual_2d.gd"
## Screen-facing image-generated reverse shockwave animation.

const ANIMATION_NAME := &"dash_shockwave"
const FRAME_SIZE := 128.0
const BACK_OFFSET := 11.0
const PLAYBACK_FPS := 24.0
const FRAME_TEXTURES: Array[Texture2D] = [
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_01_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_02_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_03_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_04_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_05_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_06_normalized.png"),
]

var _direction := Vector2.RIGHT
var _screen_direction := Vector2.RIGHT
var _playing := false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	# This visual is owned by the player, so it must inherit the player's depth
	# bucket instead of calculating a second, incompatible screen-Y z-index.
	depth_sort_enabled = false
	z_as_relative = true
	z_index = -1
	show_behind_parent = true
	screen_offset = Vector2(0, -8)
	super._ready()
	_build_animation()


func start_jet(direction: Vector2, _duration: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	_direction = direction.normalized()
	_playing = true
	_update_screen_direction()
	_update_sprite_transform()
	_sprite.visible = true
	_sprite.stop()
	_sprite.frame = 0
	_sprite.play(ANIMATION_NAME)


func release_jet() -> void:
	# The generated frames already contain their own breakup and fade-out timing.
	pass


func stop_jet() -> void:
	_playing = false
	if is_instance_valid(_sprite):
		_sprite.stop()
		_sprite.visible = false


func _process(delta: float) -> void:
	super._process(delta)
	if not _playing:
		return
	_update_screen_direction()
	_update_sprite_transform()


func _build_animation() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_loop(ANIMATION_NAME, false)
	frames.set_animation_speed(ANIMATION_NAME, PLAYBACK_FPS)
	for texture in FRAME_TEXTURES:
		frames.add_frame(ANIMATION_NAME, texture)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.animation = ANIMATION_NAME
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_as_relative = true
	_sprite.z_index = 0
	_sprite.visible = false
	_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_sprite)


func _update_screen_direction() -> void:
	var view := _get_hybrid_view()
	if view != null:
		_screen_direction = (view.call("world_vector_to_screen", _direction, get_parent().global_position) as Vector2).normalized()
	else:
		_screen_direction = FixedObliqueProjectionType.world_vector_to_screen(_direction).normalized()


func _update_sprite_transform() -> void:
	var shock_direction := -_screen_direction
	_sprite.rotation = shock_direction.angle()
	# Every source frame is left-aligned at X=0. Offset the centered texture by
	# half a frame so that this shared left edge stays fixed behind the player.
	_sprite.position = (shock_direction * (FRAME_SIZE * 0.5 + BACK_OFFSET)).round()


func _on_animation_finished() -> void:
	stop_jet()
