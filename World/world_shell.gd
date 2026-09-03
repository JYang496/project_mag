extends Node2D
class_name WorldShell

signal build_stage_changed(stage: StringName, progress: float)
signal build_completed

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const ENEMY_SPAWNER_SCENE := preload("res://World/spawn/enemy_spawner.tscn")
const BOARD_SCRIPT := preload("res://World/board_cell_generator.gd")
const PLAYER_SPAWNER_SCRIPT := preload("res://World/player_spawner.gd")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const CELL_PROFILE_SCRIPT := preload("res://Board/Cells/cell_profile.gd")
const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const REWARD_MANAGER_SCENE := preload("res://World/rewards/reward_manager.tscn")
const HYBRID_GROUND_SCRIPT := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const UNLOADED_ENVIRONMENT_SCRIPT := preload("res://Visual/Oblique/unloaded_world_environment.gd")
const READY_COORDINATOR_SCRIPT := preload("res://World/world_ready_coordinator.gd")
const BATTLEFIELD_CENTER := Vector2(-212.0, 244.0)

var build_stage: StringName = &"shell_ready"
var build_progress := 0.0
var world_build_complete := false


func _enter_tree() -> void:
	LoadingPerformance.mark("world_tree_entered")


func _ready() -> void:
	call_deferred("_build_world_over_frames")


func _build_world_over_frames() -> void:
	await _run_stage(&"reward_manager", 0.855, _build_reward_manager)
	await _run_stage(&"board", 0.875, _build_board)
	await _run_stage(&"rest_area", 0.89, _build_rest_area)
	await _run_stage(&"ui", 0.91, _build_ui)
	await _run_stage(&"player", 0.925, _build_player)
	await _run_stage(&"ground", 0.94, _build_ground)
	await _run_stage(&"world_services", 0.955, _build_world_services)

	world_build_complete = true
	_set_stage(&"complete", 0.97)
	var coordinator := READY_COORDINATOR_SCRIPT.new()
	coordinator.name = "WorldReadyCoordinator"
	add_child(coordinator)
	build_completed.emit()


func _run_stage(stage: StringName, progress: float, builder: Callable) -> void:
	_set_stage(stage, progress)
	LoadingPerformance.begin_segment("world_shell_%s" % stage)
	builder.call()
	LoadingPerformance.end_segment("world_shell_%s" % stage)
	# Adding a subtree runs its enter/ready callbacks synchronously. Yield after
	# every bounded phase so the persistent loading preview can keep rendering.
	await get_tree().process_frame


func _set_stage(stage: StringName, progress: float) -> void:
	build_stage = stage
	build_progress = clampf(progress, build_progress, 1.0)
	LoadingPerformance.update_world_preview_loading_progress(build_progress)
	build_stage_changed.emit(build_stage, build_progress)


func _build_reward_manager() -> void:
	var reward_manager := REWARD_MANAGER_SCENE.instantiate()
	reward_manager.name = "RewardManager"
	add_child(reward_manager)


func _build_board() -> void:
	var board := BOARD_SCRIPT.new() as BoardCellGenerator
	board.name = "Board"
	board.cell_scene = CELL_SCENE
	board.player_spawner_path = NodePath()
	board.position = BATTLEFIELD_CENTER - board.get_board_size() * 0.5
	var profiles: Array[CellProfile] = []
	for unused in range(9):
		profiles.append(CELL_PROFILE_SCRIPT.new() as CellProfile)
	board.initial_cell_profiles = profiles
	add_child(board)


func _build_rest_area() -> void:
	var rest_area := REST_AREA_SCENE.instantiate() as RestArea
	rest_area.name = "RestArea"
	rest_area.position = Vector2(-256.0, -256.0)
	rest_area.board_path = NodePath("../Board")
	rest_area.add_to_group(&"rest_area")
	add_child(rest_area)
	var board := get_node_or_null("Board") as BoardCellGenerator
	if board != null:
		board.call("_resolve_rest_area")


func _build_ui() -> void:
	var ui := UI_SCENE.instantiate()
	ui.name = "UI"
	add_child(ui)


func _build_player() -> void:
	var board := get_node_or_null("Board") as BoardCellGenerator
	if board == null:
		push_error("World shell cannot spawn the player without Board.")
		return
	var center_cell := board.get_center_cell()
	if center_cell == null:
		push_error("World shell cannot spawn the player without a center cell.")
		return
	var player_spawner := PLAYER_SPAWNER_SCRIPT.new()
	player_spawner.name = "PlayerSpawner"
	player_spawner.position = board.get_center_spawn_offset()
	center_cell.add_child(player_spawner)


func _build_ground() -> void:
	var ground := HYBRID_GROUND_SCRIPT.new() as HybridGroundView3D
	ground.name = "HybridGroundView3D"
	ground.board_path = NodePath("../Board")
	add_child(ground)


func _build_world_services() -> void:
	var unloaded_environment := UNLOADED_ENVIRONMENT_SCRIPT.new()
	unloaded_environment.name = "UnloadedWorldEnvironment"
	add_child(unloaded_environment)

	var enemy_spawner := ENEMY_SPAWNER_SCENE.instantiate() as EnemySpawner
	enemy_spawner.name = "EnemySpawner"
	add_child(enemy_spawner)
