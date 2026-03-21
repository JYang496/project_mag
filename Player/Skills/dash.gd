extends Skills

@export var dash_distance: float = 220.0
@export var dash_duration: float = 0.12
@export var disable_movement_while_dashing := true
@export var default_cooldown: float = 5.0

var _is_dashing := false

func on_skill_ready() -> void:
	var data_cooldown := float(PlayerData.dash_cooldown)
	if data_cooldown > 0.0:
		cooldown = data_cooldown
	elif cooldown <= 0.0:
		cooldown = default_cooldown

func can_activate() -> bool:
	return not _is_dashing and _get_dash_direction() != Vector2.ZERO

func activate_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var dash_direction := _get_dash_direction()
	if dash_direction == Vector2.ZERO:
		return
	_is_dashing = true
	var start_pos := _player.global_position
	var target_pos := start_pos + dash_direction * dash_distance
	var prev_movement_enabled: bool = bool(_player.movement_enabled)
	if disable_movement_while_dashing:
		_player.movement_enabled = false
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player, "global_position", target_pos, dash_duration)
	await tween.finished
	if disable_movement_while_dashing and is_instance_valid(_player):
		_player.movement_enabled = prev_movement_enabled
	_is_dashing = false

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
