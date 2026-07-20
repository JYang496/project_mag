extends BaseEnemy
class_name EnemyMortarTurret

const AREA_EFFECT_SCENE := preload("res://Combat/area_effect/area_effect.tscn")
const WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")

@export var detect_range: float = 560.0
@export var attack_range: float = 360.0
@export_range(0.1, 1.0, 0.01) var stationary_enter_range_ratio: float = 0.8
@export var cast_delay: float = 1.25
@export var cooldown_duration: float = 2.9
@export var aoe_radius: float = 62.0
@export var aoe_damage_multiplier: float = 1.8
@export var screen_fire_margin: float = 28.0

var _cooldown_remaining: float = 0.0
var _casting: bool = false
var _cast_remaining: float = 0.0
var _is_stationary_mode: bool = false
var _target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	combat_role = "ranged"

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
	move_enemy(_get_chase_velocity(), delta)
	_process_attack(delta)

func _update_stationary_mode() -> void:
	if PlayerData.player == null:
		_is_stationary_mode = false
		return
	var distance := global_position.distance_to(PlayerData.player.global_position)
	var enter_distance := attack_range * clampf(stationary_enter_range_ratio, 0.1, 1.0)
	if _is_stationary_mode:
		if _casting:
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
		_cancel_cast()
		return
	if not _is_stationary_mode:
		if _cooldown_remaining > 0.0:
			_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		_cancel_cast()
		return
	if _casting:
		_cast_remaining -= delta
		if _cast_remaining <= 0.0:
			_casting = false
			_spawn_mortar_impact(_target_position)
			_cooldown_remaining = cooldown_duration
		return
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		return
	var player_pos: Vector2 = PlayerData.player.global_position
	if player_pos.distance_to(global_position) > attack_range:
		_cancel_cast()
		return
	if not is_world_position_in_player_screen(global_position, screen_fire_margin):
		_cancel_cast()
		return
	_target_position = player_pos
	_casting = true
	_cast_remaining = cast_delay
	_spawn_warning(_target_position)

func _cancel_cast() -> void:
	_casting = false
	_cast_remaining = 0.0

func _spawn_warning(world_pos: Vector2) -> void:
	var warning := WARNING_SCENE.instantiate() as TargetWarning
	if warning == null:
		return
	warning.global_position = world_pos
	warning.duration = cast_delay
	warning.radius = aoe_radius
	warning.visual_preset = TargetWarning.VisualPreset.DODGE_STYLE
	call_deferred("add_sibling", warning)

func _spawn_mortar_impact(world_pos: Vector2) -> void:
	var area := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	if area == null:
		return
	area.global_position = world_pos
	area.duration = 0.22
	area.radius = maxf(aoe_radius, 8.0)
	area.target_group = AreaEffect.TargetGroup.ALLIES
	area.one_shot_damage = max(1, int(round(float(max(1, damage)) * maxf(aoe_damage_multiplier, 1.0))))
	area.tick_damage = 0
	area.visual_enabled = false
	area.draw_enabled = true
	area.debug_fill_color = Color(1.0, 0.18, 0.16, 0.24)
	area.debug_line_color = Color(1.0, 0.45, 0.3, 1.0)
	area.apply_once_per_target = true
	area.source_node = self
	call_deferred("add_sibling", area)
