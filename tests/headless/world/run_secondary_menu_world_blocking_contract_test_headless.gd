extends Node

const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")

var _failures: PackedStringArray = PackedStringArray()
var _ui: UI
var _rest_area: RestArea
var _board: BoardCellGenerator

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	print("SecondaryMenuWorldBlockingContractTest: START")
	get_tree().current_scene = self
	_reset_global_state()
	await _setup_scene()
	if not _failures.is_empty():
		_finish()
		return

	await _assert_hover_recovers("initial")
	await _test_purchase_secondary_blocks_hover()
	await _test_upgrade_secondary_blocks_hover()
	await _test_warehouse_secondary_blocks_hover()
	await _test_board_edit_secondary_blocks_hover()
	await _test_task_management_secondary_blocks_hover()
	await _test_confirmation_modal_blocks_hover()
	await _assert_hover_recovers("after closing blocking UI")
	_finish()

func _setup_scene() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_record("failed to instantiate player")
		return
	get_tree().root.add_child(player)
	await get_tree().process_frame

	_ui = UI_SCENE.instantiate() as UI
	if _ui == null:
		_record("failed to instantiate UI")
		return
	get_tree().root.add_child(_ui)

	_board = BoardCellGenerator.new()
	_board.name = "Board"
	_board.cell_scene = CELL_SCENE
	_board.auto_assign_enemy_on_battle = false
	for _index in range(9):
		_board.initial_cell_profiles.append(CellProfile.new())
	add_child(_board)

	_rest_area = REST_AREA_SCENE.instantiate() as RestArea
	_rest_area.board_path = NodePath("../Board")
	_rest_area.add_to_group("rest_area")
	add_child(_rest_area)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	_rest_area._set_camera_owner_active(false)
	await get_tree().process_frame

	if not _rest_area.is_active():
		_record("rest area is not active in prepare phase")

func _test_purchase_secondary_blocks_hover() -> void:
	await _open_purchase_secondary()
	await _assert_unified_secondary_dim_visible("purchase secondary")
	_assert_controls_hint_context(
		"purchase secondary",
		"ui.tutorial.state.secondary.purchase",
		"Current: Shop",
		[
			"ui.tutorial.panel.secondary.purchase.line1",
			"ui.tutorial.panel.secondary.purchase.line2",
			"ui.tutorial.panel.secondary.purchase.line3",
		]
	)
	await _assert_world_blocked_and_hover_cleared("purchase secondary")
	await _close_purchase_secondary()
	await _assert_unified_secondary_dim_hidden("purchase secondary closed")
	await _assert_hover_recovers("purchase secondary closed")

func _test_warehouse_secondary_blocks_hover() -> void:
	await _open_warehouse_secondary()
	await _assert_unified_secondary_dim_visible("warehouse secondary")
	_assert_controls_hint_context(
		"warehouse secondary",
		"ui.tutorial.state.secondary.warehouse",
		"Current: Warehouse",
		[
			"ui.tutorial.panel.secondary.warehouse.line1",
			"ui.tutorial.panel.secondary.warehouse.line2",
			"ui.tutorial.panel.secondary.warehouse.line3",
		]
	)
	await _assert_world_blocked_and_hover_cleared("warehouse secondary")
	await _close_warehouse_secondary()
	await _assert_unified_secondary_dim_hidden("warehouse secondary closed")
	await _assert_hover_recovers("warehouse secondary closed")

func _test_upgrade_secondary_blocks_hover() -> void:
	await _open_upgrade_secondary()
	await _assert_unified_secondary_dim_visible("upgrade secondary")
	_assert_controls_hint_context(
		"upgrade secondary",
		"ui.tutorial.state.secondary.upgrade",
		"Current: Upgrade",
		[
			"ui.tutorial.panel.secondary.upgrade.line1",
			"ui.tutorial.panel.secondary.upgrade.line2",
			"ui.tutorial.panel.secondary.upgrade.line3",
		]
	)
	await _assert_world_blocked_and_hover_cleared("upgrade secondary")
	await _close_upgrade_secondary()
	await _assert_unified_secondary_dim_hidden("upgrade secondary closed")
	await _assert_hover_recovers("upgrade secondary closed")

func _test_board_edit_secondary_blocks_hover() -> void:
	await _open_board_edit_secondary()
	await _assert_unified_secondary_dim_visible("board edit secondary")
	_assert_controls_hint_context(
		"board edit secondary",
		"ui.tutorial.state.secondary.grid_management",
		"Current: Grid Management",
		[
			"ui.tutorial.panel.secondary.grid_management.line1",
			"ui.tutorial.panel.secondary.grid_management.line2",
			"ui.tutorial.panel.secondary.grid_management.line3",
			"ui.tutorial.panel.secondary.grid_management.line4",
		]
	)
	await _assert_world_blocked_and_hover_cleared("board edit secondary")
	await _close_board_edit_secondary()
	await _assert_unified_secondary_dim_hidden("board edit secondary closed")
	await _assert_hover_recovers("board edit secondary closed")

