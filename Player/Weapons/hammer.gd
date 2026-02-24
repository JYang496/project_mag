extends Melee
class_name Hammer

signal calculate_weapon_damage(damage)
signal calculate_attack_cooldown(attack_cooldown)
signal calculate_weapon_speed(speed)
signal calculate_weapon_size(size)

const AIM_ROTATION_OFFSET := deg_to_rad(90)
var ITEM_NAME := "Hammer"

var weapon_data := {
	"1": {
		"level": "1",
		"damage": "42",
		"range": "130",
		"dash_speed": "780",
		"return_speed": "620",
		"reload": "1.3",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "50",
		"range": "140",
		"dash_speed": "820",
		"return_speed": "650",
		"reload": "1.2",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "58",
		"range": "150",
		"dash_speed": "860",
		"return_speed": "680",
		"reload": "1.1",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "70",
		"range": "160",
		"dash_speed": "900",
		"return_speed": "700",
		"reload": "1.0",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "84",
		"range": "170",
		"dash_speed": "940",
		"return_speed": "720",
		"reload": "0.95",
		"cost": "1",
	},
	"6": {
		"level": "6",
		"damage": "100",
		"range": "180",
		"dash_speed": "980",
		"return_speed": "740",
		"reload": "0.9",
		"cost": "1",
	},
	"7": {
		"level": "7",
		"damage": "120",
		"range": "190",
		"dash_speed": "1040",
		"return_speed": "780",
		"reload": "0.85",
		"cost": "1",
	},
}

var base_damage := 1
var damage := 1
var attack_range := 130.0
var base_dash_speed := 780.0
var dash_speed := 780.0
var base_return_speed := 620.0
var return_speed := 620.0
var base_attack_cooldown := 1.0
var attack_cooldown := 1.0
var base_size := 1.0
var size := 1.0
var overlapping := false

var _tracked_enemies: Array[BaseEnemy] = []
var _target: BaseEnemy

enum AttackState {
	IDLE,
	DASHING,
	RETURNING,
	COOLDOWN,
}
var _state := AttackState.IDLE

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var attack_range_area: Area2D = $AttackRange
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D
@onready var blade_anchor: Node2D = $BladeAnchor
@onready var hit_box: HitBox = $BladeAnchor/HitBox
@onready var _base_blade_scale: Vector2 = blade_anchor.scale
@onready var _base_hitbox_size: Vector2 = _get_current_hitbox_size()

func _ready() -> void:
	if sprite:
		sprite.visible = false
	_apply_fuse_sprite()
	hit_box.hitbox_owner = self
	hit_box.set_collision_mask_value(3, true)
	hit_box.collision.disabled = true
	attack_range_area.set_collision_mask_value(3, true)
	attack_range_area.set_collision_layer_value(1, false)
	setup_melee_attack_range_area(attack_range_area)
	if level:
		set_level(level)
	else:
		set_level(1)

