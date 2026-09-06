extends Melee
class_name DashBlade

const TRAIL_AREA_EFFECT := preload("res://Combat/area_effect/trail_area_effect.gd")

signal calculate_weapon_damage(damage)
signal calculate_attack_cooldown(attack_cooldown)
signal calculate_weapon_speed(speed)
signal calculate_weapon_size(size)

const AIM_ROTATION_OFFSET := deg_to_rad(90)
const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")
const PixelArtPolicyType := preload("res://Visual/pixel_art_policy.gd")
const BLADE_SPRITE_TARGET_HEIGHT := PixelArtPolicyType.WEAPON_TARGET_HEIGHT_PX

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
var _dash_target_position: Vector2 = Vector2.ZERO
var _rift_armed := false
var _active_rift: TrailAreaEffect

enum AttackState {
	IDLE,
	DASHING,
	RETURNING,
	COOLDOWN,
}
var _state := AttackState.IDLE

@onready var attack_range_area: Area2D = $AttackRange
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D
@onready var blade_anchor: Node2D = $BladeAnchor
@onready var blade_sprite: Sprite2D = $BladeAnchor/BladeSprite
@onready var hit_box: HitBox = $BladeAnchor/HitBox
@onready var _base_blade_scale: Vector2 = blade_sprite.scale
@onready var _base_hitbox_size: Vector2 = _get_current_hitbox_size()

func _ready() -> void:
	cooldown_timer = $CooldownTimer
	super._ready()
	if sprite:
		sprite.visible = false
	_apply_fuse_sprite()
	_adjust_blade_sprite_height()
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
	branch_runtime.notify_branch_level_applied(level)
	_update_attack_range_shape()

func sync_stats() -> void:
	damage = base_damage
	attack_range = base_attack_range
	dash_speed = base_dash_speed
	return_speed = base_return_speed
	attack_cooldown = base_attack_cooldown
	size = base_size
	damage = max(1, int(round(float(damage) * branch_runtime.get_branch_damage_multiplier())))
	attack_range = maxf(1.0, attack_range * branch_runtime.get_branch_attack_range_multiplier())
	dash_speed = maxf(1.0, dash_speed * branch_runtime.get_branch_dash_speed_multiplier())
	return_speed = maxf(1.0, return_speed * branch_runtime.get_branch_return_speed_multiplier())
	attack_cooldown = maxf(0.02, attack_cooldown * branch_runtime.get_branch_cooldown_multiplier())
	apply_module_stat_pipeline()
	apply_size_multiplier(size)
	calculate_damage(damage)
	calculate_attack_cooldown.emit(attack_cooldown)
	calculate_speed(dash_speed)
	calculate_weapon_size.emit(size)
	if attack_cooldown > 0:
		cooldown_timer.wait_time = get_runtime_attack_cooldown()
	_update_attack_range_shape()

func calculate_damage(pre_damage: int) -> void:
	calculate_weapon_damage.emit(pre_damage)

func get_runtime_damage() -> int:
	return get_runtime_damage_value(float(base_damage))

func get_runtime_attack_cooldown() -> float:
	return attack_cooldown * get_role_stat_multiplier(&"attack_cooldown")

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

func _adjust_blade_sprite_height() -> void:
	if not blade_sprite or not blade_sprite.texture:
		return
	var tex_height := float(blade_sprite.texture.get_height())
	if tex_height <= 0.0:
		return
	var scale_factor := BLADE_SPRITE_TARGET_HEIGHT / tex_height
	_base_blade_scale = Vector2(scale_factor, scale_factor)
	blade_sprite.scale = _base_blade_scale

func _on_fuse_texture_changed() -> void:
	_adjust_blade_sprite_height()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	center_melee_attack_range_area(attack_range_area)
	_cleanup_targets()
	_update_target()
	match _state:
		AttackState.IDLE:
			_process_idle(delta)
		AttackState.DASHING:
			_process_dashing(delta)
		AttackState.RETURNING:
			_process_returning(delta)
		AttackState.COOLDOWN:
			pass

func _process_idle(delta: float = 0.0) -> void:
	blade_anchor.position = Vector2.ZERO
	var attack_aligned := false
	if _target and is_instance_valid(_target):
		attack_aligned = _point_blade_to(_target.global_position, delta)
	else:
		_point_blade_to_auto_aim_target(delta)
	if not _can_run_dash_attack():
		return
	if _target and is_instance_valid(_target) and attack_aligned:
		_start_dash()

func _point_blade_to_auto_aim_target(delta: float = 0.0) -> void:
	if has_meta(&"_player_assist_auto_aim_target"):
		var target_variant: Variant = get_meta(&"_player_assist_auto_aim_target")
		if target_variant is Vector2:
			_point_blade_to(target_variant as Vector2, delta)
			return
	if not has_weapon_trait(WeaponTrait.AUTO_FIRE):
		return
	var aim_target := find_closest_enemy(get_auto_fire_target_origin(), INF)
	if aim_target != null and is_instance_valid(aim_target):
		_point_blade_to(aim_target.global_position, delta)

func _can_run_dash_attack() -> bool:
	if not is_attack_phase_allowed():
		return false
	return is_main_weapon() or is_support_weapon()

func request_automatic_fire() -> bool:
	return _state == AttackState.IDLE

