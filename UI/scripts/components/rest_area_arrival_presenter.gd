extends RefCounted
class_name RestAreaArrivalPresenter

const ARRIVAL_DURATION_SEC := 1.40
const GROUND_REVEAL_DELAY_SEC := 0.18
const INITIAL_GROUND_REVEAL_DELAY_SEC := 0.10
const GROUND_REVEAL_DURATION_SEC := 0.82
const SCRIM_ALPHA := 0.18
const INITIAL_COVER_ALPHA := 1.0
const INITIAL_COVER_RELEASE_SEC := 0.38
const FIRST_SERVICE_INTRO_DURATION_SEC := 4.20

var owner_ui: UI
var overlay: Control
var scrim: ColorRect
var scan_line: ColorRect
var status_panel: PanelContainer
var status_label: Label
var progress_fill: ColorRect
var audio: AudioStreamPlayer

var _rest_area: Node
var _ground_view: HybridGroundView3D
var _transition_tween: Tween
var _generation := 0
var _prepared := false
var _playing := false
var _initial_cover_primed := false


func bind(ui: UI, root: Control) -> void:
	owner_ui = ui
	_build_overlay(root)
	if not PhaseManager.phase_changed.is_connected(_on_phase_changed):
		PhaseManager.phase_changed.connect(_on_phase_changed)


func prepare(initial_cover: bool = false) -> void:
	_generation += 1
	_prepared = true
	_initial_cover_primed = initial_cover
	_resolve_world_nodes()
	_set_rest_area_locked(true)
	if _ground_view != null:
		_ground_view.prepare_rest_area_arrival()
	if initial_cover:
		_prepare_visual_state(true)


func play(skip_readiness_wait: bool = false) -> void:
	if not _prepared:
		prepare()
	var generation := _generation
	_playing = true
	if not skip_readiness_wait:
		await owner_ui.get_tree().process_frame
		await owner_ui.get_tree().process_frame
	if generation != _generation:
		return
	if PhaseManager.current_state() != PhaseManager.REST:
		cancel()
		return
	_resolve_world_nodes()
	_set_rest_area_locked(true)
	if _ground_view != null:
		_ground_view.prepare_rest_area_arrival()
	var initial_handoff := _initial_cover_primed
	var show_service_intro := initial_handoff and not SaveManager.rest_area_service_intro_seen
	_prepare_visual_state(initial_handoff)
	await _play_timeline(initial_handoff, show_service_intro)
	if generation != _generation:
		return
	_finish_visual_state()
	_prepared = false
	_playing = false
	_initial_cover_primed = false
	if show_service_intro:
		SaveManager.mark_rest_area_service_intro_seen()


func cancel() -> void:
	_generation += 1
	_prepared = false
	_playing = false
	_initial_cover_primed = false
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	_finish_visual_state()


func is_playing() -> bool:
	return _playing


func _prepare_visual_state(initial_cover: bool = false) -> void:
	if overlay == null:
		return
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.color.a = INITIAL_COVER_ALPHA if initial_cover else 0.0
	scan_line.modulate.a = 0.0
	scan_line.scale = Vector2(0.0, 1.0)
	status_panel.modulate.a = 0.0
	status_panel.scale = Vector2(0.96, 0.96)
	status_label.text = _tr("rest_arrival.calibrating", "SAFE ZONE // CALIBRATING")
	progress_fill.scale = Vector2(0.0, 1.0)


