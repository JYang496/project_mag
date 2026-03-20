extends CellObjectiveModule
class_name ClearCellObjectiveModule

@export var quest_enemy_count: int = 6
@export var completion_ratio: float = 0.8
@export var pre_entry_damage_mul: float = 0.5
@export var freeze_before_entry: bool = true
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var _quest_enemies: Array[BaseEnemy] = []
var _quest_enemy_weights: Dictionary = {}
var _progress := 0.0
var _required_progress := 0.0
var _spawned := false
var _player_entered := false
var _ui_visible := false
var _pending_spawn_after_phase_change := false
var _finishing_objective := false

func _ready() -> void:
	super._ready()
	if _cell and not _cell.is_connected("player_presence_changed", Callable(self, "_on_player_presence_changed")):
		_cell.player_presence_changed.connect(_on_player_presence_changed)

func set_task_parameters(params: Dictionary) -> void:
	if params.has("clear_enemy_count"):
		quest_enemy_count = int(params["clear_enemy_count"])
	if params.has("clear_completion_ratio"):
		completion_ratio = float(params["clear_completion_ratio"])
	if params.has("clear_pre_entry_damage_mul"):
		pre_entry_damage_mul = float(params["clear_pre_entry_damage_mul"])
	if params.has("clear_freeze_before_entry"):
		freeze_before_entry = bool(params["clear_freeze_before_entry"])

func reset_objective_runtime() -> void:
	super.reset_objective_runtime()
	_cleanup_quest_enemies()
	_progress = 0.0
	_required_progress = 0.0
	_spawned = false
	_player_entered = false
	_pending_spawn_after_phase_change = false
	_finishing_objective = false

func _process_objective(_delta: float) -> void:
	if _pending_spawn_after_phase_change:
		return
	if not _spawned:
		_try_spawn_quest_enemies()

func _on_phase_changed(new_phase: String) -> void:
	super._on_phase_changed(new_phase)
	if new_phase == PhaseManager.BATTLE:
		_pending_spawn_after_phase_change = true
		call_deferred("_spawn_after_phase_change")
		return
	_pending_spawn_after_phase_change = false
	_cleanup_quest_enemies()
	_spawned = false
	_player_entered = false
	_finishing_objective = false

func _spawn_after_phase_change() -> void:
	if not is_inside_tree():
		return
	_pending_spawn_after_phase_change = false
	_try_spawn_quest_enemies()

func _on_player_presence_changed(_cell_ref: Cell, player_count: int) -> void:
	if player_count <= 0:
		_hide_ui_hint()
		return
	if not _player_entered:
		_player_entered = true
		_unlock_quest_enemies()
	_show_ui_hint()

func _try_spawn_quest_enemies() -> void:
	if _spawned:
		return
	if not _is_active_phase():
		return
	if not _is_objective_active():
		return
	_spawn_quest_enemies()

func _spawn_quest_enemies() -> void:
	_spawned = true
	_progress = 0.0
	_required_progress = 0.0
	_quest_enemies.clear()
	_quest_enemy_weights.clear()

	var spawn_infos := _get_level_spawn_infos()
	if spawn_infos.is_empty():
		push_warning("ClearCellObjectiveModule: no spawn data available.")
		# Invalid level config for this objective: do not auto-complete and do not grant reward.
		return

	var normal_candidates: Array[SpawnInfo] = []
	for info in spawn_infos:
		if info == null:
			continue
		if not _is_elite_spawn(info):
			normal_candidates.append(info)

	if normal_candidates.is_empty():
		push_warning("ClearCellObjectiveModule: no normal spawn data available.")
		# Invalid level config for this objective: do not auto-complete and do not grant reward.
		return

	var normal_count: int = max(quest_enemy_count, 0)
	for _i in range(normal_count):
		var info: SpawnInfo = normal_candidates.pick_random() as SpawnInfo
		var enemy := _spawn_enemy_from_info(info)
		if enemy:
			_register_quest_enemy(enemy, 1.0)

	var total_weight := 0.0
	for weight in _quest_enemy_weights.values():
		total_weight += float(weight)
	_required_progress = maxf(total_weight * clampf(completion_ratio, 0.0, 1.0), 0.0)

	if _cell and _cell.has_player_inside():
		_player_entered = true
		_unlock_quest_enemies()
		_show_ui_hint()

	if total_weight <= 0.0:
		push_warning("ClearCellObjectiveModule: spawned zero quest enemies; objective skipped for this battle.")

func _register_quest_enemy(enemy: BaseEnemy, weight: float) -> void:
	if enemy == null:
		return
	_quest_enemies.append(enemy)
	_quest_enemy_weights[enemy] = weight
	if not enemy.is_connected("enemy_death", Callable(self, "_on_quest_enemy_death").bind(enemy)):
		enemy.connect("enemy_death", Callable(self, "_on_quest_enemy_death").bind(enemy))
	enemy.call_deferred("set_quest_highlight", true, highlight_color)
	enemy.set_quest_lock(true, pre_entry_damage_mul, freeze_before_entry)

