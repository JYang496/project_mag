extends BaseEnemy
class_name EnemySpikeTurret

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const PROJECTILE_SCENE := preload("res://Npc/enemy/scenes/enemy_spike_projectile.tscn")

@export var detect_range: float = 760.0
@export var attack_range: float = 430.0
@export_range(0.1, 1.0, 0.01) var stationary_enter_range_ratio: float = 0.8
@export var lock_duration: float = 1.1
@export var cooldown_duration: float = 1.9
@export var projectile_speed: float = 190.0
@export var projectile_life_time: float = 3.2
@export var muzzle_offset: float = 22.0
@export var screen_fire_margin: float = 28.0
@export var aim_warning_color: Color = Color(PALETTE.ENEMY_PRIMARY, 0.94)
@export var aim_warning_width: float = 3.0
@export var aim_warning_outline_width: float = 9.0
@export var release_flash_duration: float = 0.11
@export_range(0.0, 0.2, 0.005) var fire_camera_shake: float = 0.045

var _cooldown_remaining: float = 0.0
var _lock_remaining: float = 0.0
var _is_locking: bool = false
var _is_stationary_mode: bool = false
var _locked_direction: Vector2 = Vector2.RIGHT
var _locked_warning_distance: float = 0.0
var _release_flash_remaining: float = 0.0
var _aim_warning_outline: Line2D = null
var _aim_warning_line: Line2D = null
var _aim_warning_fill: Line2D = null
var _warning_lines: Array[Line2D] = []

@onready var lock_audio: AudioStreamPlayer2D = get_node_or_null("LockAudio") as AudioStreamPlayer2D
@onready var fire_audio: AudioStreamPlayer2D = get_node_or_null("FireAudio") as AudioStreamPlayer2D
@onready var muzzle_flash: Sprite2D = get_node_or_null("MuzzleFlash") as Sprite2D

func _ready() -> void:
	super._ready()
	combat_role = "ranged"
	_aim_warning_outline = _create_warning_line("AimWarningOutline", aim_warning_outline_width, Color(PALETTE.ENEMY_DARK, 0.72), 7)
	_aim_warning_line = _create_warning_line("AimWarningLine", aim_warning_width, aim_warning_color, 8)
	_aim_warning_fill = _create_warning_line("AimWarningProgress", maxf(aim_warning_width - 1.0, 2.0), Color(1.0, 0.86, 0.62, 1.0), 9)
	_warning_lines.assign([_aim_warning_outline, _aim_warning_line, _aim_warning_fill])
	call_deferred("_register_warning_lines_with_hybrid_ground")

func _create_warning_line(line_name: String, line_width: float, color: Color, line_z_index: int) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.default_color = color
	line.width = maxf(line_width, 1.0)
	line.begin_cap_mode = Line2D.LINE_CAP_BOX
	line.end_cap_mode = Line2D.LINE_CAP_BOX
	line.antialiased = false
	line.z_index = line_z_index
	line.visible = false
	line.add_to_group(&"hybrid_ground_segment")
	line.set_meta(&"hybrid_ground_visible", false)
	add_child(line)
	return line

func _register_warning_lines_with_hybrid_ground() -> void:
	for line in _warning_lines:
		if line != null and HybridGroundRegistration.register(line, &"register_ground_segment"):
			line.visible = false

func _exit_tree() -> void:
	for line in _warning_lines:
		if line != null:
			HybridGroundRegistration.unregister(line)

func _physics_process(delta: float) -> void:
	var ai_delta := consume_ai_update_delta(delta)
	if ai_delta <= 0.0:
		continue_lod_movement(delta)
		return
	delta = ai_delta
	decay_knockback()
	if is_stunned():
		move_enemy(Vector2.ZERO, delta)
		return
	_update_stationary_mode()
	var chase_velocity := _get_chase_velocity()
	move_enemy(chase_velocity, delta)
	_process_attack(delta)
	_release_flash_remaining = maxf(0.0, _release_flash_remaining - delta)
	_update_muzzle_flash()
	_update_aim_warning_visual()

func _update_stationary_mode() -> void:
	if PlayerData.player == null:
		_is_stationary_mode = false
		return
	var distance := global_position.distance_to(PlayerData.player.global_position)
	var enter_distance := attack_range * clampf(stationary_enter_range_ratio, 0.1, 1.0)
	if _is_stationary_mode:
		if _is_locking:
			return
		if distance > attack_range:
			_is_stationary_mode = false
		return
	if distance <= enter_distance:
		_is_stationary_mode = true

func _get_chase_velocity() -> Vector2:
	if _is_stationary_mode:
		return Vector2.ZERO
	if PlayerData.player == null:
		return Vector2.ZERO
	var to_player: Vector2 = PlayerData.player.global_position - global_position
	if to_player.length() <= 0.001:
		return Vector2.ZERO
	return to_player.normalized() * get_current_movement_speed()

