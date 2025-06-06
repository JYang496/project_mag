extends CharacterBody2D
class_name BaseNPC

@onready var sprite_body = $Body
@onready var hurt_box = $HurtBox
@onready var hit_label = preload("res://UI/labels/hit_label.tscn")

# Export
@export var movement_speed = 20.0
@export var hp = 10
@export var knockback_recover = 3.5

var knockback = {
	"amount": 0,
	"angle": Vector2.ZERO
}

var overlapping : bool = false
var is_dead: bool = false

func _ready():
	pass

func _physics_process(_delta):
	pass


func damaged(attack:Attack):
	
	# Hit label
	var hit_label_ins = hit_label.instantiate()
	hit_label_ins.global_position = global_position
	hit_label_ins.setNumber(attack.damage)
	get_tree().root.call_deferred("add_child",hit_label_ins)
	
	# Knock back
	knockback.amount = attack.knock_back.amount
	knockback.angle = attack.knock_back.angle
	
	
	if is_dead:
		return  # Prevents further damage processing if already dead
	hp -= attack.damage
	if hp <= 0 and not is_dead:
		is_dead = true
		death()	

func death():
		queue_free()
