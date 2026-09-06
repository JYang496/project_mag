extends Node2D
class_name WeaponSkillArea

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")

enum Mode { CHAINSAW_CAGE, PLASMA_STORM, WHITE_FROST_DOMAIN }

var mode: Mode = Mode.CHAINSAW_CAGE
var source_weapon: Weapon
var source_player: Node
var duration_sec := 4.0
var radius := 150.0
var tick_interval_sec := 0.5
var damage_ratio := 0.45
var follow_player := false
var fill_color := Color(0.45, 0.3, 1.0, 0.16)
var line_color := Color(0.72, 0.55, 1.0, 0.9)
var show_countdown := false
var _elapsed := 0.0
var _tick_accum := 0.0
var _exposure: Dictionary = {}
var _player_boost_applied := false

func setup(
	mode_value: Mode,
	weapon_value: Weapon,
	position_value: Vector2,
	duration_value: float,
	radius_value: float,
	tick_value: float,
	damage_ratio_value: float = 0.0
) -> WeaponSkillArea:
	mode = mode_value
	source_weapon = weapon_value
	source_player = DamageManager.resolve_source_player(weapon_value)
	global_position = position_value
	duration_sec = maxf(duration_value, 0.1)
	radius = maxf(radius_value, 16.0)
	tick_interval_sec = maxf(tick_value, 0.05)
	damage_ratio = maxf(damage_ratio_value, 0.0)
	follow_player = mode == Mode.WHITE_FROST_DOMAIN
	match mode:
		Mode.CHAINSAW_CAGE:
			fill_color = Color(PALETTE.WARNING, 0.14)
			line_color = Color(PALETTE.WARNING, 0.9)
		Mode.PLASMA_STORM:
			fill_color = Color(PALETTE.ENERGY, 0.18)
			line_color = Color(PALETTE.ENERGY, 0.9)
		Mode.WHITE_FROST_DOMAIN:
			fill_color = Color(PALETTE.FREEZE, 0.15)
			line_color = Color(PALETTE.PLAYER_PRIMARY, 0.85)
	return self

func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	HYBRID_GROUND_REGISTRATION.register(self, &"register_warning_circle")
	queue_redraw()

func cleanup_for_battle_end() -> void:
	_cleanup_player_boost()
	queue_free()

func _exit_tree() -> void:
	HYBRID_GROUND_REGISTRATION.unregister(self)
	_cleanup_player_boost()

func get_warning_progress() -> float:
	return 1.0

func get_warning_countdown_text() -> String:
	return ""

func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_elapsed += step
	if _elapsed >= duration_sec or source_weapon == null or not is_instance_valid(source_weapon):
		queue_free()
		return
	if follow_player and source_player is Node2D and is_instance_valid(source_player):
		global_position = (source_player as Node2D).global_position
	_update_player_boost_presence()
	_tick_accum += step
	while _tick_accum >= tick_interval_sec:
		_tick_accum -= tick_interval_sec
		_apply_tick()
	queue_redraw()

func _apply_tick() -> void:
	var inside_ids: Dictionary = {}
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), global_position, radius):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > radius:
			continue
		inside_ids[enemy.get_instance_id()] = true
		match mode:
			Mode.CHAINSAW_CAGE:
				_apply_damage(enemy, 0.30, Attack.TYPE_PHYSICAL)
			Mode.PLASMA_STORM:
				_apply_damage(enemy, damage_ratio, Attack.TYPE_ENERGY)
				_pull_enemy(enemy)
			Mode.WHITE_FROST_DOMAIN:
				_apply_frost(enemy)
	for target_id in _exposure.keys():
		if not inside_ids.has(target_id):
			_exposure.erase(target_id)
func _apply_damage(target: Node, ratio: float, damage_type: StringName) -> void:
	var amount: int = maxi(1, int(round(float(source_weapon.get_runtime_damage()) * maxf(ratio, 0.0))))
	var data := DamageManager.build_damage_data(
		source_weapon, amount, damage_type,
		{"amount": 0, "angle": Vector2.ZERO},
		DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.AREA
	)
	DamageManager.apply_to_target(target, data)

func _pull_enemy(enemy: Node2D) -> void:
	if _is_boss(enemy):
		return
	var direction := enemy.global_position.direction_to(global_position)
	if direction == Vector2.ZERO:
		return
	if enemy.get("knockback") is Dictionary:
		enemy.set("knockback", {"amount": 70.0, "angle": direction})
	elif enemy.has_method("apply_impulse"):
		enemy.call("apply_impulse", direction * 70.0)

