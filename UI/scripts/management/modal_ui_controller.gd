extends RefCounted
class_name ModalUiController

const BRANCH_SELECT_PANEL_PATH := "res://UI/scenes/branch_select_panel.tscn"
const MODULE_EQUIP_SELECTION_PANEL_PATH := "res://UI/scenes/module_equip_selection_panel.tscn"
const ROUTE_SELECTION_PANEL_PATH := "res://UI/scenes/route_selection_panel.tscn"
const REWARD_SELECTION_PANEL_PATH := "res://UI/scenes/reward_selection_panel.tscn"
const WEAPON_REPLACEMENT_PANEL_PATH := "res://UI/scenes/weapon_replacement_panel.tscn"
const WEAPON_WAREHOUSE_PANEL_PATH := "res://UI/scenes/weapon_warehouse_panel.tscn"
const GAME_OVER_VIEW_PATH := "res://UI/scenes/components/game_over_view.tscn"
const CONTROLS_HINT_VIEW_PATH := "res://UI/scenes/components/controls_hint_view.tscn"
const BOARD_EDIT_PANEL_PATH := "res://UI/scenes/board_edit_panel.tscn"
const CELL_MANAGEMENT_PANEL_SCRIPT := preload("res://UI/scripts/cell_management_panel.gd")

var owner_ui: UI
var gui_root: Control
var branch_select_panel: BranchSelectPanel
var module_equip_selection_panel: ModuleEquipSelectionPanel
var route_selection_panel: RouteSelectionPanel
var reward_selection_panel: RewardSelectionPanel
var weapon_replacement_panel: WeaponReplacementPanel
var weapon_warehouse_panel: WeaponWarehousePanel
var game_over_view
var controls_hint_view
var board_edit_panel: Control
var cell_management_panel: Control

static func is_cancel_input(event: InputEvent) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("CANCEL") or event.is_action_pressed("ESC"):
		return true
	var mouse_button := event as InputEventMouseButton
	return mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT

func bind(ui: UI, root: Control) -> void:
	owner_ui = ui
	gui_root = root
	sync_state_from_owner()

func ensure_branch_select_panel() -> bool:
	if branch_select_panel != null and is_instance_valid(branch_select_panel):
		return true
	var panel_scene := load(BRANCH_SELECT_PANEL_PATH) as PackedScene
	branch_select_panel = panel_scene.instantiate() as BranchSelectPanel if panel_scene else null
	if branch_select_panel == null:
		push_warning("Failed to create BranchSelectPanel.")
		return false
	gui_root.add_child(branch_select_panel)
	branch_select_panel.visible = false
	var callback := Callable(owner_ui, "_on_branch_selected")
	if not branch_select_panel.is_connected("branch_selected", callback):
		branch_select_panel.connect("branch_selected", callback)
	_sync_public_fields_to_owner()
	return true

func ensure_module_equip_selection_panel() -> bool:
	if module_equip_selection_panel != null and is_instance_valid(module_equip_selection_panel):
		return true
	var panel_scene := load(MODULE_EQUIP_SELECTION_PANEL_PATH) as PackedScene
	module_equip_selection_panel = panel_scene.instantiate() as ModuleEquipSelectionPanel if panel_scene else null
	if module_equip_selection_panel == null:
		push_warning("Failed to create ModuleEquipSelectionPanel.")
		return false
	gui_root.add_child(module_equip_selection_panel)
	module_equip_selection_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_route_selection_panel() -> bool:
	if route_selection_panel != null and is_instance_valid(route_selection_panel):
		return true
	var panel_scene := load(ROUTE_SELECTION_PANEL_PATH) as PackedScene
	route_selection_panel = panel_scene.instantiate() as RouteSelectionPanel if panel_scene else null
	if route_selection_panel == null:
		push_warning("Failed to create RouteSelectionPanel.")
		return false
	gui_root.add_child(route_selection_panel)
	route_selection_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_reward_selection_panel() -> bool:
	if reward_selection_panel != null and is_instance_valid(reward_selection_panel):
		return true
	var panel_scene := load(REWARD_SELECTION_PANEL_PATH) as PackedScene
	reward_selection_panel = panel_scene.instantiate() as RewardSelectionPanel if panel_scene else null
	if reward_selection_panel == null:
		push_warning("Failed to create RewardSelectionPanel.")
		return false
	gui_root.add_child(reward_selection_panel)
	reward_selection_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_weapon_replacement_panel() -> bool:
	if weapon_replacement_panel != null and is_instance_valid(weapon_replacement_panel):
		return true
	var panel_scene := load(WEAPON_REPLACEMENT_PANEL_PATH) as PackedScene
	weapon_replacement_panel = panel_scene.instantiate() as WeaponReplacementPanel if panel_scene else null
	if weapon_replacement_panel == null:
		push_warning("Failed to create WeaponReplacementPanel.")
		return false
	gui_root.add_child(weapon_replacement_panel)
	weapon_replacement_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_weapon_warehouse_panel() -> bool:
	if weapon_warehouse_panel != null and is_instance_valid(weapon_warehouse_panel):
		return true
	var panel_scene := load(WEAPON_WAREHOUSE_PANEL_PATH) as PackedScene
	weapon_warehouse_panel = panel_scene.instantiate() as WeaponWarehousePanel if panel_scene else null
	if weapon_warehouse_panel == null:
		push_warning("Failed to create WeaponWarehousePanel.")
		return false
	gui_root.add_child(weapon_warehouse_panel)
	_sync_public_fields_to_owner()
	return true

