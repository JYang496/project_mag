extends Node

const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const WORLD_SCENE := preload("res://World/world.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false
var _board: BoardCellGenerator
var _rest_area: RestArea
var _view: HybridGroundView3D
var _ui: UI
var _anchor_test_player: Node2D


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_runtime()
	await _test_real_world_initial_entry()
	_reset_runtime()
	PhaseManager.current_level = 3

	_board = BoardCellGenerator.new()
	_board.name = "Board"
	_board.cell_scene = CELL_SCENE
	add_child(_board)
	_rest_area = REST_AREA_SCENE.instantiate() as RestArea
	_rest_area.name = "RestArea"
	_rest_area.board_path = NodePath("../Board")
	_rest_area.add_to_group(&"rest_area")
	add_child(_rest_area)
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
	LocalizationManager.set_locale("zh_CN", false)
	_expect(LocalizationManager.tr_key("rest_arrival.complete") == "休整设施 // 已上线", "arrival completion status must be localized in Simplified Chinese")
	LocalizationManager.set_locale("en", false)
	_expect(LocalizationManager.tr_key("rest_arrival.complete") == "REST FACILITIES // ONLINE", "arrival completion status must be localized in English")

	_expect(_ui.prepare_initial_rest_area_entry(), "initial world entry must prepare the rest-area arrival exactly once")
	_expect(_rest_area.is_arrival_transition_locked(), "initial world entry must lock rest-area interaction before loading clears")
	_expect(_ui.rest_area_arrival_presenter.overlay.visible, "initial arrival must prime its cover before loading clears")
	_expect(_ui.rest_area_arrival_presenter.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "primed initial cover must block world input")
	_expect(is_equal_approx(_ui.rest_area_arrival_presenter.scrim.color.a, 1.0), "primed initial cover must fully conceal the built world")
	_ui.play_initial_rest_area_entry()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(PhaseManager.current_state() == PhaseManager.REST, "arrival presentation must not replace the authoritative rest phase")
	_expect(_rest_area.is_active(), "rest area must be active while its arrival presentation plays")
	_expect(_rest_area.is_arrival_transition_locked(), "arrival presentation must keep service interaction locked")
	_expect(not _rest_area.call("_is_interaction_enabled"), "world interaction must remain disabled during arrival")
	_expect(_ui.rest_area_arrival_presenter.is_playing(), "arrival presenter should remain active during its bounded timeline")
	_expect(_ui.rest_area_arrival_presenter.overlay.visible, "arrival overlay must be visible while services come online")
	_expect(_ui.rest_area_arrival_presenter.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "arrival overlay must block world input")
	_expect(_ui.rest_area_arrival_presenter.scrim.color.a > 0.18, "initial cover must release gradually instead of exposing the world in one frame")
	await get_tree().create_timer(0.35).timeout
	var rest_ground := _view.get("_rest_ground_mesh") as MeshInstance3D
	_expect(rest_ground != null, "hybrid rest ground must exist for arrival presentation")
	if rest_ground != null:
		var progress := float(rest_ground.get_instance_shader_parameter("arrival_progress"))
		_expect(progress > 0.0 and progress < 1.0, "rest ground should be partially materialized during arrival")
	var purchase_prop := _rest_area.get_node_or_null("ZoneVisuals/HybridProp0") as Sprite2D
	var upgrade_prop := _rest_area.get_node_or_null("ZoneVisuals/HybridProp1") as Sprite2D
	_expect(purchase_prop != null and upgrade_prop != null, "hybrid service props must exist for staggered arrival")
	if purchase_prop != null and upgrade_prop != null:
		_expect(purchase_prop.modulate.a > upgrade_prop.modulate.a, "purchase service must begin materializing before the upgrade service")

	var deadline := Time.get_ticks_msec() + 4000
	while _ui.rest_area_arrival_presenter.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_expect(not _ui.rest_area_arrival_presenter.is_playing(), "arrival timeline must finish within its fixed duration")
	_expect(not _ui.rest_area_arrival_presenter.overlay.visible, "completed arrival must clean up its overlay")
	_expect(_ui.rest_area_arrival_presenter.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "completed arrival must release input blocking")
	_expect(not _rest_area.is_arrival_transition_locked(), "completed arrival must release the semantic interaction lock")
	_expect(_rest_area.call("_is_interaction_enabled"), "rest-area interaction must become available after arrival")
	if rest_ground != null:
		_expect(is_equal_approx(float(rest_ground.get_instance_shader_parameter("arrival_progress")), 1.0), "rest ground must finish fully materialized")
	if purchase_prop != null and upgrade_prop != null:
		_expect(is_equal_approx(purchase_prop.modulate.a, 1.0) and is_equal_approx(upgrade_prop.modulate.a, 1.0), "all service props must finish fully visible")
	_expect(not _ui.prepare_initial_rest_area_entry(), "initial world entry animation must be one-shot for the UI lifetime")

	PhaseManager.enter_protocol_selection()
	await get_tree().process_frame
	_expect(not _ui.rest_area_arrival_presenter.is_playing(), "leaving rest must not leave the arrival presenter active")
	_expect(not _rest_area.is_arrival_transition_locked(), "leaving rest must not retain the arrival lock")
	PhaseManager.return_to_rest_from_protocol_selection()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not _ui.rest_area_arrival_presenter.is_playing(), "cancelling protocol selection back to rest must not replay initial arrival")
	_expect(not _rest_area.is_arrival_transition_locked(), "cancelling protocol selection must keep rest-area interaction unlocked")

	PhaseManager.enter_protocol_selection()
	_ui.prepare_rest_area_entry_transition()
	PhaseManager.return_to_rest_from_protocol_selection()
	_ui.rest_area_arrival_presenter.play()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_ui.rest_area_arrival_presenter.is_playing(), "restarted arrival should enter its active lifecycle")
	PhaseManager.enter_protocol_selection()
	await get_tree().process_frame
	_expect(not _ui.rest_area_arrival_presenter.is_playing(), "phase interruption must cancel an active arrival")
	_expect(not _ui.rest_area_arrival_presenter.overlay.visible, "phase interruption must clean the arrival overlay")
	_expect(not _rest_area.is_arrival_transition_locked(), "phase interruption must release the semantic interaction lock")

	await _test_post_battle_rest_centers_on_player()

	print("FAIL rest area arrival runtime" if _failed else "PASS rest area arrival runtime")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime)
	_board = null
	_rest_area = null
	_view = null
	_ui = null
	_anchor_test_player = null


