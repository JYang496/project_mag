extends Melee
class_name DashBlade

signal calculate_weapon_damage(damage)
signal calculate_attack_cooldown(attack_cooldown)
signal calculate_weapon_speed(speed)
signal calculate_weapon_size(size)

const AIM_ROTATION_OFFSET := deg_to_rad(90)
const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")

var ITEM_NAME := "Dash Blade"

var weapon_data := {
	"1": {"damage": "28", "range": "150", "dash_speed": "900", "return_speed": "700", "fire_interval_sec": "1.1", "ammo": "24"},
	"2": {"damage": "34", "range": "160", "dash_speed": "950", "return_speed": "730", "fire_interval_sec": "1.0", "ammo": "26"},
	"3": {"damage": "40", "range": "170", "dash_speed": "980", "return_speed": "760", "fire_interval_sec": "0.95", "ammo": "28"},
	"4": {"damage": "48", "range": "180", "dash_speed": "1020", "return_speed": "780", "fire_interval_sec": "0.9", "ammo": "30"},
	"5": {"damage": "58", "range": "190", "dash_speed": "1080", "return_speed": "820", "fire_interval_sec": "0.85", "ammo": "32"},
	"6": {"damage": "70", "range": "210", "dash_speed": "1150", "return_speed": "860", "fire_interval_sec": "0.8", "ammo": "34"},
	"7": {"damage": "85", "range": "230", "dash_speed": "1220", "return_speed": "900", "fire_interval_sec": "0.75", "ammo": "36"},
	"8": {"damage": "100", "range": "250", "dash_speed": "1290", "return_speed": "940", "fire_interval_sec": "0.70", "ammo": "38"},
	"9": {"damage": "115", "range": "270", "dash_speed": "1360", "return_speed": "980", "fire_interval_sec": "0.65", "ammo": "40"}
}

var base_damage := 1
var damage := 1
var base_attack_range := 150.0
var attack_range := 150.0
var base_dash_speed := 900.0
var dash_speed := 900.0
var base_return_speed := 700.0
var return_speed := 700.0
var base_attack_cooldown := 1.0
var attack_cooldown := 1.0
var base_size := 1.0
var size := 1.0
var overlapping := false

var _tracked_enemies: Array[BaseEnemy] = []
var _target: BaseEnemy
var _dash_hit_confirmed: bool = false
@export var long_dash_trigger_range_ratio: float = 0.75
@export var close_chain_slow_multiplier: float = 0.7
@export var close_chain_slow_duration_sec: float = 3.0
var _dash_start_distance: float = 0.0
var _dash_start_target_id: int = 0

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
@onready var blade_sprite: Sprite2D = $BladeAnchor/BladeSprite
@onready var hit_box: HitBox = $BladeAnchor/HitBox
@onready var _base_blade_scale: Vector2 = blade_sprite.scale
@onready var _base_hitbox_size: Vector2 = _get_current_hitbox_size()

