extends Skills

@export var dash_distance: float = 220.0
@export var dash_duration: float = 0.12
@export var default_cooldown: float = 5.0

func on_skill_ready() -> void:
	var data_cooldown := float(PlayerData.dash_cooldown)
	if data_cooldown > 0.0:
		cooldown = data_cooldown
	elif cooldown <= 0.0:
		cooldown = default_cooldown

func can_activate() -> bool:
	var direction := _get_dash_direction()
	if direction == Vector2.ZERO or _is_player_dashing():
		return false
	if _player.has_method("can_request_dash"):
		return bool(_player.call("can_request_dash", direction, dash_distance))
	return true

func activate_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var dash_direction := _get_dash_direction()
	if dash_direction == Vector2.ZERO:
		return
	if _player.has_method("request_dash"):
		_player.call("request_dash", dash_direction, dash_distance, dash_duration, &"active_dash")

func _get_dash_direction() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	if _player.velocity != Vector2.ZERO:
		return _player.velocity.normalized()
	var x_mov := Input.get_action_strength("RIGHT") - Input.get_action_strength("LEFT")
	var y_mov := Input.get_action_strength("DOWN") - Input.get_action_strength("UP")
	var input_direction := Vector2(x_mov, y_mov)
	if input_direction == Vector2.ZERO:
		return Vector2.ZERO
	return input_direction.normalized()

func _is_player_dashing() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if not _player.has_method("get_movement_status"):
		return false
	var status: Dictionary = _player.call("get_movement_status")
	return status.get("mode", StringName()) == &"dash"