func _apply_frost(enemy: Node2D) -> void:
	var target_id := enemy.get_instance_id()
	var exposure := float(_exposure.get(target_id, 0.0)) + tick_interval_sec
	_exposure[target_id] = exposure
	if _is_boss(enemy):
		_apply_slow(enemy, 0.70, tick_interval_sec + 0.2)
		return
	_apply_slow(enemy, 0.55, tick_interval_sec + 0.2)
	if exposure + 0.001 >= 2.0:
		if enemy.has_method("apply_status_payload"):
			enemy.call("apply_status_payload", &"stun", {"duration": 1.5})
		elif enemy.has_method("apply_stun"):
			enemy.call("apply_stun", 1.5)
		_exposure[target_id] = 0.0

func _apply_slow(target: Node, multiplier: float, duration: float) -> void:
	if target.has_method("apply_status_payload"):
		target.call("apply_status_payload", &"slow", {"multiplier": multiplier, "duration": duration})
	elif target.has_method("apply_slow"):
		target.call("apply_slow", multiplier, duration)

func _apply_player_boost() -> void:
	if source_player == null or not is_instance_valid(source_player):
		return
	if source_player.has_method("apply_move_speed_mul"):
		source_player.call("apply_move_speed_mul", &"white_frost_domain", 1.20)
	else:
		source_player.set_meta(&"white_frost_domain_speed_multiplier", 1.20)
	_player_boost_applied = true

func _update_player_boost_presence() -> void:
	if mode != Mode.WHITE_FROST_DOMAIN:
		return
	var player := source_player as Node2D
	var player_inside := player != null and is_instance_valid(player) \
		and player.global_position.distance_squared_to(global_position) <= radius * radius
	if player_inside:
		if not _player_boost_applied:
			_apply_player_boost()
	elif _player_boost_applied:
		_cleanup_player_boost()

func _cleanup_player_boost() -> void:
	_player_boost_applied = false
	if source_player == null or not is_instance_valid(source_player):
		return
	if source_player.has_method("remove_move_speed_mul"):
		source_player.call("remove_move_speed_mul", &"white_frost_domain")
	if source_player.has_meta(&"white_frost_domain_speed_multiplier"):
		source_player.remove_meta(&"white_frost_domain_speed_multiplier")

func _is_boss(target: Node) -> bool:
	if target.is_in_group(&"boss"):
		return true
	if target is BaseEnemy:
		return bool((target as BaseEnemy).is_boss)
	return bool(target.get_meta(&"is_boss", false))

func _draw() -> void:
	if bool(get_meta(&"hybrid_ground_registered", false)):
		return
	var life := clampf(1.0 - _elapsed / maxf(duration_sec, 0.001), 0.0, 1.0)
	match mode:
		Mode.CHAINSAW_CAGE:
			var color := Color(PALETTE.WARNING, 0.85 * life)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.35 * life), 3.0)
			for index in range(6):
				var angle := _elapsed * 3.0 + TAU * float(index) / 6.0
				var point := Vector2.RIGHT.rotated(angle) * radius
				draw_circle(point, 13.0, color)
				draw_line(point - Vector2.RIGHT.rotated(angle) * 18.0, point + Vector2.RIGHT.rotated(angle) * 18.0, Color.WHITE, 2.0)
		Mode.PLASMA_STORM:
			var color := Color(PALETTE.ENERGY, 0.22 * life)
			draw_circle(Vector2.ZERO, radius, color)
			for index in range(3):
				draw_arc(Vector2.ZERO, radius * (0.35 + index * 0.25), _elapsed * (1.5 + index), _elapsed * (1.5 + index) + PI * 1.35, 24, Color(PALETTE.ENERGY, 0.85 * life), 3.0)
		Mode.WHITE_FROST_DOMAIN:
			draw_circle(Vector2.ZERO, radius, Color(PALETTE.FREEZE, 0.13 * life))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(PALETTE.PLAYER_PRIMARY, 0.75 * life), 3.0)
			for index in range(8):
				var angle := TAU * float(index) / 8.0 + _elapsed * 0.25
				draw_line(Vector2.RIGHT.rotated(angle) * radius * 0.72, Vector2.RIGHT.rotated(angle) * radius * 0.93, Color(PALETTE.FREEZE, 0.8 * life), 2.0)
