extends CharacterBody2D
class_name Bullet

var hp = 1
var speed = 600.0
var damage = 1
var direction = Vector2.RIGHT
var blt_texture
@onready var player  = get_tree().get_first_node_in_group("player")
@onready var expire_timer = $ExpireTimer
@onready var bullet_sprite = get_node("%BulletSprite")

func _ready():
	bullet_sprite.texture = blt_texture
	rotation = direction.angle() + deg_to_rad(90)
	velocity = direction * speed
	expire_timer.start()

func _physics_process(_delta):
	move_and_slide()
	
func enemy_hit(charge = 1):
	hp -= charge
	if hp <= 0:
		queue_free()


func _on_expire_timer_timeout():
	queue_free()
