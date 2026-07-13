extends BaseEnemy
class_name EnemyShieldCore

@export var aura_radius: float = 180.0
@export_range(0.0, 1.0, 0.01) var ally_damage_taken_multiplier: float = 0.65
@export var preferred_range: float = 260.0
@export var aura_fill_color: Color = Color(0.15, 0.65, 1.0, 0.14)
@export var aura_line_color: Color = Color(0.3, 0.85, 1.0, 0.9)
@export var protected_line_color: Color = Color(0.4, 0.9, 1.0, 0.45)

var _protected_targets: Array[BaseEnemy] = []

func _ready() -> void:
	super._ready()
	support_role = &"shield_core"
	add_to_group(&"hybrid_enemy_aura_source")
	add_to_group(&"hybrid_enemy_link_source")
	call_deferred("register_hybrid_support_visuals")

func _physics_process(delta: float) -> void:
	queue_redraw()
	_sync_protected_targets()
	if is_stunned():
		decay_knockback()
		move_with_body_push(Vector2.ZERO, delta)
		return
	var desired := compute_ranged_navigation(delta, 760.0, preferred_range, 1.0, 0.65, 2.5)
	decay_knockback()
	move_with_body_push(desired, delta)

func _exit_tree() -> void:
	_clear_all_protection()
	super._exit_tree()

func _sync_protected_targets() -> void:
	var desired: Array[BaseEnemy] = []
	for enemy_ref in _get_nearby_enemies(aura_radius):
		var enemy := enemy_ref as BaseEnemy
		if enemy == null or not enemy.can_receive_support_from(self):
			continue
		desired.append(enemy)
		enemy.set_support_damage_reduction(self, ally_damage_taken_multiplier)
	for target in _protected_targets:
		if is_instance_valid(target) and not desired.has(target):
			target.clear_support_damage_reduction(self)
	_protected_targets = desired

func _clear_all_protection() -> void:
	for target in _protected_targets:
		if is_instance_valid(target):
			target.clear_support_damage_reduction(self)
	_protected_targets.clear()

func _get_nearby_enemies(radius: float) -> Array[Node2D]:
	var registry := get_node_or_null("/root/EnemyRegistry")
	if registry != null and registry.has_method("get_enemies_in_radius"):
		return registry.call("get_enemies_in_radius", global_position, radius, self)
	return []

func _draw() -> void:
	if uses_hybrid_ground_visuals():
		return
	draw_circle(Vector2.ZERO, aura_radius, aura_fill_color)
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 56, aura_line_color, 2.5, true)
	for target in _protected_targets:
		if is_instance_valid(target):
			draw_line(Vector2.ZERO, to_local(target.global_position), protected_line_color, 1.5, true)

func get_hybrid_aura_visual() -> Dictionary:
	return {
		"visible": true,
		"radius": aura_radius,
		"fill_color": aura_fill_color,
		"line_color": aura_line_color,
		"line_width": 2.5,
	}

func get_hybrid_link_visuals() -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for target in _protected_targets:
		if is_instance_valid(target):
			links.append({"target": target, "color": protected_line_color, "width": 1.5})
	return links
