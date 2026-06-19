extends Cell
class_name RestArea

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
var _zone_hint_status_signature := ""
var _zone_hint_visual_state := ""
@onready var _start_battle_button: StartBattleButton = get_node_or_null("StartBattleButton")
@onready var _texture_root: Node2D = get_node_or_null("Texture")
@onready var _merchant_hint_label: Label = get_node_or_null("MerchantHintLabel")
@onready var _smith_hint_label: Label = get_node_or_null("SmithHintLabel")
@onready var _module_hint_label: Label = get_node_or_null("ModuleHintLabel")
@onready var _battle_hint_label: Label = get_node_or_null("BattleHintLabel")
@onready var _reward_manager: BonusManager = get_tree().current_scene.get_node_or_null("RewardManager") as BonusManager

const GRID_DIM := 3
const ZONE_COUNT := GRID_DIM * GRID_DIM
const ZONE_ID_MERCHANT := 0
const ZONE_ID_SMITH := 1
const ZONE_ID_MODULE := 2
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
	&"BranchSelectPanel",
	&"ModuleEquipSelectionPanel",
	&"WeaponReplacementPanel",
	&"WeaponWarehousePanel"
]

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
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.connect("language_changed", Callable(self, "_on_language_changed"))
	if not InventoryData.temporary_modules_changed.is_connected(_on_zone_hint_status_changed):
		InventoryData.temporary_modules_changed.connect(_on_zone_hint_status_changed)
	if not PlayerData.weapon_list_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.weapon_list_changed.connect(_on_zone_hint_status_changed)
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

func _exit_tree() -> void:
	CursorManager.clear_world_state(self)
	if LocalizationManager and LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.disconnect("language_changed", Callable(self, "_on_language_changed"))
	if InventoryData and InventoryData.temporary_modules_changed.is_connected(_on_zone_hint_status_changed):
		InventoryData.temporary_modules_changed.disconnect(_on_zone_hint_status_changed)
	if PlayerData and PlayerData.weapon_list_changed.is_connected(_on_zone_hint_status_changed):
		PlayerData.weapon_list_changed.disconnect(_on_zone_hint_status_changed)

func _on_language_changed(_new_locale: String) -> void:
	_zone_hint_status_signature = ""
	_refresh_scene_hint_labels()

func _on_zone_hint_status_changed() -> void:
	_zone_hint_status_signature = ""
	_refresh_scene_hint_labels()

func _refresh_scene_hint_labels() -> void:
	if _merchant_hint_label:
		_merchant_hint_label.text = "%s\n%s" % [
			LocalizationManager.tr_key("ui.rest.zone.purchase.title", zone_merchant_hint_text),
			LocalizationManager.tr_key("ui.rest.zone.purchase.status", "Buy weapons and modules"),
		]
	if _smith_hint_label:
		var upgradable_count := _get_affordable_upgrade_count()
		var upgrade_status := LocalizationManager.tr_key("ui.rest.zone.upgrade.none", "No upgrades available")
		if upgradable_count > 0:
			upgrade_status = LocalizationManager.tr_format(
				"ui.rest.zone.upgrade.available",
				{"count": upgradable_count},
				"%d upgrades available" % upgradable_count
			)
		_smith_hint_label.text = "%s\n%s" % [
			LocalizationManager.tr_key("ui.rest.zone.combined_upgrade.title", zone_smith_hint_text),
			upgrade_status,
		]
	if _module_hint_label:
		var pending_count := InventoryData.temporary_modules.size()
		var module_status := LocalizationManager.tr_key("ui.rest.zone.warehouses.none", "Open weapon and module warehouses")
		if pending_count > 0:
			module_status = LocalizationManager.tr_format(
				"ui.rest.zone.warehouses.pending",
				{"count": pending_count},
				"%d stored modules" % pending_count
			)
		_module_hint_label.text = "%s\n%s" % [
			LocalizationManager.tr_key("ui.rest.zone.warehouses.title", zone_module_hint_text),
			module_status,
		]
	if _battle_hint_label:
		_battle_hint_label.text = LocalizationManager.tr_key("ui.tutorial.ctx.battle_hold", zone_battle_hold_hint_text)
	_zone_hint_status_signature = _build_zone_hint_status_signature()
	_layout_scene_hint_labels()

