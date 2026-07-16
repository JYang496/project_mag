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
	if hit_box_dot != null:
		hit_box_dot.process_mode = Node.PROCESS_MODE_DISABLED
		hit_box_dot.collision_layer = 0
		hit_box_dot.collision_mask = 0
	_pick_next_waypoint()

func _physics_process(delta: float) -> void:
	_waypoint_time_left -= maxf(delta, 0.0)
	if _waypoint_time_left <= 0.0 or global_position.distance_to(_waypoint) <= arrival_distance:
		_pick_next_waypoint()
	var direction := global_position.direction_to(_waypoint)
	velocity = direction * get_current_movement_speed()
	move_and_slide()

func _pick_next_waypoint() -> void:
	_waypoint_time_left = randf_range(waypoint_interval_min, waypoint_interval_max)
	var spawner = GlobalVariables.enemy_spawner
	if spawner != null and is_instance_valid(spawner) and spawner.has_method("get_random_position"):
		_waypoint = spawner.get_random_position()
	else:
		_waypoint = global_position + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(160.0, 360.0)
