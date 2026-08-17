extends Cell
class_name RestArea

const REST_AREA_ZONE_HELPER := preload("res://World/rest_area_zone_helper.gd")
const REST_AREA_MENU_BRIDGE := preload("res://World/rest_area_menu_bridge.gd")
const REST_AREA_AUTO_NAVIGATION := preload("res://World/rest_area_auto_navigation.gd")
const REST_AREA_HINT_PRESENTER := preload("res://World/rest_area_hint_presenter.gd")
const REST_AREA_ROUTE_FLOW := preload("res://World/rest_area_route_flow.gd")
const REST_AREA_GROUND_TEXTURE: Texture2D = preload("res://asset/images/cells/rest_area_safe_medical.png")

signal rest_menu_requested(zone_id: int, zone_center_global: Vector2)
signal rest_menu_cancelled

@export var board_path: NodePath
@export var bounds_shape_path: NodePath = NodePath("Area2D/CollisionShape2D")
@export var fade_duration: float = 0.35
@export var zone_move_speed: float = 500.0
@export var zone_reach_distance: float = 6.0
@export var menu_open_cooldown_msec: int = 150
@export var zone_grid_color: Color = Color(0.70, 0.84, 1.0, 0.18)
@export var zone_hover_color: Color = Color(0.44, 0.88, 1.0, 1.0)
@export var zone_selected_color: Color = Color(0.38, 1.0, 0.58, 0.95)
@export var zone_grid_line_width: float = 1.0
@export var zone_outline_line_width: float = 4.0
@export var zone_grid_inner_alpha_multiplier: float = 0.45
@export var zone_hover_fill_alpha: float = 0.12
@export var zone_selected_fill_alpha: float = 0.16
@export var debug_click_logs: bool = false
@export var zone_merchant_hint_text: String = "Purchase"
@export var zone_smith_hint_text: String = "Upgrade"
@export var zone_module_hint_text: String = "Warehouses"
@export var zone_board_hint_text: String = "Board"
@export var zone_battle_hint_text: String = "Choose next protocol"
@export var zone_hint_forward_offset: Vector2 = Vector2(0.0, -44.0)
@export var zone_battle_hint_extra_offset: Vector2 = Vector2(0.0, -14.0)
@export var zone_hint_z_index: int = 80
@export var zone_hint_intro_duration: float = 8.0

