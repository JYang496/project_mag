extends Cell
class_name RestArea

@export var board_path: NodePath
@export var bounds_shape_path: NodePath = NodePath("Area2D/CollisionShape2D")
@export var fade_duration: float = 0.35

var _board: BoardCellGenerator
var _fade_tween: Tween
var _active := false
var _route_selection_pending := false
@onready var _start_battle_button: StartBattleButton = get_node_or_null("StartBattleButton")
@onready var _reward_manager: BonusManager = get_tree().current_scene.get_node_or_null("RewardManager") as BonusManager

func _ready() -> void:
	super._ready()
	if _reward_manager == null:
		var scene_root := get_tree().current_scene
		if scene_root:
			_reward_manager = scene_root.get_node_or_null("RewardManager") as BonusManager
	if board_path != NodePath():
		_board = get_node_or_null(board_path) as BoardCellGenerator
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	var area := get_node_or_null("Area2D") as Area2D
	if area:
		area.monitoring = false
		area.monitorable = false
	if _progress_timer:
		_progress_timer.stop()
	objective_enabled = false
	aura_enabled = false
	_apply_bounds_size()
	_sync_to_target_center()
	_set_active(_should_be_active(PhaseManager.current_state()), true)
	_setup_start_battle_button()

func _on_phase_changed(new_phase: String) -> void:
	var should_show := _should_be_active(new_phase)
	if should_show:
		_sync_to_target_center()
	_set_active(should_show, false)
	if should_show and _start_battle_button:
		_start_battle_button.reset_state()

func _should_be_active(phase: String) -> bool:
	return phase == PhaseManager.PREPARE

func _apply_bounds_size() -> void:
	if _board == null:
		return
	var shape_node := get_node_or_null(bounds_shape_path) as CollisionShape2D
	if shape_node == null:
		return
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect
	rect.size = _board.cell_spacing
	shape_node.scale = Vector2.ONE

func _sync_to_target_center() -> void:
	if _board == null:
		return
	var target_center := _board.get_center_cell_global_position()
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		target_center = _board.get_cell_center_global_for_point(PlayerData.player.global_position)
	global_position = target_center - _get_local_center_offset()
	_snap_start_battle_button()

func _get_local_center_offset() -> Vector2:
	var shape_node := get_node_or_null(bounds_shape_path) as CollisionShape2D
	if shape_node:
		return shape_node.position
	return Vector2.ZERO

func get_spawn_position() -> Vector2:
	return global_position + _get_local_center_offset()

func is_active() -> bool:
	return _active

func _set_active(active: bool, immediate: bool) -> void:
	if _active == active and not immediate:
		return
	_active = active
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	if immediate:
		visible = active
		process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		var color := modulate
		color.a = 1.0 if active else 0.0
		modulate = color
		return
	if active:
		_sync_to_target_center()
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
		var start_color := modulate
		start_color.a = 0.0
		modulate = start_color
		var end_color := modulate
		end_color.a = 1.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate", end_color, fade_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	else:
		var end_color := modulate
		end_color.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate", end_color, fade_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
		_fade_tween.finished.connect(func():
			visible = false
			process_mode = Node.PROCESS_MODE_DISABLED
		)

func _move_player_to_center() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	PlayerData.player.global_position = get_spawn_position()
	_snap_start_battle_button()

func _snap_start_battle_button() -> void:
	if _start_battle_button == null:
		return
	_start_battle_button.global_position = get_spawn_position()

func set_button_visible(visible: bool) -> void:
	if _start_battle_button == null:
		return
	_start_battle_button.visible = visible
	_start_battle_button.monitoring = visible
	_start_battle_button.monitorable = visible
	_start_battle_button.process_mode = Node.PROCESS_MODE_INHERIT
	_start_battle_button.set_process(visible)
	_start_battle_button.set_physics_process(visible)
	_start_battle_button.reset_state()
	if visible:
		_snap_start_battle_button()

func _setup_start_battle_button() -> void:
	if _start_battle_button == null:
		return
	if not _start_battle_button.is_connected("activated", Callable(self, "_on_start_battle_button_activated")):
		_start_battle_button.connect("activated", Callable(self, "_on_start_battle_button_activated"))
	_snap_start_battle_button()

func _on_start_battle_button_activated() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if _route_selection_pending:
		return
	_route_selection_pending = true
	var current_level: int = max(PhaseManager.current_level, 0)
	var route_options := RunRouteManager.get_available_routes_for_level(current_level)
	var default_route_id := RunRouteManager.get_default_route_id()
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_route_selection"):
		var opened: bool = bool(ui.request_route_selection(
			route_options,
			default_route_id,
			Callable(self, "_on_route_confirmed"),
			Callable(self, "_on_route_selection_cancelled")
		))
		if opened:
			return
	_on_route_confirmed(default_route_id)

func _on_route_selection_cancelled() -> void:
	_route_selection_pending = false
	if _start_battle_button:
		_start_battle_button.reset_state()

func _on_route_confirmed(route_id: String) -> void:
	_route_selection_pending = false
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	var route_def := RunRouteManager.select_route_for_current_level(route_id)
	if route_def == null:
		route_def = RunRouteManager.select_route_for_current_level(RunRouteManager.get_default_route_id())
	if route_def.battle_enabled:
		if GlobalVariables.enemy_spawner:
			GlobalVariables.enemy_spawner.start_timer()
		PhaseManager.enter_battle()
		return
	_start_bonus_route_flow(route_def)

func _start_bonus_route_flow(route_def: RunRouteDefinition) -> void:
	var level_index: int = max(PhaseManager.current_level, 0)
	var reward_options: Array[RewardInfo] = []
	if _reward_manager:
		reward_options = _reward_manager.build_reward_selection_options(level_index, route_def)
	if reward_options.is_empty():
		var fallback_reward := RewardInfo.new()
		fallback_reward.total_chip_value = max(route_def.fallback_reward_chip_value, 1)
		reward_options = [fallback_reward]
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_reward_selection"):
		var opened: bool = bool(ui.request_reward_selection(
			route_def.display_name,
			reward_options,
			Callable(self, "_on_bonus_reward_selected"),
			Callable(self, "_on_bonus_reward_selection_cancelled")
		))
		if opened:
			return
	_on_bonus_reward_selected(reward_options[0])

func _on_bonus_reward_selection_cancelled() -> void:
	if _start_battle_button:
		_start_battle_button.reset_state()

func _on_bonus_reward_selected(reward: RewardInfo) -> void:
	if _reward_manager and reward:
		_reward_manager.grant_reward_immediately(reward)
	PhaseManager.enter_prepare()
