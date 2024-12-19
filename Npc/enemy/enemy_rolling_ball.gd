extends BaseEnemy

@onready var hit_box_dot: HitBoxDot = $HitBoxDot

func _ready() -> void:
	hit_box_dot.hitbox_owner = self

func _physics_process(_delta):
	## direction to applied normalized
	var direction = global_position.direction_to(player.global_position)
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	velocity = direction * movement_speed
	velocity += knockback.amount * knockback.angle
	move_and_slide()
