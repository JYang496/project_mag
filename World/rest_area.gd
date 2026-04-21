extends Cell
class_name RestArea

signal rest_menu_requested(zone_id: int, zone_center_global: Vector2)
signal rest_menu_cancelled

@export var board_path: NodePath
@export var bounds_shape_path: NodePath = NodePath("Area2D/CollisionShape2D")
@export var fade_duration: float = 0.35
@export var zone_move_speed: float = 500.0
@export var zone_reach_distance: float = 6.0
@export var zone_grid_color: Color = Color(0.70, 0.84, 1.0, 0.60)
@export var zone_hover_color: Color = Color(0.44, 0.88, 1.0, 1.0)
@export var zone_selected_color: Color = Color(0.38, 1.0, 0.58, 0.95)
@export var zone_grid_line_width: float = 2.0
@export var zone_outline_line_width: float = 4.0
@export var zone_hover_fill_alpha: float = 0.12
@export var zone_selected_fill_alpha: float = 0.16
@export var zone4_hold_duration: float = 1.0
@export var zone4_hold_color: Color = Color(0.36, 0.92, 0.56, 1.0)
@export var zone4_hold_track_alpha: float = 0.36
@export var zone4_hold_track_width: float = 4.0
@export var zone4_hold_progress_width: float = 8.0
@export var debug_click_logs: bool = false
@export var zone_merchant_hint_text: String = "买卖区"
@export var zone_smith_hint_text: String = "强化区"
@export var zone_battle_hold_hint_text: String = "长按进入下一关"

var _board: BoardCellGenerator
var _fade_tween: Tween
var _active := false
var _route_selection_pending := false
var hover_zone_id := -1
var selected_zone_id := 4
var menu_open := false
var move_target_global := Vector2.ZERO
var is_auto_moving := false
var _emit_menu_on_arrival := false
var _zone4_hold_elapsed := 0.0
var _zone4_hold_triggered := false
@onready var _start_battle_button: StartBattleButton = get_node_or_null("StartBattleButton")
@onready var _texture_root: Node2D = get_node_or_null("Texture")
@onready var _reward_manager: BonusManager = get_tree().current_scene.get_node_or_null("RewardManager") as BonusManager

const GRID_DIM := 3
const ZONE_COUNT := GRID_DIM * GRID_DIM
const CENTER_ZONE_ID := 4

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
	_ensure_visual_layering()
	_sync_to_target_center()
	_set_active(_should_be_active(PhaseManager.current_state()), true)
	_setup_start_battle_button()
	if not rest_menu_requested.is_connected(Callable(self, "_on_rest_menu_requested")):
		rest_menu_requested.connect(Callable(self, "_on_rest_menu_requested"))
	if not rest_menu_cancelled.is_connected(Callable(self, "_on_rest_menu_cancelled")):
		rest_menu_cancelled.connect(Callable(self, "_on_rest_menu_cancelled"))
	if _should_be_active(PhaseManager.current_state()):
		_reset_prepare_state(true)
	_refresh_interaction_state()
	queue_redraw()

func _ensure_visual_layering() -> void:
	# Keep base texture behind this CanvasItem's custom draw (grid/hover/progress).
	if _texture_root and is_instance_valid(_texture_root):
		_texture_root.z_as_relative = true
		_texture_root.z_index = -10

func _on_phase_changed(new_phase: String) -> void:
	var should_show := _should_be_active(new_phase)
	if should_show:
		_sync_to_target_center()
	_set_active(should_show, false)
	if should_show:
		_reset_prepare_state(true)
	else:
		_reset_prepare_state(false)
	_refresh_interaction_state()
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
	queue_redraw()

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
		_refresh_interaction_state()
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
		_refresh_interaction_state()
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
			_refresh_interaction_state()
		)

func _move_player_to_center() -> void:
	_place_player_at_zone(CENTER_ZONE_ID)

func _place_player_at_zone(zone_id: int) -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	PlayerData.player.global_position = _get_zone_center_global(zone_id)
	_snap_start_battle_button()

func _snap_start_battle_button() -> void:
	if _start_battle_button == null:
		return
	_start_battle_button.global_position = get_spawn_position()