func _setup_scene_hint_labels() -> void:
	for label in [_merchant_hint_label, _smith_hint_label, _module_hint_label, _battle_hint_label]:
		if label == null:
			continue
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_as_relative = false
		label.z_index = zone_hint_z_index
	for zone_label in [_merchant_hint_label, _smith_hint_label, _module_hint_label]:
		if zone_label == null:
			continue
		zone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zone_label.add_theme_font_size_override("font_size", 16)
		zone_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		zone_label.add_theme_constant_override("shadow_offset_x", 1)
		zone_label.add_theme_constant_override("shadow_offset_y", 2)
	_update_zone_hint_visuals(true)
	_layout_scene_hint_labels()

func _layout_scene_hint_labels() -> void:
	_place_zone_hint_label(_merchant_hint_label, ZONE_ID_MERCHANT)
	_place_zone_hint_label(_smith_hint_label, ZONE_ID_SMITH)
	_place_zone_hint_label(_module_hint_label, ZONE_ID_MODULE)
	_place_zone_hint_label(_battle_hint_label, CENTER_ZONE_ID)

func _place_zone_hint_label(label: Label, zone_id: int) -> void:
	if label == null:
		return
	var zone_rect := _get_zone_rect_local(zone_id)
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return
	var label_size := label.size
	if label_size.x <= 0.0 or label_size.y <= 0.0:
		label_size = label.get_combined_minimum_size()
	var target_center := zone_rect.get_center() + zone_hint_forward_offset
	label.position = target_center - label_size * 0.5

func _build_zone_hint_status_signature() -> String:
	var weapon_parts: PackedStringArray = []
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon != null and is_instance_valid(weapon):
			weapon_parts.append("%d:%d" % [int(weapon.level), int(weapon.max_level)])
	return "%d|%d|%s" % [
		int(PlayerData.player_gold),
		InventoryData.temporary_modules.size(),
		",".join(weapon_parts),
	]

func _get_affordable_upgrade_count() -> int:
	var count := 0
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon) or weapon.level >= weapon.max_level:
			continue
		if PlayerData.player_gold >= _get_weapon_upgrade_cost(weapon):
			count += 1
	for module_ref in InventoryData.get_all_owned_modules():
		var module_instance := module_ref as Module
		if module_instance == null or not is_instance_valid(module_instance) or int(module_instance.module_level) >= Module.MAX_LEVEL:
			continue
		if PlayerData.player_gold >= _get_module_upgrade_cost(module_instance):
			count += 1
	return count

func _get_weapon_upgrade_cost(weapon: Weapon) -> int:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return 1
	if GlobalVariables.economy_data == null:
		return maxi(1, int(round(float(weapon_def.price) * 0.5)))
	return GlobalVariables.economy_data.get_weapon_upgrade_gold(int(weapon_def.price))

func _get_module_upgrade_cost(module_instance: Module) -> int:
	if module_instance == null or not is_instance_valid(module_instance):
		return 1
	if GlobalVariables.economy_data == null:
		return maxi(1, int(module_instance.cost))
	return GlobalVariables.economy_data.get_module_upgrade_gold(int(module_instance.cost))

func _update_zone_hint_visibility() -> void:
	var show_zone_hints := _is_interaction_enabled()
	for label in [_merchant_hint_label, _smith_hint_label, _module_hint_label, _battle_hint_label]:
		if label:
			label.visible = show_zone_hints

func _update_zone_hint_visuals(force: bool = false) -> void:
	var state := "%d|%d|%s" % [hover_zone_id, selected_zone_id, str(is_auto_moving)]
	if not force and state == _zone_hint_visual_state:
		return
	_zone_hint_visual_state = state
	_style_zone_hint(_merchant_hint_label, ZONE_ID_MERCHANT)
	_style_zone_hint(_smith_hint_label, ZONE_ID_SMITH)
	_style_zone_hint(_module_hint_label, ZONE_ID_MODULE)

func _style_zone_hint(label: Label, zone_id: int) -> void:
	if label == null:
		return
	var is_hovered := hover_zone_id == zone_id
	var is_selected := selected_zone_id == zone_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.92)
	style.border_color = Color(0.28, 0.42, 0.55, 0.95)
	if is_hovered:
		style.bg_color = Color(0.055, 0.18, 0.26, 0.96)
		style.border_color = zone_hover_color
	if is_selected:
		style.bg_color = Color(0.045, 0.20, 0.13, 0.96)
		style.border_color = zone_selected_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_color_override(
		"font_color",
		Color(0.82, 1.0, 0.88) if is_selected else Color(0.86, 0.95, 1.0)
	)

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

