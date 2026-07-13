extends Node2D
class_name Cell

signal cell_state_changed(cell: Cell, old_state: int, new_state: int)
signal player_presence_changed(cell: Cell, player_count: int)
signal enemy_presence_changed(cell: Cell, enemy_count: int)
signal enemy_killed_in_cell(cell: Cell, enemy: BaseEnemy)
signal objective_completed(cell_id: String)
signal terrain_visual_changed(cell: Cell, texture: Texture2D)

enum CellState {IDLE, PLAYER, CONTESTED, LOCKED}
enum TaskType {NONE, OFFENSE, DEFENSE, CLEAR, HUNT, DODGE}
enum RewardType {NONE, COMBAT, ECONOMY}
enum TerrainType {NONE, CORROSION, JUNGLE, SPEED_BOOST, REGEN, LUCKY_STRIKE, DOUBLE_LOOT, LOW_HP_BERSERK}

class TaskMarkerVisual:
	extends BillboardVisual2D

	const ACTIVE_MARKER_SIZE := Vector2(58.0, 58.0)
	const COMPLETE_MARKER_SIZE := Vector2(36.0, 36.0)
	const BAR_SIZE := Vector2(78.0, 6.0)
	const EDGE_SAFE_MARGIN := 52.0
	const EDGE_ARROW_SIZE := 18.0
	const TASK_COLORS := {
		"kill": Color(1.0, 0.34, 0.26, 1.0),
		"hold": Color(0.36, 0.92, 0.56, 1.0),
		"clear": Color(0.42, 0.82, 1.0, 1.0),
		"hunt": Color(1.0, 0.76, 0.28, 1.0),
		"dodge": Color(1.0, 0.54, 0.22, 1.0),
		"fallback": Color(0.72, 0.84, 0.94, 1.0)
	}

	var status: Dictionary = {}
	var cell_rect := Rect2(Vector2.ZERO, Vector2(512.0, 512.0))
	var player_highlight := false
	var flash_alpha := 0.0:
		set(value):
			flash_alpha = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _ready() -> void:
		z_index = 16

	func configure(new_status: Dictionary, new_cell_rect: Rect2, is_player_highlighted: bool) -> void:
		status = new_status.duplicate(true)
		cell_rect = new_cell_rect
		player_highlight = is_player_highlighted
		set_logical_local_position(_resolve_marker_center(COMPLETE_MARKER_SIZE if _is_completed() else ACTIVE_MARKER_SIZE))
		visible = not status.is_empty()
		queue_redraw()

	func _draw() -> void:
		if status.is_empty():
			return
		var icon_key := str(status.get("icon_key", status.get("type", "fallback")))
		var state_text := str(status.get("state", "waiting"))
		var completed := _is_completed()
		var marker_size := COMPLETE_MARKER_SIZE if completed else ACTIVE_MARKER_SIZE
		var base_color := _get_task_color(icon_key)
		var marker_center := Vector2.ZERO
		var progress := clampf(float(status.get("progress", 0.0)), 0.0, 1.0)
		if completed:
			progress = 1.0
		var marker_color := base_color.lightened(0.15 if player_highlight else 0.0)
		var bg_alpha := 0.62 if player_highlight else 0.48
		var border_alpha := 0.92 if player_highlight else 0.68
		if completed:
			bg_alpha = 0.34
			border_alpha = 0.50
			marker_color = marker_color.darkened(0.12)
		var bg_color := Color(0.02, 0.035, 0.045, bg_alpha)
		var border_color := Color(marker_color.r, marker_color.g, marker_color.b, border_alpha)
		var edge_hint := _get_edge_hint_position(marker_center)
		if not edge_hint.is_empty():
			_draw_edge_hint(edge_hint, marker_center, marker_color)
			return
		var marker_rect := Rect2(marker_center - marker_size * 0.5, marker_size)
		draw_circle(marker_rect.get_center(), marker_size.x * 0.48, bg_color)
		draw_arc(marker_rect.get_center(), marker_size.x * 0.48, 0.0, TAU, 32, border_color, 2.0, true)
		if player_highlight and not completed:
			draw_arc(marker_rect.get_center(), marker_size.x * 0.58, -PI * 0.5, TAU * 0.78, 32, Color(marker_color.r, marker_color.g, marker_color.b, 0.45), 3.0, true)
		if completed:
			_draw_complete_badge(marker_rect, marker_color)
		else:
			_draw_task_icon(icon_key, marker_rect.get_center(), marker_size.x * 0.22, marker_color)
			var bar_rect := Rect2(
				Vector2(marker_rect.position.x - 10.0, marker_rect.end.y + 6.0),
				BAR_SIZE
			)
			draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.50), true)
			draw_rect(bar_rect, Color(border_color.r, border_color.g, border_color.b, 0.62), false, 1.0)
			if progress > 0.0:
				draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), Color(marker_color.r, marker_color.g, marker_color.b, 0.86), true)
		if flash_alpha > 0.0:
			draw_circle(marker_rect.get_center(), marker_size.x * (0.70 + flash_alpha * 0.42), Color(marker_color.r, marker_color.g, marker_color.b, flash_alpha * 0.36))

	func _is_completed() -> bool:
		var state_text := str(status.get("state", "waiting"))
		return state_text == "complete" or state_text == "completed"

	func _resolve_marker_center(marker_size: Vector2) -> Vector2:
		var target := cell_rect.position + cell_rect.size * Vector2(0.50, 0.32)
		var min_pos := cell_rect.position + marker_size * 0.65
		var max_pos := cell_rect.end - marker_size * 0.65
		return Vector2(
			clampf(target.x, min_pos.x, max_pos.x),
			clampf(target.y, min_pos.y, max_pos.y)
		)

	func _get_edge_hint_position(local_target: Vector2) -> Dictionary:
		var viewport := get_viewport()
		if viewport == null:
			return {}
		var viewport_rect := viewport.get_visible_rect()
		if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
			return {}
		var safe_rect := Rect2(
			Vector2(EDGE_SAFE_MARGIN, EDGE_SAFE_MARGIN),
			viewport_rect.size - Vector2(EDGE_SAFE_MARGIN * 2.0, EDGE_SAFE_MARGIN * 2.0)
		)
		if safe_rect.has_point(get_global_transform_with_canvas() * local_target):
			return {}
		var canvas_target := get_global_transform_with_canvas() * local_target
		var clamped_canvas := Vector2(
			clampf(canvas_target.x, safe_rect.position.x, safe_rect.end.x),
			clampf(canvas_target.y, safe_rect.position.y, safe_rect.end.y)
		)
		var local_hint := get_global_transform_with_canvas().affine_inverse() * clamped_canvas
		return {
			"position": local_hint,
			"direction": (local_target - local_hint).normalized()
		}

	func _get_task_color(icon_key: String) -> Color:
		return TASK_COLORS.get(icon_key, TASK_COLORS["fallback"]) as Color

	func _draw_edge_hint(edge_hint: Dictionary, local_target: Vector2, color: Color) -> void:
		var center := edge_hint.get("position", local_target) as Vector2
		var direction := edge_hint.get("direction", Vector2.UP) as Vector2
		if direction.length_squared() < 0.001:
			direction = Vector2.UP
		direction = direction.normalized()
		var tangent := direction.orthogonal()
		var tip := center + direction * EDGE_ARROW_SIZE
		var left := center - direction * EDGE_ARROW_SIZE * 0.55 + tangent * EDGE_ARROW_SIZE * 0.55
		var right := center - direction * EDGE_ARROW_SIZE * 0.55 - tangent * EDGE_ARROW_SIZE * 0.55
		var points := PackedVector2Array([tip, left, right])
		draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.56))
		points.append(tip)
		draw_polyline(points, Color(color.r, color.g, color.b, 0.88), 2.0, true)
		draw_circle(center, 4.0, Color(color.r, color.g, color.b, 0.82))

	func _draw_task_icon(icon_key: String, center: Vector2, size: float, color: Color) -> void:
		match icon_key:
			"kill":
				draw_arc(center, size, 0.0, TAU, 24, color, 2.5, true)
				draw_line(center + Vector2(-size * 1.2, 0.0), center + Vector2(size * 1.2, 0.0), color, 2.5, true)
				draw_line(center + Vector2(0.0, -size * 1.2), center + Vector2(0.0, size * 1.2), color, 2.5, true)
			"hold":
				var points := PackedVector2Array([
					center + Vector2(0.0, -size * 1.35),
					center + Vector2(size, -size * 0.65),
					center + Vector2(size * 0.75, size * 0.75),
					center,
					center + Vector2(-size * 0.75, size * 0.75),
					center + Vector2(-size, -size * 0.65)
				])
				draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.24))
				var closed_points := points.duplicate()
				closed_points.append(points[0])
				draw_polyline(closed_points, color, 2.5, true)
			"clear":
				for offset in [-0.55, 0.0, 0.55]:
					draw_line(center + Vector2(offset * size, -size), center + Vector2(offset * size, size), color, 2.0, true)
					draw_line(center + Vector2(-size, offset * size), center + Vector2(size, offset * size), color, 2.0, true)
			"hunt":
				var points := PackedVector2Array([
					center + Vector2(0.0, -size * 1.35),
					center + Vector2(size * 1.15, 0.0),
					center + Vector2(0.0, size * 1.35),
					center + Vector2(-size * 1.15, 0.0),
					center + Vector2(0.0, -size * 1.35)
				])
				draw_polyline(points, color, 2.8, true)
				draw_circle(center, size * 0.25, color)
			"dodge":
				draw_line(center + Vector2(-size, -size * 0.85), center + Vector2(size, 0.0), color, 3.0, true)
				draw_line(center + Vector2(size, 0.0), center + Vector2(-size, size * 0.85), color, 3.0, true)
				draw_line(center + Vector2(-size * 0.25, -size * 0.85), center + Vector2(size * 0.75, 0.0), color, 2.0, true)
				draw_line(center + Vector2(size * 0.75, 0.0), center + Vector2(-size * 0.25, size * 0.85), color, 2.0, true)
			_:
				draw_circle(center, size * 0.75, color)

	func _draw_complete_badge(marker_rect: Rect2, color: Color) -> void:
		var center := marker_rect.get_center()
		var left := center + Vector2(-marker_rect.size.x * 0.20, 0.0)
		var mid := center + Vector2(-marker_rect.size.x * 0.04, marker_rect.size.y * 0.16)
		var right := center + Vector2(marker_rect.size.x * 0.24, -marker_rect.size.y * 0.18)
		draw_line(left + Vector2(1.0, 1.0), mid + Vector2(1.0, 1.0), Color(0.0, 0.0, 0.0, 0.48), 3.2, true)
		draw_line(mid + Vector2(1.0, 1.0), right + Vector2(1.0, 1.0), Color(0.0, 0.0, 0.0, 0.48), 3.2, true)
		draw_line(left, mid, color.lightened(0.14), 2.4, true)
		draw_line(mid, right, color.lightened(0.14), 2.4, true)

