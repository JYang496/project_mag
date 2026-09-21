extends Node
class_name SimulatedPlayerDriver

var player: Player
var weapon: Weapon
var scenario: WeaponPerformanceScenario
var targets: Array[Node2D] = []
var elapsed_sec := 0.0
var _skill_fired := false
var _periodic_skill_elapsed := 0.0
var _origin := Vector2.ZERO
var _running := false


func begin(
		player_value: Player,
		weapon_value: Weapon,
		scenario_value: WeaponPerformanceScenario,
		target_values: Array[Node2D]
) -> void:
	player = player_value
	weapon = weapon_value
	scenario = scenario_value
	targets = target_values
	elapsed_sec = 0.0
	_skill_fired = false
	_periodic_skill_elapsed = 0.0
	_origin = player.global_position if player != null else Vector2.ZERO
	_running = true
	_release_actions()


func stop() -> void:
	_running = false
	_release_actions()
	if weapon != null and is_instance_valid(weapon):
		weapon.handle_primary_input(false, false, true, 0.0)


func _physics_process(delta: float) -> void:
	if not _running or player == null or weapon == null \
			or not is_instance_valid(player) or not is_instance_valid(weapon):
		return
	elapsed_sec += maxf(delta, 0.0)
	_update_movement()
	var target := _select_target()
	if target != null:
		weapon.turn_toward_world_position(target.global_position, delta, 12.0)
	_update_fire(delta)
	_update_skill(delta)


func _update_movement() -> void:
	_release_movement()
	match scenario.movement_pattern:
		&"circle":
			var phase := fposmod(elapsed_sec, 8.0) / 8.0 * TAU
			_press_direction(Vector2(cos(phase), sin(phase)))
		&"figure_eight":
			var phase := fposmod(elapsed_sec, 10.0) / 10.0 * TAU
			_press_direction(Vector2(cos(phase), sin(phase * 2.0)))


func _press_direction(direction: Vector2) -> void:
	if direction.x < -0.25:
		Input.action_press("LEFT")
	elif direction.x > 0.25:
		Input.action_press("RIGHT")
	if direction.y < -0.25:
		Input.action_press("UP")
	elif direction.y > 0.25:
		Input.action_press("DOWN")


func _update_fire(delta: float) -> void:
	var should_fire := false
	match scenario.fire_pattern:
		&"continuous":
			should_fire = true
		&"standard_sequence":
			should_fire = (elapsed_sec >= 3.0 and elapsed_sec < 8.0) \
				or (elapsed_sec >= 10.0 and elapsed_sec < 13.0)
		&"burst":
			should_fire = fmod(elapsed_sec, 1.0) < 0.35
	if should_fire:
		Input.action_press("ATTACK")
		weapon.handle_primary_input(true, false, false, delta)
	else:
		Input.action_release("ATTACK")
		weapon.handle_primary_input(false, false, true, delta)


func _update_skill(delta: float) -> void:
	if scenario.skill_pattern == &"none" or weapon.active_skill_effect_id == StringName():
		return
	var once_time := 9.5 if scenario.fire_pattern == &"standard_sequence" else 1.5
	if scenario.skill_pattern == &"once" and not _skill_fired and elapsed_sec >= once_time:
		_cast_skill()
	elif scenario.skill_pattern == &"periodic":
		_periodic_skill_elapsed += delta
		if _periodic_skill_elapsed >= 2.5:
			_periodic_skill_elapsed = 0.0
			_cast_skill()


func _cast_skill() -> void:
	weapon.skill_runtime.force_ready()
	player.add_energy(player.player_max_energy)
	_skill_fired = weapon.request_weapon_skill() or _skill_fired


func _select_target() -> Node2D:
	var best: Node2D
	var best_distance := INF
	for target in targets:
		if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		var distance := player.global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


func _release_actions() -> void:
	Input.action_release("ATTACK")
	_release_movement()


func _release_movement() -> void:
	for action in ["UP", "DOWN", "LEFT", "RIGHT"]:
		Input.action_release(action)


func _exit_tree() -> void:
	_release_actions()