func ensure_board_edit_panel() -> bool:
	if board_edit_panel != null and is_instance_valid(board_edit_panel):
		return true
	var panel_scene := load(BOARD_EDIT_PANEL_PATH) as PackedScene
	board_edit_panel = panel_scene.instantiate() as Control if panel_scene else null
	if board_edit_panel == null:
		push_warning("Failed to create BoardEditPanel.")
		return false
	gui_root.add_child(board_edit_panel)
	board_edit_panel.visible = false
	if board_edit_panel.has_signal("close_requested"):
		var callback := Callable(owner_ui, "_on_board_edit_panel_close_requested")
		if not board_edit_panel.is_connected("close_requested", callback):
			board_edit_panel.connect("close_requested", callback)
	_sync_public_fields_to_owner()
	return true

func ensure_cell_management_panel() -> bool:
	if cell_management_panel != null and is_instance_valid(cell_management_panel):
		return true
	cell_management_panel = CELL_MANAGEMENT_PANEL_SCRIPT.new() as Control
	cell_management_panel.name = "CellManagementPanel"
	gui_root.add_child(cell_management_panel)
	cell_management_panel.visible = false
	if cell_management_panel.has_method("bind"):
		cell_management_panel.call("bind", owner_ui)
	if cell_management_panel.has_signal("board_management_requested"):
		var board_callback := Callable(owner_ui, "_on_cell_management_board_requested")
		if not cell_management_panel.is_connected("board_management_requested", board_callback):
			cell_management_panel.connect("board_management_requested", board_callback)
	_sync_public_fields_to_owner()
	return true

func open_board_edit_panel() -> bool:
	if owner_ui == null:
		return false
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return false
	if TaskRewardManager.is_reward_blocking_interactions():
		owner_ui.show_item_message("Choose objective rewards first.", 1.6)
		return false
	if not ensure_board_edit_panel():
		return false
	var opened := bool(board_edit_panel.open_panel(owner_ui._find_board()))
	if owner_ui.rest_area_ui_controller != null:
		owner_ui.rest_area_ui_controller.sync_secondary_menu_dim_overlay()
	return opened

func request_close_board_edit_panel() -> bool:
	if board_edit_panel == null or not is_instance_valid(board_edit_panel) or not board_edit_panel.visible:
		return false
	close_board_edit_panel_without_confirmation()
	return true

func close_board_edit_panel_without_confirmation() -> void:
	if owner_ui == null:
		return
	if board_edit_panel and is_instance_valid(board_edit_panel):
		board_edit_panel.close_panel()
	if owner_ui.rest_area_ui_controller != null and owner_ui.rest_area_ui_controller.primary_menu_id == &"board_edit":
		owner_ui.rest_area_ui_controller.back_to_board_primary_menu()
		return
	if owner_ui.rest_area_ui_controller != null:
		owner_ui.rest_area_ui_controller.cancel_menu_level()

func open_cell_management_panel(mode: StringName = &"task") -> bool:
	if owner_ui == null:
		return false
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return false
	if TaskRewardManager.is_reward_blocking_interactions():
		owner_ui.show_item_message("Choose objective rewards first.", 1.6)
		return false
	if not ensure_cell_management_panel():
		return false
	var opened := bool(cell_management_panel.call("open_panel", owner_ui._find_board(), mode))
	if owner_ui.rest_area_ui_controller != null:
		owner_ui.rest_area_ui_controller.sync_secondary_menu_dim_overlay()
	return opened

func request_close_cell_management_panel() -> bool:
	if owner_ui == null:
		return false
	if cell_management_panel == null or not is_instance_valid(cell_management_panel) or not cell_management_panel.visible:
		return false
	cell_management_panel.call("close_panel")
	if owner_ui.rest_area_ui_controller != null and owner_ui.rest_area_ui_controller.primary_menu_id == &"board_edit":
		owner_ui.rest_area_ui_controller.back_to_board_primary_menu()
	elif owner_ui.rest_area_ui_controller != null:
		owner_ui.rest_area_ui_controller.cancel_menu_level()
	return true

func is_modal_open() -> bool:
	sync_state_from_owner()
	for panel in _selection_modal_panels():
		if _panel_is_modal_open(panel):
			return true
	return false