func _test_post_battle_rest_centers_on_player() -> void:
	_anchor_test_player = Node2D.new()
	_anchor_test_player.name = "PostBattleAnchorPlayer"
	add_child(_anchor_test_player)
	PlayerData.player = _anchor_test_player
	var battle_end_position := _board.get_center_cell_global_position() + Vector2(73.0, -41.0)
	_anchor_test_player.global_position = battle_end_position

	PhaseManager.phase = PhaseManager.BATTLE
	_board.call("_on_phase_changed", PhaseManager.BATTLE)
	PhaseManager.enter_settlement()
	await get_tree().process_frame
	_expect(
		_board.get_rest_area_target_center_global_position().distance_to(battle_end_position) <= 0.01,
		"post-battle rest anchor must preserve the player's exact battle-end position"
	)
	_expect(
		_anchor_test_player.global_position.distance_to(battle_end_position) <= 0.01,
		"settlement must not move the player toward the previous cell center"
	)

	PhaseManager.enter_protocol_selection()
	PhaseManager.enter_rest()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_rest_area.is_active(), "rest area must activate after the post-battle phase chain")
	_expect(
		_rest_area.get_spawn_position().distance_to(battle_end_position) <= 0.01,
		"rest platform center must materialize at the player's battle-end position"
	)
	_expect(
		_anchor_test_player.global_position.distance_to(battle_end_position) <= 0.01,
		"entering rest must not add a visible automatic move"
	)
	_expect(not bool(_rest_area.get("is_auto_moving")), "post-battle rest entry must not start auto-navigation")
	_rest_area.call("_begin_zone_move", 1, false)
	_expect(bool(_rest_area.get("is_auto_moving")), "explicit rest-zone navigation must remain available")
	_rest_area.call("_stop_auto_move")
	PlayerData.player = null
	_anchor_test_player.queue_free()
	await get_tree().process_frame


func _test_real_world_initial_entry() -> void:
	LoadingPerformance.show_world_build_overlay()
	var loading_overlay := LoadingPerformance.get("_world_build_overlay") as CanvasLayer
	var world := WORLD_SCENE.instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var observed_stages: Array[StringName] = []
	world.build_stage_changed.connect(func(stage: StringName, _progress: float):
		observed_stages.append(stage)
	)
	var build_deadline := Time.get_ticks_msec() + 8000
	while not bool(world.get("world_build_complete")) and Time.get_ticks_msec() < build_deadline:
		await get_tree().process_frame
	_expect(bool(world.get("world_build_complete")), "real world shell must finish its staged build")
	_expect(
		observed_stages == [
			&"reward_manager", &"board", &"rest_area", &"ui", &"player",
			&"ground", &"world_services", &"complete",
		],
		"real world shell must preserve the dependency-safe staged build order"
	)
	var real_ui := world.get_node("UI") as UI
	var real_rest_area := world.get_node("RestArea") as RestArea
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		if bool(real_ui.get("_initial_rest_area_entry_prepared")) \
				and real_ui.rest_area_arrival_presenter.is_playing():
			break
		await get_tree().process_frame
	_expect(bool(real_ui.get("_initial_rest_area_entry_prepared")), "real world readiness must prepare initial rest-area arrival")
	_expect(real_ui.rest_area_arrival_presenter.is_playing(), "real world readiness must automatically start initial rest-area arrival")
	_expect(real_ui.rest_area_arrival_presenter.overlay.visible, "real world entry must retain visual coverage through the loading handoff")
	_expect(loading_overlay != null and loading_overlay.visible, "loading overlay must still be fading when the initial arrival begins")
	_expect(real_ui.rest_area_arrival_presenter.scrim.color.a > 0.18, "arrival cover must conceal the world while loading fades")
	_expect(real_rest_area.is_arrival_transition_locked(), "real world entry must keep rest interaction locked during arrival")
	await get_tree().create_timer(0.44).timeout
	var loading_root := LoadingPerformance.get("_world_build_overlay_root") as ColorRect
	_expect(not loading_overlay.visible or loading_root.modulate.a <= 0.01, "loading overlay must finish its preview-matched crossfade while arrival remains active")
	_expect(real_ui.rest_area_arrival_presenter.overlay.visible, "arrival overlay must keep visual ownership after loading exits")
	while real_ui.rest_area_arrival_presenter.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_expect(not real_ui.rest_area_arrival_presenter.is_playing(), "real world initial arrival must complete within the readiness deadline")
	_expect(not real_rest_area.is_arrival_transition_locked(), "real world initial arrival must release rest interaction")
	get_tree().current_scene = self
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)


func _reset_runtime() -> void:
	BattleContractManager.reset_persistent_state()
	PhaseManager.reset_runtime_state()
	PlayerData.reset_runtime_state()
	GlobalVariables.reset_runtime_state()
