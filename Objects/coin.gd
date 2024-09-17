extends Node2D

@export var value = 1
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var sound = $Snd_collected	
var target = null
var speed = 0

func _ready():
	if value < 5:
		return
	elif value < 25:
		pass
	else:
		pass

func _physics_process(delta):
	if target != null:
		global_position = global_position.move_toward(target.global_position, speed)
		speed += 5*delta
		
func collect():
	collision.call_deferred("set","disabled",true)
	sprite.visible = false
	sound.play()
	return value


func _on_snd_collected_finished():
	queue_free()
