extends EliteEnemy

@onready var skill_area: Area2D = $SkillArea
var bonus_speed:float = 0
var charging : bool = false
var player_in_range : bool = false
@onready var direction = Vector2.ZERO

func _physics_process(_delta):
	if not charging:
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
	if player_in_range:
		skill_ready = false
		bonus_speed = -0.7 * movement_speed
		highlight_material.set_shader_parameter("outline_color", Color.RED)
		self.set_collision_mask_value(3,false)
		await get_tree().create_timer(1.0).timeout
		charging = true
		bonus_speed = 15 * movement_speed
		await get_tree().create_timer(1.2).timeout
		highlight_material.set_shader_parameter("outline_color", Color.YELLOW)
		self.set_collision_mask_value(3,true)
		charging = false
		bonus_speed = 0
		skill_timer.start()

func _on_skill_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true

func _on_skill_area_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
