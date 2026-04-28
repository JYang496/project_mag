extends BaseEnemy
class_name EnemySpikeTurret

const PROJECTILE_SCENE := preload("res://Npc/enemy/scenes/enemy_spike_projectile.tscn")

@export var detect_range: float = 760.0
@export var attack_range: float = 430.0
@export var lock_duration: float = 1.1
@export var cooldown_duration: float = 1.9
@export var projectile_speed: float = 190.0
@export var projectile_life_time: float = 3.2
@export var muzzle_offset: float = 22.0
@export var random_move_change_interval_sec: float = 3.0
@export var screen_fire_margin: float = 28.0
@export var approaching_velocity_threshold: float = 4.0
@export var aim_warning_color: Color = Color(1.0, 0.12, 0.12, 0.9)
@export var aim_warning_width: float = 3.0

var _cooldown_remaining: float = 0.0
var _lock_remaining: float = 0.0
var _is_locking: bool = false
var _locked_direction: Vector2 = Vector2.RIGHT
var _locked_warning_distance: float = 0.0
var _aim_warning_line: Line2D = null

func _ready() -> void:
	super._ready()
	combat_role = "ranged"
	_aim_warning_line = Line2D.new()
	_aim_warning_line.name = "AimWarningLine"
	_aim_warning_line.default_color = aim_warning_color
	_aim_warning_line.width = maxf(aim_warning_width, 1.0)
	_aim_warning_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_aim_warning_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_aim_warning_line.z_index = 8
	_aim_warning_line.visible = false
	add_child(_aim_warning_line)

func _physics_process(delta: float) -> void:
	knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
	if is_stunned():
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	var ranged_move_velocity := compute_ranged_navigation(
		delta,
		detect_range,
		attack_range,
		1.0,
		0.78,
		random_move_change_interval_sec
	)
	velocity = ranged_move_velocity + knockback.amount * knockback.angle
	move_and_slide()
	_process_attack(delta)
	_update_aim_warning_visual()

func _process_attack(delta: float) -> void:
	if PlayerData.player == null:
		_cancel_lock()
		return
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		_cancel_lock()
		return
	var to_player: Vector2 = PlayerData.player.global_position - global_position
	if to_player.length() > attack_range:
		_cancel_lock()
		return
	if not is_world_position_in_player_screen(global_position, screen_fire_margin):
		_cancel_lock()
		return
	if not _is_approaching_player(to_player):
		_cancel_lock()
		return
	if not _is_locking:
		_locked_direction = to_player.normalized() if to_player.length() > 0.001 else Vector2.RIGHT
		_locked_warning_distance = _resolve_lock_warning_distance()
		_is_locking = true
		_lock_remaining = lock_duration
		return
	_lock_remaining -= delta
	if _lock_remaining > 0.0:
		return
	_fire_projectile()
	_is_locking = false
	_cooldown_remaining = cooldown_duration

func _fire_projectile() -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as EnemySpikeProjectile
	if projectile == null:
		return
	projectile.global_position = global_position + _locked_direction * muzzle_offset
	projectile.direction = _locked_direction
	projectile.speed = projectile_speed
	projectile.life_time = projectile_life_time
	projectile.damage = max(1, damage)
	projectile.source_enemy = self
	call_deferred("add_sibling", projectile)

func _cancel_lock() -> void:
	_is_locking = false
	_lock_remaining = 0.0
	_locked_warning_distance = 0.0

func _resolve_lock_warning_distance() -> float:
	var line_distance := attack_range
	if PlayerData.player:
		line_distance = minf(attack_range, PlayerData.player.global_position.distance_to(global_position))
	return maxf(line_distance, muzzle_offset + 24.0)

func _is_approaching_player(to_player: Vector2) -> bool:
	# Stationary turrets cannot move toward the player; keep them attack-capable.
	if get_current_movement_speed() <= 1.0:
		return true
	if to_player.length() <= 0.001 or velocity.length() <= 0.001:
		return false
	var approach_speed := velocity.dot(to_player.normalized())
	return approach_speed >= approaching_velocity_threshold

func _update_aim_warning_visual() -> void:
	if _aim_warning_line == null:
		return
	if not _is_locking:
		_aim_warning_line.visible = false
		_aim_warning_line.clear_points()
		return
	var lock_progress := 1.0 - (_lock_remaining / maxf(lock_duration, 0.01))
	lock_progress = clampf(lock_progress, 0.0, 1.0)
	var line_color := aim_warning_color
	line_color.a *= (0.35 + 0.65 * lock_progress)
	_aim_warning_line.default_color = line_color
	var line_start := _locked_direction * muzzle_offset
	var line_end := _locked_direction * maxf(_locked_warning_distance, muzzle_offset + 24.0)
	_aim_warning_line.points = PackedVector2Array([line_start, line_end])
	_aim_warning_line.visible = true