var _board: BoardCellGenerator
var _fade_tween: Tween
var _active := false
var _arrival_transition_locked := false
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
var _zone_hint_intro_remaining := 0.0
var _zone_helper: RefCounted
var _menu_bridge: RefCounted
var _auto_navigation: RefCounted
var _hint_presenter: RefCounted
var _route_flow: RefCounted
var _hybrid_hint_canvas: CanvasLayer
var _hybrid_hint_zones: Dictionary = {}
var _arrival_focus_zone := -1
var _readiness_canvas: CanvasLayer
var _readiness_label: Label
var _readiness_signature := ""
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
const LEGACY_BLOCKING_UI_ROOTS: Array[StringName] = [
	&"PrimaryMenuRoot",
	&"ShoppingRootv2",
	&"UpgradeRootv2",
	&"ModuleManagementRoot",
	&"PauseMenuRoot",
	&"RewardSelectionPanel",
	&"BoardEditPanel",
	&"CellManagementPanel",
	&"TaskManagementPanel",
	&"BranchSelectPanel",
	&"ModuleEquipSelectionPanel",
	&"BattleContractSelectionPanel",
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
	if not PhaseManager.post_battle_collect_gate_changed.is_connected(_on_post_battle_collect_gate_changed):
		PhaseManager.post_battle_collect_gate_changed.connect(_on_post_battle_collect_gate_changed)
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.connect("language_changed", Callable(self, "_on_language_changed"))
	if not InventoryData.temporary_modules_changed.is_connected(_on_zone_hint_status_changed):
		InventoryData.temporary_modules_changed.connect(_on_zone_hint_status_changed)
	if not InventoryData.weapon_storage_changed.is_connected(_on_zone_hint_status_changed):
		InventoryData.weapon_storage_changed.connect(_on_zone_hint_status_changed)
	if not PlayerData.weapon_list_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.weapon_list_changed.connect(_on_zone_hint_status_changed)
	if not PlayerData.player_gold_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.player_gold_changed.connect(_on_zone_hint_status_changed)
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
		_start_zone_hint_intro()
	_refresh_scene_hint_labels()
	_refresh_interaction_state()
	queue_redraw()
	call_deferred("_setup_hybrid_hint_canvas")
	call_deferred("_setup_readiness_checklist")

func _apply_terrain_texture() -> void:
	if _sprite == null:
		return
	_sprite.texture = REST_AREA_GROUND_TEXTURE
	terrain_visual_changed.emit(self, REST_AREA_GROUND_TEXTURE)

func _setup_helpers() -> void:
	var interactive_zone_ids: Array[int] = [
		ZONE_ID_MERCHANT,
		ZONE_ID_SMITH,
		ZONE_ID_MODULE,
		CENTER_ZONE_ID,
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
		zone_battle_hint_text,
		zone_hint_forward_offset,
		zone_battle_hint_extra_offset,
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
	if InventoryData and InventoryData.weapon_storage_changed.is_connected(_on_zone_hint_status_changed):
		InventoryData.weapon_storage_changed.disconnect(_on_zone_hint_status_changed)
	if PlayerData and PlayerData.weapon_list_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.weapon_list_changed.disconnect(_on_zone_hint_status_changed)
	if PlayerData and PlayerData.player_gold_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.player_gold_changed.disconnect(_on_zone_hint_status_changed)
	if CellEffectRuntime and CellEffectRuntime.inventory_changed.is_connected(_on_zone_hint_status_changed):
		CellEffectRuntime.inventory_changed.disconnect(_on_zone_hint_status_changed)
	if CellEffectRuntime and CellEffectRuntime.pending_changed.is_connected(_on_zone_hint_status_changed):
		CellEffectRuntime.pending_changed.disconnect(_on_zone_hint_status_changed)
	if TaskRewardManager and TaskRewardManager.pending_reward_changed.is_connected(_on_pending_reward_changed):
		TaskRewardManager.pending_reward_changed.disconnect(_on_pending_reward_changed)
	if PhaseManager and PhaseManager.post_battle_collect_gate_changed.is_connected(_on_post_battle_collect_gate_changed):
		PhaseManager.post_battle_collect_gate_changed.disconnect(_on_post_battle_collect_gate_changed)

func _on_language_changed(_new_locale: String) -> void:
	if _hint_presenter != null:
		_hint_presenter.call("invalidate_status")
	_refresh_scene_hint_labels()

func _on_zone_hint_status_changed(_unused: Variant = null) -> void:
	if _hint_presenter != null:
		_hint_presenter.call("invalidate_status")
	_refresh_scene_hint_labels()

func _on_pending_reward_changed(_has_pending: bool) -> void:
	_on_zone_hint_status_changed()
	_refresh_interaction_state()
	_update_zone_hint_visuals(true)
	queue_redraw()

func _on_post_battle_collect_gate_changed(blocking: bool) -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if blocking:
		_refresh_interaction_state()
		return
	_start_zone_hint_intro()
	_refresh_interaction_state()
	queue_redraw()

func _refresh_scene_hint_labels() -> void:
	if _hint_presenter != null:
		_hint_presenter.call("refresh")
	# Refresh recalculates the labels in the rest area's local 2D grid. Once the
	# labels live in the hybrid CanvasLayer, immediately restore their projected
	# screen positions instead of leaving them at those local coordinates until
	# a later process frame.
	_sync_hybrid_hint_positions()

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
	if new_phase == PhaseManager.PROTOCOL_SELECTION:
		_enter_non_prepare_phase()
		call_deferred("_request_protocol_selection")
		return
	if _should_be_active(new_phase):
		_enter_prepare_phase()
		return
	_enter_non_prepare_phase()

func _enter_prepare_phase() -> void:
	_sync_to_target_center()
	_set_active(true, false)
	_refresh_readiness_checklist(true)
	_set_camera_owner_active(true)
	call_deferred("_ensure_camera_owner_binding")
	# The platform is centered on the player's battle-end position, so entering
	# rest must not add a second, visible move back to the center zone.
	_reset_prepare_state(false)
	if not _arrival_transition_locked:
		_start_zone_hint_intro()
	_refresh_interaction_state()
	if _start_battle_button:
		_start_battle_button.reset_state()

func _enter_non_prepare_phase() -> void:
	_zone_hint_intro_remaining = 0.0
	_set_readiness_checklist_visible(false)
	_set_active(false, false)
	_set_camera_owner_active(false)
	call_deferred("_ensure_camera_owner_binding")
	_reset_prepare_state(false)
	_refresh_interaction_state()

func _should_be_active(phase: String) -> bool:
	return phase == PhaseManager.REST

func _request_protocol_selection() -> void:
	if PhaseManager.current_state() != PhaseManager.PROTOCOL_SELECTION or _route_flow == null:
		return
	_route_flow.call("request_battle_contract")

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

func set_arrival_transition_locked(locked: bool) -> void:
	if _arrival_transition_locked == locked:
		return
	_arrival_transition_locked = locked
	if locked:
		_zone_hint_intro_remaining = 0.0
	else:
		if _active and PhaseManager.current_state() == PhaseManager.REST:
			_start_zone_hint_intro()
	_refresh_interaction_state()
	queue_redraw()

func is_arrival_transition_locked() -> bool:
	return _arrival_transition_locked

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

func _get_rest_area_board() -> BoardCellGenerator:
	return _board

func _get_reward_manager() -> BonusManager:
	return _reward_manager

func _setup_start_battle_button() -> void:
	if _start_battle_button == null:
		return
	_start_battle_button.visible = false
	_start_battle_button.monitoring = false
	_start_battle_button.monitorable = false
	_start_battle_button.set_physics_process(false)

func _on_start_battle_button_activated() -> void:
	if _route_flow != null:
		_route_flow.call("on_start_battle_button_activated")

func start_initial_battle() -> bool:
	if _route_flow == null:
		return false
	return await _route_flow.start_initial_battle()

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

func _process(delta: float) -> void:
	_ensure_camera_owner_binding()
	_sync_hybrid_hint_positions()
	_refresh_readiness_checklist()
	if not _is_interaction_enabled():
		_zone_hint_intro_remaining = 0.0
		_update_zone_hint_visibility()
		CursorManager.clear_world_state(self)
		return
	if _hint_presenter != null and bool(_hint_presenter.call("has_status_changed")):
		_refresh_scene_hint_labels()
	_update_hover_from_mouse()
	_update_auto_move()
	_update_zone_hint_intro(delta)
	_update_zone_hint_visibility()
	_refresh_cursor_state()

func _input(event: InputEvent) -> void:
	if not _is_interaction_enabled():
		return
	if event.is_echo():
		return
	var direction := _get_direction_from_input(event)
	if direction != Vector2i.ZERO:
		_handle_direction_navigation(direction)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(_get_interaction_mouse_world())
		elif event.is_action_pressed("CANCEL"):
			_handle_right_click()

func _handle_left_click(global_pos: Vector2) -> void:
	if debug_click_logs:
		print("[RestArea] left click event_pos=", global_pos, " world_mouse=", get_global_mouse_position())
	_sync_menu_open_with_ui()
	if _is_mouse_over_ui():
		return
	if _is_world_interaction_blocked():
		if debug_click_logs:
			print("[RestArea] left click ignored: world interaction blocked")
		return
	if _menu_bridge != null and not bool(_menu_bridge.call("is_navigation_allowed")):
		if debug_click_logs:
			print("[RestArea] left click ignored: zone navigation locked by submenu depth")
		return
	var zone_id := _get_zone_id_for_global_point(global_pos)
	if zone_id < 0:
		if debug_click_logs:
			print("[RestArea] left click ignored: outside 3x3 bounds")
		return
	if not _is_zone_available(zone_id):
		if debug_click_logs:
			print("[RestArea] left click ignored: zone unavailable zone_id=", zone_id)
		return
	_select_zone_for_navigation(zone_id)

func _select_zone_for_navigation(zone_id: int) -> void:
	var current_menu_open := _is_menu_open()
	if current_menu_open and zone_id == selected_zone_id and _zone_opens_interaction(zone_id):
		# Already inside this zone with its interaction open; ignore repeated click.
		if debug_click_logs:
			print("[RestArea] left click ignored: primary menu already open for zone=", zone_id)
		return
	if current_menu_open and zone_id != selected_zone_id:
		_close_rest_area_primary_menu_if_open()
		_sync_menu_open_with_ui()
	_begin_zone_move(zone_id, _zone_opens_interaction(zone_id))
	if debug_click_logs:
		print("[RestArea] left click accepted: zone_id=", zone_id, " target=", _get_zone_center_global(zone_id))
	get_viewport().set_input_as_handled()

func _get_direction_from_input(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("UP"):
		return Vector2i.UP
	if event.is_action_pressed("DOWN"):
		return Vector2i.DOWN
	if event.is_action_pressed("LEFT"):
		return Vector2i.LEFT
	if event.is_action_pressed("RIGHT"):
		return Vector2i.RIGHT
	return Vector2i.ZERO

func _handle_direction_navigation(direction: Vector2i) -> void:
	_sync_menu_open_with_ui()
	# Visible primary menus own directional input through Godot's focus chain.
	if _menu_bridge != null and bool(_menu_bridge.call("is_primary_menu_open")):
		return
	if _is_world_interaction_blocked():
		return
	if _menu_bridge != null and not bool(_menu_bridge.call("is_navigation_allowed")):
		return
	var target_zone_id := _get_adjacent_zone_id(selected_zone_id, direction)
	if target_zone_id < 0 or not _is_zone_available(target_zone_id):
		return
	_select_zone_for_navigation(target_zone_id)

func _get_adjacent_zone_id(from_zone_id: int, direction: Vector2i) -> int:
	if from_zone_id < 0 or from_zone_id >= ZONE_COUNT:
		return -1
	var from_cell := Vector2i(from_zone_id % GRID_DIM, from_zone_id / GRID_DIM)
	var target_cell := from_cell + direction
	if target_cell.x < 0 or target_cell.x >= GRID_DIM \
			or target_cell.y < 0 or target_cell.y >= GRID_DIM:
		return -1
	return target_cell.y * GRID_DIM + target_cell.x

func _handle_right_click() -> void:
	if not _is_menu_open():
		return
	if _menu_bridge != null and bool(_menu_bridge.call("handle_right_cancel")):
		_sync_menu_open_with_ui()
		get_viewport().set_input_as_handled()
		return
	rest_menu_cancelled.emit()
	_sync_menu_open_with_ui()
	_begin_zone_move(CENTER_ZONE_ID, false)
	get_viewport().set_input_as_handled()

func _is_menu_open() -> bool:
	_sync_menu_open_with_ui()
	return menu_open

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
	_sync_menu_open_with_ui()
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

func _start_return_to_center_after_battle() -> void:
	# Reuse the same rest-area navigation pipeline as normal zone clicks.
	_begin_zone_move(CENTER_ZONE_ID, false)

func _reset_prepare_state(move_player_to_center: bool) -> void:
	menu_open = false
	_stop_auto_move()
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
		_zone_hint_intro_remaining = 0.0
		_update_zone_hint_visibility()
		CursorManager.clear_world_state(self)

func _is_interaction_enabled() -> bool:
	return _active \
		and visible \
		and PhaseManager.current_state() == PhaseManager.PREPARE \
		and not _arrival_transition_locked \
		and not TaskRewardManager.is_reward_blocking_interactions()

func is_module_management_available() -> bool:
	return _is_interaction_enabled()

func _update_hover_from_mouse() -> void:
	if _is_world_interaction_blocked():
		_set_hover_zone(-1)
		return
	var zone_id := _get_zone_id_for_global_point(_get_interaction_mouse_world())
	_set_hover_zone(zone_id if _is_zone_available(zone_id) else -1)

func _get_hybrid_ground_view() -> Node:
	if not is_inside_tree():
		return null
	var views := get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	return views[0] as Node if not views.is_empty() else null

func _get_interaction_mouse_world() -> Vector2:
	var hybrid_view := _get_hybrid_ground_view()
	if hybrid_view == null:
		return get_global_mouse_position()
	return hybrid_view.call("screen_to_world_2d", get_viewport().get_mouse_position()) as Vector2

func _setup_hybrid_hint_canvas() -> void:
	if _get_hybrid_ground_view() == null or _hybrid_hint_canvas != null:
		return
	_hybrid_hint_canvas = CanvasLayer.new()
	_hybrid_hint_canvas.name = "HybridRestHintCanvas"
	_hybrid_hint_canvas.layer = 20
	add_child(_hybrid_hint_canvas)
	_hybrid_hint_zones = {
		0: get_node_or_null("MerchantHintLabel"),
		1: get_node_or_null("SmithHintLabel"),
		2: get_node_or_null("ModuleHintLabel"),
		4: get_node_or_null("BattleHintLabel"),
		6: get_node_or_null("BoardHintLabel"),
	}
	for label_variant in _hybrid_hint_zones.values():
		var label := label_variant as Label
		if label != null:
			label.reparent(_hybrid_hint_canvas, false)
	_sync_hybrid_hint_positions()

func _sync_hybrid_hint_positions() -> void:
	if _hybrid_hint_canvas == null:
		return
	var hybrid_view := _get_hybrid_ground_view()
	if hybrid_view == null:
		return
	for zone_id in _hybrid_hint_zones:
		var label := _hybrid_hint_zones[zone_id] as Label
		if label == null:
			continue
		var anchor_world := _get_zone_center_global(int(zone_id)) + zone_hint_forward_offset
		if int(zone_id) == CENTER_ZONE_ID:
			anchor_world += zone_battle_hint_extra_offset
		var screen_position := hybrid_view.call("project_world_to_screen", anchor_world) as Vector2
		screen_position = _align_service_hint_with_hybrid_prop(int(zone_id), screen_position)
		# The projected zone center is the semantic anchor. Center the whole hint on
		# it so adjacent service labels retain their intended inter-zone gap.
		label.position = (screen_position - label.size * 0.5).round()

func _align_service_hint_with_hybrid_prop(zone_id: int, projected_position: Vector2) -> Vector2:
	if zone_id == CENTER_ZONE_ID:
		return projected_position
	var prop := get_node_or_null("ZoneVisuals/HybridProp%d" % zone_id) as Sprite2D
	if prop == null or not is_instance_valid(prop):
		return projected_position
	# BillboardVisual2D has already placed the prop in canvas coordinates. Use
	# its rendered horizontal center as the label anchor so both visuals remain
	# aligned under camera/stretch canvas transforms. Preserve the label's own
	# vertical offset to keep the text below the facility art.
	var prop_screen_position := get_viewport().get_canvas_transform() * prop.global_position
	return Vector2(prop_screen_position.x, projected_position.y)

func _set_hover_zone(zone_id: int) -> void:
	if hover_zone_id == zone_id:
		return
	hover_zone_id = zone_id
	if debug_click_logs:
		print("[RestArea] hover_zone=", hover_zone_id)
	_update_zone_hint_visuals()
	_update_zone_hint_visibility()
	_refresh_zone_hover_hint()
	queue_redraw()

func _start_zone_hint_intro() -> void:
	_zone_hint_intro_remaining = maxf(zone_hint_intro_duration, 0.0)
	_update_zone_hint_visibility()

func _update_zone_hint_intro(delta: float) -> void:
	if _zone_hint_intro_remaining <= 0.0:
		return
	var previous_remaining := _zone_hint_intro_remaining
	_zone_hint_intro_remaining = maxf(_zone_hint_intro_remaining - maxf(delta, 0.0), 0.0)
	if previous_remaining > 0.0 and _zone_hint_intro_remaining <= 0.0:
		_update_zone_hint_visibility()

func _is_zone_hint_intro_active() -> bool:
	return _zone_hint_intro_remaining > 0.0

func _should_show_zone_hint_label(zone_id: int, is_center_action_hint: bool = false) -> bool:
	if _arrival_focus_zone == zone_id:
		return true
	if not _is_interaction_enabled():
		return false
	if not _is_zone_available(zone_id):
		return false
	if _are_zone_hints_suppressed_by_ui():
		return false
	if _is_zone_hint_intro_active():
		return true
	if is_center_action_hint:
		return hover_zone_id == CENTER_ZONE_ID
	if hover_zone_id == zone_id:
		return true
	return selected_zone_id == zone_id and zone_id != CENTER_ZONE_ID

func set_arrival_service_focus(zone_id: int) -> void:
	_arrival_focus_zone = zone_id
	_update_zone_hint_visuals(true)
	_update_zone_hint_visibility()
	queue_redraw()

func clear_arrival_service_focus() -> void:
	set_arrival_service_focus(-1)

func sync_selected_service_zone(zone_id: int) -> void:
	selected_zone_id = zone_id
	hover_zone_id = -1
	_update_zone_hint_visuals(true)
	_update_zone_hint_visibility()
	queue_redraw()

func _setup_readiness_checklist() -> void:
	if _readiness_canvas != null:
		return
	_readiness_canvas = CanvasLayer.new()
	_readiness_canvas.name = "RestReadinessChecklistCanvas"
	_readiness_canvas.layer = 19
	add_child(_readiness_canvas)
	_readiness_label = Label.new()
	_readiness_label.name = "ReadinessChecklist"
	_readiness_label.position = Vector2(24.0, 112.0)
	_readiness_label.custom_minimum_size = Vector2(310.0, 0.0)
	_readiness_label.add_theme_font_size_override("font_size", 14)
	_readiness_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0, 0.94))
	_readiness_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_readiness_label.add_theme_constant_override("shadow_offset_x", 1)
	_readiness_label.add_theme_constant_override("shadow_offset_y", 2)
	_readiness_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readiness_canvas.add_child(_readiness_label)
	_refresh_readiness_checklist(true)

func _refresh_readiness_checklist(force: bool = false) -> void:
	if _readiness_label == null:
		return
	var should_show := _active and PhaseManager.current_state() == PhaseManager.REST and not _are_zone_hints_suppressed_by_ui()
	_set_readiness_checklist_visible(should_show)
	if not should_show:
		return
	var lines: PackedStringArray = []
	if TaskRewardManager.is_reward_blocking_interactions() or RewardDraftRuntime.has_pending_standard_draft():
		lines.append(LocalizationManager.tr_key("ui.rest.checklist.reward", "• Reward choice pending"))
	var ui := GlobalVariables.ui
	if ui != null and is_instance_valid(ui) and ui.has_method("is_branch_selection_blocking_interactions") \
			and bool(ui.call("is_branch_selection_blocking_interactions")):
		lines.append(LocalizationManager.tr_key("ui.rest.checklist.branch", "• Evolution branch pending"))
	if InventoryData.temporary_modules.size() > 0:
		lines.append(LocalizationManager.tr_format("ui.rest.checklist.modules", {"count": InventoryData.temporary_modules.size()}, "• %d stored modules" % InventoryData.temporary_modules.size()))
	var affordable := _get_affordable_upgrade_count()
	if affordable > 0:
		lines.append(LocalizationManager.tr_format("ui.rest.checklist.upgrades", {"count": affordable}, "• %d affordable upgrades" % affordable))
	if CellEffectRuntime.has_pending_edits():
		lines.append(LocalizationManager.tr_key("ui.rest.checklist.board", "• Board changes awaiting commit"))
	if lines.is_empty():
		lines.append(LocalizationManager.tr_key("ui.rest.checklist.ready", "• Ready for the next protocol"))
	lines.resize(mini(lines.size(), 4))
	var signature := "|".join(lines)
	if force or signature != _readiness_signature:
		_readiness_signature = signature
		_readiness_label.text = LocalizationManager.tr_key("ui.rest.checklist.title", "PREPARATION") + "\n" + "\n".join(lines)

func _set_readiness_checklist_visible(should_show: bool) -> void:
	if _readiness_canvas != null:
		_readiness_canvas.visible = should_show
	if _readiness_label != null:
		_readiness_label.visible = should_show

func _are_zone_hints_suppressed_by_ui() -> bool:
	return _is_world_interaction_blocked()

func _is_mouse_over_ui() -> bool:
	var viewport := get_viewport()
	return bool(_menu_bridge.call("is_mouse_over_blocking_ui", viewport, LEGACY_BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _is_world_interaction_blocked() -> bool:
	var viewport := get_viewport()
	return bool(_menu_bridge.call("is_world_interaction_blocked", viewport, LEGACY_BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _is_inside_blocking_ui_branch(control: Control) -> bool:
	return bool(_menu_bridge.call("_is_inside_blocking_ui_branch", control, LEGACY_BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _is_mouse_inside_visible_blocking_ui_root(mouse_position: Vector2) -> bool:
	return bool(_menu_bridge.call("_is_mouse_inside_visible_blocking_ui_root", mouse_position, LEGACY_BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _control_tree_has_blocking_root_at(control: Control, mouse_position: Vector2) -> bool:
	return bool(_menu_bridge.call("_control_tree_has_blocking_root_at", control, mouse_position, LEGACY_BLOCKING_UI_ROOTS)) if _menu_bridge != null else false

func _on_rest_menu_requested(zone_id: int, _zone_center_global: Vector2) -> void:
	if _menu_bridge != null:
		_menu_bridge.call("open_zone_menu", zone_id, ZONE_ID_MERCHANT, ZONE_ID_SMITH, ZONE_ID_MODULE, ZONE_ID_BOARD_EDIT, CENTER_ZONE_ID)

func _on_rest_menu_cancelled() -> void:
	_close_rest_area_primary_menu_if_open()

func _close_rest_area_primary_menu_if_open() -> void:
	if _menu_bridge != null:
		_menu_bridge.call("close_primary_menu")

func _refresh_zone_hover_hint() -> void:
	if _menu_bridge != null:
		_menu_bridge.call("clear_hover_hint")

func _draw() -> void:
	if _get_hybrid_ground_view() != null:
		return
	if not _is_interaction_enabled():
		return
	var bounds := _get_bounds_local_rect()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	_draw_zone_grid(bounds)
	if _should_draw_selected_service_highlight():
		_draw_zone_outline(selected_zone_id, zone_selected_color, zone_outline_line_width)
	if _should_draw_hover_service_highlight():
		_draw_zone_outline(hover_zone_id, zone_hover_color, zone_outline_line_width)

func _should_draw_selected_service_highlight() -> bool:
	return _is_service_zone_highlightable(selected_zone_id)

func _should_draw_hover_service_highlight() -> bool:
	return hover_zone_id != selected_zone_id and _is_service_zone_highlightable(hover_zone_id)

func _is_service_zone_highlightable(zone_id: int) -> bool:
	return _zone_opens_interaction(zone_id)

func _draw_zone_grid(bounds: Rect2) -> void:
	var line_width := maxf(zone_grid_line_width, 0.5)
	var outer_color := zone_grid_color
	outer_color.a = clampf(outer_color.a, 0.0, 1.0)
	draw_rect(bounds, outer_color, false, line_width)
	var zone_w := bounds.size.x / float(GRID_DIM)
	var zone_h := bounds.size.y / float(GRID_DIM)
	var inner_color := outer_color
	inner_color.a = clampf(zone_grid_color.a * zone_grid_inner_alpha_multiplier, 0.0, 1.0)
	for line_idx in range(1, GRID_DIM):
		var x := bounds.position.x + float(line_idx) * zone_w
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), inner_color, line_width)
		var y := bounds.position.y + float(line_idx) * zone_h
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), inner_color, line_width)

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
	return _is_zone_available(zone_id) \
		and (bool(_zone_helper.call("zone_opens_interaction", zone_id)) if _zone_helper != null else false)

func _is_zone_available(zone_id: int) -> bool:
	if zone_id == ZONE_ID_MERCHANT:
		return PhaseManager.is_full_shop_open()
	if zone_id == ZONE_ID_BOARD_EDIT:
		return _board != null and _board.is_cell_system_visible()
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
		active
	)
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
	if _is_menu_open():
		return
	if not _emit_menu_on_arrival:
		return
	_emit_menu_on_arrival = false
	if debug_click_logs:
		print("[RestArea] open menu source=", source, " zone=", zone_id)
	rest_menu_requested.emit(zone_id, zone_center)
	_sync_menu_open_with_ui()
	queue_redraw()

func _apply_zone_move_speed_override() -> void:
	if _auto_navigation != null:
		_auto_navigation.call("configure_zone_move_speed", zone_move_speed)

func _clear_zone_move_speed_override() -> void:
	if _auto_navigation != null:
		_auto_navigation.call("clear_zone_move_speed_override")

func _refresh_cursor_state() -> void:
	if not _is_interaction_enabled():
		CursorManager.clear_world_state(self)
		return
	if _is_world_interaction_blocked():
		CursorManager.clear_world_state(self)
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
			if is_auto_moving or _is_world_interaction_blocked():
				return false
			var ui = GlobalVariables.ui
			if ui and is_instance_valid(ui) and ui.has_method("is_rest_area_zone_navigation_allowed"):
				return bool(ui.call("is_rest_area_zone_navigation_allowed"))
			return true
		return not _is_menu_open() and not _is_world_interaction_blocked()
	if not _zone_opens_interaction(zone_id):
		return false
	return bool(_menu_bridge.call("is_navigation_allowed")) if _menu_bridge != null else true
