extends RefCounted
class_name BattlefieldDeploymentPresenter

const CELL_REVEAL_SEC := 0.32
const CELL_STAGGER_SEC := 0.09
const DEPLOYMENT_BASE_DELAY_SEC := 0.28
const MIN_BUILD_END_SEC := 1.42
const COMPLETION_HOLD_SEC := 0.22
const SCRIM_ALPHA := 0.22
const CAMERA_OVERVIEW_FACTOR := 1.05
const OVERLAY_SCENE := preload("res://UI/components/BattlefieldDeploymentOverlay/BattlefieldDeploymentOverlay.tscn")

var owner_ui: UI
var overlay: Control
var scrim: ColorRect
var scan_line: ColorRect
var status_panel: PanelContainer
var status_label: Label
var progress_fill: ColorRect
var audio: AudioStreamPlayer

var _board: BoardCellGenerator
var _ground_view: HybridGroundView3D
var _previous_cell_ids := PackedInt32Array()
var _board_was_visible := false
var _transition_tween: Tween
var _generation := 0
var _playing := false
var _battle_view_multiplier := 1.0
var _camera_overview_multiplier := CAMERA_OVERVIEW_FACTOR
var _pre_deployment_view_multiplier := 1.0


func bind(ui: UI, root: Control) -> void:
	owner_ui = ui
	_build_overlay(root)
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)


func capture_previous_topology() -> void:
	_resolve_world_nodes()
	_previous_cell_ids = _board.get_active_cell_ids().duplicate() if _board != null else PackedInt32Array()
	_board_was_visible = _board != null and _board.is_board_visual_active()
	if _ground_view != null:
		_ground_view.arm_battlefield_deployment(_previous_cell_ids, _board_was_visible)


func play() -> void:
	_generation += 1
	var generation := _generation
	_playing = true
	_resolve_world_nodes()
	# BATTLE_STARTING refreshes topology and schedules the hybrid ground rebuild.
	# Waiting two frames guarantees that the new meshes exist before parameters
	# are animated, without rebuilding them during the transition.
	await owner_ui.get_tree().process_frame
	await owner_ui.get_tree().process_frame
	if generation != _generation or PhaseManager.current_state() != PhaseManager.BATTLE_STARTING:
		return
	_resolve_world_nodes()
	var current_ids := _board.get_active_cell_ids().duplicate() if _board != null else PackedInt32Array()
	var origin := _resolve_deployment_origin()
	var positions := _build_cell_position_map(current_ids)
	var retained_ids := _previous_cell_ids if _board_was_visible else PackedInt32Array()
	var plan := build_deployment_plan(retained_ids, current_ids, positions, origin)
	_prepare_visual_state(plan)
	await _play_timeline(plan)
	if generation != _generation:
		return
	_finish_visual_state(true)
	_playing = false


func cancel() -> void:
	_generation += 1
	_playing = false
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	_finish_visual_state(false)


func is_playing() -> bool:
	return _playing


static func build_deployment_plan(
	previous_ids: PackedInt32Array,
	current_ids: PackedInt32Array,
	cell_positions: Dictionary,
	origin: Vector2
) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for cell_id in current_ids:
		var position := cell_positions.get(int(cell_id), origin) as Vector2
		plan.append({
			"cell_id": int(cell_id),
			"kind": &"retained" if previous_ids.has(int(cell_id)) else &"added",
			"distance": position.distance_to(origin),
		})
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var distance_a := float(a.get("distance", 0.0))
		var distance_b := float(b.get("distance", 0.0))
		if not is_equal_approx(distance_a, distance_b):
			return distance_a < distance_b
		return int(a.get("cell_id", 0)) < int(b.get("cell_id", 0))
	)
	for index in range(plan.size()):
		plan[index]["delay"] = DEPLOYMENT_BASE_DELAY_SEC + float(index) * CELL_STAGGER_SEC
		plan[index]["duration"] = CELL_REVEAL_SEC
	return plan


func _prepare_visual_state(plan: Array) -> void:
	if overlay == null:
		return
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.color.a = 0.0
	scan_line.modulate.a = 0.0
	status_panel.modulate.a = 0.0
	status_panel.scale = Vector2(0.96, 0.96)
	status_label.text = _tr("battle_deployment.topology", "BATTLEFIELD TOPOLOGY // SYNCING")
	progress_fill.scale = Vector2(0.0, 1.0)
	if _ground_view != null:
		_pre_deployment_view_multiplier = _ground_view.get_view_multiplier()
		_battle_view_multiplier = _resolve_battle_camera_view_multiplier()
		_camera_overview_multiplier = _battle_view_multiplier * CAMERA_OVERVIEW_FACTOR
		_ground_view.prepare_battlefield_deployment(plan)
		_ground_view.set_view_multiplier(_camera_overview_multiplier, 0.30)


