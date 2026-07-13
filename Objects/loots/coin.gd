extends Node2D
class_name Coin

@export var value = 1
@export var spawn_ready: bool = false
@export var trajectory_animation_managed: bool = false
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var sound = $Snd_collected
@onready var collectable = false

var target = null
var speed = 0

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
	if target != null:
		global_position = global_position.move_toward(target.global_position, speed)
		speed += 5 * delta
		
func collect():
	collision.call_deferred("set","disabled",true)
	sprite.visible = false
	sound.play()
	return value

func set_value():
	if value < 5:
		return
	elif value < 25:
		pass
	else:
		pass

	
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