func _setup_start_battle_button() -> void:
	if _start_battle_button == null:
		return
	if not _start_battle_button.is_connected("activated", Callable(self, "_on_start_battle_button_activated")):
		_start_battle_button.connect("activated", Callable(self, "_on_start_battle_button_activated"))
	_snap_start_battle_button()

func _on_start_battle_button_activated() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if TaskRewardManager.is_reward_blocking_interactions():
		return
	if _route_selection_pending:
		return
	_clear_zone4_hold_move_boost()
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_temporary_module_settlement"):
		ui.call(
			"request_temporary_module_settlement",
			Callable(self, "_continue_start_battle"),
			Callable(self, "_on_battle_start_cancelled")
		)
		return
	_continue_start_battle()

func _on_battle_start_cancelled() -> void:
	_clear_zone4_hold_move_boost()
	_reset_zone4_hold()
	if _start_battle_button:
		_start_battle_button.reset_state()

func _continue_start_battle() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE or _route_selection_pending:
		return
	_route_selection_pending = true
	_on_route_confirmed("normal")

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
		if not TaskRewardManager.begin_battle_snapshot():
			if _start_battle_button:
				_start_battle_button.reset_state()
			return
		if PlayerData.player != null and is_instance_valid(PlayerData.player):
			if PlayerData.player.has_method("set_restarea_camera_control_enabled"):
				PlayerData.player.call("set_restarea_camera_control_enabled", false)
		if GlobalVariables.enemy_spawner:
			GlobalVariables.enemy_spawner.start_timer()
		PhaseManager.enter_battle()
		if PlayerData.player != null and is_instance_valid(PlayerData.player):
			if PlayerData.player.has_method("_update_vision_effect"):
				PlayerData.player.call_deferred("_update_vision_effect")
			if PlayerData.player.has_method("force_recover_battle_camera_zoom"):
				PlayerData.player.call_deferred("force_recover_battle_camera_zoom")
		_clear_zone4_hold_move_boost()
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
		if ui.has_method("is_branch_selection_blocking_interactions") and bool(ui.call("is_branch_selection_blocking_interactions")):
			_route_selection_pending = false
			if _start_battle_button:
				_start_battle_button.reset_state()
			return
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
	_ensure_camera_owner_binding()
	if not _is_interaction_enabled():
		_reset_zone4_hold()
		CursorManager.clear_world_state(self)
		return
	var status_signature := _build_zone_hint_status_signature()
	if status_signature != _zone_hint_status_signature:
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
	if menu_open and zone_id == selected_zone_id and _zone_opens_primary_menu(zone_id):
		# Already inside this zone with its primary menu open; ignore repeated click.
		if debug_click_logs:
			print("[RestArea] left click ignored: primary menu already open for zone=", zone_id)
		return
	if menu_open and zone_id != selected_zone_id:
		_close_rest_area_primary_menu_if_open()
		menu_open = false
	_begin_zone_move(zone_id, _zone_opens_primary_menu(zone_id))
	if debug_click_logs:
		print("[RestArea] left click accepted: zone_id=", zone_id, " target=", _get_zone_center_global(zone_id))
	get_viewport().set_input_as_handled()

func _handle_right_click() -> void:
	_sync_menu_open_with_ui()
	if not menu_open:
		return
	var ui = GlobalVariables.ui
	var rest_ui_controller = ui.rest_area_ui_controller if ui and is_instance_valid(ui) else null
	if rest_ui_controller != null:
		var consumed := bool(rest_ui_controller.handle_right_cancel())
		if consumed:
			_sync_menu_open_with_ui()
			get_viewport().set_input_as_handled()
			return
	menu_open = false
	rest_menu_cancelled.emit()
	_begin_zone_move(CENTER_ZONE_ID, false)
	get_viewport().set_input_as_handled()

