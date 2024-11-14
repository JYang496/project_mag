extends Area2D
class_name HitBoxDot

@onready var collision = $CollisionShape2D
@onready var hit_timer = $HitTimer
@onready var hit_box_owner = get_owner()
var attack : Attack
var cooldown = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	for area in get_overlapping_areas():
		if area is HurtBox and not cooldown:
			cooldown = true
			hit_timer.start()
			var target = area.get_owner()
			attack = Attack.new()
			attack.damage = hit_box_owner.damage
			target.damaged(attack)


func _on_hit_timer_timeout() -> void:
	cooldown = false