func _play_timeline(initial_handoff: bool = false, show_service_intro: bool = false) -> void:
	if owner_ui == null or not owner_ui.is_inside_tree():
		return
	_transition_tween = owner_ui.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.set_parallel(true)
	var cover_release_duration := INITIAL_COVER_RELEASE_SEC if initial_handoff else 0.18
	var ground_reveal_delay := INITIAL_GROUND_REVEAL_DELAY_SEC if initial_handoff else GROUND_REVEAL_DELAY_SEC
	_transition_tween.tween_property(scrim, "color:a", SCRIM_ALPHA, cover_release_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(status_panel, "modulate:a", 1.0, 0.18).set_delay(0.06)
	_transition_tween.tween_property(status_panel, "scale", Vector2.ONE, 0.22).set_delay(0.06)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(scan_line, "modulate:a", 0.72, 0.12).set_delay(0.12)
	_transition_tween.tween_property(scan_line, "scale:x", 1.0, 0.72).set_delay(0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_method(
		_set_arrival_progress,
		0.0,
		1.0,
		GROUND_REVEAL_DURATION_SEC
	).set_delay(ground_reveal_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(progress_fill, "scale:x", 0.82, 0.82).set_delay(0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_callback(_set_status.bind(
		_tr("rest_arrival.services", "REST FACILITIES // COMING ONLINE")
	)).set_delay(0.62)
	_transition_tween.tween_callback(_set_status.bind(
		_tr("rest_arrival.complete", "REST FACILITIES // ONLINE")
	)).set_delay(1.06)
	_transition_tween.tween_callback(_play_completion_tone).set_delay(1.06)
	_transition_tween.tween_property(progress_fill, "scale:x", 1.0, 0.14).set_delay(1.02)
	_transition_tween.tween_property(scan_line, "modulate:a", 0.0, 0.18).set_delay(1.02)
	_transition_tween.tween_property(scrim, "color:a", 0.0, 0.28).set_delay(1.10)
	_transition_tween.tween_property(status_panel, "modulate:a", 0.0, 0.20).set_delay(1.20)
	_transition_tween.tween_callback(_play_arrival_tone).set_delay(0.34)
	if show_service_intro:
		var service_zones: Array[int] = [0, 1, 2, 6, 4]
		var service_names := ["PURCHASE", "UPGRADE", "WAREHOUSE", "BOARD", "PROTOCOL"]
		for index in range(service_zones.size()):
			var delay := 0.62 + float(index) * 0.62
			_transition_tween.tween_callback(_focus_service.bind(service_zones[index], service_names[index])).set_delay(delay)
		_transition_tween.tween_callback(_clear_service_focus).set_delay(FIRST_SERVICE_INTRO_DURATION_SEC - 0.12)
		_transition_tween.tween_interval(FIRST_SERVICE_INTRO_DURATION_SEC)
	await _transition_tween.finished
	_transition_tween = null


func _set_arrival_progress(value: float) -> void:
	if _ground_view == null:
		return
	var progress := clampf(value, 0.0, 1.0)
	_ground_view.set_rest_area_arrival_state(progress, sin(progress * PI))


func _finish_visual_state() -> void:
	_clear_service_focus()
	if _ground_view != null and is_instance_valid(_ground_view):
		_ground_view.finish_rest_area_arrival()
	if audio != null and is_instance_valid(audio):
		audio.stop()
	_set_rest_area_locked(false)
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scrim.color.a = 0.0
		scan_line.modulate.a = 0.0
		status_panel.modulate.a = 0.0

func _focus_service(zone_id: int, fallback_name: String) -> void:
	if _rest_area != null and is_instance_valid(_rest_area) and _rest_area.has_method("set_arrival_service_focus"):
		_rest_area.call("set_arrival_service_focus", zone_id)
	_set_status(_tr("rest_arrival.service.%s" % fallback_name.to_lower(), "SERVICE ONLINE // %s" % fallback_name))

func _clear_service_focus() -> void:
	if _rest_area != null and is_instance_valid(_rest_area) and _rest_area.has_method("clear_arrival_service_focus"):
		_rest_area.call("clear_arrival_service_focus")


func _resolve_world_nodes() -> void:
	if owner_ui == null or not owner_ui.is_inside_tree():
		return
	var scene := owner_ui.get_tree().current_scene
	if scene != null:
		_ground_view = scene.get_node_or_null("HybridGroundView3D") as HybridGroundView3D
	var rest_areas := owner_ui.get_tree().get_nodes_in_group(&"rest_area")
	_rest_area = rest_areas[0] if not rest_areas.is_empty() else null


func _set_rest_area_locked(locked: bool) -> void:
	if _rest_area != null and is_instance_valid(_rest_area) \
			and _rest_area.has_method("set_arrival_transition_locked"):
		_rest_area.call("set_arrival_transition_locked", locked)


func _build_overlay(root: Control) -> void:
	overlay = Control.new()
	overlay.name = "RestAreaArrivalOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 410
	overlay.visible = false
	root.add_child(overlay)

	scrim = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.008, 0.040, 0.030, 0.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(scrim)

	scan_line = ColorRect.new()
	scan_line.set_anchors_preset(Control.PRESET_CENTER)
	scan_line.offset_left = -420.0
	scan_line.offset_top = -1.0
	scan_line.offset_right = 420.0
	scan_line.offset_bottom = 1.0
	scan_line.pivot_offset = Vector2(420.0, 1.0)
	scan_line.color = Color(0.42, 1.0, 0.58, 0.82)
	scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(scan_line)

	status_panel = PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_panel.offset_left = -220.0
	status_panel.offset_top = 38.0
	status_panel.offset_right = 220.0
	status_panel.offset_bottom = 104.0
	status_panel.pivot_offset = Vector2(220.0, 33.0)
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", _build_status_style())
	overlay.add_child(status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 10)
	status_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.70, 1.0, 0.80, 1.0))
	column.add_child(status_label)
	var progress_track := ColorRect.new()
	progress_track.custom_minimum_size = Vector2(0.0, 3.0)
	progress_track.color = Color(0.06, 0.20, 0.14, 0.92)
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress_track)
	progress_fill = ColorRect.new()
	progress_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_fill.color = Color(0.38, 0.92, 0.58, 1.0)
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_fill.pivot_offset = Vector2.ZERO
	progress_track.add_child(progress_fill)

	audio = AudioStreamPlayer.new()
	audio.bus = &"SFX"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.18
	audio.stream = stream
	root.add_child(audio)


func _build_status_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.075, 0.050, 0.93)
	style.border_color = Color(0.30, 0.82, 0.50, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.03, 0.02, 0.62)
	style.shadow_size = 6
	return style


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _play_arrival_tone() -> void:
	_play_tone(390.0, 0.07, 0.055)


func _play_completion_tone() -> void:
	_play_tone(585.0, 0.12, 0.075)


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


func _on_phase_changed(phase: String) -> void:
	if phase != PhaseManager.REST and (_prepared or _playing):
		cancel()


func _tr(key: String, fallback: String) -> String:
	return LocalizationManager.tr_key(key, fallback)
