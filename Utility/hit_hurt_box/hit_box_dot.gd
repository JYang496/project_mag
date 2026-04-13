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
	if not (area is HurtBox):
		return
	if cooldown:
		return
	cooldown = true
	hit_timer.start()
	apply_attack(area)

func check_hits() -> void:
	var has_hurt_box := false
	for area in get_overlapping_areas():
		if area is HurtBox:
			has_hurt_box = true
			apply_attack(area)
	if has_hurt_box:
		cooldown = true
		hit_timer.start()
	else:
		cooldown = false # Cooldown will be false when no hurt box detected.


func _on_hit_timer_timeout() -> void:
	check_hits()
	check_overlapping()