func _process_dashing(delta: float) -> void:
	blade_anchor.global_position = blade_anchor.global_position.move_toward(_dash_target_position, dash_speed * delta)
	if blade_anchor.global_position.distance_to(_dash_target_position) <= 8.0:
		if _target and is_instance_valid(_target) and blade_anchor.global_position.distance_to(_target.global_position) <= 8.0:
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
	register_shot_heat()
	_dash_hit_confirmed = false
	_dash_start_distance = 0.0
	_dash_start_target_id = 0
	if _target and is_instance_valid(_target):
		_dash_start_distance = blade_anchor.global_position.distance_to(_target.global_position)
		_dash_start_target_id = _target.get_instance_id()
	_dash_target_position = blade_anchor.global_position + get_blade_aim_forward() * maxf(_dash_start_distance, attack_range)
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.has_method("on_dash_cycle_started"):
			behavior.call("on_dash_cycle_started")
	_state = AttackState.DASHING
	_set_hitbox_enabled(true)
	if _rift_armed:
		_rift_armed = false
		if blade_sprite != null:
			blade_sprite.modulate = Color.WHITE
		_start_rift_trail()

func _start_return() -> void:
	if _state != AttackState.DASHING:
		return
	_state = AttackState.RETURNING
	if _active_rift != null and is_instance_valid(_active_rift):
		var completed_rift := _active_rift
		completed_rift.detach_emitter(blade_anchor)
		get_tree().create_timer(3.5, false).timeout.connect(completed_rift.queue_free, CONNECT_ONE_SHOT)
		_active_rift = null
	_set_hitbox_enabled(_branch_wants_dash_return_hitbox())
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.has_method("on_dash_return_started"):
			behavior.call("on_dash_return_started")

func activate_weapon_skill_effect(_context: SkillActionContext) -> bool:
	_rift_armed = true
	if blade_sprite != null:
		blade_sprite.modulate = Color(0.72, 0.46, 1.0, 1.0)
	return true

func _start_rift_trail() -> void:
	var trail := TRAIL_AREA_EFFECT.new()
	trail.surface_style = TrailAreaEffect.SurfaceStyle.RIFT
	trail.duration = 3.0
	trail.tick_interval = 0.4
	trail.sample_interval = 0.025
	trail.max_segments = 20
	trail.tick_damage = max(1, int(round(float(get_runtime_damage()) * 0.35)))
	trail.damage_type = Attack.TYPE_ENERGY
	trail.source_node = self
	trail.source_category = DamageData.SOURCE_PLAYER_WEAPON
	trail.fill_color = Color(0.60, 0.32, 1.0, 0.22)
	trail.line_color = Color(0.78, 0.62, 1.0, 0.9)
	get_tree().root.add_child(trail)
	trail.attach_emitter(blade_anchor, 34.0, 10.0, false)
	_active_rift = trail

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_rift_armed = false
	if blade_sprite != null:
		blade_sprite.modulate = Color.WHITE
	if _active_rift != null and is_instance_valid(_active_rift):
		_active_rift.queue_free()
	_active_rift = null

func _start_cooldown() -> void:
	if _state == AttackState.COOLDOWN:
		return
	_set_hitbox_enabled(false)
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.has_method("on_dash_cycle_finished"):
			behavior.call("on_dash_cycle_finished")
	_state = AttackState.COOLDOWN
	cooldown_timer.start()

func _branch_wants_dash_return_hitbox() -> bool:
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.has_method("wants_dash_return_hitbox") \
				and bool(behavior.call("wants_dash_return_hitbox")):
			return true
	return false

func _set_hitbox_enabled(enabled: bool) -> void:
	hit_box.collision.set_deferred("disabled", not enabled)

func _point_blade_to(world_target: Vector2, delta: float = 0.0) -> bool:
	return turn_melee_anchor_toward_attack(blade_anchor, world_target, delta, AIM_ROTATION_OFFSET)

func get_blade_aim_forward() -> Vector2:
	return Vector2.RIGHT.rotated(blade_anchor.global_rotation - AIM_ROTATION_OFFSET).normalized()

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
	var dash_ratio := _dash_start_distance / maxf(attack_range, 1.0)
	if _state == AttackState.DASHING and dash_ratio + 0.0001 >= long_dash_trigger_range_ratio:
		mark_weapon_skill_ready()
		emit_passive_trigger(&"dash_blade_long_dash_hit_triggered", {
			"target": target,
			"distance": _dash_start_distance,
			"range_ratio": dash_ratio,
			"threshold": long_dash_trigger_range_ratio,
			"refresh": "long_dash_hit",
		}, PASSIVE_SCOPE_GLOBAL)
	_apply_close_chain_slow(target)
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.has_method("on_dash_target_hit"):
			behavior.call("on_dash_target_hit", target, _state == AttackState.RETURNING)
	branch_runtime.notify_branch_target_hit(target)

func _apply_close_chain_slow(target: Node) -> void:
	CLOSE_CHAIN_RULES.apply_dash_slow(target, close_chain_slow_multiplier, close_chain_slow_duration_sec)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)

func get_passive_status() -> Dictionary:
	var state := "building"
	var status := {
		"id": "dash_blade_long_dash_hit_triggered",
		"display_name": "Long Dash Hit",
		"state": state,
		"progress": 0.0,
		"ready": false,
		"condition_type": "long_dash_hit",
		"required": long_dash_trigger_range_ratio,
		"condition_visible": true,
		"condition_progress": 0.0,
		"trigger_hint": "long_dash_hit",
		"refresh_hint": "long_dash_hit",
		"slow_multiplier": clampf(close_chain_slow_multiplier, 0.05, 1.0),
		"slow_duration": maxf(close_chain_slow_duration_sec, 0.1),
	}
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
