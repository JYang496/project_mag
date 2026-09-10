extends Node2D
class_name DelayedGroundImpact

const TARGET_WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")
const BILLBOARD_VISUAL := preload("res://Visual/Oblique/billboard_visual_2d.gd")

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
var _projected_visuals_created := false
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
	warning.reveal_from_center = false
	add_child(warning)
	_projected_visuals_created = true

	_shell_visual = Node2D.new()
	_shell_visual.name = "ProjectedShell"
	_shell_visual.set_script(BILLBOARD_VISUAL)
	var shell_shape := Sprite2D.new()
	shell_shape.texture = preload("res://asset/images/weapons/projectiles/cannon_shell.png")
	shell_shape.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shell_visual.add_child(shell_shape)
	if idle_empowered:
		# Extra armor fins change the silhouette without touching the impact area.
		var fins := Polygon2D.new()
		fins.polygon = PackedVector2Array([Vector2(-10,7),Vector2(-7,-2),Vector2(0,-12),Vector2(7,-2),Vector2(10,7),Vector2(4,4),Vector2(0,-7),Vector2(-4,4)])
		fins.color = Color("b7c5ce")
		_shell_visual.add_child(fins)
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
	var vfx := preload("res://Player/Weapons/Effects/projectile_impact_vfx_service.gd").ensure(get_tree())
	if vfx != null:
		vfx.play(impact_position, origin_position.direction_to(impact_position), impact_damage_type, 2, &"explode", {"ground": true, "empowered": idle_empowered})
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
		if idle_empowered and applied_count > 0:
			TimeImpactController.trigger_weapon_impact(&"cannon_empowered", 0.04)
		source_weapon.call(
			"on_cannon_ground_impact_complete", self, impact_position,
			impact_damage, strongest_final_damage, applied_count
		)

func _draw() -> void:
	if _projected_visuals_created:
		if _impacted:
			return
		var t := clampf(_elapsed_sec / impact_delay_sec, 0.0, 1.0)
		var view := get_tree().get_first_node_in_group(&"hybrid_ground_view_3d")
		var center := impact_position
		var shadow := origin_position.lerp(impact_position, t)
		var center_visible := true
		var shadow_visible := true
		if view != null:
			center_visible = view.call("can_project_world_point", center)
			shadow_visible = view.call("can_project_world_point", shadow)
			if center_visible:
				center = view.call("project_world_to_canvas", center, get_viewport())
			if shadow_visible:
				shadow = view.call("project_world_to_canvas", shadow, get_viewport())
		center = to_local(center).round()
		shadow = to_local(shadow).round()
		if shadow_visible:
			draw_set_transform(shadow, 0, Vector2(1, 0.45))
			draw_circle(Vector2.ZERO, 6, Color(0.08, 0.07, 0.09, 0.4))
			draw_set_transform(Vector2.ZERO)
		if not center_visible:
			return
		var blink := impact_delay_sec - _elapsed_sec <= 0.1 and int(_elapsed_sec * 40) % 2 == 0
		var accent := Color.WHITE if blink else telegraph_color
		var radius := lerpf(28, 7, t)
		draw_arc(center, radius, 0, TAU, 16, accent, 1)
		if idle_empowered:
			var diamond := PackedVector2Array([center+Vector2(0,-10),center+Vector2(10,0),center+Vector2(0,10),center+Vector2(-10,0),center+Vector2(0,-10)])
			draw_polyline(diamond, accent, 2)
			draw_arc(center, radius + 5, 0, TAU, 8, accent, 1)
		else:
			draw_line(center-Vector2(5,0),center+Vector2(5,0),accent,1)
			draw_line(center-Vector2(0,5),center+Vector2(0,5),accent,1)
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
	draw_circle(shell_position, 7.0, Color(1.0, 0.82, 0.42, 0.95))