func _process_attack(delta: float) -> void:
	if PlayerData.player == null:
		_cancel_lock()
		return
	if not _is_stationary_mode:
		if _cooldown_remaining > 0.0:
			_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		_cancel_lock()
		return
	var to_player: Vector2 = PlayerData.player.global_position - global_position
	if _is_locking:
		_lock_remaining -= delta
		if _lock_remaining > 0.0:
			return
		_fire_projectile()
		_is_locking = false
		_cooldown_remaining = cooldown_duration
		return
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		return
	if to_player.length() > attack_range:
		_cancel_lock()
		return
	if not is_world_position_in_player_screen(global_position, screen_fire_margin):
		_cancel_lock()
		return
	_locked_direction = to_player.normalized() if to_player.length() > 0.001 else Vector2.RIGHT
	_locked_warning_distance = _resolve_lock_warning_distance()
	_is_locking = true
	_lock_remaining = lock_duration
	if lock_audio != null:
		lock_audio.play()

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
	_release_flash_remaining = maxf(release_flash_duration, 0.01)
	if muzzle_flash != null:
		muzzle_flash.visible = true
		muzzle_flash.modulate = Color(1.0, 0.96, 0.78, 1.0)
		if muzzle_flash.has_method("set_logical_local_position"):
			muzzle_flash.call("set_logical_local_position", _locked_direction * muzzle_offset)
		if muzzle_flash.has_method("set_world_direction"):
			muzzle_flash.call("set_world_direction", _locked_direction)
	if fire_audio != null:
		fire_audio.play()
	if PlayerData.player != null and PlayerData.player.has_method("request_camera_shake"):
		PlayerData.player.call("request_camera_shake", fire_camera_shake, global_position, 720.0)

func _update_muzzle_flash() -> void:
	if muzzle_flash == null:
		return
	if _release_flash_remaining <= 0.0:
		muzzle_flash.visible = false
		return
	var remaining_ratio := clampf(_release_flash_remaining / maxf(release_flash_duration, 0.01), 0.0, 1.0)
	muzzle_flash.visible = true
	muzzle_flash.modulate.a = remaining_ratio

func _cancel_lock() -> void:
	_is_locking = false
	_lock_remaining = 0.0
	_locked_warning_distance = 0.0

func _resolve_lock_warning_distance() -> float:
	var line_distance := attack_range
	if PlayerData.player:
		line_distance = minf(attack_range, PlayerData.player.global_position.distance_to(global_position))
	return maxf(line_distance, muzzle_offset + 24.0)

func _update_aim_warning_visual() -> void:
	if _warning_lines.is_empty():
		return
	if not _is_locking and _release_flash_remaining <= 0.0:
		_clear_warning_visuals()
		return
	var line_start := _locked_direction * muzzle_offset
	var line_end := _locked_direction * maxf(_locked_warning_distance, muzzle_offset + 24.0)
	if not _is_locking:
		var flash_progress := 1.0 - (_release_flash_remaining / maxf(release_flash_duration, 0.01))
		var flash_alpha := 1.0 - clampf(flash_progress, 0.0, 1.0)
		_set_warning_points(_aim_warning_outline, line_start, line_end)
		_set_warning_points(_aim_warning_line, line_start, line_end.lerp(line_start, flash_progress * 0.18))
		_set_warning_points(_aim_warning_fill, line_start, line_end.lerp(line_start, flash_progress * 0.18))
		_aim_warning_outline.default_color = Color(PALETTE.ENEMY_DARK, 0.66 * flash_alpha)
		_aim_warning_line.default_color = Color(PALETTE.ENEMY_SECONDARY, flash_alpha)
		_aim_warning_fill.default_color = Color(1.0, 0.96, 0.82, flash_alpha)
		return
	var lock_progress := clampf(1.0 - (_lock_remaining / maxf(lock_duration, 0.01)), 0.0, 1.0)
	var final_phase := clampf((lock_progress - 0.77) / 0.23, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(lock_progress * TAU * 9.0)
	var pulse_strength := lerpf(1.0, lerpf(0.72, 1.0, pulse), final_phase)
	_aim_warning_outline.default_color = Color(PALETTE.ENEMY_DARK, 0.66)
	_aim_warning_line.default_color = Color(aim_warning_color.r, aim_warning_color.g, aim_warning_color.b, lerpf(0.46, 0.94, lock_progress) * pulse_strength)
	_aim_warning_fill.default_color = Color(1.0, lerpf(0.55, 0.90, lock_progress), lerpf(0.28, 0.70, lock_progress), lerpf(0.78, 1.0, lock_progress) * pulse_strength)
	_set_warning_points(_aim_warning_outline, line_start, line_end)
	_set_warning_points(_aim_warning_line, line_start, line_end)
	_set_warning_points(_aim_warning_fill, line_start, line_start.lerp(line_end, lock_progress))

func _set_warning_points(line: Line2D, start: Vector2, end: Vector2) -> void:
	if line == null:
		return
	line.points = PackedVector2Array([start, end])
	line.set_meta(&"hybrid_ground_visible", true)
	line.visible = not bool(line.get_meta(&"hybrid_ground_registered", false))

func _clear_warning_visuals() -> void:
	for line in _warning_lines:
		if line == null:
			continue
		line.set_meta(&"hybrid_ground_visible", false)
		line.visible = false
		line.clear_points()
