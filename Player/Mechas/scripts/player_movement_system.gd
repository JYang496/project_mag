extends RefCounted
class_name PlayerMovementSystem

var _player
var _auto_nav_speed_mul: float = 1.0

func setup(player) -> void:
	_player = player

func tick(delta: float) -> void:
	if _player == null:
		return
	if _player.moveto_enabled:
		_update_auto_navigation(delta)
	elif _player.movement_enabled:
		_update_manual_movement(delta)
	else:
		_player.velocity = _player.velocity.move_toward(Vector2.ZERO, maxf(_player.move_decel, 0.0) * maxf(delta, 0.0))

func start_auto_nav(dest: Vector2) -> void:
	if _player == null:
		return
	_player.movement_enabled = false
	_player.moveto_enabled = true
	_player.moveto_dest = dest

func stop_auto_nav() -> void:
	if _player == null:
		return
	_player.movement_enabled = true
	_player.moveto_enabled = false
	_player.moveto_dest = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_auto_nav_speed_mul = 1.0

func is_auto_navigating() -> bool:
	if _player == null:
		return false
	return bool(_player.moveto_enabled)

func configure_auto_nav_speed_mul(speed_mul: float) -> void:
	_auto_nav_speed_mul = maxf(speed_mul, 0.05)

func _update_manual_movement(delta: float) -> void:
	var allow_manual_input := true
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		allow_manual_input = str(PhaseManager.current_state()) != str(PhaseManager.PREPARE)
	if allow_manual_input:
		var mov: Vector2 = _player._resolve_buffered_move_input() + _player.extra_direction
		var speed: float = (_player.PlayerData.player_speed + _player.PlayerData.player_bonus_speed) * _player.get_total_move_speed_mul()
		var target_velocity: Vector2 = mov.normalized() * speed if mov.length_squared() > 0.0001 else Vector2.ZERO
		var is_turning: bool = _player.velocity.length_squared() > 1.0 and target_velocity.length_squared() > 1.0 and _player.velocity.dot(target_velocity) < 0.0
		var accel: float = _player.move_accel if target_velocity.length_squared() > 0.0 else _player.move_decel
		if is_turning:
			accel *= (1.0 - clampf(_player.move_turn_penalty, 0.0, 0.9))
		_player.velocity = _player.velocity.move_toward(target_velocity, maxf(accel, 0.0) * maxf(delta, 0.0))
	else:
		_player.velocity = _player.velocity.move_toward(Vector2.ZERO, maxf(_player.move_decel, 0.0) * maxf(delta, 0.0))

func _update_auto_navigation(delta: float) -> void:
	var to_dest: Vector2 = _player.moveto_dest - _player.global_position
	var distance_to_dest: float = to_dest.length()
	var reach_distance: float = maxf(3.0, _player.velocity.length() * 0.03)
	if distance_to_dest <= reach_distance:
		_player.global_position = _player.moveto_dest
		_player.velocity = Vector2.ZERO
		stop_auto_nav()
		return
	var speed: float = (_player.PlayerData.player_speed + _player.PlayerData.player_bonus_speed) * _player.get_total_move_speed_mul() * _auto_nav_speed_mul
	var target_velocity: Vector2 = to_dest.normalized() * speed
	_player.velocity = _player.velocity.move_toward(target_velocity, maxf(_player.move_accel, 0.0) * maxf(delta, 0.0))
