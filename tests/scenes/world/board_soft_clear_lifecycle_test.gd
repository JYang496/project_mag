extends Node

const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const DEPLOYMENT_PRESENTER := preload("res://UI/scripts/components/battlefield_deployment_presenter.gd")
const DEPLOYMENT_SHADER := preload("res://Shaders/battlefield_deployment_ground.gdshader")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

class CleanupProbe:
	extends Node
	var cleaned := false

	func cleanup_for_battle_end() -> void:
		cleaned = true

var _failed := false
var _board: BoardCellGenerator
var _hybrid_view: HybridGroundView3D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.BATTLE
	PhaseManager.current_level = 3

	_board = BoardCellGenerator.new()
	_board.name = "Board"
	_board.cell_scene = CELL_SCENE
	_board.auto_assign_enemy_on_battle = false
	_board.fade_duration = 0.01
	add_child(_board)
	_hybrid_view = HYBRID_VIEW.new()
	_hybrid_view.board_path = NodePath("../Board")
	add_child(_hybrid_view)
	var cleanup_probe := CleanupProbe.new()
	add_child(cleanup_probe)
	cleanup_probe.add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	await get_tree().process_frame
	await get_tree().process_frame

	var original_cell_ids := _get_cell_instance_ids()
	var completed_battle_active_ids := _board.get_active_cell_ids()
	_expect(_board.visible and _board.is_board_visual_active(), "battle should render the board")
	_expect(_board.is_board_combat_enabled(), "battle should enable board interactions")
	PhaseManager.cleanup_battle_runtime_transients()
	_expect(cleanup_probe.cleaned, "soft clear should clean registered battle transients")

	# PhaseManager advances the level before it emits SETTLEMENT. The completed
	# battle topology must remain unchanged until deployment starts.
	PhaseManager.current_level = 4
	await _transition_to(PhaseManager.SETTLEMENT)
	_expect(_board.visible and _board.is_board_visual_active(), "settlement should preserve the completed board")
	_expect(not _board.is_board_combat_enabled(), "settlement should disable board interactions")
	_expect(_board.process_mode == Node.PROCESS_MODE_INHERIT, "soft-cleared board should remain renderable")
	_expect(_board.get_active_cell_ids() == completed_battle_active_ids, "settlement should not expand the next board early")
	_expect(_get_cell_instance_ids() == original_cell_ids, "settlement should not recycle cell nodes")
	_expect(not _active_cells_are_monitoring(), "settlement cells should stop capture monitoring")

	await _transition_to(PhaseManager.PROTOCOL_SELECTION)
	_expect(_board.visible and _board.is_board_visual_active(), "protocol selection from settlement should retain the board")
	_expect(not _board.is_board_combat_enabled(), "protocol selection should remain non-interactive")
	_expect(_board.get_active_cell_ids() == completed_battle_active_ids, "protocol selection should retain completed topology")
	_expect(_get_cell_instance_ids() == original_cell_ids, "protocol selection should reuse the same cell nodes")

	await _transition_to(PhaseManager.BATTLE_STARTING)
	_expect(_board.visible and _board.is_board_visual_active(), "deployment should keep the retained board visible")
	_expect(not _board.is_board_combat_enabled(), "deployment should not enable cell interactions before battle")
	_expect(_board.get_active_cell_ids().size() > completed_battle_active_ids.size(), "deployment should apply the next level topology")
	_expect(_get_cell_instance_ids() == original_cell_ids, "deployment should reconfigure instead of rebuilding cells")
	_expect_deployment_visual_contract(completed_battle_active_ids)

	await _transition_to(PhaseManager.BATTLE)
	_expect(_board.is_board_combat_enabled(), "the next battle should reactivate board interactions")
	_expect(_active_cells_are_monitoring(), "the next battle should restore active-cell monitoring")
	_expect(_get_cell_instance_ids() == original_cell_ids, "the second battle should still use the original cells")

	# Entering the Rest Protocol still swaps to the dedicated rest platform. A
	# protocol selection opened from rest must not reveal the hidden battlefield.
	await _transition_to(PhaseManager.SETTLEMENT)
	await _transition_to(PhaseManager.PROTOCOL_SELECTION)
	await _transition_to(PhaseManager.REST)
	await get_tree().create_timer(0.05, true, false, true).timeout
	_expect(not _board.visible and not _board.is_board_visual_active(), "rest should hide the battle board")
	await _transition_to(PhaseManager.PROTOCOL_SELECTION)
	_expect(not _board.visible and not _board.is_board_visual_active(), "protocol selection from rest should keep the rest platform")
	await _transition_to(PhaseManager.BATTLE_STARTING)
	await get_tree().create_timer(0.05, true, false, true).timeout
	_expect(_board.visible and _board.is_board_visual_active(), "deployment from rest should restore the existing board")
	_expect(_get_cell_instance_ids() == original_cell_ids, "deployment from rest should not rebuild cells")

	print("FAIL board soft-clear lifecycle" if _failed else "PASS board soft-clear lifecycle")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime)
	_board = null
	_hybrid_view = null

