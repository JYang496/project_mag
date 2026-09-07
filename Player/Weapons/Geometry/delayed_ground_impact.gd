extends Node2D
class_name DelayedGroundImpact

const TARGET_WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")
const BILLBOARD_VISUAL := preload("res://Visual/Oblique/billboard_visual_2d.gd")
const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")

var source_weapon: Weapon
var origin_position := Vector2.ZERO
var impact_position := Vector2.ZERO
var impact_delay_sec := 0.55
var impact_radius := 72.0
var impact_damage := 1
var impact_damage_type: StringName = Attack.TYPE_PHYSICAL
var arc_height := 110.0
var telegraph_color := Color(1.0, 0.48, 0.18, 0.85)
var idle_empowered := false
var _elapsed_sec := 0.0
var _impacted := false
var _linger_sec := 0.08
var _trajectory_line: Line2D
var _shell_visual: Node2D

func setup(
	weapon: Weapon,
	origin: Vector2,
	target: Vector2,
	delay: float,
	radius: float,
	damage_value: int,
	damage_type: StringName,
	empowered: bool = false
) -> DelayedGroundImpact:
	source_weapon = weapon
	origin_position = origin
	impact_position = target
	impact_delay_sec = maxf(delay, 0.05)
	impact_radius = maxf(radius, 1.0)
	impact_damage = maxi(damage_value, 1)
	impact_damage_type = Attack.normalize_damage_type(damage_type)
	idle_empowered = empowered
	return self

func _ready() -> void:
	global_position = Vector2.ZERO
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	_create_projected_visuals()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed_sec += maxf(delta, 0.0)
	if not _impacted and _elapsed_sec >= impact_delay_sec:
		_impacted = true
		_apply_impact()
	if _impacted and _elapsed_sec >= impact_delay_sec + _linger_sec:
		queue_free()
		return
	_update_shell_visual()
	queue_redraw()

func cleanup_for_battle_end() -> void:
	queue_free()

func _exit_tree() -> void:
	if _trajectory_line != null:
		HYBRID_GROUND_REGISTRATION.unregister(_trajectory_line)

func _create_projected_visuals() -> void:
	var warning := TARGET_WARNING_SCENE.instantiate() as TargetWarning
	warning.name = "ImpactWarning"
	warning.global_position = impact_position
	warning.duration = impact_delay_sec
	warning.radius = impact_radius
	warning.fill_color = Color(telegraph_color, 0.18)
	warning.line_color = telegraph_color
	warning.line_width = 2.0
	warning.show_countdown = false
	add_child(warning)

	_trajectory_line = Line2D.new()
	_trajectory_line.name = "ProjectedTrajectory"
	_trajectory_line.points = PackedVector2Array([origin_position, impact_position])
	_trajectory_line.width = 1.0
	_trajectory_line.default_color = Color(telegraph_color, 0.18)
	_trajectory_line.set_meta(&"hybrid_ground_visible", true)
	add_child(_trajectory_line)
	if HYBRID_GROUND_REGISTRATION.register(_trajectory_line, &"register_ground_segment"):
		_trajectory_line.visible = false

	_shell_visual = Node2D.new()
	_shell_visual.name = "ProjectedShell"
	_shell_visual.set_script(BILLBOARD_VISUAL)
	var shell_shape := Polygon2D.new()
	shell_shape.color = Color(1.0, 0.82, 0.42, 0.95)
	var points := PackedVector2Array()
	for index in range(12):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 12.0) * 7.0)
	shell_shape.polygon = points
	_shell_visual.add_child(shell_shape)
	add_child(_shell_visual)
	_update_shell_visual()

func _update_shell_visual() -> void:
	if _shell_visual == null or _impacted:
		if _shell_visual != null:
			_shell_visual.visible = false
		return
	var progress := clampf(_elapsed_sec / impact_delay_sec, 0.0, 1.0)
	var shell_position := origin_position.lerp(impact_position, progress)
	shell_position += Vector2.UP * sin(progress * PI) * arc_height
	_shell_visual.call("set_logical_local_position", shell_position)

func _apply_impact() -> void:
	if source_weapon == null or not is_instance_valid(source_weapon):
		return
	var strongest_final_damage: int = 0
	var applied_count: int = 0
	var seen_targets: Dictionary = {}
	for enemy in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), impact_position, impact_radius):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(impact_position) > impact_radius:
			continue
		var target_id: int = enemy.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		var damage_data: DamageData = DamageManager.build_damage_data(
			self, impact_damage, impact_damage_type,
			{"amount": 55.0, "angle": impact_position.direction_to(enemy.global_position)},
			DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.AREA,
			get_meta(Weapon.HEAT_SNAPSHOT_META) if has_meta(Weapon.HEAT_SNAPSHOT_META) else null
		)
		damage_data.dedupe_token = StringName("cannon_ground_impact_%d_%d" % [get_instance_id(), target_id])
		damage_data.dedupe_window_sec = 0.05
		var result: DamageResult = DamageManager.apply_to_target_result(enemy, damage_data)
		if not result.applied:
			continue
		applied_count += 1
		strongest_final_damage = maxi(strongest_final_damage, result.final_damage)
		if source_weapon.has_method("on_cannon_ground_impact_damage_dealt"):
			source_weapon.call(
				"on_cannon_ground_impact_damage_dealt", self, enemy,
				impact_damage_type, result.final_damage, idle_empowered
			)
		if source_weapon.has_method("on_hit_target_with_damage_type"):
			source_weapon.call("on_hit_target_with_damage_type", enemy, impact_damage_type)
	if source_weapon.has_method("on_cannon_ground_impact_complete"):
		source_weapon.call(
			"on_cannon_ground_impact_complete", self, impact_position,
			impact_damage, strongest_final_damage, applied_count
		)

func _draw() -> void:
	if _trajectory_line != null:
		return
	var progress: float = clampf(_elapsed_sec / impact_delay_sec, 0.0, 1.0)
	var marker_alpha: float = 0.30 + progress * 0.35
	draw_circle(impact_position, impact_radius, Color(telegraph_color, marker_alpha * 0.35))
	draw_arc(impact_position, impact_radius, 0.0, TAU, 64, Color(telegraph_color, marker_alpha), 2.0)
	if _impacted:
		draw_circle(impact_position, impact_radius, Color(1.0, 0.72, 0.28, 0.38))
		return
	var shell_position: Vector2 = origin_position.lerp(impact_position, progress)
	shell_position += Vector2.UP * sin(progress * PI) * arc_height
	draw_line(origin_position, impact_position, Color(telegraph_color, 0.18), 1.0)
	draw_circle(shell_position, 7.0, Color(1.0, 0.82, 0.42, 0.95))
