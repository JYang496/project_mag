extends Cell
class_name RestArea

const REST_AREA_ZONE_HELPER := preload("res://World/rest_area_zone_helper.gd")
const REST_AREA_MENU_BRIDGE := preload("res://World/rest_area_menu_bridge.gd")
const REST_AREA_AUTO_NAVIGATION := preload("res://World/rest_area_auto_navigation.gd")
const REST_AREA_HINT_PRESENTER := preload("res://World/rest_area_hint_presenter.gd")
const REST_AREA_ROUTE_FLOW := preload("res://World/rest_area_route_flow.gd")

signal rest_menu_requested(zone_id: int, zone_center_global: Vector2)
signal rest_menu_cancelled

@export var board_path: NodePath
@export var bounds_shape_path: NodePath = NodePath("Area2D/CollisionShape2D")
@export var fade_duration: float = 0.35
@export var zone_move_speed: float = 500.0
@export var zone_reach_distance: float = 6.0
@export var menu_open_cooldown_msec: int = 150
@export var rest_camera_enter_min_speed: float = 160.0
@export var rest_camera_enter_max_speed: float = 680.0
@export var rest_camera_enter_speed_curve: float = 2.4
@export var rest_camera_enter_speed_mul: float = 0.8
@export var zone4_hold_move_boost_mul: float = 2.2
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
@export var zone_merchant_hint_text: String = "Purchase"
@export var zone_smith_hint_text: String = "Upgrade"
@export var zone_module_hint_text: String = "Warehouses"
@export var zone_board_hint_text: String = "Board Edit"
@export var zone_battle_hold_hint_text: String = "Hold left mouse on center to start battle"
@export var zone_hint_forward_offset: Vector2 = Vector2(0.0, -44.0)
@export var zone_hint_z_index: int = 80

var _board: BoardCellGenerator
var _fade_tween: Tween
var _active := false
var _route_selection_pending := false
var hover_zone_id := -1
var selected_zone_id := 4
var menu_open := false
var move_target_global := Vector2.ZERO
var player_move_target_global := Vector2.ZERO
var is_auto_moving := false
var _emit_menu_on_arrival := false
var _arrival_token: int = 0
var _camera_owner_active := false
var _camera_owner_bound := false
var _last_menu_open_msec: int = -1000000
var _zone4_hold_elapsed := 0.0
var _zone4_hold_triggered := false
var _zone4_hold_boost_active: bool = false
var _zone_helper: RefCounted
var _menu_bridge: RefCounted
var _auto_navigation: RefCounted
var _hint_presenter: RefCounted
var _route_flow: RefCounted
@onready var _start_battle_button: StartBattleButton = get_node_or_null("StartBattleButton")
@onready var _texture_root: Node2D = get_node_or_null("Texture")
@onready var _reward_manager: BonusManager = get_tree().current_scene.get_node_or_null("RewardManager") as BonusManager

const GRID_DIM := 3
const ZONE_COUNT := GRID_DIM * GRID_DIM
const ZONE_ID_MERCHANT := 0
const ZONE_ID_SMITH := 1
const ZONE_ID_MODULE := 2
const ZONE_ID_BOARD_EDIT := 6
const CENTER_ZONE_ID := 4
const ZONE4_HOLD_BOOST_SOURCE_ID: StringName = &"rest_zone4_hold_boost"
const BLOCKING_UI_ROOTS: Array[StringName] = [
	&"ShoppingRootv2",
	&"UpgradeRootv2",
	&"ModuleManagementRoot",
	&"ModuleRoot",
	&"PauseMenuRoot",
	&"MerchantRoot",
	&"SmithRoot",
	&"ModuleMenuRoot",
	&"RouteSelectionPanel",
	&"RewardSelectionPanel",
	&"BoardEditPanel",
	&"BranchSelectPanel",
	&"ModuleEquipSelectionPanel",
	&"WeaponReplacementPanel",
	&"WeaponWarehousePanel"
]