func set_button_visible(visible: bool) -> void:
	if _start_battle_button == null:
		return
	# Battle start is now driven by hold-on-zone4 interaction.
	_start_battle_button.visible = false
	_start_battle_button.monitoring = false
	_start_battle_button.monitorable = false
	_start_battle_button.process_mode = Node.PROCESS_MODE_INHERIT
	_start_battle_button.set_process(false)
	_start_battle_button.set_physics_process(false)
	_start_battle_button.reset_state()
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

func _process(delta: float) -> void:
	if not _is_interaction_enabled():
		_reset_zone4_hold()
		return
	_update_hover_from_mouse()
	_update_auto_move(delta)
	_update_zone4_hold(delta)

func _input(event: InputEvent) -> void:
	if not _is_interaction_enabled():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(get_global_mouse_position())
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click()

func _handle_left_click(global_pos: Vector2) -> void:
	if debug_click_logs:
		print("[RestArea] left click event_pos=", global_pos, " world_mouse=", get_global_mouse_position())
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("is_rest_area_zone_navigation_allowed"):
		var zone_nav_allowed := bool(ui.call("is_rest_area_zone_navigation_allowed"))
		if not zone_nav_allowed:
			if debug_click_logs:
				print("[RestArea] left click ignored: zone navigation locked by submenu depth")
			return
	if _is_mouse_over_ui():
		if debug_click_logs:
			print("[RestArea] left click ignored: mouse over blocking UI")
		return
	var zone_id := _get_zone_id_for_global_point(get_global_mouse_position())
	if zone_id < 0:
		if debug_click_logs:
			print("[RestArea] left click ignored: outside 3x3 bounds")
		return
	if zone_id == CENTER_ZONE_ID and selected_zone_id == CENTER_ZONE_ID and not is_auto_moving:
		# Center zone enters battle by hold, not click-to-open-menu.
		return
	if menu_open and zone_id != selected_zone_id:
		_close_rest_area_primary_menu_if_open()
		menu_open = false
	_begin_zone_move(zone_id, _zone_opens_primary_menu(zone_id))
	if debug_click_logs:
		print("[RestArea] left click accepted: zone_id=", zone_id, " target=", _get_zone_center_global(zone_id))
	get_viewport().set_input_as_handled()

func _handle_right_click() -> void:
	if not menu_open:
		return
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("handle_rest_area_right_cancel"):
		var consumed := bool(ui.call("handle_rest_area_right_cancel"))
		if consumed:
			return
	menu_open = false
	rest_menu_cancelled.emit()
	_begin_zone_move(CENTER_ZONE_ID, false)
	get_viewport().set_input_as_handled()

func _begin_zone_move(zone_id: int, open_menu_on_arrival: bool) -> void:
	selected_zone_id = zone_id
	menu_open = false
	move_target_global = _get_zone_center_global(zone_id)
	is_auto_moving = true
	_emit_menu_on_arrival = open_menu_on_arrival
	if debug_click_logs:
		print("[RestArea] begin move zone=", zone_id, " target=", move_target_global, " open_menu=", open_menu_on_arrival)
	queue_redraw()

func _update_auto_move(delta: float) -> void:
	if not is_auto_moving:
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		_stop_auto_move()
		return
	var step := maxf(zone_move_speed, 1.0) * maxf(delta, 0.0)
	PlayerData.player.global_position = PlayerData.player.global_position.move_toward(move_target_global, step)
	_snap_start_battle_button()
	if PlayerData.player.global_position.distance_to(move_target_global) > zone_reach_distance:
		return
	PlayerData.player.global_position = move_target_global
	is_auto_moving = false
	if _emit_menu_on_arrival:
		menu_open = true
		if debug_click_logs:
			print("[RestArea] arrived zone=", selected_zone_id, " menu_open=true")
		rest_menu_requested.emit(selected_zone_id, move_target_global)
	else:
		menu_open = false
		if debug_click_logs:
			print("[RestArea] arrived center/menu cancelled")
	_emit_menu_on_arrival = false
	queue_redraw()

func _stop_auto_move() -> void:
	is_auto_moving = false
	_emit_menu_on_arrival = false