var state: int = CellState.LOCKED : set = set_state
var _player_bodies: Array[Node2D] = []
var _enemy_bodies: Array[Node2D] = []
var _enemy_death_callbacks: Dictionary = {}
var progress: int = 0
@onready var _sprite: Sprite2D = $Texture/Sprite2D
@onready var _activation_visual: CellActivationVisual = get_node_or_null("ActivationVisual") as CellActivationVisual
@export var task_type: int = TaskType.NONE
@export var reward_type: int = RewardType.NONE
@export var terrain_type: int = TerrainType.NONE
@export var objective_enabled := false
@export var aura_enabled := false
@export var logical_id: int = 0
@export var profile: CellProfile
@export var module_scenes: Array[PackedScene] = []
var board_enabled: bool = true

const PROGRESS_INTERVAL := 0.2
const PROGRESS_STEP := 1
const PROGRESS_LIMIT := 100
const CONTESTED_PROGRESS_MULTIPLIER := 0.5
const TERRAIN_TEXTURE_PATHS := {
	TerrainType.NONE: "res://asset/images/cells/default.png",
	TerrainType.CORROSION: "res://asset/images/cells/dirt2.png",
	TerrainType.JUNGLE: "res://asset/images/cells/glass.png",
	TerrainType.SPEED_BOOST: "res://asset/images/cells/ice.png",
	TerrainType.LOW_HP_BERSERK: "res://asset/images/cells/lava.png",
	TerrainType.LUCKY_STRIKE: "res://asset/images/cells/gold1.png",
	TerrainType.REGEN: "res://asset/images/cells/fact1.png",
	TerrainType.DOUBLE_LOOT: "res://asset/images/cells/gold2.png"
}

