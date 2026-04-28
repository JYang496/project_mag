extends CellObjectiveModule
class_name DodgeSurvivalObjectiveModule

@export var required_survival_seconds: float = 10.0
@export var aoe_damage: int = 1
@export var aoe_damage_type: StringName = Attack.TYPE_FIRE
@export var aoe_radius: float = 72.0
@export var aoe_warning_seconds: float = 1.1
@export var aoe_interval_min: float = 0.9
@export var aoe_interval_max: float = 1.6
@export var aoe_impact_duration: float = 0.2
@export var warning_fill_color: Color = Color(1.0, 0.12, 0.12, 0.22)
@export var warning_outline_color: Color = Color(1.0, 0.3, 0.25, 0.95)
@export var warning_wave_color: Color = Color(1.0, 0.92, 0.74, 0.95)
@export var impact_fill_color: Color = Color(1.0, 0.48, 0.2, 0.35)
@export var impact_outline_color: Color = Color(1.0, 0.72, 0.45, 1.0)
@export var warning_z_index: int = 8

var _active := false
var _survival_elapsed := 0.0
var _time_until_next_strike := 0.0
var _pending_warning_nodes: Array[Node2D] = []
var _ui_visible := false

func _ready() -> void:
	super._ready()
	if _cell and not _cell.is_connected("player_presence_changed", Callable(self, "_on_player_presence_changed")):
		_cell.player_presence_changed.connect(_on_player_presence_changed)

func set_task_parameters(params: Dictionary) -> void:
	if params.has("dodge_required_survival_seconds"):
		required_survival_seconds = float(params["dodge_required_survival_seconds"])
	if params.has("dodge_aoe_damage"):
		aoe_damage = int(params["dodge_aoe_damage"])
	if params.has("dodge_aoe_damage_type"):
		aoe_damage_type = Attack.normalize_damage_type(params["dodge_aoe_damage_type"])
	if params.has("dodge_aoe_radius"):
		aoe_radius = float(params["dodge_aoe_radius"])
	if params.has("dodge_aoe_warning_seconds"):
		aoe_warning_seconds = float(params["dodge_aoe_warning_seconds"])
	if params.has("dodge_aoe_interval_min"):
		aoe_interval_min = float(params["dodge_aoe_interval_min"])
	if params.has("dodge_aoe_interval_max"):
		aoe_interval_max = float(params["dodge_aoe_interval_max"])
	if params.has("dodge_aoe_impact_duration"):
		aoe_impact_duration = float(params["dodge_aoe_impact_duration"])

func reset_objective_runtime() -> void:
	super.reset_objective_runtime()
	_deactivate_challenge(true)

func _process_objective(delta: float) -> void:
	if _cell == null:
		return
	if not _active:
		if _cell.has_player_inside():
			_activate_challenge()
		return
	if not _cell.has_player_inside():
		_deactivate_challenge(true)
		return
	_survival_elapsed += delta
	_update_ui_hint()
	if _survival_elapsed >= maxf(required_survival_seconds, 0.1):
		_clear_pending_warnings()
		_hide_ui_hint()
		_active = false
		_complete_objective()
		return
	_time_until_next_strike -= delta
	while _time_until_next_strike <= 0.0:
		_spawn_warning_strike()
		_schedule_next_strike()

func _on_phase_changed(new_phase: String) -> void:
	super._on_phase_changed(new_phase)
	if new_phase != PhaseManager.BATTLE:
		_deactivate_challenge(true)

func _on_player_presence_changed(_cell_ref: Cell, player_count: int) -> void:
	if player_count > 0:
		if not _active and _is_active_phase() and _is_objective_active():
			_activate_challenge()
		return
	if _active:
		_deactivate_challenge(true)

func _activate_challenge() -> void:
	if _active or not _is_objective_active():
		return
	_active = true
	_survival_elapsed = 0.0
	_schedule_next_strike()
	_show_ui_hint()

func _deactivate_challenge(reset_progress: bool) -> void:
	_active = false
	_time_until_next_strike = 0.0
	_clear_pending_warnings()
	_hide_ui_hint()
	if reset_progress:
		_survival_elapsed = 0.0

