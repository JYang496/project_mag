extends Area2D
class_name MachineGunFrontShield

@export var forward_distance: float = 28.0
@export var block_stun_seconds: float = 0.5
@export var block_knockback_amount: float = 140.0
@export_range(10.0, 89.0, 1.0) var block_half_angle_degrees: float = 60.0
@export var debug_draw_enabled: bool = true
@export var debug_arc_radius: float = 60.0
@export var debug_arc_steps: int = 20
@export var consume_same_target_cooldown_ms: int = 120

var weapon: Weapon
@onready var shield_sprite: Sprite2D = $ShieldSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var max_charges: int = 2
var current_charges: int = 2
var recharge_interval_seconds: float = 10.0
var _recharge_elapsed: float = 0.0
var _charge_consumed_frame: int = -1
var _consumed_target_ids: Dictionary = {}
var _target_last_consume_ms: Dictionary = {}

func _ready() -> void:
	# Detach local transform inheritance so shield rotation always matches weapon exactly.
	top_level = true
	_refresh_capacity_from_weapon()
	current_charges = max_charges
	_recharge_elapsed = 0.0
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))

func setup(target_weapon: Weapon) -> void:
	weapon = target_weapon
	_refresh_capacity_from_weapon()
	current_charges = max_charges
	_recharge_elapsed = 0.0

func _physics_process(_delta: float) -> void:
	if weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	_update_recharge(_delta)
	global_rotation = weapon.global_rotation
	# Gameplay protection zone is centered on player, not weapon muzzle.
	if PlayerData.player and is_instance_valid(PlayerData.player):
		global_position = PlayerData.player.global_position
	else:
		global_position = weapon.global_position
	# Sprite is visual-only and stays near muzzle/front side.
	if shield_sprite:
		shield_sprite.position = Vector2.UP * forward_distance
	if debug_draw_enabled:
		queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	if not _can_block():
		return
	if area == null or not is_instance_valid(area):
		return
	if not _is_in_front_block_arc(_resolve_area_origin(area)):
		return
	if _is_enemy_attack_area(area):
		if not _try_consume_charge_for_target(_resolve_target_key_from_area(area)):
			return
		_consume_enemy_attack(area)

func _on_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not _is_in_front_block_arc(body.global_position):
		return
	if body is BaseEnemy:
		var target_key: int = body.get_instance_id()
		var blocked: bool = _try_consume_charge_for_target(target_key) or _is_target_recently_blocked(target_key)
		if not blocked:
			return
		_interrupt_enemy(body)

func _is_enemy_attack_area(area: Area2D) -> bool:
	if area is HitBox:
		var owner_node: Variant = area.get("hitbox_owner")
		if owner_node != null and owner_node is Node and owner_node is BaseEnemy:
			return true
	# Ignore enemy HurtBox/body proxy areas. They are not hostile attack hitboxes.
	if area is HurtBox:
		return false
	var owner := area.get_owner()
	if owner is Projectile:
		return true
	return false

func _consume_enemy_attack(area: Area2D) -> void:
	if area is HitBox and area.has_method("set_deferred"):
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	var parent := area.get_parent()
	if parent and parent is Projectile:
		parent.call_deferred("queue_free")
		return

func _interrupt_enemy(enemy: BaseEnemy) -> void:
	_apply_knockback(enemy)
	if enemy.has_method("interrupt_movement"):
		enemy.call("interrupt_movement")
	if enemy.has_method("apply_stun"):
		enemy.call("apply_stun", block_stun_seconds)

func _apply_knockback(enemy: BaseEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.get("knockback") == null:
		return
	var push_dir: Vector2 = enemy.global_position - global_position
	if push_dir == Vector2.ZERO:
		push_dir = _get_forward_direction()
	push_dir = push_dir.normalized()
	var knockback_data: Dictionary = enemy.knockback
	var final_knockback: float = maxf(0.0, block_knockback_amount)
	if enemy is EliteEnemy or enemy.is_boss or enemy.is_in_group("boss"):
		final_knockback *= 0.5
	knockback_data["amount"] = final_knockback
	knockback_data["angle"] = push_dir
	enemy.knockback = knockback_data

func _get_forward_direction() -> Vector2:
	return Vector2.UP.rotated(global_rotation).normalized()

func _resolve_area_origin(area: Area2D) -> Vector2:
	if area == null:
		return global_position
	if area is HitBox:
		var owner_node: Variant = area.get("hitbox_owner")
		if owner_node != null and owner_node is Node2D and is_instance_valid(owner_node):
			return (owner_node as Node2D).global_position
	return area.global_position

func _is_in_front_block_arc(target_position: Vector2) -> bool:
	var to_target := target_position - global_position
	if to_target == Vector2.ZERO:
		return true
	var cos_threshold := cos(deg_to_rad(block_half_angle_degrees))
	return _get_forward_direction().dot(to_target.normalized()) >= cos_threshold

func _draw() -> void:
	if not debug_draw_enabled:
		return
	var radius := maxf(8.0, _get_effective_block_radius())
	var half_angle := deg_to_rad(block_half_angle_degrees)
	var steps := maxi(4, debug_arc_steps)
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a: float = lerpf(-half_angle, half_angle, t)
		# Shield's forward is local up (Vector2.UP).
		var p := Vector2.UP.rotated(a) * radius
		points.append(p)
	var fill_color := Color(0.2, 0.8, 1.0, 0.18)
	var line_color := Color(0.3, 0.95, 1.0, 0.8)
	draw_colored_polygon(points, fill_color)
	for i in range(1, points.size() - 1):
		draw_line(points[i], points[i + 1], line_color, 2.0)
	draw_line(Vector2.ZERO, points[1], line_color, 2.0)
	draw_line(Vector2.ZERO, points[points.size() - 1], line_color, 2.0)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size
	if font:
		var charge_text := "Shield %d/%d" % [current_charges, max_charges]
		var text_pos := Vector2(-radius * 0.55, radius + 18.0)
		draw_string(font, text_pos, charge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.85, 1.0, 1.0, 0.95))

