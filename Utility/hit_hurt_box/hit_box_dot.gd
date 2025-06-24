extends HitBox
class_name HitBoxDot

@onready var hit_timer = $HitTimer
var dot_cd : float
var cooldown = false

func _ready() -> void:
	if dot_cd:
		hit_timer.wait_time = dot_cd
	if hitbox_owner:
		set_owner(hitbox_owner)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox and not cooldown:
		check_hits()

func check_hits() -> void:
	cooldown = false # Cooldown will be false when no hurt box detected.
	for area in get_overlapping_areas():
		if area is HurtBox:
			cooldown = true
			hit_timer.start()
			apply_attack(area)


func _on_hit_timer_timeout() -> void:
	check_hits()
	check_overlapping()