func _ready() -> void:
	super._ready()
	_setup_helpers()
	if _reward_manager == null:
		var scene_root := get_tree().current_scene
		if scene_root:
			_reward_manager = scene_root.get_node_or_null("RewardManager") as BonusManager
	if board_path != NodePath():
		_board = get_node_or_null(board_path) as BoardCellGenerator
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.connect("language_changed", Callable(self, "_on_language_changed"))
	if not InventoryData.temporary_modules_changed.is_connected(_on_zone_hint_status_changed):
		InventoryData.temporary_modules_changed.connect(_on_zone_hint_status_changed)
	if not PlayerData.weapon_list_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.weapon_list_changed.connect(_on_zone_hint_status_changed)
	if not CellEffectRuntime.inventory_changed.is_connected(_on_zone_hint_status_changed):
		CellEffectRuntime.inventory_changed.connect(_on_zone_hint_status_changed)
	if not CellEffectRuntime.pending_changed.is_connected(_on_zone_hint_status_changed):
		CellEffectRuntime.pending_changed.connect(_on_zone_hint_status_changed)
	if not TaskRewardManager.pending_reward_changed.is_connected(_on_pending_reward_changed):
		TaskRewardManager.pending_reward_changed.connect(_on_pending_reward_changed)
	var area := get_node_or_null("Area2D") as Area2D
	if area:
		area.monitoring = false
		area.monitorable = false
	if _progress_timer:
		_progress_timer.stop()
	objective_enabled = false
	aura_enabled = false
	_apply_bounds_size()
	_setup_scene_hint_labels()
	_ensure_visual_layering()
	_sync_to_target_center()
	var should_show := _should_be_active(PhaseManager.current_state())
	_set_camera_owner_active(should_show)
	_set_active(should_show, true)
	call_deferred("_ensure_camera_owner_binding")
	_setup_start_battle_button()
	if not rest_menu_requested.is_connected(Callable(self, "_on_rest_menu_requested")):
		rest_menu_requested.connect(Callable(self, "_on_rest_menu_requested"))
	if not rest_menu_cancelled.is_connected(Callable(self, "_on_rest_menu_cancelled")):
		rest_menu_cancelled.connect(Callable(self, "_on_rest_menu_cancelled"))
	if should_show:
		_reset_prepare_state(true)
	_refresh_scene_hint_labels()
	_refresh_interaction_state()
	queue_redraw()

func _setup_helpers() -> void:
	var interactive_zone_ids: Array[int] = [
		ZONE_ID_MERCHANT,
		ZONE_ID_SMITH,
		ZONE_ID_MODULE,
		ZONE_ID_BOARD_EDIT,
	]
	_zone_helper = REST_AREA_ZONE_HELPER.new()
	_zone_helper.setup(
		self,
		bounds_shape_path,
		GRID_DIM,
		ZONE_COUNT,
		interactive_zone_ids
	)
	_menu_bridge = REST_AREA_MENU_BRIDGE.new()
	_menu_bridge.setup(self)
	_auto_navigation = REST_AREA_AUTO_NAVIGATION.new()
	_hint_presenter = REST_AREA_HINT_PRESENTER.new()
	_hint_presenter.setup(
		self,
		{
			"merchant": ZONE_ID_MERCHANT,
			"smith": ZONE_ID_SMITH,
			"module": ZONE_ID_MODULE,
			"board": ZONE_ID_BOARD_EDIT,
			"center": CENTER_ZONE_ID,
		},
		zone_merchant_hint_text,
		zone_smith_hint_text,
		zone_module_hint_text,
		zone_board_hint_text,
		zone_battle_hold_hint_text,
		zone_hint_forward_offset,
		zone_hint_z_index,
		zone_hover_color,
		zone_selected_color
	)
	_route_flow = REST_AREA_ROUTE_FLOW.new()
	_route_flow.setup(self)

