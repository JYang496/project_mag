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
		decay_knockback()
		move_with_body_push(Vector2.ZERO, delta)
		return
	if PlayerData.player == null:
		return
	var direction := global_position.direction_to(PlayerData.player.global_position)
	decay_knockback()
	move_with_body_push(direction * get_current_movement_speed(), delta)

func _grants_standard_death_rewards() -> bool:
	return false
