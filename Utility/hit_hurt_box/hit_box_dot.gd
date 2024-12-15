extends Area2D
class_name HitBoxDot

@onready var collision = $CollisionShape2D
@onready var hit_timer = $HitTimer
@onready var hit_box_owner = get_owner()
var hitbox_owner
var dot_cd : float
var attack : Attack
var cooldown = false


func _ready() -> void:
	if dot_cd:
		hit_timer.wait_time = dot_cd
	if hitbox_owner:
		set_owner(hitbox_owner)
		hit_box_owner = get_owner()


func _physics_process(delta: float) -> void:
	if cooldown:
		return
	for area in get_overlapping_areas():
		if area is HurtBox:
			cooldown = true
			hit_timer.start()
			var target = area.get_owner()
			attack = Attack.new()
			attack.damage = hit_box_owner.damage
			if "knock_back" in hitbox_owner:
				attack.knock_back = hit_box_owner.knock_back
				if hitbox_owner is Tornado:
					attack.knock_back = {
						"amount" : 100,
						"angle" : area.global_position.direction_to(hit_box_owner.global_position)
					}
			target.damaged(attack)
			if hit_box_owner.has_method("enemy_hit"):
				hit_box_owner.enemy_hit(1)


func _on_hit_timer_timeout() -> void:
	cooldown = false