func _exit_tree() -> void:
	CursorManager.clear_world_state(self)
	if LocalizationManager and LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.disconnect("language_changed", Callable(self, "_on_language_changed"))
	if InventoryData and InventoryData.temporary_modules_changed.is_connected(_on_zone_hint_status_changed):
		InventoryData.temporary_modules_changed.disconnect(_on_zone_hint_status_changed)
	if PlayerData and PlayerData.weapon_list_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.weapon_list_changed.disconnect(_on_zone_hint_status_changed)
	if CellEffectRuntime and CellEffectRuntime.inventory_changed.is_connected(_on_zone_hint_status_changed):
		CellEffectRuntime.inventory_changed.disconnect(_on_zone_hint_status_changed)
	if CellEffectRuntime and CellEffectRuntime.pending_changed.is_connected(_on_zone_hint_status_changed):
		CellEffectRuntime.pending_changed.disconnect(_on_zone_hint_status_changed)
	if TaskRewardManager and TaskRewardManager.pending_reward_changed.is_connected(_on_pending_reward_changed):
		TaskRewardManager.pending_reward_changed.disconnect(_on_pending_reward_changed)

func _on_language_changed(_new_locale: String) -> void:
	if _hint_presenter != null:
		_hint_presenter.call("invalidate_status")
	_refresh_scene_hint_labels()

func _on_zone_hint_status_changed() -> void:
	if _hint_presenter != null:
		_hint_presenter.call("invalidate_status")
	_refresh_scene_hint_labels()

func _on_pending_reward_changed(_has_pending: bool) -> void:
	_refresh_interaction_state()
	_update_zone_hint_visuals(true)
	queue_redraw()

func _refresh_scene_hint_labels() -> void:
	if _hint_presenter != null:
		_hint_presenter.call("refresh")

func _setup_scene_hint_labels() -> void:
	if _hint_presenter != null:
		_hint_presenter.call("setup_labels")

func _layout_scene_hint_labels() -> void:
	if _hint_presenter != null:
		_hint_presenter.call("layout")

func _place_zone_hint_label(label: Label, zone_id: int) -> void:
	if _hint_presenter != null:
		_hint_presenter.call("_place_zone_hint_label", label, zone_id)

func _build_zone_hint_status_signature() -> String:
	return str(_hint_presenter.call("_build_zone_hint_status_signature")) if _hint_presenter != null else ""

func _get_affordable_upgrade_count() -> int:
	return int(_hint_presenter.call("_get_affordable_upgrade_count")) if _hint_presenter != null else 0

func _get_weapon_upgrade_cost(weapon: Weapon) -> int:
	return int(_hint_presenter.call("_get_weapon_upgrade_cost", weapon)) if _hint_presenter != null else 1

func _get_module_upgrade_cost(module_instance: Module) -> int:
	return int(_hint_presenter.call("_get_module_upgrade_cost", module_instance)) if _hint_presenter != null else 1

func _update_zone_hint_visibility() -> void:
	if _hint_presenter != null:
		_hint_presenter.call("update_visibility")

func _update_zone_hint_visuals(force: bool = false) -> void:
	if _hint_presenter != null:
		_hint_presenter.call("update_visuals", force)

func _style_zone_hint(label: Label, zone_id: int) -> void:
	if _hint_presenter != null:
		_hint_presenter.call("_style_zone_hint", label, zone_id)

func _ensure_visual_layering() -> void:
	# Keep base texture behind this CanvasItem's custom draw (grid/hover/progress).
	if _texture_root and is_instance_valid(_texture_root):
		_texture_root.z_as_relative = true
		_texture_root.z_index = -10

func _on_phase_changed(new_phase: String) -> void:
	if _should_be_active(new_phase):
		_enter_prepare_phase()
		return
	_enter_non_prepare_phase()

