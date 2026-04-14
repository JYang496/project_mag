extends Skills
class_name RangerDroneStrike

@export var drone_count: int = 2
@export var active_duration_sec: float = 6.0
@export var strike_interval_sec: float = 0.45
@export var base_cooldown: float = 10.0
@export var base_hit_damage: int = 14
@export var level_bonus_per_three_levels: int = 3
@export var damage_type: StringName = Attack.TYPE_ENERGY

var _is_active: bool = false
var _active_left_sec: float = 0.0
var _drone_nodes: Array[Node2D] = []
var _drone_accums: Array[float] = []

func on_skill_ready() -> void:
	cooldown = maxf(base_cooldown, 0.1)

func can_activate() -> bool:
	return not _is_active

func activate_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_is_active = true
	_active_left_sec = maxf(active_duration_sec, 0.1)
	_spawn_drones()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _is_active:
		return
	if _player == null or not is_instance_valid(_player):
		_end_skill()
		return
	var step := maxf(delta, 0.0)
	_active_left_sec = maxf(0.0, _active_left_sec - step)
	_update_drone_positions(step)
	var interval := maxf(strike_interval_sec, 0.05)
	for i in range(_drone_accums.size()):
		_drone_accums[i] += step
		while _drone_accums[i] >= interval:
			_drone_accums[i] -= interval
			_fire_random_target_hit()
	if _active_left_sec <= 0.0:
		_end_skill()

func _spawn_drones() -> void:
	_clear_drones()
	var count: int = max(1, drone_count)
	for i in range(count):
		var drone := Node2D.new()
		drone.name = "RangerDrone_%d" % i
		_player.add_child(drone)
		_drone_nodes.append(drone)
		_drone_accums.append(randf_range(0.0, maxf(strike_interval_sec, 0.05)))

func _update_drone_positions(_delta: float) -> void:
	if _drone_nodes.is_empty():
		return
	var center := _player.global_position
	var count := _drone_nodes.size()
	var radius := 34.0
	var time_sec := float(Time.get_ticks_msec()) / 1000.0
	for i in range(count):
		var drone := _drone_nodes[i]
		if drone == null or not is_instance_valid(drone):
			continue
		var angle := time_sec * 3.5 + TAU * float(i) / float(max(1, count))
		drone.global_position = center + Vector2(cos(angle), sin(angle)) * radius

func _fire_random_target_hit() -> void:
	var target := _pick_random_enemy()
	if target == null:
		return
	var damage_data := DamageManager.build_damage_data(
		_player,
		_get_hit_damage(),
		damage_type,
		{"amount": 0, "angle": Vector2.ZERO}
	)
	DamageManager.apply_to_target(target, damage_data)
	if _player.has_method("apply_bonus_hit_if_needed"):
		_player.call("apply_bonus_hit_if_needed", target)

func _pick_random_enemy() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var pool: Array[Node] = []
	for enemy_variant in tree.get_nodes_in_group("enemies"):
		var enemy := enemy_variant as Node
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy.has_method("damaged"):
			continue
		pool.append(enemy)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _get_hit_damage() -> int:
	var level: int = max(1, int(PlayerData.player_level))
	var bonus_steps := int((level - 1) / 3)
	return max(1, base_hit_damage + bonus_steps * max(0, level_bonus_per_three_levels))

func _end_skill() -> void:
	_is_active = false
	_active_left_sec = 0.0
	_clear_drones()

func _clear_drones() -> void:
	for drone in _drone_nodes:
		if drone != null and is_instance_valid(drone):
			drone.queue_free()
	_drone_nodes.clear()
	_drone_accums.clear()

func _exit_tree() -> void:
	_end_skill()
