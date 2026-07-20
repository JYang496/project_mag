extends BaseEnemy
class_name RewardEnemy

@export var waypoint_interval_min := 2.2
@export var waypoint_interval_max := 4.0
@export var arrival_distance := 28.0

var _waypoint := Vector2.ZERO
var _waypoint_time_left := 0.0

func _ready() -> void:
	super._ready()
	damage = 0
	set_collision_mask_value(1, false)
	_pick_next_waypoint()

func _physics_process(delta: float) -> void:
	var ai_delta := consume_ai_update_delta(delta)
	if ai_delta <= 0.0:
		continue_lod_movement(delta)
		return
	delta = ai_delta
	_waypoint_time_left -= maxf(delta, 0.0)
	if _waypoint_time_left <= 0.0 or global_position.distance_to(_waypoint) <= arrival_distance:
		_pick_next_waypoint()
	var direction := global_position.direction_to(_waypoint)
	move_enemy(direction * get_current_movement_speed(), delta)

func _pick_next_waypoint() -> void:
	_waypoint_time_left = randf_range(waypoint_interval_min, waypoint_interval_max)
	var spawner = GlobalVariables.enemy_spawner
	if spawner != null and is_instance_valid(spawner) and spawner.has_method("get_random_position"):
		_waypoint = spawner.get_random_position()
	else:
		_waypoint = global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(160.0, 360.0)