func set_level(lv) -> void:
	lv = str(lv)
	if not weapon_data.has(lv):
		return
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	attack_range = float(weapon_data[lv]["range"])
	base_dash_speed = float(weapon_data[lv]["dash_speed"])
	base_return_speed = float(weapon_data[lv]["return_speed"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	_update_attack_range_shape()

func sync_stats() -> void:
	damage = base_damage
	dash_speed = base_dash_speed
	return_speed = base_return_speed
	attack_cooldown = base_attack_cooldown
	size = base_size
	apply_size_multiplier(size)
	calculate_damage(damage)
	calculate_attack_cooldown.emit(attack_cooldown)
	calculate_speed(dash_speed)
	calculate_weapon_size.emit(size)
	if attack_cooldown > 0:
		cooldown_timer.wait_time = attack_cooldown

func calculate_damage(pre_damage: int) -> void:
	calculate_weapon_damage.emit(pre_damage)

func calculate_speed(pre_speed: float) -> void:
	calculate_weapon_speed.emit(pre_speed)

func apply_size_multiplier(multiplier: float) -> void:
	var final_multiplier := maxf(0.1, multiplier)
	if blade_anchor:
		blade_anchor.scale = _base_blade_scale * final_multiplier
	var shape: Shape2D = hit_box.collision.shape
	if shape is RectangleShape2D:
		shape.size = _base_hitbox_size * final_multiplier

func _get_current_hitbox_size() -> Vector2:
	if hit_box and hit_box.collision and hit_box.collision.shape is RectangleShape2D:
		return (hit_box.collision.shape as RectangleShape2D).size
	return Vector2.ONE

func _physics_process(delta: float) -> void:
	center_melee_attack_range_area(attack_range_area)
	_cleanup_targets()
	_update_target()
	match _state:
		AttackState.IDLE:
			_process_idle()
		AttackState.DASHING:
			_process_dashing(delta)
		AttackState.RETURNING:
			_process_returning(delta)
		AttackState.COOLDOWN:
			pass

func _process_idle() -> void:
	blade_anchor.position = Vector2.ZERO
	if _target and is_instance_valid(_target):
		_point_weapon_to(_target.global_position)
		_start_dash()

func _process_dashing(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		_start_return()
		return
	var target_pos := _target.global_position
	blade_anchor.global_position = blade_anchor.global_position.move_toward(target_pos, dash_speed * delta)
	_point_weapon_to(target_pos)
	if blade_anchor.global_position.distance_to(target_pos) <= 8.0:
		_start_return()

func _process_returning(delta: float) -> void:
	blade_anchor.position = blade_anchor.position.move_toward(Vector2.ZERO, return_speed * delta)
	if blade_anchor.position.length() <= 1.0:
		blade_anchor.position = Vector2.ZERO
		_start_cooldown()

func _update_target() -> void:
	var range_center := get_melee_range_center()
	if _target and is_instance_valid(_target):
		if range_center.distance_to(_target.global_position) <= attack_range:
			return
	_target = _get_closest_target()

func _cleanup_targets() -> void:
	var valid_targets: Array[BaseEnemy] = []
	for enemy in _tracked_enemies:
		if is_instance_valid(enemy) and not enemy.is_dead:
			valid_targets.append(enemy)
	_tracked_enemies = valid_targets

func _get_closest_target() -> BaseEnemy:
	var range_center := get_melee_range_center()
	var nearest: BaseEnemy
	var min_dist := INF
	for enemy in _tracked_enemies:
		var dist := range_center.distance_to(enemy.global_position)
		if dist <= attack_range and dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _start_dash() -> void:
	if _state != AttackState.IDLE:
		return
	_state = AttackState.DASHING
	_set_hitbox_enabled(true)

func _start_return() -> void:
	if _state != AttackState.DASHING:
		return
	_set_hitbox_enabled(false)
	_state = AttackState.RETURNING

func _start_cooldown() -> void:
	if _state == AttackState.COOLDOWN:
		return
	_set_hitbox_enabled(false)
	_state = AttackState.COOLDOWN
	cooldown_timer.start()

func _set_hitbox_enabled(enabled: bool) -> void:
	hit_box.collision.set_deferred("disabled", not enabled)

func _point_weapon_to(world_target: Vector2) -> void:
	var direction := world_target - blade_anchor.global_position
	if direction == Vector2.ZERO:
		return
	blade_anchor.rotation = direction.angle() + AIM_ROTATION_OFFSET

func enemy_hit(_charge := 1) -> void:
	_start_return()

func _update_attack_range_shape() -> void:
	var circle_shape := attack_range_shape.shape as CircleShape2D
	if circle_shape:
		circle_shape.radius = attack_range

func _on_cooldown_timer_timeout() -> void:
	_state = AttackState.IDLE

func _on_attack_range_body_entered(body: Node2D) -> void:
	if body is BaseEnemy and not _tracked_enemies.has(body):
		_tracked_enemies.append(body)

func _on_attack_range_body_exited(body: Node2D) -> void:
	if body is BaseEnemy:
		_tracked_enemies.erase(body)