var _progress_timer: Timer
var _module_root: Node
var _progress_accumulator := 0.0
var _runtime_effect_id := ""
var _runtime_task_module_id := ""
var _task_marker_visual: TaskMarkerVisual
var _task_marker_status: Dictionary = {}
var _last_task_marker_state := ""
var _task_marker_flash_tween: Tween

func set_state(value: int) -> void:
	if state == value:
		return
	var old = state
	state = value
	cell_state_changed.emit(self, old, state)
	_update_activation_visual()
	_update_task_marker_visual(false)

func _ready() -> void:
	if _sprite:
		_apply_terrain_texture()
	_update_activation_visual()
	_progress_timer = Timer.new()
	_progress_timer.wait_time = PROGRESS_INTERVAL
	_progress_timer.autostart = true
	_progress_timer.one_shot = false
	add_child(_progress_timer)
	_progress_timer.timeout.connect(_on_progress_timer_timeout)
	_setup_profile_and_modules()

func apply_profile(new_profile: CellProfile) -> void:
	profile = new_profile
	if profile == null:
		return
	task_type = profile.task_type
	reward_type = profile.reward_type
	terrain_type = profile.terrain_type
	_apply_terrain_texture()
	objective_enabled = profile.objective_enabled
	aura_enabled = profile.aura_enabled
	module_scenes = profile.resolve_module_scenes()
	_update_activation_visual()