func _enter_prepare_phase() -> void:
	_sync_to_target_center()
	_set_active(true, false)
	_set_camera_owner_active(true)
	call_deferred("_ensure_camera_owner_binding")
	_reset_prepare_state(true)
	_refresh_interaction_state()
	if _start_battle_button:
		_start_battle_button.reset_state()

func _enter_non_prepare_phase() -> void:
	_clear_zone4_hold_move_boost()
	_set_active(false, false)
	_set_camera_owner_active(false)
	call_deferred("_ensure_camera_owner_binding")
	_reset_prepare_state(false)
	_refresh_interaction_state()

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
	_layout_scene_hint_labels()

func _sync_to_target_center() -> void:
	if _board == null:
		return
	var target_center := _board.get_rest_area_target_center_global_position()
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

func _reset_start_battle_button() -> void:
	if _start_battle_button:
		_start_battle_button.reset_state()

func _is_route_selection_pending() -> bool:
	return _route_selection_pending

func _set_route_selection_pending(pending: bool) -> void:
	_route_selection_pending = pending

func _get_rest_area_board() -> BoardCellGenerator:
	return _board

func _get_reward_manager() -> BonusManager:
	return _reward_manager

func _setup_start_battle_button() -> void:
	if _start_battle_button == null:
		return
	if not _start_battle_button.is_connected("activated", Callable(self, "_on_start_battle_button_activated")):
		_start_battle_button.connect("activated", Callable(self, "_on_start_battle_button_activated"))
	_snap_start_battle_button()

func _on_start_battle_button_activated() -> void:
	if _route_flow != null:
		_route_flow.call("on_start_battle_button_activated")

func _on_battle_start_cancelled() -> void:
	if _route_flow != null:
		_route_flow.call("on_battle_start_cancelled")

func _continue_start_battle() -> void:
	if _route_flow != null:
		_route_flow.call("continue_start_battle")

func _commit_board_edits_and_continue_start_battle() -> void:
	if _route_flow != null:
		_route_flow.call("commit_board_edits_and_continue_start_battle")

func _discard_unassigned_task_modules_and_continue_start_battle() -> void:
	if _route_flow != null:
		_route_flow.call("discard_unassigned_task_modules_and_continue_start_battle")

func _on_route_selection_cancelled() -> void:
	if _route_flow != null:
		_route_flow.call("on_route_selection_cancelled")

func _on_route_confirmed(route_id: String) -> void:
	if _route_flow != null:
		_route_flow.call("on_route_confirmed", route_id)

func _start_bonus_route_flow(route_def: RunRouteDefinition) -> void:
	if _route_flow != null:
		_route_flow.call("start_bonus_route_flow", route_def)

func _on_bonus_reward_selection_cancelled() -> void:
	if _route_flow != null:
		_route_flow.call("on_bonus_reward_selection_cancelled")

func _on_bonus_reward_selected(reward: RewardInfo) -> void:
	if _route_flow != null:
		_route_flow.call("on_bonus_reward_selected", reward)

func _process(delta: float) -> void:
	_ensure_camera_owner_binding()
	if not _is_interaction_enabled():
		_reset_zone4_hold()
		CursorManager.clear_world_state(self)
		return
	if _hint_presenter != null and bool(_hint_presenter.call("has_status_changed")):
		_refresh_scene_hint_labels()
	_update_zone_hint_visibility()
	_update_hover_from_mouse()
	_update_auto_move()
	_update_zone4_hold(delta)
	_refresh_cursor_state()

func _input(event: InputEvent) -> void:
	if not _is_interaction_enabled():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(get_global_mouse_position())
		elif event.is_action_pressed("CANCEL"):
			_handle_right_click()