func _sync_menu_open_with_ui() -> void:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	var rest_ui_controller = ui.rest_area_ui_controller
	if rest_ui_controller == null:
		return
	var ui_menu_visible := bool(rest_ui_controller.is_menu_visible())
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
	_apply_zone_move_speed_override()
	if PlayerData.player != null and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("start_auto_nav"):
		PlayerData.player.call("start_auto_nav", player_move_target_global)
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
	var arrived_now := false
	if PlayerData.player.has_method("is_auto_nav_active"):
		arrived_now = not bool(PlayerData.player.call("is_auto_nav_active"))
	else:
		arrived_now = PlayerData.player.global_position.distance_to(player_move_target_global) <= zone_reach_distance
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
	_clear_zone_move_speed_override()
	_clear_zone4_hold_move_boost()
	if PlayerData.player != null and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("stop_auto_nav"):
		PlayerData.player.call("stop_auto_nav")

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
	if viewport == null:
		return false
	if _is_mouse_inside_visible_blocking_ui_root(viewport.get_mouse_position()):
		return true
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
	var current: Node = control
	while current != null:
		if BLOCKING_UI_ROOTS.has(StringName(current.name)):
			return true
		current = current.get_parent()
	return false

func _is_mouse_inside_visible_blocking_ui_root(mouse_position: Vector2) -> bool:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return false
	var gui := ui.get_node_or_null("GUI") as Control
	if gui == null:
		return false
	return _control_tree_has_blocking_root_at(gui, mouse_position)

func _control_tree_has_blocking_root_at(control: Control, mouse_position: Vector2) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	if BLOCKING_UI_ROOTS.has(StringName(control.name)) and control.get_global_rect().has_point(mouse_position):
		return true
	for child in control.get_children():
		var child_control := child as Control
		if child_control != null and _control_tree_has_blocking_root_at(child_control, mouse_position):
			return true
	return false

func _on_rest_menu_requested(zone_id: int, _zone_center_global: Vector2) -> void:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if ui.rest_area_ui_controller == null:
		return
	if zone_id == ZONE_ID_MERCHANT:
		ui.rest_area_ui_controller.open_menu(&"purchase")
		return
	if zone_id == ZONE_ID_SMITH:
		ui.rest_area_ui_controller.open_menu(&"upgrade")
		return
	if zone_id == ZONE_ID_MODULE:
		ui.rest_area_ui_controller.open_menu(&"warehouse")
		return

func _on_rest_menu_cancelled() -> void:
	_close_rest_area_primary_menu_if_open()

func _close_rest_area_primary_menu_if_open() -> void:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if ui.rest_area_ui_controller:
		ui.rest_area_ui_controller.close_primary_menu()
		return

func _refresh_zone_hover_hint() -> void:
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	# Rest-area zone hints are now authored directly in the scene.
	if ui.has_method("clear_rest_area_hover_hint"):
		ui.call("clear_rest_area_hover_hint")

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
	return zone_id == ZONE_ID_MERCHANT or zone_id == ZONE_ID_SMITH or zone_id == ZONE_ID_MODULE

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
	if not _zone_opens_primary_menu(zone_id):
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
	if _zone4_hold_boost_active:
		return
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("apply_move_speed_mul"):
		return
	player.call("apply_move_speed_mul", ZONE4_HOLD_BOOST_SOURCE_ID, maxf(zone4_hold_move_boost_mul, 0.05))
	_zone4_hold_boost_active = true

func _clear_zone4_hold_move_boost() -> void:
	if not _zone4_hold_boost_active:
		return
	var player: Node = PlayerData.player
	if player != null and is_instance_valid(player) and player.has_method("remove_move_speed_mul"):
		player.call("remove_move_speed_mul", ZONE4_HOLD_BOOST_SOURCE_ID)
	_zone4_hold_boost_active = false

func _apply_zone_move_speed_override() -> void:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("configure_auto_nav_speed_mul"):
		return
	var base_speed := 1.0
	if "player_speed" in PlayerData and "player_bonus_speed" in PlayerData:
		base_speed = maxf(float(PlayerData.player_speed) + float(PlayerData.player_bonus_speed), 1.0)
	var target_speed := maxf(zone_move_speed, 1.0)
	var speed_mul := clampf(target_speed / base_speed, 0.1, 8.0)
	player.call("configure_auto_nav_speed_mul", speed_mul)

func _clear_zone_move_speed_override() -> void:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("configure_auto_nav_speed_mul"):
		player.call("configure_auto_nav_speed_mul", 1.0)

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
	if not _zone_opens_primary_menu(zone_id):
		return false
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("is_rest_area_zone_navigation_allowed"):
		return bool(ui.call("is_rest_area_zone_navigation_allowed"))
	return true
