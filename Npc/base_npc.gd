extends CharacterBody2D
class_name BaseNPC

@onready var sprite_body = $Body
@onready var hurt_box = $HurtBox
@onready var player = get_tree().get_first_node_in_group("player")
@onready var hit_label = preload("res://UI/labels/hit_label.tscn")

# Export
@export var movement_speed = 20.0
@export var hp = 10
@export var knockback_recover = 3.5
@export var experience = 1

var knockback = Vector2.ZERO


func _ready():
	pass
	
func _physics_process(_delta):
	pass


func damaged(attack:Attack):
	var ins = hit_label.instantiate()
	ins.global_position = global_position
	ins.setNumber(attack.damage)
	$".".get_parent().add_sibling(ins)
	hp -= attack.damage
	if hp <= 0:
		death()	

func death():
		queue_free()