func is_world_interaction_blocking_modal_open() -> bool:
	return is_modal_open()

func cancel_visible_modal() -> bool:
	sync_state_from_owner()
	for panel in _selection_modal_panels():
		if not _panel_is_modal_open(panel):
			continue
		if panel.has_method("cancel_visible_modal"):
			panel.call("cancel_visible_modal")
		return true
	return false

func open_cell_board_management() -> void:
	if owner_ui == null:
		return
	if cell_management_panel and is_instance_valid(cell_management_panel):
		cell_management_panel.call("close_panel")
	if owner_ui.rest_area_ui_controller != null:
		owner_ui.rest_area_ui_controller.open_cell_grid_panel()
	else:
		open_board_edit_panel()

func ensure_game_over_view() -> bool:
	if game_over_view != null and is_instance_valid(game_over_view):
		return true
	var view_scene := load(GAME_OVER_VIEW_PATH) as PackedScene
	game_over_view = view_scene.instantiate() if view_scene else null
	if game_over_view == null:
		push_warning("Failed to create GameOverView.")
		return false
	gui_root.add_child(game_over_view)
	game_over_view.bind(owner_ui)
	_sync_public_fields_to_owner()
	return true

func show_game_over() -> void:
	if owner_ui == null:
		return
	if not ensure_game_over_view():
		return
	owner_ui.pause_menu_root.visible = false
	owner_ui._init_rest_area_ui_controller()
	owner_ui.rest_area_ui_controller.set_management_root_visible(&"purchase", false)
	owner_ui.rest_area_ui_controller.set_management_root_visible(&"upgrade", false)
	owner_ui.rest_area_ui_controller.set_management_root_visible(&"warehouse", false)
	if game_over_view != null and is_instance_valid(game_over_view):
		game_over_view.show_game_over()
		owner_ui.get_tree().paused = true
	_sync_public_fields_to_owner()

func ensure_controls_hint_view() -> bool:
	if controls_hint_view != null and is_instance_valid(controls_hint_view):
		return true
	var view_scene := load(CONTROLS_HINT_VIEW_PATH) as PackedScene
	controls_hint_view = view_scene.instantiate() if view_scene else null
	if controls_hint_view == null:
		push_warning("Failed to create ControlsHintView.")
		return false
	gui_root.add_child(controls_hint_view)
	_sync_public_fields_to_owner()
	return true

func layout_controls_hint_panel(viewport_size: Vector2) -> void:
	if controls_hint_view != null and is_instance_valid(controls_hint_view):
		controls_hint_view.layout_for_viewport(viewport_size)

func update_controls_guide_for_phase(phase: String, primary_open: bool, secondary_menu_context: StringName = &"") -> void:
	if controls_hint_view != null and is_instance_valid(controls_hint_view):
		controls_hint_view.refresh_for_phase(phase, primary_open, secondary_menu_context)

func refresh_controls_hint_visibility(primary_open: bool, secondary_menu_context: StringName = &"") -> void:
	if controls_hint_view != null and is_instance_valid(controls_hint_view):
		controls_hint_view.refresh_visibility(primary_open, secondary_menu_context)

func sync_state_from_owner() -> void:
	if owner_ui == null:
		return
	branch_select_panel = owner_ui.branch_select_panel
	module_equip_selection_panel = owner_ui.module_equip_selection_panel
	route_selection_panel = owner_ui.route_selection_panel
	reward_selection_panel = owner_ui.reward_selection_panel
	weapon_replacement_panel = owner_ui.weapon_replacement_panel
	weapon_warehouse_panel = owner_ui.weapon_warehouse_panel
	game_over_view = owner_ui.game_over_view
	controls_hint_view = owner_ui.controls_hint_view
	board_edit_panel = owner_ui.board_edit_panel
	cell_management_panel = owner_ui.cell_management_panel

func _selection_modal_panels() -> Array:
	return [
		branch_select_panel,
		weapon_replacement_panel,
		route_selection_panel,
		reward_selection_panel,
		module_equip_selection_panel,
	]

func _panel_is_modal_open(panel) -> bool:
	if panel == null or not is_instance_valid(panel):
		return false
	if panel.has_method("is_modal_open"):
		return bool(panel.call("is_modal_open"))
	return bool(panel.get("visible"))

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui.branch_select_panel = branch_select_panel
	owner_ui.module_equip_selection_panel = module_equip_selection_panel
	owner_ui.route_selection_panel = route_selection_panel
	owner_ui.reward_selection_panel = reward_selection_panel
	owner_ui.weapon_replacement_panel = weapon_replacement_panel
	owner_ui.weapon_warehouse_panel = weapon_warehouse_panel
	owner_ui.game_over_view = game_over_view
	owner_ui.controls_hint_view = controls_hint_view
	owner_ui.board_edit_panel = board_edit_panel
	owner_ui.cell_management_panel = cell_management_panel