func _play_timeline(plan: Array) -> void:
	if owner_ui == null or not owner_ui.is_inside_tree():
		return
	_transition_tween = owner_ui.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(scrim, "color:a", SCRIM_ALPHA, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(status_panel, "modulate:a", 1.0, 0.16).set_delay(0.06)
	_transition_tween.tween_property(status_panel, "scale", Vector2.ONE, 0.20).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(scan_line, "modulate:a", 0.70, 0.10).set_delay(0.12)
	_transition_tween.tween_property(scan_line, "position:y", _viewport_height() - 90.0, 0.92).from(92.0).set_delay(0.12).set_trans(Tween.TRANS_SINE)
	_transition_tween.tween_property(scan_line, "modulate:a", 0.0, 0.18).set_delay(0.94)

	var build_end := MIN_BUILD_END_SEC
	for item in plan:
		var delay := float(item.get("delay", DEPLOYMENT_BASE_DELAY_SEC))
		var duration := float(item.get("duration", CELL_REVEAL_SEC))
		build_end = maxf(build_end, delay + duration)
		_transition_tween.tween_method(
			_animate_cell.bind(int(item.get("cell_id", -1)), StringName(item.get("kind", &"added"))),
			0.0,
			1.0,
			duration
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition_tween.tween_callback(_play_cell_tone).set_delay(delay)

	_transition_tween.tween_callback(_set_status.bind(
		_tr("battle_deployment.modules", "TACTICAL MODULES // DEPLOYING")
	)).set_delay(0.74)
	_transition_tween.tween_property(progress_fill, "scale:x", 0.78, maxf(build_end - 0.26, 0.2)).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_callback(_set_status.bind(
		_tr("battle_deployment.complete", "BATTLEFIELD DEPLOYMENT // COMPLETE")
	)).set_delay(build_end)
	_transition_tween.tween_callback(_play_completion_tone).set_delay(build_end)
	_transition_tween.tween_property(progress_fill, "scale:x", 1.0, 0.16).set_delay(build_end)
	_transition_tween.tween_property(scrim, "color:a", 0.0, 0.24).set_delay(build_end)
	_transition_tween.tween_property(status_panel, "modulate:a", 0.0, 0.20).set_delay(build_end + COMPLETION_HOLD_SEC)
	if _ground_view != null:
		_transition_tween.tween_method(_set_camera_return_progress, 0.0, 1.0, 0.28).set_delay(build_end)
	await _transition_tween.finished
	_transition_tween = null


func _animate_cell(value: float, cell_id: int, kind: StringName) -> void:
	if _ground_view == null:
		return
	var eased := clampf(value, 0.0, 1.0)
	var progress_value := 1.0 if kind == &"retained" else eased
	var dim_value := lerpf(0.28 if kind == &"retained" else 0.0, 1.0, eased)
	var pulse := sin(eased * PI)
	_ground_view.set_cell_deployment_state(cell_id, progress_value, dim_value, pulse)


func _set_camera_return_progress(value: float) -> void:
	if _ground_view == null:
		return
	_ground_view.set_view_multiplier(lerpf(
		_camera_overview_multiplier,
		_battle_view_multiplier,
		clampf(value, 0.0, 1.0)
	))


func _finish_visual_state(settle_to_battle: bool) -> void:
	if _ground_view != null and is_instance_valid(_ground_view):
		_ground_view.finish_battlefield_deployment()
		var target_multiplier := _battle_view_multiplier if settle_to_battle else _pre_deployment_view_multiplier
		_ground_view.set_view_multiplier(target_multiplier)
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scrim.color.a = 0.0
		scan_line.modulate.a = 0.0
		status_panel.modulate.a = 0.0


func _resolve_world_nodes() -> void:
	if owner_ui == null or not owner_ui.is_inside_tree():
		return
	var scene := owner_ui.get_tree().current_scene
	if scene == null:
		return
	_board = scene.get_node_or_null("Board") as BoardCellGenerator
	_ground_view = scene.get_node_or_null("HybridGroundView3D") as HybridGroundView3D


func _resolve_deployment_origin() -> Vector2:
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		return PlayerData.player.global_position
	if _board != null:
		return _board.get_center_cell_global_position()
	return Vector2.ZERO


func _resolve_battle_camera_view_multiplier() -> float:
	if PlayerData.player != null and is_instance_valid(PlayerData.player) \
			and PlayerData.player.has_method("get_battle_camera_view_multiplier"):
		return maxf(float(PlayerData.player.call("get_battle_camera_view_multiplier")), 0.05)
	return 1.0


func _build_cell_position_map(cell_ids: PackedInt32Array) -> Dictionary:
	var result := {}
	if _board == null:
		return result
	for cell_id in cell_ids:
		var cell := _board.get_cell_by_logical_id(int(cell_id))
		if cell != null:
			result[int(cell_id)] = cell.global_position + _board.cell_spacing * 0.5
	return result


func _build_overlay(root: Control) -> void:
	overlay = OVERLAY_SCENE.instantiate() as Control
	root.add_child(overlay)
	scrim = overlay.get_node("Scrim") as ColorRect
	scan_line = overlay.get_node("ScanLine") as ColorRect
	status_panel = overlay.get_node("StatusPanel") as PanelContainer
	status_label = overlay.get_node("StatusPanel/Margin/Column/StatusLabel") as Label
	progress_fill = overlay.get_node("StatusPanel/Margin/Column/ProgressTrack/ProgressFill") as ColorRect
	audio = overlay.get_node("AudioPlayer") as AudioStreamPlayer


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _play_cell_tone() -> void:
	_play_tone(520.0, 0.045, 0.075)


func _play_completion_tone() -> void:
	_play_tone(780.0, 0.10, 0.10)


func _play_tone(frequency: float, duration: float, amplitude: float) -> void:
	if audio == null or not audio.is_inside_tree():
		return
	audio.play()
	var playback := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frame_count := mini(roundi(duration * 22050.0), playback.get_frames_available())
	for frame_index in range(frame_count):
		var envelope := 1.0 - float(frame_index) / maxf(float(frame_count), 1.0)
		var sample := sin(TAU * frequency * float(frame_index) / 22050.0) * amplitude * envelope
		playback.push_frame(Vector2(sample, sample))


func _viewport_height() -> float:
	return maxf(owner_ui.get_viewport().get_visible_rect().size.y, 720.0) if owner_ui != null else 720.0


func _on_phase_changed(phase: String) -> void:
	if phase not in [PhaseManager.BATTLE_STARTING, PhaseManager.BATTLE] and _playing:
		cancel()


func _tr(key: String, fallback: String) -> String:
	return LocalizationManager.tr_key(key, fallback)
