extends BaseEnemy
class_name EnemyMortarTurret

const AREA_EFFECT_SCENE := preload("res://Utility/area_effect/area_effect.tscn")
const WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")

@export var attack_range: float = 620.0
@export var cast_delay: float = 1.25
@export var cooldown_duration: float = 2.9
@export var aoe_radius: float = 62.0
@export var aoe_damage_multiplier: float = 1.8

var _cooldown_remaining: float = 0.0
var _casting: bool = false
var _cast_remaining: float = 0.0
var _target_position: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
	velocity = knockback.amount * knockback.angle
	move_and_slide()
	if is_stunned():
		return
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