func _reset_prepare_state(move_player_to_center: bool) -> void:
	menu_open = false
	_route_selection_pending = false
	_stop_auto_move()
	_reset_zone4_hold()
	selected_zone_id = CENTER_ZONE_ID
	_set_hover_zone(-1)
	_close_rest_area_primary_menu_if_open()
	if move_player_to_center:
		_move_player_to_center()
	queue_redraw()

func _refresh_interaction_state() -> void:
	var enabled := _is_interaction_enabled()
	set_process(enabled)
	set_process_input(enabled)
	if not enabled:
		_set_hover_zone(-1)
		_reset_zone4_hold()

func _is_interaction_enabled() -> bool:
	return _active and visible and PhaseManager.current_state() == PhaseManager.PREPARE

func _update_hover_from_mouse() -> void:
	if _is_mouse_over_ui():
		_set_hover_zone(-1)
		return
	_set_hover_zone(_get_zone_id_for_global_point(get_global_mouse_position()))

func _set_hover_zone(zone_id: int) -> void:
	if hover_zone_id == zone_id:
		return
	hover_zone_id = zone_id
	if debug_click_logs:
		print("[RestArea] hover_zone=", hover_zone_id)
	if hover_zone_id != CENTER_ZONE_ID:
		_reset_zone4_hold()
	_refresh_zone_hover_hint()
	queue_redraw()

func _is_mouse_over_ui() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var hovered := viewport.gui_get_hovered_control()
	if hovered == null or not hovered.is_visible_in_tree():
		return false
	# Block only truly interactive controls or visible modal/panel UI branches.
	if hovered is BaseButton:
		return true
	if hovered is LineEdit or hovered is TextEdit:
		return true
	if hovered is ItemList or hovered is Tree:
		return true
	if hovered is OptionButton or hovered is SpinBox:
		return true
	if hovered is Slider or hovered is ScrollBar:
		return true
	if _is_inside_blocking_ui_branch(hovered):
		return true
	return false

func _is_inside_blocking_ui_branch(control: Control) -> bool:
	var blocking_roots := [
		"ShoppingRootv2",
		"UpgradeRootv2",
		"GearFuseRoot",
		"ModuleRoot",
		"InventoryRoot",
		"PauseMenuRoot",
		"MerchantRoot",
		"SmithRoot",
		"BossRoot",
		"RouteSelectionPanel",
		"RewardSelectionPanel",
		"BranchSelectPanel",
		"ModuleEquipSelectionPanel"
	]
	var current: Node = control
	while current != null:
		if blocking_roots.has(current.name):
			return true
		current = current.get_parent()
	return false

func _on_rest_menu_requested(zone_id: int, _zone_center_global: Vector2) -> void:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if zone_id == 0:
		if ui.has_method("open_rest_area_merchant_menu"):
			ui.call("open_rest_area_merchant_menu")
			return
		if ui.has_method("merchant_menu_in"):
			ui.call("merchant_menu_in")
		return
	if zone_id == 1:
		if ui.has_method("open_rest_area_smith_menu"):
			ui.call("open_rest_area_smith_menu")
			return
		if ui.has_method("smith_menu_in"):
			ui.call("smith_menu_in")
		return

func _on_rest_menu_cancelled() -> void:
	_close_rest_area_primary_menu_if_open()

func _close_rest_area_primary_menu_if_open() -> void:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if ui.has_method("close_rest_area_primary_menu"):
		ui.call("close_rest_area_primary_menu")
		return
	if ui.has_method("close_rest_area_merchant_menu"):
		ui.call("close_rest_area_merchant_menu")
		return
	if ui.has_method("merchant_menu_out"):
		ui.call("merchant_menu_out")

func _refresh_zone_hover_hint() -> void:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	var hint_text := ""
	var hint_anchor := Vector2.ZERO
	if _is_interaction_enabled():
		hint_text = _get_zone_hover_hint_text(hover_zone_id)
		hint_anchor = _get_zone_hover_anchor_global(hover_zone_id)
	if ui.has_method("set_rest_area_hover_hint_at_world"):
		ui.call("set_rest_area_hover_hint_at_world", hint_text, hint_anchor)
		return
	if ui.has_method("set_rest_area_hover_hint"):
		ui.call("set_rest_area_hover_hint", hint_text)
		return
	if hint_text == "" and ui.has_method("clear_rest_area_hover_hint"):
		ui.call("clear_rest_area_hover_hint")