func _apply_terrain_texture() -> void:
	if not _sprite:
		return
	if not TERRAIN_TEXTURE_PATHS.has(terrain_type):
		return
	var texture_path := str(TERRAIN_TEXTURE_PATHS[terrain_type])
	var loaded := load(texture_path)
	if loaded is Texture2D:
		var texture := loaded as Texture2D
		_sprite.texture = texture
		terrain_visual_changed.emit(self, texture)

func set_locked(is_locked: bool) -> void:
	if is_locked:
		set_state(CellState.LOCKED)
		_progress_accumulator = 0.0
	else:
		# Leave LOCKED first, then evaluate occupancy to derive PLAYER/CONTESTED/IDLE.
		if state == CellState.LOCKED:
			set_state(CellState.IDLE)
		_evaluate_cell_state()

func set_board_enabled(enabled: bool) -> void:
	board_enabled = enabled
	var area: Area2D = get_node_or_null("Area2D") as Area2D
	if area:
		area.set_deferred("monitoring", enabled)
		area.set_deferred("monitorable", enabled)
	if enabled:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		for tracked_enemy in _enemy_death_callbacks.keys():
			_untrack_enemy_death(tracked_enemy as BaseEnemy)
		_player_bodies.clear()
		_enemy_bodies.clear()
		_progress_accumulator = 0.0
		progress = 0
		clear_task_marker_status(false)
		set_state(CellState.LOCKED)
	_update_activation_visual()

func has_player_inside() -> bool:
	return not _player_bodies.is_empty()

func has_enemy_inside() -> bool:
	return not _enemy_bodies.is_empty()

func get_player_count() -> int:
	return _player_bodies.size()

func get_enemy_count() -> int:
	return _enemy_bodies.size()

func emit_objective_completed() -> void:
	objective_completed.emit(str(logical_id))

func set_task_marker_status(status: Dictionary) -> void:
	if status.is_empty() or not board_enabled:
		clear_task_marker_status(false)
		return
	_task_marker_status = status.duplicate(true)
	_update_activation_visual()
	var state_text := str(_task_marker_status.get("state", "waiting"))
	var should_flash := state_text == "complete" and _last_task_marker_state != "complete"
	_last_task_marker_state = state_text
	_update_task_marker_visual(should_flash)

func clear_task_marker_status(reset_last_state: bool = true) -> void:
	_task_marker_status.clear()
	_update_activation_visual()
	if reset_last_state:
		_last_task_marker_state = ""
	if _task_marker_flash_tween:
		_task_marker_flash_tween.kill()
		_task_marker_flash_tween = null
	if _task_marker_visual and is_instance_valid(_task_marker_visual):
		_task_marker_visual.visible = false

