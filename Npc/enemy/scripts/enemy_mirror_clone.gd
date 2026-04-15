extends BaseEnemy
class_name EnemyMirrorClone

@export var life_time: float = 6.0

var _life_remaining: float = 0.0

func _ready() -> void:
	super._ready()
	_life_remaining = maxf(life_time, 0.2)

func _physics_process(delta: float) -> void:
	_life_remaining -= maxf(delta, 0.0)
	if _life_remaining <= 0.0:
		erase()
		return
	if is_stunned():
		knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	if PlayerData.player == null:
		return
	var direction := global_position.direction_to(PlayerData.player.global_position)
	knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
	velocity = direction * get_current_movement_speed() + knockback.amount * knockback.angle
	move_and_slide()

func death(_killing_attack: Attack = null) -> void:
	enemy_death.emit(true)
	queue_free()