func _transition_to(next_phase: String) -> void:
	PhaseManager.phase = next_phase
	_board.call("_on_phase_changed", next_phase)
	await get_tree().process_frame
	await get_tree().process_frame

func _get_cell_instance_ids() -> PackedInt64Array:
	var ids := PackedInt64Array()
	for cell in _board.get_cells():
		ids.append(cell.get_instance_id())
	return ids

func _active_cells_are_monitoring() -> bool:
	for cell in _board.get_active_cells():
		var area := cell.get_node_or_null("Area2D") as Area2D
		if area == null or not area.monitoring or not area.monitorable:
			return false
	return not _board.get_active_cells().is_empty()

func _expect_deployment_visual_contract(previous_ids: PackedInt32Array) -> void:
	var current_ids := _board.get_active_cell_ids()
	var positions := {}
	for cell_id in current_ids:
		var cell := _board.get_cell_by_logical_id(int(cell_id))
		positions[int(cell_id)] = cell.global_position + _board.cell_spacing * 0.5
	var origin := _board.get_center_cell_global_position()
	var plan := DEPLOYMENT_PRESENTER.build_deployment_plan(previous_ids, current_ids, positions, origin)
	_expect(plan.size() == current_ids.size(), "deployment plan should contain every active cell exactly once")
	_expect(not plan.is_empty() and int(plan[0].cell_id) == 5, "deployment plan should reveal the center cell first")
	for index in range(1, plan.size()):
		var previous_distance := float(plan[index - 1].distance)
		var current_distance := float(plan[index].distance)
		_expect(current_distance >= previous_distance, "deployment plan should be ordered by distance from the player origin")

	_hybrid_view.prepare_battlefield_deployment(plan)
	var retained_id := -1
	var added_id := -1
	for item in plan:
		if StringName(item.kind) == &"retained" and retained_id < 0:
			retained_id = int(item.cell_id)
		elif StringName(item.kind) == &"added" and added_id < 0:
			added_id = int(item.cell_id)
	_expect(retained_id >= 0 and added_id >= 0, "next-battle deployment should distinguish retained and newly unlocked cells")
	var retained_mesh := _hybrid_view.call("_get_cell_ground_mesh", retained_id) as MeshInstance3D
	var added_mesh := _hybrid_view.call("_get_cell_ground_mesh", added_id) as MeshInstance3D
	var retained_material := retained_mesh.mesh.surface_get_material(0) as ShaderMaterial if retained_mesh != null else null
	_expect(retained_material != null and retained_material.shader == DEPLOYMENT_SHADER, "battlefield cells should use the pixel deployment shader")
	_expect(retained_mesh != null and is_equal_approx(float(retained_mesh.get_instance_shader_parameter("deployment_progress")), 1.0), "retained cells should stay spatially readable while recalibrating")
	_expect(added_mesh != null and is_equal_approx(float(added_mesh.get_instance_shader_parameter("deployment_progress")), 0.0), "new cells should begin fully unmaterialized")
	_hybrid_view.set_cell_deployment_state(added_id, 0.5, 0.5, 1.0)
	_expect(added_mesh != null and is_equal_approx(float(added_mesh.get_instance_shader_parameter("deployment_progress")), 0.5), "deployment progress should update per cell without rebuilding topology")
	_hybrid_view.finish_battlefield_deployment()
	_expect(added_mesh != null and is_equal_approx(float(added_mesh.get_instance_shader_parameter("deployment_progress")), 1.0), "deployment cleanup should leave active cells fully rendered")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _reset_runtime() -> void:
	PhaseManager.reset_runtime_state()
