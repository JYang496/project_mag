extends BaseEnemy
class_name EnemyShieldCore

@export var aura_radius: float = 180.0
@export_range(0.0, 1.0, 0.01) var ally_damage_taken_multiplier: float = 0.65
@export var preferred_range: float = 260.0
@export var aura_fill_color: Color = Color(0.15, 0.65, 1.0, 0.14)
@export var aura_line_color: Color = Color(0.3, 0.85, 1.0, 0.9)
@export var protected_line_color: Color = Color(0.4, 0.9, 1.0, 0.45)

# Visual-only compatibility list. Runtime protection comes from the spatial snapshot;
# gameplay code must not populate this by searching nearby enemies.
var _protected_targets: Array[BaseEnemy] = []
@onready var shield_area: Area2D = $ShieldArea
@onready var shield_shape: CollisionShape2D = $ShieldArea/CollisionShape2D

func _ready() -> void:
	super._ready()
	support_role = &"shield_core"
	EnemyRegistry.refresh_enemy_roles(self)
	add_to_group(&"hybrid_enemy_aura_source")
	call_deferred("register_hybrid_support_visuals")
	if shield_shape != null and shield_shape.shape is CircleShape2D:
		(shield_shape.shape as CircleShape2D).radius = aura_radius

func _physics_process(delta: float) -> void:
	var ai_delta := consume_ai_update_delta(delta)
	if ai_delta <= 0.0:
		continue_lod_movement(delta)
		return
	delta = ai_delta
	if is_stunned():
		decay_knockback()
		move_enemy(Vector2.ZERO, delta)
		return
	var desired := compute_ranged_navigation(delta, 760.0, preferred_range, 1.0, 0.65, 2.5)
	decay_knockback()
	move_enemy(desired, delta)

func _exit_tree() -> void:
	for target in _protected_targets:
		if target != null and is_instance_valid(target):
			target.clear_support_damage_reduction(self)
	_protected_targets.clear()
	super._exit_tree()

func _on_shield_area_body_entered(body: Node2D) -> void:
	if body is BaseEnemy:
		var target := body as BaseEnemy
		if target != self and target.can_receive_support_from(self):
			target.set_support_damage_reduction(self, ally_damage_taken_multiplier)
			if not _protected_targets.has(target):
				_protected_targets.append(target)

func _on_shield_area_body_exited(body: Node2D) -> void:
	if body is BaseEnemy:
		var target := body as BaseEnemy
		target.clear_support_damage_reduction(self)
		_protected_targets.erase(target)

func _draw() -> void:
	if uses_hybrid_ground_visuals():
		return
	draw_circle(Vector2.ZERO, aura_radius, aura_fill_color)
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 56, aura_line_color, 2.5, true)
	for index in mini(_protected_targets.size(), 4):
		var target := _protected_targets[index]
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
	for index in mini(_protected_targets.size(), 4):
		var target := _protected_targets[index]
		if is_instance_valid(target):
			links.append({"target": target, "color": protected_line_color, "width": 1.5})
	return links