func set_active_boundary_edges(edges: PackedStringArray) -> void:
	if _activation_visual == null or not is_instance_valid(_activation_visual):
		_activation_visual = get_node_or_null("ActivationVisual") as CellActivationVisual
	if _activation_visual == null:
		return
	_activation_visual.set_active_boundary_edges(edges)

func get_active_task_marker_status() -> Dictionary:
	var objective := _get_objective_module()
	if objective != null and objective.has_method("get_combat_task_status"):
		var status: Variant = objective.call("get_combat_task_status")
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}

func _evaluate_cell_state() -> void:
	if state == CellState.LOCKED:
		return
	var player_present := not _player_bodies.is_empty()
	var enemy_present := not _enemy_bodies.is_empty()
	if player_present and enemy_present:
		set_state(CellState.CONTESTED)
	elif player_present:
		set_state(CellState.PLAYER)
	else:
		set_state(CellState.IDLE)

func _on_progress_timer_timeout() -> void:
	if state == CellState.LOCKED:
		return
	var delta := 0.0
	if state == CellState.PLAYER:
		delta = PROGRESS_STEP
	elif state == CellState.CONTESTED:
		delta = PROGRESS_STEP * CONTESTED_PROGRESS_MULTIPLIER
	if delta == 0:
		return
	_progress_accumulator += delta
	var progress_step := int(floor(_progress_accumulator))
	if progress_step <= 0:
		return
	_progress_accumulator -= progress_step
	progress = clamp(progress + progress_step, 0, PROGRESS_LIMIT)

# Body with layer 5 can be detected
func _on_area_2d_body_entered(body: Node2D) -> void:
	var state_changed := false
	if body is Player and not _player_bodies.has(body):
		_player_bodies.append(body)
		player_presence_changed.emit(self, _player_bodies.size())
		state_changed = true
	elif body is BaseEnemy and not _enemy_bodies.has(body):
		_enemy_bodies.append(body)
		_track_enemy_death(body)
		enemy_presence_changed.emit(self, _enemy_bodies.size())
		state_changed = true
	if state_changed:
		_evaluate_cell_state()
		_update_task_marker_visual(false)


func _on_area_2d_body_exited(body: Node2D) -> void:
	var state_changed := false
	if body is Player and _player_bodies.has(body):
		_player_bodies.erase(body)
		player_presence_changed.emit(self, _player_bodies.size())
		state_changed = true
	elif body is BaseEnemy and _enemy_bodies.has(body):
		_enemy_bodies.erase(body)
		_untrack_enemy_death(body)
		enemy_presence_changed.emit(self, _enemy_bodies.size())
		state_changed = true
	if state_changed:
		_evaluate_cell_state()
		_update_task_marker_visual(false)

func _track_enemy_death(enemy: BaseEnemy) -> void:
	if enemy == null or _enemy_death_callbacks.has(enemy):
		return
	# Always disconnect first to avoid duplicate connections
	var callback := Callable(self, "_on_tracked_enemy_death").bind(enemy)
	if enemy.is_connected("enemy_death", callback):
		enemy.disconnect("enemy_death", callback)
	enemy.connect("enemy_death", callback)
	_enemy_death_callbacks[enemy] = callback

func _untrack_enemy_death(enemy: BaseEnemy) -> void:
	if enemy == null:
		return
	if not _enemy_death_callbacks.has(enemy):
		return
	var callback: Callable = _enemy_death_callbacks[enemy]
	if is_instance_valid(enemy) and enemy.is_connected("enemy_death", callback):
		enemy.disconnect("enemy_death", callback)
	_enemy_death_callbacks.erase(enemy)

# Note: bind params come AFTER signal params in Godot 4
func _on_tracked_enemy_death(was_killed: bool, enemy: BaseEnemy) -> void:
	if not is_instance_valid(self):
		return
	if not is_instance_valid(enemy):
		return
	var was_inside := _enemy_bodies.has(enemy)
	if was_inside:
		_enemy_bodies.erase(enemy)
		enemy_presence_changed.emit(self, _enemy_bodies.size())
		if was_killed:
			enemy_killed_in_cell.emit(self, enemy)
	_evaluate_cell_state()
	_untrack_enemy_death(enemy)