func _get_zone_hover_hint_text(zone_id: int) -> String:
	match zone_id:
		0:
			return zone_merchant_hint_text
		1:
			return zone_smith_hint_text
		CENTER_ZONE_ID:
			return zone_battle_hold_hint_text
		_:
			return ""

func _get_zone_hover_anchor_global(zone_id: int) -> Vector2:
	var zone_rect := _get_zone_rect_local(zone_id)
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return get_spawn_position()
	var local_top_center := Vector2(zone_rect.position.x + zone_rect.size.x * 0.5, zone_rect.position.y)
	return to_global(local_top_center)

func _draw() -> void:
	if not _is_interaction_enabled():
		return
	var bounds := _get_bounds_local_rect()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	_draw_zone_grid(bounds)
	_draw_zone_outline(selected_zone_id, zone_selected_color, zone_outline_line_width)
	_draw_zone_outline(hover_zone_id, zone_hover_color, zone_outline_line_width)
	_draw_zone4_hold_progress()

func _draw_zone_grid(bounds: Rect2) -> void:
	draw_rect(bounds, zone_grid_color, false, zone_grid_line_width)
	var zone_w := bounds.size.x / float(GRID_DIM)
	var zone_h := bounds.size.y / float(GRID_DIM)
	for line_idx in range(1, GRID_DIM):
		var x := bounds.position.x + float(line_idx) * zone_w
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), zone_grid_color, zone_grid_line_width)
		var y := bounds.position.y + float(line_idx) * zone_h
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), zone_grid_color, zone_grid_line_width)

func _draw_zone_outline(zone_id: int, color: Color, width: float) -> void:
	var zone_rect := _get_zone_rect_local(zone_id)
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return
	var fill_alpha := zone_hover_fill_alpha
	if zone_id == selected_zone_id:
		fill_alpha = zone_selected_fill_alpha
	if fill_alpha > 0.0:
		var fill_color := Color(color.r, color.g, color.b, clampf(fill_alpha, 0.0, 1.0))
		draw_rect(zone_rect, fill_color, true)
	draw_rect(zone_rect, color, false, width)

func _get_zone_rect_local(zone_id: int) -> Rect2:
	if zone_id < 0 or zone_id >= ZONE_COUNT:
		return Rect2()
	var bounds := _get_bounds_local_rect()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Rect2()
	var zone_w := bounds.size.x / float(GRID_DIM)
	var zone_h := bounds.size.y / float(GRID_DIM)
	var row := int(zone_id / GRID_DIM)
	var col := zone_id % GRID_DIM
	return Rect2(
		bounds.position + Vector2(float(col) * zone_w, float(row) * zone_h),
		Vector2(zone_w, zone_h)
	)

func _get_zone_center_global(zone_id: int) -> Vector2:
	var zone_rect := _get_zone_rect_local(zone_id)
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return get_spawn_position()
	return to_global(zone_rect.get_center())

func _get_zone_id_for_global_point(global_pos: Vector2) -> int:
	var bounds := _get_bounds_local_rect()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return -1
	var local_pos := to_local(global_pos)
	if not bounds.has_point(local_pos):
		return -1
	var zone_w := bounds.size.x / float(GRID_DIM)
	var zone_h := bounds.size.y / float(GRID_DIM)
	if zone_w <= 0.0 or zone_h <= 0.0:
		return -1
	var col := clampi(int(floor((local_pos.x - bounds.position.x) / zone_w)), 0, GRID_DIM - 1)
	var row := clampi(int(floor((local_pos.y - bounds.position.y) / zone_h)), 0, GRID_DIM - 1)
	return row * GRID_DIM + col

func _get_bounds_local_rect() -> Rect2:
	var shape_node := get_node_or_null(bounds_shape_path) as CollisionShape2D
	if shape_node == null:
		return Rect2()
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2()
	var abs_scale := shape_node.scale.abs()
	var size := Vector2(rect_shape.size.x * abs_scale.x, rect_shape.size.y * abs_scale.y)
	return Rect2(shape_node.position - size * 0.5, size)