func _get_effective_block_radius() -> float:
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		var scale_factor := maxf(absf(collision_shape.scale.x), absf(collision_shape.scale.y))
		return float(circle.radius) * maxf(1.0, scale_factor)
	return debug_arc_radius

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.BATTLE:
		_refresh_capacity_from_weapon()
		current_charges = max_charges
		_recharge_elapsed = 0.0

func _exit_tree() -> void:
	if PhaseManager and PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.disconnect("phase_changed", Callable(self, "_on_phase_changed"))

func _refresh_capacity_from_weapon() -> void:
	var fuse_level: int = 2
	if weapon and is_instance_valid(weapon):
		fuse_level = max(1, int(weapon.fuse))
	if fuse_level >= 3:
		max_charges = 4
		recharge_interval_seconds = 8.0
	else:
		max_charges = 2
		recharge_interval_seconds = 10.0
	current_charges = clampi(current_charges, 0, max_charges)

func _update_recharge(delta: float) -> void:
	if current_charges >= max_charges:
		_recharge_elapsed = 0.0
		return
	_recharge_elapsed += maxf(delta, 0.0)
	if _recharge_elapsed < recharge_interval_seconds:
		return
	_recharge_elapsed = 0.0
	current_charges = mini(current_charges + 1, max_charges)

func _can_block() -> bool:
	return current_charges > 0

func _consume_charge() -> void:
	current_charges = maxi(0, current_charges - 1)
	_recharge_elapsed = 0.0

func _try_consume_charge_for_target(target_key: int) -> bool:
	if not _can_block():
		return false
	var now_ms: int = Time.get_ticks_msec()
	var last_ms_variant: Variant = _target_last_consume_ms.get(target_key, -999999)
	var last_ms: int = int(last_ms_variant)
	if now_ms - last_ms < maxi(0, consume_same_target_cooldown_ms):
		return false
	var physics_frame: int = Engine.get_physics_frames()
	if _charge_consumed_frame != physics_frame:
		_charge_consumed_frame = physics_frame
		_consumed_target_ids.clear()
	if _consumed_target_ids.has(target_key):
		return false
	_consumed_target_ids[target_key] = true
	_target_last_consume_ms[target_key] = now_ms
	_consume_charge()
	return true

func _is_target_recently_blocked(target_key: int) -> bool:
	var physics_frame: int = Engine.get_physics_frames()
	if _charge_consumed_frame == physics_frame and _consumed_target_ids.has(target_key):
		return true
	var now_ms: int = Time.get_ticks_msec()
	var last_ms_variant: Variant = _target_last_consume_ms.get(target_key, -999999)
	var last_ms: int = int(last_ms_variant)
	return now_ms - last_ms < maxi(0, consume_same_target_cooldown_ms)

func _resolve_target_key_from_area(area: Area2D) -> int:
	if area == null:
		return -1
	var owner_node_generic := area.get_owner()
	if owner_node_generic != null and owner_node_generic is Node and is_instance_valid(owner_node_generic):
		var owner_node := owner_node_generic as Node
		if owner_node is BaseEnemy:
			return int(owner_node.get_instance_id())
		if owner_node is Projectile:
			return int(owner_node.get_instance_id())
	if area is HitBox:
		var owner_node: Variant = area.get("hitbox_owner")
		if owner_node != null and owner_node is Node and is_instance_valid(owner_node):
			var hit_owner := owner_node as Node
			if hit_owner is BaseEnemy:
				return int(hit_owner.get_instance_id())
			if hit_owner is Projectile:
				return int(hit_owner.get_instance_id())
			return int(hit_owner.get_instance_id())
	return int(area.get_instance_id())