func _handle_left_click(global_pos: Vector2) -> void:
	if debug_click_logs:
		print("[RestArea] left click event_pos=", global_pos, " world_mouse=", get_global_mouse_position())
	_sync_menu_open_with_ui()
	if _menu_bridge != null and not bool(_menu_bridge.call("is_navigation_allowed")):
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
	if menu_open and zone_id == selected_zone_id and _zone_opens_interaction(zone_id):
		# Already inside this zone with its interaction open; ignore repeated click.
		if debug_click_logs:
			print("[RestArea] left click ignored: primary menu already open for zone=", zone_id)
		return
	if menu_open and zone_id != selected_zone_id:
		_close_rest_area_primary_menu_if_open()
		menu_open = false
	_begin_zone_move(zone_id, _zone_opens_interaction(zone_id))
	if debug_click_logs:
		print("[RestArea] left click accepted: zone_id=", zone_id, " target=", _get_zone_center_global(zone_id))
	get_viewport().set_input_as_handled()

func _handle_right_click() -> void:
	_sync_menu_open_with_ui()
	if not menu_open:
		return
	if _menu_bridge != null and bool(_menu_bridge.call("handle_right_cancel")):
		_sync_menu_open_with_ui()
		get_viewport().set_input_as_handled()
		return
	menu_open = false
	rest_menu_cancelled.emit()
	_begin_zone_move(CENTER_ZONE_ID, false)
	get_viewport().set_input_as_handled()

func _sync_menu_open_with_ui() -> void:
	if _menu_bridge == null:
		return
	var visible_variant: Variant = _menu_bridge.call("get_menu_visible")
	if visible_variant == null:
		return
	var ui_menu_visible := bool(visible_variant)
	if menu_open == ui_menu_visible:
		return
	menu_open = ui_menu_visible
	if not menu_open:
		_emit_menu_on_arrival = false
	queue_redraw()

func _begin_zone_move(zone_id: int, open_menu_on_arrival: bool) -> void:
	_arrival_token += 1
	selected_zone_id = zone_id
	menu_open = false
	_update_zone_hint_visuals()
	move_target_global = _get_zone_center_global(zone_id)
	player_move_target_global = move_target_global
	if not _camera_owner_active:
		_set_camera_owner_active(true)
	is_auto_moving = true
	_emit_menu_on_arrival = open_menu_on_arrival
	if _auto_navigation != null:
		_auto_navigation.call("start_player_navigation", player_move_target_global, zone_move_speed)
	if debug_click_logs:
		print("[RestArea] begin move zone=", zone_id, " cam_target=", move_target_global, " player_target=", player_move_target_global, " open_menu=", open_menu_on_arrival)
	queue_redraw()

func _update_auto_move() -> void:
	if not is_auto_moving:
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		_stop_auto_move()
		return
	_snap_start_battle_button()
	var arrived_now := bool(_auto_navigation.call("has_player_arrived", player_move_target_global, zone_reach_distance)) if _auto_navigation != null else true
	if not arrived_now:
		return
	is_auto_moving = false
	if _emit_menu_on_arrival:
		_try_open_menu_for_zone(selected_zone_id, move_target_global, "player_fallback")
	queue_redraw()

func _get_player_move_target_for_zone(zone_id: int) -> Vector2:
	return _get_zone_center_global(zone_id)

func _stop_auto_move() -> void:
	_arrival_token += 1
	is_auto_moving = false
	_emit_menu_on_arrival = false
	if _auto_navigation != null:
		_auto_navigation.call("stop_player_navigation")
	_zone4_hold_boost_active = false

func _start_return_to_center_after_battle() -> void:
	# Reuse the same rest-area navigation pipeline as normal zone clicks.
	_begin_zone_move(CENTER_ZONE_ID, false)

func _reset_prepare_state(move_player_to_center: bool) -> void:
	menu_open = false
	_route_selection_pending = false
	_stop_auto_move()
	_reset_zone4_hold()
	selected_zone_id = CENTER_ZONE_ID
	_update_zone_hint_visuals()
	_set_hover_zone(-1)
	_close_rest_area_primary_menu_if_open()
	if move_player_to_center:
		_start_return_to_center_after_battle()
	queue_redraw()