func _test_task_management_secondary_blocks_hover() -> void:
	await _open_task_management_secondary()
	await _assert_unified_secondary_dim_visible("task management secondary")
	_assert_controls_hint_context(
		"task management secondary",
		"ui.tutorial.state.secondary.task_management",
		"Current: Task Management",
		[
			"ui.tutorial.panel.secondary.task_management.line1",
			"ui.tutorial.panel.secondary.task_management.line2",
			"ui.tutorial.panel.secondary.task_management.line3",
			"ui.tutorial.panel.secondary.task_management.line4",
		]
	)
	await _assert_world_blocked_and_hover_cleared("task management secondary")
	await _close_task_management_secondary()
	await _assert_unified_secondary_dim_hidden("task management secondary closed")
	await _assert_hover_recovers("task management secondary closed")

func _test_confirmation_modal_blocks_hover() -> void:
	_ui.request_confirmation(
		&"world_blocking_contract_modal",
		"Blocking Modal",
		"Visible confirmation modals must block RestArea world hover.",
		"Continue",
		"Cancel",
		Callable(),
		Callable(),
		true,
		Vector2i(420, 180)
	)
	await get_tree().process_frame
	await _assert_world_blocked_and_hover_cleared("blocking confirmation modal")
	_ui.cancel_visible_dialog()
	await get_tree().process_frame

func _open_purchase_secondary() -> void:
	_ui.rest_area_ui_controller.open_menu(&"purchase")
	_rest_area.selected_zone_id = 0
	_ui.rest_area_ui_controller.open_purchase_weapon_panel()
	await get_tree().create_timer(0.25).timeout

func _close_purchase_secondary() -> void:
	_ui.rest_area_ui_controller.close_purchase_panel()
	_ui.rest_area_ui_controller.close_primary_menu()
	await get_tree().process_frame

func _open_warehouse_secondary() -> void:
	_ui.rest_area_ui_controller.open_menu(&"warehouse")
	_rest_area.selected_zone_id = 2
	_ui.rest_area_ui_controller.open_warehouse_management_panel()
	await get_tree().create_timer(0.25).timeout

func _close_warehouse_secondary() -> void:
	_ui.rest_area_ui_controller.close_warehouse_panel()
	_ui.rest_area_ui_controller.close_primary_menu()
	await get_tree().process_frame

func _open_upgrade_secondary() -> void:
	_ui.rest_area_ui_controller.open_menu(&"upgrade")
	_rest_area.selected_zone_id = 1
	_ui.rest_area_ui_controller.open_upgrade_panel()
	await get_tree().create_timer(0.25).timeout

func _close_upgrade_secondary() -> void:
	_ui.rest_area_ui_controller.close_upgrade_panel()
	_ui.rest_area_ui_controller.close_primary_menu()
	await get_tree().process_frame

func _open_board_edit_secondary() -> void:
	_ui.rest_area_ui_controller.open_board_edit_panel()
	_rest_area.selected_zone_id = 6
	_ui.rest_area_ui_controller.open_cell_grid_panel()
	await get_tree().create_timer(0.25).timeout

func _close_board_edit_secondary() -> void:
	_ui.request_close_board_edit_panel(false)
	_ui.rest_area_ui_controller.close_primary_menu()
	await get_tree().process_frame

func _open_task_management_secondary() -> void:
	_ui.rest_area_ui_controller.open_board_edit_panel()
	_rest_area.selected_zone_id = 6
	_ui.rest_area_ui_controller.open_cell_task_panel()
	await get_tree().create_timer(0.25).timeout

func _close_task_management_secondary() -> void:
	_ui.request_close_cell_management_panel()
	_ui.rest_area_ui_controller.close_primary_menu()
	await get_tree().process_frame

func _assert_world_blocked_and_hover_cleared(label: String) -> void:
	if not _ui.is_world_interaction_blocked():
		_record("%s did not report ui.is_world_interaction_blocked()" % label)
		return
	if not _rest_area._is_world_interaction_blocked():
		_record("%s did not report RestArea._is_world_interaction_blocked()" % label)
		return
	await _assert_blocked_click_is_ignored(label)
	await _assert_blocked_hold_start_is_ignored(label)
	_rest_area.hover_zone_id = 0
	_rest_area._update_hover_from_mouse()
	await get_tree().process_frame
	if _rest_area.hover_zone_id != -1:
		_record("%s allowed RestArea hover_zone_id=%d" % [label, _rest_area.hover_zone_id])

