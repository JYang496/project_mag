extends BaseEnemy
class_name EnemyMortarTurret

const AREA_EFFECT_SCENE := preload("res://Utility/area_effect/area_effect.tscn")
const WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")

@export var detect_range: float = 900.0
@export var attack_range: float = 620.0
@export var cast_delay: float = 1.25
@export var cooldown_duration: float = 2.9
@export var aoe_radius: float = 62.0
@export var aoe_damage_multiplier: float = 1.8
@export var random_move_change_interval_sec: float = 3.0
@export var screen_fire_margin: float = 28.0
@export var approaching_velocity_threshold: float = 4.0

var _cooldown_remaining: float = 0.0
var _casting: bool = false
var _cast_remaining: float = 0.0
var _target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	combat_role = "ranged"

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
		0.68,
		random_move_change_interval_sec
	)
	velocity = ranged_move_velocity + knockback.amount * knockback.angle
	move_and_slide()
	_process_attack(delta)

func _process_attack(delta: float) -> void:
	if PlayerData.player == null:
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
	var player_pos := PlayerData.player.global_position
	if player_pos.distance_to(global_position) > attack_range:
		return
	if not is_world_position_in_player_screen(global_position, screen_fire_margin):
		return
	if not _is_approaching_player(player_pos - global_position):
		return
	_target_position = player_pos
	_casting = true
	_cast_remaining = cast_delay
	_spawn_warning(_target_position)

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

func _is_approaching_player(to_player: Vector2) -> bool:
	# Stationary turrets cannot move toward the player; keep them attack-capable.
	if get_current_movement_speed() <= 1.0:
		return true
	if to_player.length() <= 0.001 or velocity.length() <= 0.001:
		return false
	var approach_speed := velocity.dot(to_player.normalized())
	return approach_speed >= approaching_velocity_threshold