func _ready() -> void:
	super._ready()
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
	var level_data := get_weapon_level_data(lv, weapon_data)
	if level_data.is_empty():
		return
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_attack_range = float(level_data["range"])
	base_dash_speed = float(level_data["dash_speed"])
	base_return_speed = float(level_data["return_speed"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	notify_branch_level_applied(level)
	_update_attack_range_shape()

func sync_stats() -> void:
	damage = base_damage
	attack_range = base_attack_range
	dash_speed = base_dash_speed
	return_speed = base_return_speed
	attack_cooldown = base_attack_cooldown
	size = base_size
	damage = max(1, int(round(float(damage) * get_branch_damage_multiplier())))
	attack_range = maxf(1.0, attack_range * get_branch_attack_range_multiplier())
	dash_speed = maxf(1.0, dash_speed * get_branch_dash_speed_multiplier())
	return_speed = maxf(1.0, return_speed * get_branch_return_speed_multiplier())
	attack_cooldown = maxf(0.02, attack_cooldown * get_branch_cooldown_multiplier())
	apply_module_stat_pipeline()
	apply_size_multiplier(size)
	calculate_damage(damage)
	calculate_attack_cooldown.emit(attack_cooldown)
	calculate_speed(dash_speed)
	calculate_weapon_size.emit(size)
	if attack_cooldown > 0:
		cooldown_timer.wait_time = attack_cooldown
	_update_attack_range_shape()

func calculate_damage(pre_damage: int) -> void:
	calculate_weapon_damage.emit(pre_damage)

func calculate_speed(pre_speed: float) -> void:
	calculate_weapon_speed.emit(pre_speed)

func apply_size_multiplier(multiplier: float) -> void:
	var final_multiplier := maxf(0.1, multiplier)
	if blade_sprite:
		blade_sprite.scale = _base_blade_scale * final_multiplier
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
	if not can_run_active_behavior():
		return
	if _target and is_instance_valid(_target):
		_point_blade_to(_target.global_position)
		_start_dash()

func _process_dashing(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		_start_return()
		return
	var target_pos := _target.global_position
	blade_anchor.global_position = blade_anchor.global_position.move_toward(target_pos, dash_speed * delta)
	_point_blade_to(target_pos)
	if blade_anchor.global_position.distance_to(target_pos) <= 8.0:
		_try_confirm_dash_hit(_target)
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
	_dash_hit_confirmed = false
	_dash_start_distance = 0.0
	_dash_start_target_id = 0
	if _target and is_instance_valid(_target):
		_dash_start_distance = blade_anchor.global_position.distance_to(_target.global_position)
		_dash_start_target_id = _target.get_instance_id()
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

func _point_blade_to(world_target: Vector2) -> void:
	var direction := world_target - blade_anchor.global_position
	if direction == Vector2.ZERO:
		return
	blade_anchor.rotation = direction.angle() + AIM_ROTATION_OFFSET

func enemy_hit(_charge := 1) -> void:
	_dash_hit_confirmed = true
	_start_return()

func _try_confirm_dash_hit(target: BaseEnemy) -> void:
	if _dash_hit_confirmed:
		return
	if target == null or not is_instance_valid(target):
		return
	var hurt_box := target.get_node_or_null("HurtBox")
	if hurt_box is HurtBox:
		hit_box.apply_attack(hurt_box)
		_dash_hit_confirmed = true

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	_apply_close_chain_slow(target)
	_try_trigger_long_dash_hit(target)
	notify_branch_target_hit(target)

func _apply_close_chain_slow(target: Node) -> void:
	CLOSE_CHAIN_RULES.apply_dash_slow(target, close_chain_slow_multiplier, close_chain_slow_duration_sec)

func _try_trigger_long_dash_hit(target: Node) -> void:
	if not is_main_weapon():
		return
	if not is_offhand_skill_ready():
		return
	if target == null or not is_instance_valid(target):
		return
	if _dash_start_target_id != target.get_instance_id():
		return
	var threshold := attack_range * maxf(long_dash_trigger_range_ratio, 0.0)
	if _dash_start_distance < threshold:
		return
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"dash_blade_long_dash_hit_triggered", {
		"target": target,
		"dash_distance": _dash_start_distance,
		"threshold": threshold,
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var threshold := attack_range * maxf(long_dash_trigger_range_ratio, 0.0)
	var state := "ready"
	if not is_main_weapon():
		state = "inactive"
	elif not is_passive_ready():
		state = "waiting_refresh"
	var status := {
		"id": "dash_blade_long_dash_hit_triggered",
		"display_name": "Long Dash Hit",
		"state": state,
		"ready": state == "ready",
		"condition_type": "distance_threshold",
		"required": threshold,
		"comparison": ">=",
		"trigger_hint": "dash_start_distance",
		"refresh_hint": "reload",
		"slow_multiplier": clampf(close_chain_slow_multiplier, 0.05, 1.0),
		"slow_duration": maxf(close_chain_slow_duration_sec, 0.1),
	}
	if _state == AttackState.DASHING or _state == AttackState.RETURNING:
		var current_distance := maxf(_dash_start_distance, 0.0)
		status["current"] = current_distance
		status["progress"] = clampf(current_distance / maxf(threshold, 0.001), 0.0, 1.0)
	return status

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