func _assert_unified_secondary_dim_visible(label: String) -> void:
	var overlays := _ui.gui_root.find_children("SecondaryMenuDimOverlay", "ColorRect", false, false)
	if overlays.size() != 1:
		_record("%s expected one unified secondary dim overlay, got %d" % [label, overlays.size()])
		return
	var overlay := overlays[0] as ColorRect
	if overlay == null:
		_record("%s unified secondary dim overlay is not a ColorRect" % label)
		return
	if overlay.get_parent() != _ui.gui_root:
		_record("%s unified secondary dim overlay is not owned by GUI root" % label)
		return
	if not overlay.visible:
		_record("%s unified secondary dim overlay is hidden" % label)
		return
	if not overlay.color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.42)):
		_record("%s unified secondary dim overlay has unexpected color %s" % [label, str(overlay.color)])
		return
	if overlay.get_index() != 0:
		_record("%s unified secondary dim overlay should stay behind menu panels" % label)

func _assert_unified_secondary_dim_hidden(label: String) -> void:
	var overlay := _ui.gui_root.get_node_or_null("SecondaryMenuDimOverlay") as ColorRect
	if overlay != null and overlay.visible:
		_record("%s left unified secondary dim overlay visible" % label)

func _assert_controls_hint_context(label: String, title_key: String, title_fallback: String, body_keys: Array) -> void:
	var panel := _ui.controls_hint_view as Control
	if panel == null or not is_instance_valid(panel):
		_record("%s has no controls hint view" % label)
		return
	if not panel.visible:
		_record("%s hid the controls hint view" % label)
		return
	var title := panel.get_node_or_null("Title") as Label
	var body := panel.get_node_or_null("Body") as Label
	if title == null or body == null:
		_record("%s controls hint view is missing labels" % label)
		return
	var expected_title := LocalizationManager.tr_key(title_key, title_fallback)
	if title.text != expected_title:
		_record("%s controls hint title expected '%s', got '%s'" % [label, expected_title, title.text])
	for key in body_keys:
		var expected_line := LocalizationManager.tr_key(str(key), "")
		if expected_line == "":
			_record("%s missing localization for %s" % [label, str(key)])
			continue
		if not body.text.contains(expected_line):
			_record("%s controls hint body missing '%s' in '%s'" % [label, expected_line, body.text])

func _assert_blocked_click_is_ignored(label: String) -> void:
	var selected_before := _rest_area.selected_zone_id
	var rest_menu_visible_before := _ui.is_rest_area_menu_visible()
	_rest_area._handle_left_click(_rest_area._get_zone_center_global(1))
	await get_tree().process_frame
	if _rest_area.selected_zone_id != selected_before:
		_record("%s allowed blocked click to change selected_zone_id from %d to %d" % [
			label,
			selected_before,
			_rest_area.selected_zone_id,
		])
	if rest_menu_visible_before != _ui.is_rest_area_menu_visible():
		_record("%s allowed blocked click to change menu visibility from %s to %s" % [
			label,
			str(rest_menu_visible_before),
			str(_ui.is_rest_area_menu_visible()),
		])

func _assert_blocked_hold_start_is_ignored(label: String) -> void:
	var selected_before := _rest_area.selected_zone_id
	var hover_before := _rest_area.hover_zone_id
	var route_pending_before := _rest_area._is_route_selection_pending()
	_rest_area.selected_zone_id = 4
	_rest_area.hover_zone_id = 4
	_rest_area._set_route_selection_pending(false)
	_rest_area._zone4_hold_elapsed = _rest_area.zone4_hold_duration * 0.5
	if _rest_area._is_zone4_hold_available():
		_record("%s allowed center hold-start while world interaction is blocked" % label)
	_rest_area._update_zone4_hold(_rest_area.zone4_hold_duration)
	await get_tree().process_frame
	if _rest_area._zone4_hold_elapsed > 0.0:
		_record("%s kept center hold progress while world interaction is blocked" % label)
	_rest_area.selected_zone_id = selected_before
	_rest_area.hover_zone_id = hover_before
	_rest_area._set_route_selection_pending(route_pending_before)

func _assert_hover_recovers(label: String) -> void:
	if _ui.is_world_interaction_blocked():
		_record("%s left ui.is_world_interaction_blocked() true" % label)
		return
	if _rest_area._is_world_interaction_blocked():
		_record("%s left RestArea._is_world_interaction_blocked() true" % label)
		return
	var target_zone := _rest_area._get_zone_id_for_global_point(_rest_area._get_zone_center_global(0))
	if target_zone != 0:
		_record("%s could not map RestArea zone 0, got %d" % [label, target_zone])
		return
	_rest_area._set_hover_zone(target_zone)
	if _rest_area.hover_zone_id != 0:
		_record("%s did not restore RestArea hover, got %d" % [label, _rest_area.hover_zone_id])

func _reset_global_state() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.load_definitions()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0

func _record(message: String) -> void:
	_failures.append(message)
	push_error("SecondaryMenuWorldBlockingContractTest: " + message)

func _finish() -> void:
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	if _failures.is_empty():
		print("SecondaryMenuWorldBlockingContractTest: PASS")
		get_tree().quit(0)
		return
	print("SecondaryMenuWorldBlockingContractTest: FAIL (%d)" % _failures.size())
	for failure in _failures:
		print(" - " + failure)
	get_tree().quit(1)
