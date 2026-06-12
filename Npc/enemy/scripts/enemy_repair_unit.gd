extends BaseEnemy
class_name EnemyRepairUnit

@export var heal_radius: float = 240.0
@export var preferred_range: float = 280.0
@export var heal_cooldown: float = 4.0
@export var cast_duration: float = 0.8
@export var interrupted_cooldown: float = 1.5
@export_range(0.01, 1.0, 0.01) var heal_max_hp_ratio: float = 0.12
@export var heal_line_color: Color = Color(0.25, 1.0, 0.45, 0.95)

var _cooldown_remaining: float = 1.5
var _cast_remaining: float = 0.0
var _heal_target: BaseEnemy = null

func _ready() -> void:
	super._ready()
	support_role = &"repair_unit"

func _physics_process(delta: float) -> void:
	queue_redraw()
	if is_stunned():
		if _heal_target != null:
			_interrupt_cast()
		decay_knockback()
		move_with_body_push(Vector2.ZERO, delta)
		return
	_process_healing(delta)
	var desired := compute_ranged_navigation(delta, 760.0, preferred_range, 1.0, 0.65, 2.5)
	decay_knockback()
	move_with_body_push(desired * (0.45 if _heal_target != null else 1.0), delta)

func _process_healing(delta: float) -> void:
	if _heal_target != null:
		if not _is_valid_heal_target(_heal_target):
			_interrupt_cast()
			return
		_cast_remaining -= maxf(delta, 0.0)
		if _cast_remaining <= 0.0:
			_complete_heal()
		return
	_cooldown_remaining = maxf(_cooldown_remaining - maxf(delta, 0.0), 0.0)
	if _cooldown_remaining > 0.0:
		return
	var target := _find_lowest_health_target()
	if target != null:
		_heal_target = target
		_cast_remaining = maxf(cast_duration, 0.05)

func _find_lowest_health_target() -> BaseEnemy:
	var best: BaseEnemy = null
	var best_ratio := 1.0
	for enemy_ref in _get_nearby_enemies(heal_radius):
		var enemy := enemy_ref as BaseEnemy
		if not _is_valid_heal_target(enemy):
			continue
		var ratio := enemy.get_health_ratio()
		if ratio < best_ratio:
			best_ratio = ratio
			best = enemy
	return best

func _is_valid_heal_target(target: BaseEnemy) -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and not target.is_dead
		and target.can_receive_support_from(self)
		and target.global_position.distance_to(global_position) <= heal_radius
		and target.get_health_ratio() < 1.0
	)

func _complete_heal() -> void:
	if _is_valid_heal_target(_heal_target):
		var heal_amount := maxi(int(round(float(_heal_target.get_incoming_damage_max_hp()) * heal_max_hp_ratio)), 1)
		_heal_target.heal(heal_amount)
	_heal_target = null
	_cast_remaining = 0.0
	_cooldown_remaining = maxf(heal_cooldown, 0.1)

func _interrupt_cast() -> void:
	_heal_target = null
	_cast_remaining = 0.0
	_cooldown_remaining = maxf(interrupted_cooldown, 0.1)

func _get_nearby_enemies(radius: float) -> Array[Node2D]:
	var registry := get_node_or_null("/root/EnemyRegistry")
	if registry != null and registry.has_method("get_enemies_in_radius"):
		return registry.call("get_enemies_in_radius", global_position, radius, self)
	return []

func _draw() -> void:
	draw_arc(Vector2.ZERO, heal_radius, 0.0, TAU, 48, Color(0.25, 1.0, 0.45, 0.18), 1.5, true)
	if _heal_target != null and is_instance_valid(_heal_target):
		draw_line(Vector2.ZERO, to_local(_heal_target.global_position), heal_line_color, 3.0, true)
