extends "res://Objects/loots/drop_collectable.gd"
class_name Coin

const FixedObliqueProjectionType := preload("res://Visual/Oblique/fixed_oblique_projection_2d.gd")
const BASE_SPRITE_SCALE := Vector2(0.625, 0.625)
const VALUE_5_SCALE := 1.25
const VALUE_10_SCALE := 1.5
const DROP_VISUAL_HEIGHT := 24.0

@export var default_value: int = 1
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var ground_shadow: Polygon2D = $GroundShadow
@onready var collision = $CollisionShape2D
@onready var sound = $Snd_collected
@onready var collectable = false

var target = null
var speed = 0
var _collected := false
var _screen_height := 0.0
var _value_visual_scale := 1.0
var _drop_tween: Tween

func _enter_tree() -> void:
	CollectableRegistry.register_collectable(self)

func _exit_tree() -> void:
	CollectableRegistry.unregister_collectable(self)

func _ready():
	if value <= 0:
		value = default_value
	set_value()
	if spawn_ready:
		collision.call_deferred("set","disabled",false)
		start_ground_spin()
		# Enemy coins remain at their drop point and immediately collectible.
		# The short fall and rebound affect only the visual, never pickup geometry.
		if trajectory_animation_managed:
			play_animation()
		return
	if trajectory_animation_managed:
		start_drop_flip()
		return
	play_animation()


func _physics_process(delta):
	batch_attraction_step(delta)

func _process(_delta: float) -> void:
	if FixedObliqueProjectionType.is_enabled():
		z_index = int(round(FixedObliqueProjectionType.get_projected_depth(global_position) / 16.0)) - 1

func batch_attraction_step(delta: float) -> void:
	if target != null:
		global_position = global_position.move_toward(target.global_position, speed)
		speed += 5 * delta
		
func collect():
	if _collected:
		return 0
	_collected = true
	if _drop_tween != null:
		_drop_tween.kill()
	collision.call_deferred("set","disabled",true)
	sprite.stop()
	sprite.visible = false
	sprite.set_process(false)
	ground_shadow.visible = false
	ground_shadow.set_process(false)
	sound.play()
	return value

func set_value():
	if sprite == null or sound == null:
		return
	var visual_scale := 1.0
	if value >= 10:
		visual_scale = VALUE_10_SCALE
		sound.pitch_scale = 1.18
		sound.volume_db = 2.0
	elif value >= 5:
		visual_scale = VALUE_5_SCALE
		sound.pitch_scale = 1.08
		sound.volume_db = 1.0
	else:
		sound.pitch_scale = 1.0
		sound.volume_db = 0.0
	_value_visual_scale = visual_scale
	sprite.set("extra_scale", BASE_SPRITE_SCALE * visual_scale)
	_update_shadow()
	sync_trajectory_visual()

func play_animation() -> void:
	if _collected:
		return
	if _drop_tween != null:
		_drop_tween.kill()
	start_drop_flip()
	set_trajectory_screen_height(DROP_VISUAL_HEIGHT)
	_drop_tween = create_tween()
	_drop_tween.tween_method(set_trajectory_screen_height, DROP_VISUAL_HEIGHT, 0.0, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_tween.tween_method(set_trajectory_screen_height, 0.0, 5.0, 0.10)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_drop_tween.tween_method(set_trajectory_screen_height, 5.0, 0.0, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_tween.finished.connect(_on_dest_tween_finished)

func start_drop_flip() -> void:
	if sprite == null or _collected:
		return
	sprite.visible = true
	sprite.speed_scale = 1.5
	sprite.play(&"flip")

func sync_trajectory_visual() -> void:
	if sprite != null:
		sprite.call("_apply_compensation")
	if ground_shadow != null:
		ground_shadow.call("_apply_compensation")


func uses_screen_height_trajectory() -> bool:
	return true


func set_trajectory_screen_height(height: float) -> void:
	_screen_height = maxf(height, 0.0)
	if sprite != null and sprite.has_method("set_screen_offset"):
		sprite.call("set_screen_offset", Vector2(0.0, -_screen_height))
	_update_shadow()
	sync_trajectory_visual()

func _update_shadow() -> void:
	if ground_shadow == null:
		return
	var altitude := clampf(_screen_height / DROP_VISUAL_HEIGHT, 0.0, 1.0)
	ground_shadow.set("extra_scale", Vector2.ONE * _value_visual_scale * lerpf(1.0, 0.65, altitude))
	ground_shadow.self_modulate.a = lerpf(1.0, 0.4, altitude)

func start_ground_spin() -> void:
	if sprite == null or _collected:
		return
	sprite.speed_scale = 1.0
	sprite.play(&"flip")

func activate_pickup_detection() -> void:
	spawn_ready = true
	if _collected:
		return
	set_trajectory_screen_height(0.0)
	start_ground_spin()
	collision.call_deferred("set","disabled",false)

func _on_dest_tween_finished():
	activate_pickup_detection()

func _on_snd_collected_finished():
	queue_free()