func _on_quest_enemy_death(enemy: BaseEnemy) -> void:
	if not _quest_enemy_weights.has(enemy):
		return
	var weight := float(_quest_enemy_weights[enemy])
	_quest_enemy_weights.erase(enemy)
	_quest_enemies.erase(enemy)
	if _finishing_objective:
		return
	_progress += weight
	_update_ui_hint()
	if _progress >= _required_progress and not _completed:
		_finish_objective()

func _finish_objective() -> void:
	if _completed or _finishing_objective:
		return
	_finishing_objective = true
	var remaining_enemies := _quest_enemies.duplicate()
	for enemy in remaining_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.set_quest_highlight(false)
		enemy.erase()
	_hide_ui_hint()
	_complete_objective()
	_finishing_objective = false

func _unlock_quest_enemies() -> void:
	for enemy in _quest_enemies:
		if enemy and is_instance_valid(enemy):
			enemy.set_quest_lock(false)

func _cleanup_quest_enemies() -> void:
	_finishing_objective = false
	for enemy in _quest_enemies:
		if enemy and is_instance_valid(enemy):
			enemy.set_quest_lock(false)
			enemy.set_quest_highlight(false)
	_quest_enemies.clear()
	_quest_enemy_weights.clear()
	_hide_ui_hint()

func _get_level_spawn_infos() -> Array[SpawnInfo]:
	if SpawnData.level_list.is_empty():
		return []
	var level_index := clampi(PhaseManager.current_level, 0, SpawnData.level_list.size() - 1)
	var level_config := SpawnData.level_list[level_index]
	if level_config == null:
		return []
	return level_config.spawns.duplicate()

func _is_elite_spawn(info: SpawnInfo) -> bool:
	if info == null:
		return false
	var scene := info.enemy as PackedScene
	if scene == null:
		return false
	var instance := scene.instantiate()
	var is_elite := instance is EliteEnemy
	if instance:
		instance.queue_free()
	return is_elite

func _spawn_enemy_from_info(info: SpawnInfo) -> BaseEnemy:
	if info == null:
		return null
	var scene := info.enemy as PackedScene
	if scene == null:
		return null
	var enemy := scene.instantiate()
	if enemy == null or not (enemy is BaseEnemy):
		if enemy:
			enemy.queue_free()
		return null
	var base_enemy := enemy as BaseEnemy
	_apply_level_scaling(info, base_enemy)
	base_enemy.global_position = _get_random_point_in_cell()
	_attach_enemy(base_enemy)
	return base_enemy

func _attach_enemy(enemy: BaseEnemy) -> void:
	if GlobalVariables.enemy_spawner:
		GlobalVariables.enemy_spawner.call_deferred("add_child", enemy)
		return
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.call_deferred("add_child", enemy)
		return
	get_tree().root.call_deferred("add_child", enemy)

func _apply_level_scaling(spawn_info: SpawnInfo, enemy_instance: BaseEnemy) -> void:
	if enemy_instance == null:
		return
	var level_index: int = maxi(PhaseManager.current_level, 0)
	enemy_instance.hp = spawn_info.get_scaled_hp(level_index, enemy_instance.hp)
	enemy_instance.damage = spawn_info.get_scaled_damage(level_index, enemy_instance.damage)

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
		var candidate_local: Vector2 = Vector2(
			randf_range(local_aabb.position.x, local_aabb.end.x),
			randf_range(local_aabb.position.y, local_aabb.end.y)
		)
		if Geometry2D.is_point_in_polygon(candidate_local, polygon_points):
			return capture_polygon.global_transform * candidate_local
	var centroid_local: Vector2 = _get_polygon_centroid(polygon_points)
	return capture_polygon.global_transform * centroid_local

func _get_polygon_local_aabb(polygon_points: PackedVector2Array) -> Rect2:
	if polygon_points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_x: float = polygon_points[0].x
	var max_x: float = polygon_points[0].x
	var min_y: float = polygon_points[0].y
	var max_y: float = polygon_points[0].y
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
	var remaining := maxf(_required_progress - _progress, 0.0)
	var percent := 0.0
	if _required_progress > 0.0:
		percent = clampf(_progress / _required_progress, 0.0, 1.0)
	var text := "Quest: Clear Cell  %d%%  (%.1f remaining)" % [int(round(percent * 100.0)), remaining]
	_set_ui_hint_text(text)

func _set_ui_hint_text(text: String) -> void:
	if GlobalVariables.ui == null:
		return
	if GlobalVariables.ui.has_method("set_quest_hint"):
		GlobalVariables.ui.set_quest_hint(text)
