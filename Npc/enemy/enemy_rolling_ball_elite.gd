extends EliteEnemy

@onready var skill_area: Area2D = $SkillArea
var bonus_speed:float = 0
var dashing : bool = false
@onready var direction = Vector2.ZERO

func _physics_process(_delta):
	if not dashing:
		direction = global_position.direction_to(PlayerData.player.global_position)
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	velocity = direction * (movement_speed + bonus_speed)
	velocity += knockback.amount * knockback.angle
	move_and_slide()

func _on_skill_timer_timeout() -> void:
	skill_ready = true


func _on_detect_timer_timeout() -> void:
	if not skill_ready:
		return
	for area in skill_area.get_overlapping_areas():
		if area is HurtBox:
			skill_ready = false
			bonus_speed = -0.7 * movement_speed
			await get_tree().create_timer(0.5).timeout
			dashing = true
			bonus_speed = 2 * movement_speed
			await get_tree().create_timer(1.0).timeout
			dashing = false
			bonus_speed = 0