func _setup_profile_and_modules() -> void:
	if profile:
		apply_profile(profile)
	_module_root = get_node_or_null("Modules")
	if _module_root == null:
		_module_root = Node.new()
		_module_root.name = "Modules"
		add_child(_module_root)
	if module_scenes.is_empty():
		return
	for module_scene in module_scenes:
		if module_scene == null:
			continue
		var module_instance = module_scene.instantiate()
		if module_instance:
			_module_root.add_child(module_instance)
			_apply_module_parameters(module_instance)

func apply_runtime_cell_effect(definition: CellEffectDefinition, preview_only: bool = false) -> void:
	_ensure_module_root()
	_remove_aura_modules()
	if definition == null:
		_runtime_effect_id = ""
		_restore_profile_terrain_effect()
		return
	_runtime_effect_id = definition.effect_id
	terrain_type = definition.terrain_type
	aura_enabled = not preview_only
	_apply_terrain_texture()
	if preview_only:
		return
	_add_aura_module_for_terrain(terrain_type, definition.get_aura_parameters())

func restore_profile_terrain_effect() -> void:
	_runtime_effect_id = ""
	_ensure_module_root()
	_remove_aura_modules()
	_restore_profile_terrain_effect()

func apply_runtime_task_module(definition: TaskModuleDefinition) -> void:
	_ensure_module_root()
	_remove_objective_modules()
	if definition == null:
		restore_profile_task_module()
		return
	_runtime_task_module_id = definition.module_id
	task_type = definition.task_type
	objective_enabled = true
	_add_objective_module_for_task(task_type)

func restore_profile_task_module() -> void:
	_runtime_task_module_id = ""
	clear_task_marker_status()
	_ensure_module_root()
	_remove_objective_modules()
	if profile == null:
		task_type = TaskType.NONE
		objective_enabled = false
		return
	task_type = profile.task_type
	reward_type = profile.reward_type
	objective_enabled = profile.objective_enabled
	if objective_enabled:
		_add_objective_module_for_task(task_type)
	_update_activation_visual()

func _restore_profile_terrain_effect() -> void:
	if profile == null:
		terrain_type = TerrainType.NONE
		aura_enabled = false
		_apply_terrain_texture()
		return
	terrain_type = profile.terrain_type
	aura_enabled = profile.aura_enabled
	_apply_terrain_texture()
	if aura_enabled:
		_add_aura_module_for_terrain(terrain_type, profile.get_aura_parameters())

func _ensure_module_root() -> void:
	if _module_root != null and is_instance_valid(_module_root):
		return
	_module_root = get_node_or_null("Modules")
	if _module_root == null:
		_module_root = Node.new()
		_module_root.name = "Modules"
		add_child(_module_root)

func _remove_aura_modules() -> void:
	if _module_root == null:
		return
	for child in _module_root.get_children().duplicate():
		if child is CellAuraModule:
			_module_root.remove_child(child)
			child.free()

func _remove_objective_modules() -> void:
	if _module_root == null:
		return
	for child in _module_root.get_children().duplicate():
		if child is CellObjectiveModule:
			_module_root.remove_child(child)
			child.queue_free()

func _add_aura_module_for_terrain(target_terrain_type: int, aura_parameters: Dictionary) -> void:
	if not CellProfile.TERRAIN_AURA_REGISTRY.has(target_terrain_type):
		return
	var scene_path := str(CellProfile.TERRAIN_AURA_REGISTRY[target_terrain_type])
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return
	var module_instance := scene.instantiate()
	if module_instance == null:
		return
	_module_root.add_child(module_instance)
	if module_instance.has_method("set_aura_parameters"):
		module_instance.set_aura_parameters(aura_parameters)
	if module_instance is CellAuraModule:
		(module_instance as CellAuraModule).aura_enabled = true

func _add_objective_module_for_task(target_task_type: int) -> void:
	if not CellProfile.TASK_OBJECTIVE_REGISTRY.has(target_task_type):
		return
	var scene_path := str(CellProfile.TASK_OBJECTIVE_REGISTRY[target_task_type])
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return
	var module_instance := scene.instantiate()
	if module_instance == null:
		return
	_module_root.add_child(module_instance)
	if module_instance is CellObjectiveModule:
		(module_instance as CellObjectiveModule).objective_enabled = true
	_connect_objective_module_status(module_instance)
	_apply_module_parameters(module_instance)
	if _runtime_task_module_id.strip_edges() != "":
		call_deferred("_refresh_runtime_task_marker_from_module")
	_update_activation_visual()

