extends Node2D


var speed = 1200.0
var target = null
var direction = Vector2.ZERO
var state : String = "ready"
var target_hits = 0
var hitted : bool = false
@export var target_limits = 5
@export var damage = 2

# Enemy realted
var target_close = []
var erase_buffer = []

@onready var collision = $RemoteTransform2D/Knife/CollisionShape2D
@onready var player  = get_tree().get_first_node_in_group("player")
@onready var cooldown_timer = get_node("%CooldownTimer")
@onready var detect_area = get_node("%DetectArea")
@onready var sprite = get_node("%KnifeSprite")
@onready var knife = get_node("%Knife")

func _ready():
	collision.call_deferred("set","disabled",true)
	cooldown_timer.start()

func _physics_process(delta):
	knife.damage = damage
	if target == null:
		target = get_random_target()
	if target == null:
		knife.rotation = knife.global_position.direction_to(get_global_mouse_position()).angle() + deg_to_rad(90)
	else:
		knife.rotation = knife.global_position.direction_to(target).angle() + deg_to_rad(90)
		
	match state:
		"cooldown":
			target_hits = 0
			knife.global_position = knife.global_position.move_toward(global_position,delta*speed)
			collision.call_deferred("set","disabled",true)
		"ready":
			knife.global_position = knife.global_position.move_toward(global_position,delta*speed)
			collision.call_deferred("set","disabled",true)
			if target != null:
				state = "attack"
				if target_hits >= target_limits:
					cooldown_timer.start()
					state = "cooldown"
				else:
					state = "attack"
		"return":
			collision.call_deferred("set","disabled",true)
			target = global_position
			if target.distance_to(knife.global_position) > 1:
				knife.global_position = knife.global_position.move_toward(target,delta*speed)
			else:
				target = null
				hitted = false
				if target_hits >= target_limits:
					for body in erase_buffer:
						erase_buffer.erase(body)
						target_close.erase(body)
					cooldown_timer.start()
					state = "cooldown"
				else:
					state = "attack"
				
		"attack":
			if not hitted and target != null:
				collision.call_deferred("set","disabled",false)
				knife.global_position = knife.global_position.move_toward(target,delta*speed)
			else:
				state = "return"


func get_random_target():
	if target_close.size() > 0:
		var target = target_close.pick_random()
		if target != null:
			return target.global_position
	return null

func _on_detect_area_body_entered(body):
	if not target_close.has(body) and body.is_in_group("enemies"):
		target_close.append(body)

func _on_detect_area_body_exited(body):
	if target_close.has(body):
		erase_buffer.append(body)

func _on_knife_body_entered(body):
	if body.is_in_group("enemies"):
		hitted = true
		target_hits += 1
		state = "return"

func _on_cooldown_timer_timeout():
	state = "ready"
