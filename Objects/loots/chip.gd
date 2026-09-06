extends "res://Objects/loots/drop_collectable.gd"
class_name Chip

@export var default_value: int = 1
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var sound = $Snd_collected
@onready var collectable = false

var target = null
var speed = 0

func _enter_tree() -> void:
	CollectableRegistry.register_collectable(self)

func _exit_tree() -> void:
	CollectableRegistry.unregister_collectable(self)

func _ready():
	if value <= 0:
		value = default_value
	if spawn_ready:
		collision.call_deferred("set","disabled",false)
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
	var dest_tween = create_tween()
	dest_tween.tween_property(self,"rotation_degrees", 1800, 1).set_ease(Tween.EASE_IN_OUT)
	dest_tween.connect("finished", _on_dest_tween_finished)


func activate_pickup_detection() -> void:
	super.activate_pickup_detection()
	collision.call_deferred("set", "disabled", false)



func _on_dest_tween_finished():
	collision.call_deferred("set","disabled",false)

func _on_snd_collected_finished():
	queue_free()
