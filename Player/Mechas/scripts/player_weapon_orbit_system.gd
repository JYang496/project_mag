extends RefCounted
class_name PlayerWeaponOrbitSystem

# Owns equipped-weapon formation, follow motion, and depth ordering.
const ORBIT_RADIUS := Vector2(45, 30)
const ORBIT_ACCEL := 16.0
const ORBIT_MAX_SPEED := 8.0
const ORBIT_FRICTION := 6.0
const ORBIT_OFFSET := Vector2(0, -25)
const WEAPON_BEHIND_PLAYER_Z_INDEX := -1
const WEAPON_IN_FRONT_OF_PLAYER_Z_INDEX := 1

var _player: Node2D
var weapon_orbit_states: Dictionary = {}

func _init(player: Node2D) -> void:
	_player = player

func _sync_weapon_orbit_states(force_reset := false) -> void:
	var weapons: Array = PlayerData.player_weapon_list
	var total: int = max(weapons.size(), 1)
	var base_angle := _get_mouse_angle()
	var formations := _get_formation_angle_offsets(weapons.size())
	for weapon_index in range(weapons.size()):
		var weapon = weapons[weapon_index]
		if not is_instance_valid(weapon):
			continue
		_attach_weapon_to_equipped_holder(weapon)
		var offset := TAU * float(weapon_index) / float(total)
		if weapon_index < formations.size():
			offset = formations[weapon_index]
		var state: Dictionary = weapon_orbit_states.get(weapon, {})
		if state.is_empty():
			state = {"angle": base_angle + offset, "velocity": 0.0, "offset": offset}
			weapon_orbit_states[weapon] = state
		else:
			if force_reset:
				state["angle"] = base_angle + offset
				state["velocity"] = 0.0
			state["offset"] = offset
	_remove_missing_weapon_states(weapons)

func _attach_weapon_to_equipped_holder(weapon: Weapon) -> void:
	var holder := _player.get("equppied_weapons") as Node2D
	if weapon.get_parent() == holder:
		return
	if weapon.get_parent():
		weapon.reparent(holder)
	else:
		holder.add_child(weapon)

func _update_weapon_orbits(delta: float) -> void:
	if PlayerData.player_weapon_list.is_empty():
		return
	var base_angle := _get_mouse_angle()
	for weapon in PlayerData.player_weapon_list:
		if not is_instance_valid(weapon):
			continue
		var state: Dictionary = weapon_orbit_states.get(weapon, {})
		if state.is_empty():
			continue
		var current_angle: float = state.get("angle", base_angle)
		var angular_velocity: float = state.get("velocity", 0.0)
		var offset: float = state.get("offset", 0.0)
		var target_angle := wrapf(base_angle + offset, -PI, PI)
		var angle_diff := _shortest_angle(current_angle, target_angle)
		angular_velocity += clamp(angle_diff * ORBIT_ACCEL, -ORBIT_ACCEL, ORBIT_ACCEL) * delta
		angular_velocity = clamp(angular_velocity, -ORBIT_MAX_SPEED, ORBIT_MAX_SPEED)
		angular_velocity = lerp(angular_velocity, 0.0, clamp(ORBIT_FRICTION * delta, 0.0, 1.0))
		current_angle = wrapf(current_angle + angular_velocity * delta, -PI, PI)
		state["angle"] = current_angle
		state["velocity"] = angular_velocity
		weapon.position = _get_orbit_position(current_angle)
		_update_weapon_orbit_z_index(weapon)

func _update_weapon_orbit_z_index(weapon: CanvasItem) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var weapon_node := weapon as Node2D
	if weapon_node == null:
		return
	# Judge occlusion around the orbit's visual center. ORBIT_OFFSET raises the
	# whole formation toward the mech's torso and must not make almost the entire
	# orbit count as being behind the player.
	var is_behind_player := weapon_node.position.y < ORBIT_OFFSET.y
	weapon.set_meta(&"orbit_behind_owner", is_behind_player)
	weapon.z_as_relative = true
	weapon.z_index = WEAPON_BEHIND_PLAYER_Z_INDEX \
		if is_behind_player else WEAPON_IN_FRONT_OF_PLAYER_Z_INDEX

func _remove_missing_weapon_states(valid_weapons: Array) -> void:
	var to_remove: Array = []
	for weapon in weapon_orbit_states.keys():
		if not valid_weapons.has(weapon) or not is_instance_valid(weapon):
			to_remove.append(weapon)
	for weapon in to_remove:
		weapon_orbit_states.erase(weapon)

func _get_formation_angle_offsets(count: int) -> Array:
	match count:
		1:
			return [PI]
		2:
			return [PI / 2, -PI / 2]
		3:
			return [PI / 2, -PI / 2, PI]
		4:
			return [
				PI / 4,         # front left
				-PI / 4,        # front right
				PI - PI / 4,    # back left
				-PI + PI / 4    # back right
			]
		_:
			var offsets: Array = []
			if count <= 0:
				return offsets
			for i in range(count):
				offsets.append(TAU * float(i) / float(count))
			return offsets

func _get_mouse_angle() -> float:
	var aim_position: Vector2 = _player.call("get_aim_world_position")
	return _player.global_position.direction_to(aim_position).angle()

func _get_orbit_position(angle: float) -> Vector2:
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var denominator := sqrt(pow(ORBIT_RADIUS.y * cos_a, 2) + pow(ORBIT_RADIUS.x * sin_a, 2))
	if denominator == 0:
		return ORBIT_OFFSET
	var radius := (ORBIT_RADIUS.x * ORBIT_RADIUS.y) / denominator
	return Vector2(cos_a, sin_a) * radius + ORBIT_OFFSET

func _shortest_angle(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)