func _schedule_next_strike() -> void:
	var min_interval := maxf(aoe_interval_min, 0.05)
	var max_interval := maxf(aoe_interval_max, min_interval)
	_time_until_next_strike = randf_range(min_interval, max_interval)

func _spawn_warning_strike() -> void:
	if _cell == null:
		return
	var strike_point := _get_random_point_in_cell()
	var warning_node := Node2D.new()
	warning_node.name = "DodgeWarning"
	warning_node.global_position = strike_point
	warning_node.z_index = warning_z_index

	var fill := Polygon2D.new()
	fill.color = warning_fill_color
	fill.polygon = _build_circle_polygon(maxf(aoe_radius, 8.0), 28)
	warning_node.add_child(fill)

	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = warning_outline_color
	outline.closed = true
	outline.points = _build_circle_polygon(maxf(aoe_radius, 8.0), 28)
	warning_node.add_child(outline)

	var expanding_wave := Line2D.new()
	expanding_wave.name = "ExpandingWave"
	expanding_wave.width = 4.0
	expanding_wave.default_color = warning_wave_color
	expanding_wave.closed = true
	expanding_wave.points = _build_circle_polygon(maxf(aoe_radius, 8.0), 24)
	expanding_wave.scale = Vector2.ZERO
	warning_node.add_child(expanding_wave)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(aoe_warning_seconds, 0.05)
	warning_node.add_child(timer)

	_add_effect_node(warning_node)
	_pending_warning_nodes.append(warning_node)

	var tween := warning_node.create_tween()
	tween.set_loops()
	tween.tween_property(fill, "color:a", warning_fill_color.a * 1.6, maxf(aoe_warning_seconds * 0.5, 0.05))
	tween.tween_property(fill, "color:a", warning_fill_color.a, maxf(aoe_warning_seconds * 0.5, 0.05))

	var warning_duration := maxf(aoe_warning_seconds, 0.05)
	var wave_tween := warning_node.create_tween()
	wave_tween.tween_property(
		expanding_wave,
		"scale",
		Vector2.ONE,
		warning_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	wave_tween.parallel().tween_property(
		expanding_wave,
		"default_color:a",
		0.12,
		warning_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

	timer.timeout.connect(Callable(self, "_on_warning_timer_timeout").bind(warning_node, strike_point))
	timer.start()

func _on_warning_timer_timeout(warning_node: Node2D, strike_point: Vector2) -> void:
	_pending_warning_nodes.erase(warning_node)
	if is_instance_valid(warning_node):
		warning_node.queue_free()
	_resolve_strike_damage(strike_point)
	_spawn_impact_flash(strike_point)

func _resolve_strike_damage(strike_point: Vector2) -> void:
	var radius_sq := maxf(aoe_radius, 1.0)
	radius_sq *= radius_sq

	var player := PlayerData.player as Node2D
	if player and is_instance_valid(player):
		if player.global_position.distance_squared_to(strike_point) <= radius_sq:
			var player_attack := Attack.new()
			player_attack.damage = max(aoe_damage, 0)
			player_attack.damage_type = aoe_damage_type
			player.call("damaged", player_attack)

	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as BaseEnemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_squared_to(strike_point) > radius_sq:
			continue
		var attack := Attack.new()
		attack.damage = max(aoe_damage, 0)
		attack.damage_type = aoe_damage_type
		enemy.damaged(attack)

func _spawn_impact_flash(strike_point: Vector2) -> void:
	var flash := Node2D.new()
	flash.name = "DodgeImpact"
	flash.global_position = strike_point
	flash.z_index = warning_z_index + 1

	var fill := Polygon2D.new()
	fill.color = impact_fill_color
	fill.polygon = _build_circle_polygon(maxf(aoe_radius, 8.0), 24)
	flash.add_child(fill)

	var outline := Line2D.new()
	outline.width = 4.0
	outline.default_color = impact_outline_color
	outline.closed = true
	outline.points = _build_circle_polygon(maxf(aoe_radius, 8.0), 24)
	flash.add_child(outline)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(aoe_impact_duration, 0.05)
	flash.add_child(timer)

	_add_effect_node(flash)
	var tween := flash.create_tween()
	tween.tween_property(fill, "scale", Vector2(1.18, 1.18), maxf(aoe_impact_duration, 0.05))
	tween.parallel().tween_property(fill, "color:a", 0.0, maxf(aoe_impact_duration, 0.05))
	tween.parallel().tween_property(outline, "default_color:a", 0.0, maxf(aoe_impact_duration, 0.05))
	timer.timeout.connect(flash.queue_free)
	timer.start()

func _clear_pending_warnings() -> void:
	for warning_node in _pending_warning_nodes:
		if warning_node and is_instance_valid(warning_node):
			warning_node.queue_free()
	_pending_warning_nodes.clear()

func _add_effect_node(node: Node2D) -> void:
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(node)
		return
	get_tree().root.add_child(node)

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count : int = max(segments, 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _get_random_point_in_cell() -> Vector2:
	if _cell == null:
		return Vector2.ZERO
	var capture_polygon: CollisionPolygon2D = _cell.get_node_or_null("Area2D/CapturePolygon")
	if capture_polygon and not capture_polygon.polygon.is_empty():
		return _get_random_point_in_capture_polygon(capture_polygon)
	var collision_shape: CollisionShape2D = _cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape := collision_shape.shape as RectangleShape2D
		var half_size := rect_shape.size * 0.5
		var random_local := Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
		return collision_shape.global_transform * random_local
	return _cell.global_position

func _get_random_point_in_capture_polygon(capture_polygon: CollisionPolygon2D) -> Vector2:
	var polygon_points: PackedVector2Array = capture_polygon.polygon
	if polygon_points.is_empty():
		return capture_polygon.global_position
	var local_aabb: Rect2 = _get_polygon_local_aabb(polygon_points)
	var attempts: int = 24
	for _i in range(attempts):
		var candidate_local := Vector2(
			randf_range(local_aabb.position.x, local_aabb.end.x),
			randf_range(local_aabb.position.y, local_aabb.end.y)
		)
		if Geometry2D.is_point_in_polygon(candidate_local, polygon_points):
			return capture_polygon.global_transform * candidate_local
	var centroid_local := _get_polygon_centroid(polygon_points)
	return capture_polygon.global_transform * centroid_local

func _get_polygon_local_aabb(polygon_points: PackedVector2Array) -> Rect2:
	if polygon_points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_x := polygon_points[0].x
	var max_x := polygon_points[0].x
	var min_y := polygon_points[0].y
	var max_y := polygon_points[0].y
	for polygon_point in polygon_points:
		min_x = minf(min_x, polygon_point.x)
		max_x = maxf(max_x, polygon_point.x)
		min_y = minf(min_y, polygon_point.y)
		max_y = maxf(max_y, polygon_point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _get_polygon_centroid(polygon_points: PackedVector2Array) -> Vector2:
	if polygon_points.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for polygon_point in polygon_points:
		center += polygon_point
	return center / float(polygon_points.size())

func _show_ui_hint() -> void:
	if _ui_visible:
		_update_ui_hint()
		return
	_ui_visible = true
	_update_ui_hint()

func _hide_ui_hint() -> void:
	if not _ui_visible:
		return
	_ui_visible = false
	_set_ui_hint_text("")

func _update_ui_hint() -> void:
	if not _ui_visible:
		return
	var total_time := maxf(required_survival_seconds, 0.1)
	var elapsed := clampf(_survival_elapsed, 0.0, total_time)
	var remaining := maxf(total_time - elapsed, 0.0)
	var text := "Quest: Dodge  %.1f / %.1fs  (%.1fs remaining)" % [elapsed, total_time, remaining]
	_set_ui_hint_text(text)

func _set_ui_hint_text(text: String) -> void:
	if GlobalVariables.ui == null:
		return
	if GlobalVariables.ui.has_method("set_quest_hint"):
		GlobalVariables.ui.set_quest_hint(text)
