extends BaseEnemy

@export var chase_acceleration: float = 25.0
@export var slowdown_deceleration: float = 96.0
@export var max_speed_multiplier: float = 3.0
# Equal-area circular approximation of the former 150 x 150 SlowDownArea.
@export var slowdown_trigger_distance: float = 84.6

@onready var final_speed: float = movement_speed
var slowdown_triggered: bool = false

func _physics_process(delta: float) -> void:
	var ai_delta := consume_ai_update_delta(delta)
	if ai_delta <= 0.0:
		continue_lod_movement(delta)
		return
	delta = ai_delta
	var player = PlayerData.player
	if player == null or not is_instance_valid(player):
		move_enemy(Vector2.ZERO, delta)
		return
	if not slowdown_triggered:
		var trigger_distance := maxf(slowdown_trigger_distance, 0.0)
		if global_position.distance_squared_to(player.global_position) <= trigger_distance * trigger_distance:
			enter_slowdown_state()
	if is_stunned():
		decay_knockback()
		move_enemy(Vector2.ZERO, delta)
		return
	var current_base_speed: float = get_current_movement_speed()
	if slowdown_triggered:
		final_speed = move_toward(final_speed, current_base_speed, slowdown_deceleration * delta)
	else:
		var max_speed : float = current_base_speed * max_speed_multiplier
		final_speed = min(final_speed + chase_acceleration * delta, max_speed)

	## direction to applied normalized
	var direction = global_position.direction_to(player.global_position)
	move_enemy(direction * final_speed, delta)

func enter_slowdown_state() -> void:
	if slowdown_triggered:
		return
	slowdown_triggered = true
