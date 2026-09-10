extends Node2D
class_name WeaponSkillArea

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")
const WHITE_FROST_TEXTURES := [
	preload("res://asset/images/effects/white_frost_domain/white_frost_domain_01_normalized.png"),
	preload("res://asset/images/effects/white_frost_domain/white_frost_domain_02_normalized.png"),
	preload("res://asset/images/effects/white_frost_domain/white_frost_domain_03_normalized.png"),
	preload("res://asset/images/effects/white_frost_domain/white_frost_domain_04_normalized.png"),
]
const PLASMA_STORM_TEXTURES := [
	preload("res://asset/images/effects/plasma_storm/plasma_storm_01_normalized.png"),
	preload("res://asset/images/effects/plasma_storm/plasma_storm_02_normalized.png"),
	preload("res://asset/images/effects/plasma_storm/plasma_storm_03_normalized.png"),
	preload("res://asset/images/effects/plasma_storm/plasma_storm_04_normalized.png"),
]

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

const WHITE_FROST_APPEAR_SEC := 0.22
const WHITE_FROST_RELEASE_SEC := 0.80
const WHITE_FROST_APPEAR_START_SCALE := 0.74
const WHITE_FROST_RELEASE_END_SCALE := 0.94
const PLASMA_APPEAR_SEC := 0.20
const PLASMA_RELEASE_SEC := 0.50
const PLASMA_TEXTURE_OPACITY := 0.55

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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	HYBRID_GROUND_REGISTRATION.register(self, &"register_warning_circle")
	queue_redraw()

func cleanup_for_battle_end() -> void:
	_cleanup_player_boost()
	queue_free()

func _exit_tree() -> void:
	HYBRID_GROUND_REGISTRATION.unregister(self)
	_cleanup_player_boost()

func get_warning_progress() -> float:
	if mode == Mode.WHITE_FROST_DOMAIN:
		return _get_white_frost_radius_scale()
	if mode == Mode.PLASMA_STORM:
		return lerpf(0.78, 1.0, _smoothstep_ratio(_elapsed / PLASMA_APPEAR_SEC))
	return 1.0

func get_warning_fill_alpha_multiplier() -> float:
	if mode == Mode.PLASMA_STORM:
		return _get_plasma_phase_alpha() * 0.25
	if mode != Mode.WHITE_FROST_DOMAIN:
		return 1.0
	var phase_alpha := _get_white_frost_phase_alpha()
	if _elapsed < WHITE_FROST_APPEAR_SEC:
		return phase_alpha * 0.33
	var sustain_pulse := 0.94 + sin(_elapsed * TAU / 1.15) * 0.06
	return phase_alpha * sustain_pulse * 0.33

func get_warning_outline_alpha_multiplier() -> float:
	if mode == Mode.PLASMA_STORM:
		return _get_plasma_phase_alpha() * 0.25
	if mode != Mode.WHITE_FROST_DOMAIN:
		return 1.0
	return _get_white_frost_phase_alpha() * 0.45

# Both renderers sample the owning skill clock, so pause, release and cleanup
# cannot leave an independently playing animation behind.
func get_warning_texture() -> Texture2D:
	if mode == Mode.WHITE_FROST_DOMAIN:
		return WHITE_FROST_TEXTURES[int(_elapsed * 5.0) % WHITE_FROST_TEXTURES.size()]
	if mode == Mode.PLASMA_STORM:
		return PLASMA_STORM_TEXTURES[int(_elapsed * 6.0) % PLASMA_STORM_TEXTURES.size()]
	return null

func get_warning_texture_alpha() -> float:
	if mode == Mode.WHITE_FROST_DOMAIN:
		return _get_white_frost_phase_alpha() * 0.72
	if mode == Mode.PLASMA_STORM:
		return _get_plasma_phase_alpha() * PLASMA_TEXTURE_OPACITY
	return 0.0

func _get_plasma_phase_alpha() -> float:
	var appear := _smoothstep_ratio(_elapsed / PLASMA_APPEAR_SEC)
	var release := _smoothstep_ratio((duration_sec - _elapsed) / PLASMA_RELEASE_SEC)
	return minf(appear, release)

func get_white_frost_visual_phase() -> StringName:
	if mode != Mode.WHITE_FROST_DOMAIN:
		return &"steady"
	if _elapsed < WHITE_FROST_APPEAR_SEC:
		return &"forming"
	if _elapsed >= maxf(duration_sec - WHITE_FROST_RELEASE_SEC, WHITE_FROST_APPEAR_SEC):
		return &"releasing"
	return &"sustaining"

func get_warning_countdown_text() -> String:
	return ""

func _get_white_frost_radius_scale() -> float:
	if _elapsed < WHITE_FROST_APPEAR_SEC:
		var appear_ratio := clampf(_elapsed / WHITE_FROST_APPEAR_SEC, 0.0, 1.0)
		return lerpf(WHITE_FROST_APPEAR_START_SCALE, 1.0, _smoothstep_ratio(appear_ratio))
	var release_start := maxf(duration_sec - WHITE_FROST_RELEASE_SEC, WHITE_FROST_APPEAR_SEC)
	if _elapsed >= release_start:
		var release_ratio := clampf((_elapsed - release_start) / maxf(duration_sec - release_start, 0.001), 0.0, 1.0)
		return lerpf(1.0, WHITE_FROST_RELEASE_END_SCALE, _smoothstep_ratio(release_ratio))
	return 1.0

func _get_white_frost_phase_alpha() -> float:
	if _elapsed < WHITE_FROST_APPEAR_SEC:
		return _smoothstep_ratio(clampf(_elapsed / WHITE_FROST_APPEAR_SEC, 0.0, 1.0))
	var release_start := maxf(duration_sec - WHITE_FROST_RELEASE_SEC, WHITE_FROST_APPEAR_SEC)
	if _elapsed >= release_start:
		var release_ratio := clampf((_elapsed - release_start) / maxf(duration_sec - release_start, 0.001), 0.0, 1.0)
		return 1.0 - _smoothstep_ratio(release_ratio)
	return 1.0

func _smoothstep_ratio(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)

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
	var frame_texture := get_warning_texture()
	if frame_texture != null:
		var visual_radius := radius * get_warning_progress()
		draw_circle(Vector2.ZERO, visual_radius, Color(fill_color, fill_color.a * get_warning_fill_alpha_multiplier()))
		draw_arc(Vector2.ZERO, visual_radius, 0.0, TAU, 64, Color(line_color, line_color.a * get_warning_outline_alpha_multiplier()), 1.0)
		draw_texture_rect(frame_texture, Rect2(Vector2.ONE * -visual_radius, Vector2.ONE * visual_radius * 2.0), false, Color(1.0, 1.0, 1.0, get_warning_texture_alpha()))
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
