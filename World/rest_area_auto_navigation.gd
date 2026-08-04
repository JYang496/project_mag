extends RefCounted

func start_player_navigation(target_global: Vector2, zone_move_speed: float) -> void:
	var player := _get_player()
	if player == null:
		return
	configure_zone_move_speed(zone_move_speed)
	if player.has_method("start_auto_nav"):
		player.call("start_auto_nav", target_global)

func stop_player_navigation() -> void:
	var player := _get_player()
	clear_zone_move_speed_override()
	if player != null and player.has_method("stop_auto_nav"):
		player.call("stop_auto_nav")

func has_player_arrived(target_global: Vector2, reach_distance: float) -> bool:
	var player := _get_player()
	if player == null:
		return true
	if player.has_method("is_auto_nav_active"):
		return not bool(player.call("is_auto_nav_active"))
	return player.global_position.distance_to(target_global) <= reach_distance

func clear_zone_move_speed_override() -> void:
	var player := _get_player()
	if player != null and player.has_method("configure_auto_nav_speed_mul"):
		player.call("configure_auto_nav_speed_mul", 1.0)

func configure_zone_move_speed(zone_move_speed: float) -> void:
	var player := _get_player()
	if player == null or not player.has_method("configure_auto_nav_speed_mul"):
		return
	var base_speed := 1.0
	if "player_speed" in PlayerData and "player_bonus_speed" in PlayerData:
		base_speed = maxf(float(PlayerData.player_speed) + float(PlayerData.player_bonus_speed), 1.0)
	var rest_speed_bonus := 0.0
	if player.has_method("get_rest_phase_move_speed_bonus"):
		rest_speed_bonus = maxf(float(player.call("get_rest_phase_move_speed_bonus")), 0.0)
	base_speed += rest_speed_bonus
	var target_speed := maxf(zone_move_speed + rest_speed_bonus, 1.0)
	var speed_mul := clampf(target_speed / base_speed, 0.1, 8.0)
	player.call("configure_auto_nav_speed_mul", speed_mul)

func _get_player() -> Node:
	var player: Node = PlayerData.player
	if player != null and is_instance_valid(player):
		return player
	return null