func _refresh_interaction_state() -> void:
	var enabled := _is_interaction_enabled()
	set_process(enabled)
	set_process_input(enabled)
	if not enabled:
		_set_hover_zone(-1)
		_reset_zone4_hold()
		CursorManager.clear_world_state(self)

func _is_interaction_enabled() -> bool:
	return _active \
		and visible \
		and PhaseManager.current_state() == PhaseManager.PREPARE \
		and not TaskRewardManager.is_reward_blocking_interactions()

func is_module_management_available() -> bool:
	return _is_interaction_enabled()

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
	_update_zone_hint_visuals()
	_refresh_zone_hover_hint()
	queue_redraw()

func _is_mouse_over_ui() -> bool:
	var viewport := get_viewport()
	return bool(_menu_bridge.call("is_mouse_over_blocking_ui", viewport, BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _is_inside_blocking_ui_branch(control: Control) -> bool:
	return bool(_menu_bridge.call("_is_inside_blocking_ui_branch", control, BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _is_mouse_inside_visible_blocking_ui_root(mouse_position: Vector2) -> bool:
	return bool(_menu_bridge.call("_is_mouse_inside_visible_blocking_ui_root", mouse_position, BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _control_tree_has_blocking_root_at(control: Control, mouse_position: Vector2) -> bool:
	return bool(_menu_bridge.call("_control_tree_has_blocking_root_at", control, mouse_position, BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _on_rest_menu_requested(zone_id: int, _zone_center_global: Vector2) -> void:
	if _menu_bridge != null:
		_menu_bridge.call("open_zone_menu", zone_id, ZONE_ID_MERCHANT, ZONE_ID_SMITH, ZONE_ID_MODULE, ZONE_ID_BOARD_EDIT)

func _on_rest_menu_cancelled() -> void:
	_close_rest_area_primary_menu_if_open()

func _close_rest_area_primary_menu_if_open() -> void:
	if _menu_bridge != null:
		_menu_bridge.call("close_primary_menu")

func _refresh_zone_hover_hint() -> void:
	if _menu_bridge != null:
		_menu_bridge.call("clear_hover_hint")

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
	return _zone_helper.call("get_zone_rect_local", zone_id) if _zone_helper != null else Rect2()

func _get_zone_center_global(zone_id: int) -> Vector2:
	return _zone_helper.call("get_zone_center_global", zone_id) if _zone_helper != null else get_spawn_position()

func _get_zone_id_for_global_point(global_pos: Vector2) -> int:
	return int(_zone_helper.call("get_zone_id_for_global_point", global_pos)) if _zone_helper != null else -1

func _get_bounds_local_rect() -> Rect2:
	return _zone_helper.call("get_bounds_local_rect") if _zone_helper != null else Rect2()

func _zone_opens_interaction(zone_id: int) -> bool:
	return bool(_zone_helper.call("zone_opens_interaction", zone_id)) if _zone_helper != null else false

func _update_zone4_hold(delta: float) -> void:
	if not _is_zone4_hold_available():
		_clear_zone4_hold_move_boost()
		_reset_zone4_hold()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_clear_zone4_hold_move_boost()
		_reset_zone4_hold()
		return
	_ensure_zone4_hold_move_boost_active()
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

func _set_camera_owner_active(active: bool) -> void:
	_camera_owner_active = active
	if not active:
		_camera_owner_bound = false
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	if not PlayerData.player.has_method("set_restarea_camera_control_enabled"):
		return
	var center_target := _get_zone_center_global(CENTER_ZONE_ID)
	PlayerData.player.call(
		"set_restarea_camera_control_enabled",
		active,
		center_target,
		false
	)
	if active:
		if PlayerData.player.has_method("configure_restarea_camera_motion"):
			PlayerData.player.call(
				"configure_restarea_camera_motion",
				rest_camera_enter_min_speed,
				rest_camera_enter_max_speed,
				rest_camera_enter_speed_curve
			)
		if PlayerData.player.has_method("move_restarea_camera_to"):
			PlayerData.player.call("move_restarea_camera_to", center_target, maxf(rest_camera_enter_speed_mul, 0.05))
	_camera_owner_bound = true

func _ensure_camera_owner_binding() -> void:
	if _camera_owner_bound:
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	_set_camera_owner_active(_camera_owner_active)

func _try_open_menu_for_zone(zone_id: int, zone_center: Vector2, source: String) -> void:
	if not _emit_menu_on_arrival:
		return
	if not _zone_opens_interaction(zone_id):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_menu_open_msec < max(menu_open_cooldown_msec, 0):
		return
	_last_menu_open_msec = now_msec
	_open_menu_after_stable_frames(zone_id, zone_center, source, _arrival_token)

func _open_menu_after_stable_frames(zone_id: int, zone_center: Vector2, source: String, token: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if token != _arrival_token:
		return
	if menu_open:
		return
	if not _emit_menu_on_arrival:
		return
	menu_open = true
	_emit_menu_on_arrival = false
	if debug_click_logs:
		print("[RestArea] open menu source=", source, " zone=", zone_id)
	rest_menu_requested.emit(zone_id, zone_center)
	queue_redraw()

func _reset_zone4_hold() -> void:
	var needs_redraw := _zone4_hold_elapsed > 0.0
	_zone4_hold_elapsed = 0.0
	_zone4_hold_triggered = false
	if needs_redraw:
		queue_redraw()

func _ensure_zone4_hold_move_boost_active() -> void:
	if _auto_navigation != null:
		_auto_navigation.call("ensure_zone4_hold_move_boost_active", zone4_hold_move_boost_mul)
		_zone4_hold_boost_active = bool(_auto_navigation.call("is_zone4_hold_boost_active"))

func _clear_zone4_hold_move_boost() -> void:
	if _auto_navigation != null:
		_auto_navigation.call("clear_zone4_hold_move_boost")
	_zone4_hold_boost_active = false

func _apply_zone_move_speed_override() -> void:
	if _auto_navigation != null:
		_auto_navigation.call("configure_zone_move_speed", zone_move_speed)

func _clear_zone_move_speed_override() -> void:
	if _auto_navigation != null:
		_auto_navigation.call("clear_zone_move_speed_override")

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

func _refresh_cursor_state() -> void:
	if not _is_interaction_enabled():
		CursorManager.clear_world_state(self)
		return
	if _is_mouse_over_ui():
		CursorManager.clear_world_state(self)
		return
	if _zone4_hold_elapsed > 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _is_zone4_hold_available():
		CursorManager.set_world_state(self, CursorManager.STATE_HOLD_ACTIVE, 60)
		return
	if _is_zone_clickable_for_cursor(hover_zone_id):
		CursorManager.set_world_state(self, CursorManager.STATE_CLICKABLE, 50)
		return
	CursorManager.clear_world_state(self)

func _is_zone_clickable_for_cursor(zone_id: int) -> bool:
	if zone_id < 0:
		return false
	if zone_id == CENTER_ZONE_ID:
		# When the player is not on center, center zone is still clickable for move-in.
		# Hold-to-start is only available after arriving at center.
		if selected_zone_id != CENTER_ZONE_ID:
			if is_auto_moving or _is_mouse_over_ui():
				return false
			var ui = GlobalVariables.ui
			if ui and is_instance_valid(ui) and ui.has_method("is_rest_area_zone_navigation_allowed"):
				return bool(ui.call("is_rest_area_zone_navigation_allowed"))
			return true
		return _is_zone4_hold_available()
	if not _zone_opens_interaction(zone_id):
		return false
	return bool(_menu_bridge.call("is_navigation_allowed")) if _menu_bridge != null else true