func _apply_module_parameters(module_instance: Node) -> void:
	if profile == null:
		return
	# Apply task parameters
	if module_instance.has_method("set_task_parameters"):
		match task_type:
			Cell.TaskType.OFFENSE:
				module_instance.set_task_parameters({
					"required_kill_count": profile.offense_required_kill_count,
					"count_kill_only_when_player_inside": profile.offense_count_kill_only_when_player_inside
				})
			Cell.TaskType.DEFENSE:
				module_instance.set_task_parameters({
					"required_hold_seconds": profile.defense_required_hold_seconds,
					"required_progress": profile.defense_required_progress
				})
			Cell.TaskType.CLEAR:
				module_instance.set_task_parameters({
					"clear_enemy_count": profile.clear_enemy_count,
					"clear_completion_ratio": profile.clear_completion_ratio,
					"clear_pre_entry_damage_mul": profile.clear_pre_entry_damage_mul,
					"clear_freeze_before_entry": profile.clear_freeze_before_entry
				})
			Cell.TaskType.HUNT:
				module_instance.set_task_parameters({
					"hunt_elite_count": profile.hunt_elite_count,
					"hunt_pre_entry_damage_mul": profile.hunt_pre_entry_damage_mul,
					"hunt_freeze_before_entry": profile.hunt_freeze_before_entry
				})
			Cell.TaskType.DODGE:
				module_instance.set_task_parameters({
					"dodge_required_survival_seconds": profile.dodge_required_survival_seconds,
					"dodge_aoe_damage": profile.dodge_aoe_damage,
					"dodge_aoe_damage_type": profile.dodge_aoe_damage_type,
					"dodge_aoe_radius": profile.dodge_aoe_radius,
					"dodge_aoe_warning_seconds": profile.dodge_aoe_warning_seconds,
					"dodge_aoe_interval_min": profile.dodge_aoe_interval_min,
					"dodge_aoe_interval_max": profile.dodge_aoe_interval_max,
					"dodge_aoe_impact_duration": profile.dodge_aoe_impact_duration
				})
	# Apply bonus parameters
	if module_instance.has_method("set_bonus_parameters"):
		var economy_gold_value := _resolve_economy_gold_for_current_level(profile.economy_gold)
		module_instance.set_bonus_parameters({
			"combat_heal_hp": profile.combat_heal_hp,
			"combat_bonus_speed": profile.combat_bonus_speed,
			"combat_bonus_duration": profile.combat_bonus_duration,
			"combat_bonus_armor": profile.combat_bonus_armor,
			"combat_bonus_crit_rate": profile.combat_bonus_crit_rate,
			"combat_bonus_crit_damage": profile.combat_bonus_crit_damage,
			"combat_bonus_shield": profile.combat_bonus_shield,
			"combat_bonus_damage_reduction": profile.combat_bonus_damage_reduction,
			"economy_gold": economy_gold_value,
			"economy_exp": profile.economy_exp,
			"economy_drop_coin": profile.economy_drop_coin,
			"economy_drop_chip": profile.economy_drop_chip,
			"economy_drop_coin_value": profile.economy_drop_coin_value,
			"economy_drop_chip_value": profile.economy_drop_chip_value
		})
	# Apply aura parameters
	if module_instance.has_method("set_aura_parameters"):
		module_instance.set_aura_parameters({
			"aura_corrosion_move_speed_mul": profile.aura_corrosion_move_speed_mul,
			"aura_jungle_vision_mul": profile.aura_jungle_vision_mul,
			"aura_speed_move_speed_mul": profile.aura_speed_move_speed_mul,
			"aura_regen_interval_sec": profile.aura_regen_interval_sec,
			"aura_regen_heal_amount": profile.aura_regen_heal_amount,
			"aura_lucky_strike_chance": profile.aura_lucky_strike_chance,
			"aura_lucky_strike_extra_damage": profile.aura_lucky_strike_extra_damage,
			"aura_double_loot_coin_chance": profile.aura_double_loot_coin_chance,
			"aura_double_loot_chip_chance": profile.aura_double_loot_chip_chance,
			"aura_double_loot_multiplier": profile.aura_double_loot_multiplier,
			"aura_low_hp_min_hp_ratio": profile.aura_low_hp_min_hp_ratio,
			"aura_low_hp_max_damage_mul": profile.aura_low_hp_max_damage_mul
		})

