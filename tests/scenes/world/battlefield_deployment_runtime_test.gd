extends Node

const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const PLAYER_CAMERA_SYSTEM := preload("res://Player/Mechas/scripts/player_camera_system.gd")
const PLAYER_CAMERA_CONFIG := preload("res://Player/Mechas/scripts/player_camera_config.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

class FakeBattleCameraPlayer extends Node2D:
	var battle_view_multiplier := 1.0
	var active_skill_holder: Node

	func get_battle_camera_view_multiplier() -> float:
		return battle_view_multiplier

var _failed := false
var _board: BoardCellGenerator
var _view: HybridGroundView3D
var _ui: UI
var _player: FakeBattleCameraPlayer


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_runtime()
	PhaseManager.phase = PhaseManager.PROTOCOL_SELECTION
	PhaseManager.current_level = 3
	var camera_config := PLAYER_CAMERA_CONFIG.new()
	camera_config.battle_camera_view_mul = 0.8
	var camera_system := PLAYER_CAMERA_SYSTEM.new()
	camera_system.setup(null, camera_config, 1.0)
	_expect(is_equal_approx(camera_system.get_battle_view_multiplier(1.0), 0.8), "default battle camera target should include the configured battle multiplier")
	_expect(is_equal_approx(camera_system.get_battle_view_multiplier(1.25), 1.0), "battle camera target should include the current vision modifier")

	_player = FakeBattleCameraPlayer.new()
	_player.name = "FakeBattleCameraPlayer"
	_player.battle_view_multiplier = camera_system.get_battle_view_multiplier(0.9)
	add_child(_player)
	PlayerData.player = _player

	_board = BoardCellGenerator.new()
	_board.name = "Board"
	_board.cell_scene = CELL_SCENE
	_board.auto_assign_enemy_on_battle = true
	add_child(_board)
	_view = HYBRID_VIEW.new()
	_view.name = "HybridGroundView3D"
	_view.board_path = NodePath("../Board")
	add_child(_view)
	_ui = UI_SCENE.instantiate() as UI
	_ui.name = "UI"
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_board.set_board_active(true, true)
	_ui.prepare_battle_entry_transition()
	var previous_ids := _board.get_active_cell_ids().duplicate()
	PhaseManager.current_level = 4
	PhaseManager.enter_battle_starting()
	await get_tree().process_frame
	await get_tree().process_frame
	var newly_added_ids := _board.get_active_cell_ids().duplicate()
	for previous_id in previous_ids:
		var previous_index := newly_added_ids.find(previous_id)
		if previous_index >= 0:
			newly_added_ids.remove_at(previous_index)
	var armed_added_mesh := _view.call("_get_cell_ground_mesh", int(newly_added_ids[0])) as MeshInstance3D if not newly_added_ids.is_empty() else null
	_expect(armed_added_mesh != null and is_equal_approx(float(armed_added_mesh.get_instance_shader_parameter("deployment_progress")), 0.0), "armed deployment should hide newly rebuilt cells before the first rendered transition frame")
	_ui.battlefield_deployment_presenter.play()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(PhaseManager.current_state() == PhaseManager.BATTLE_STARTING, "deployment timeline must not advance the authoritative phase itself")
	_expect(_ui.battlefield_deployment_presenter.is_playing(), "real deployment presenter should remain active while the battlefield builds")
	_expect(_ui.battlefield_deployment_presenter.overlay.visible, "deployment overlay should be visible during BATTLE_STARTING")
	_expect(_ui.battlefield_deployment_presenter.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "deployment overlay should block world input while building")
	_expect(not _board.is_board_combat_enabled(), "board collisions must remain disabled throughout battlefield construction")
	_expect(_board.get_active_cell_ids().size() > previous_ids.size(), "runtime deployment should animate the newly expanded topology")

	var deadline := Time.get_ticks_msec() + 5000
	while _ui.battlefield_deployment_presenter.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_expect(not _ui.battlefield_deployment_presenter.is_playing(), "deployment timeline should finish within its bounded duration")
	_expect(not _ui.battlefield_deployment_presenter.overlay.visible, "deployment overlay should clean itself after completion")
	_expect(_ui.battlefield_deployment_presenter.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "completed deployment must release input blocking")
	_expect(is_equal_approx(_view.get_view_multiplier(), 0.72), "deployment cleanup should settle directly on the authoritative battle camera multiplier")
	for cell_id in _board.get_active_cell_ids():
		var mesh := _view.call("_get_cell_ground_mesh", int(cell_id)) as MeshInstance3D
		_expect(mesh != null and is_equal_approx(float(mesh.get_instance_shader_parameter("deployment_progress")), 1.0), "every active cell should finish fully materialized")

	PhaseManager.enter_battle()
	await get_tree().process_frame
	_expect(_board.is_board_combat_enabled(), "combat interactions should unlock only after entering BATTLE")

	print("FAIL battlefield deployment runtime" if _failed else "PASS battlefield deployment runtime")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime)
	_board = null
	_view = null
	_ui = null
	_player = null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)


func _reset_runtime() -> void:
	PhaseManager.reset_runtime_state()
	PlayerData.reset_runtime_state()
	GlobalVariables.reset_runtime_state()