func _zone_opens_primary_menu(zone_id: int) -> bool:
	return zone_id == 0 or zone_id == 1

func _update_zone4_hold(delta: float) -> void:
	if not _is_zone4_hold_available():
		_reset_zone4_hold()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_reset_zone4_hold()
		return
	if _zone4_hold_triggered:
		return
	_zone4_hold_elapsed = minf(_zone4_hold_elapsed + maxf(delta, 0.0), maxf(zone4_hold_duration, 0.01))
	if debug_click_logs:
		print("[RestArea] zone4_hold=", snappedf(_zone4_hold_elapsed, 0.01), "/", zone4_hold_duration)
	if _zone4_hold_elapsed < zone4_hold_duration:
		queue_redraw()
		return
	_zone4_hold_triggered = true
	_zone4_hold_elapsed = zone4_hold_duration
	queue_redraw()
	_on_start_battle_button_activated()

func _is_zone4_hold_available() -> bool:
	if not _is_interaction_enabled():
		return false
	if is_auto_moving:
		return false
	if selected_zone_id != CENTER_ZONE_ID:
		return false
	if hover_zone_id != CENTER_ZONE_ID:
		return false
	if menu_open:
		return false
	if _route_selection_pending:
		return false
	if _is_mouse_over_ui():
		return false
	return true

func _reset_zone4_hold() -> void:
	var needs_redraw := _zone4_hold_elapsed > 0.0
	_zone4_hold_elapsed = 0.0
	_zone4_hold_triggered = false
	if needs_redraw:
		queue_redraw()

func _draw_zone4_hold_progress() -> void:
	if selected_zone_id != CENTER_ZONE_ID and hover_zone_id != CENTER_ZONE_ID and _zone4_hold_elapsed <= 0.0:
		return
	var zone_rect := _get_zone_rect_local(CENTER_ZONE_ID)
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return
	var ratio := 0.0
	if zone4_hold_duration > 0.0:
		ratio = clampf(_zone4_hold_elapsed / zone4_hold_duration, 0.0, 1.0)
	var track_rect := zone_rect.grow(6.0)
	var base_color := Color(zone4_hold_color.r, zone4_hold_color.g, zone4_hold_color.b, clampf(zone4_hold_track_alpha, 0.0, 1.0))
	draw_rect(track_rect, base_color, false, maxf(zone4_hold_track_width, 1.0))
	if ratio > 0.0:
		_draw_rect_perimeter_progress(track_rect, ratio, zone4_hold_color, maxf(zone4_hold_progress_width, 1.0))

func _draw_rect_perimeter_progress(rect: Rect2, ratio: float, color: Color, width: float) -> void:
	var p0 := rect.position
	var p1 := Vector2(rect.end.x, rect.position.y)
	var p2 := rect.end
	var p3 := Vector2(rect.position.x, rect.end.y)
	var len_top := p0.distance_to(p1)
	var len_right := p1.distance_to(p2)
	var len_bottom := p2.distance_to(p3)
	var len_left := p3.distance_to(p0)
	var total := len_top + len_right + len_bottom + len_left
	if total <= 0.0:
		return
	var remaining := clampf(ratio, 0.0, 1.0) * total
	remaining = _draw_progress_segment(p0, p1, remaining, color, width)
	remaining = _draw_progress_segment(p1, p2, remaining, color, width)
	remaining = _draw_progress_segment(p2, p3, remaining, color, width)
	_draw_progress_segment(p3, p0, remaining, color, width)

func _draw_progress_segment(from: Vector2, to: Vector2, remaining: float, color: Color, width: float) -> float:
	if remaining <= 0.0:
		return 0.0
	var seg_len := from.distance_to(to)
	if seg_len <= 0.0:
		return remaining
	if remaining >= seg_len:
		draw_line(from, to, color, width)
		return remaining - seg_len
	var t := remaining / seg_len
	draw_line(from, from.lerp(to, t), color, width)
	return 0.0