func _connect_objective_module_status(module_instance: Node) -> void:
	if module_instance == null:
		return
	if not module_instance.has_signal("task_status_changed"):
		return
	var callback := Callable(self, "_on_objective_task_status_changed")
	if not module_instance.is_connected("task_status_changed", callback):
		module_instance.connect("task_status_changed", callback)

func _on_objective_task_status_changed(_cell_id: int) -> void:
	_refresh_runtime_task_marker_from_module()

func _refresh_runtime_task_marker_from_module() -> void:
	if _runtime_task_module_id.strip_edges() == "":
		return
	var status := get_active_task_marker_status()
	if status.is_empty():
		return
	set_task_marker_status(status)

func _get_objective_module() -> CellObjectiveModule:
	_ensure_module_root()
	if _module_root == null:
		return null
	for child in _module_root.get_children():
		if child is CellObjectiveModule:
			return child as CellObjectiveModule
	return null

func _ensure_task_marker_visual() -> void:
	if _task_marker_visual != null and is_instance_valid(_task_marker_visual):
		return
	_task_marker_visual = get_node_or_null("TaskMarkerVisual") as TaskMarkerVisual
	if _task_marker_visual == null:
		_task_marker_visual = TaskMarkerVisual.new()
		_task_marker_visual.name = "TaskMarkerVisual"
		add_child(_task_marker_visual)

func _update_activation_visual() -> void:
	if _activation_visual == null or not is_instance_valid(_activation_visual):
		_activation_visual = get_node_or_null("ActivationVisual") as CellActivationVisual
	if _activation_visual == null:
		return
	var has_task := objective_enabled or not _task_marker_status.is_empty()
	_activation_visual.configure(board_enabled, has_player_inside(), has_task, _get_local_cell_rect())

func _update_task_marker_visual(play_complete_flash: bool) -> void:
	if _task_marker_status.is_empty():
		return
	_ensure_task_marker_visual()
	_task_marker_visual.configure(_task_marker_status, _get_local_cell_rect(), has_player_inside())
	if play_complete_flash:
		_play_task_marker_complete_flash()

func _play_task_marker_complete_flash() -> void:
	if _task_marker_visual == null:
		return
	if _task_marker_flash_tween:
		_task_marker_flash_tween.kill()
	_task_marker_visual.flash_alpha = 1.0
	_task_marker_flash_tween = create_tween()
	_task_marker_flash_tween.tween_property(_task_marker_visual, "flash_alpha", 0.0, 0.45)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

func _get_local_cell_rect() -> Rect2:
	var capture_polygon: CollisionPolygon2D = get_node_or_null("Area2D/CapturePolygon") as CollisionPolygon2D
	if capture_polygon != null and not capture_polygon.polygon.is_empty():
		return Rect2(capture_polygon.position + _get_polygon_local_min(capture_polygon.polygon), _get_polygon_local_size(capture_polygon.polygon))
	var collision_shape: CollisionShape2D = get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5 * collision_shape.scale.abs()
		return Rect2(collision_shape.position - half_size, half_size * 2.0)
	return Rect2(Vector2.ZERO, Vector2(512.0, 512.0))

func _get_polygon_local_min(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var min_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
	return min_point

func _get_polygon_local_size(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return max_point - min_point

func _resolve_economy_gold_for_current_level(fallback_value: int) -> int:
	if GlobalVariables.economy_data == null:
		return fallback_value
	var override_values: PackedInt32Array = GlobalVariables.economy_data.objective_economy_gold_by_level
	if override_values.is_empty():
		return fallback_value
	var level_index := maxi(int(PhaseManager.current_level), 0)
	if level_index < 0 or level_index >= override_values.size():
		return fallback_value
	return int(override_values[level_index])
