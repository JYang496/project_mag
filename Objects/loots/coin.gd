extends Node2D
class_name Coin

const BASE_SPRITE_SCALE := Vector2(0.6, 0.6)
const VALUE_5_SCALE := 1.25
const VALUE_10_SCALE := 1.5

@export var value = 1
@export var spawn_ready: bool = false
@export var trajectory_animation_managed: bool = false
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var sound = $Snd_collected
@onready var collectable = false

var target = null
var speed = 0
var _collected := false

func _enter_tree() -> void:
	var registry: Node = get_node_or_null("/root/CollectableRegistry")
	if registry != null and registry.has_method("register_collectable"):
		registry.call("register_collectable", self)

func _exit_tree() -> void:
	var registry: Node = get_node_or_null("/root/CollectableRegistry")
	if registry != null and registry.has_method("unregister_collectable"):
		registry.call("unregister_collectable", self)

func _ready():
	if spawn_ready:
		collision.call_deferred("set","disabled",false)
		stop_drop_flip()
		set_value()
		return
	if trajectory_animation_managed:
		start_drop_flip()
		set_value()
		return
	play_animation()
	set_value()


func _physics_process(delta):
	batch_attraction_step(delta)

func batch_attraction_step(delta: float) -> void:
	if target != null:
		global_position = global_position.move_toward(target.global_position, speed)
		speed += 5 * delta
		
func collect():
	if _collected:
		return 0
	_collected = true
	collision.call_deferred("set","disabled",true)
	sprite.visible = false
	queue_redraw()
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
	sprite.scale = BASE_SPRITE_SCALE * visual_scale
	queue_redraw()

func _draw() -> void:
	if _collected:
		return
	if value >= 10:
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.94, 0.68, 0.14))
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 32, Color(1.0, 0.94, 0.68, 0.72), 1.5, true)
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 0.86, 0.22))
	elif value >= 5:
		draw_circle(Vector2.ZERO, 9.5, Color(0.72, 0.96, 1.0, 0.10))
		draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 28, Color(0.72, 0.96, 1.0, 0.58), 1.0, true)

	
func play_animation() -> void:
	start_drop_flip()
	var dest_tween = create_tween()
	dest_tween.tween_property(self,"rotation_degrees", 1800, 1).set_ease(Tween.EASE_IN_OUT)
	dest_tween.connect("finished", _on_dest_tween_finished)

func start_drop_flip() -> void:
	if sprite == null:
		return
	sprite.visible = true
	sprite.play(&"flip")

func sync_trajectory_visual() -> void:
	if sprite != null:
		sprite.call("_apply_compensation")

func set_trajectory_screen_height(height: float) -> void:
	if sprite != null and sprite.has_method("set_screen_offset"):
		sprite.call("set_screen_offset", Vector2(0.0, -maxf(height, 0.0)))

func stop_drop_flip() -> void:
	if sprite == null:
		return
	sprite.stop()
	sprite.animation = &"flip"
	sprite.frame = 0

func activate_pickup_detection() -> void:
	spawn_ready = true
	stop_drop_flip()
	collision.call_deferred("set","disabled",false)

func _on_dest_tween_finished():
	activate_pickup_detection()

func _on_snd_collected_finished():
	queue_free()
