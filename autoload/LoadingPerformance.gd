extends Node

const LONG_FRAME_MS := 33.0
const RUNTIME_DIAGNOSTICS_SCRIPT := preload("res://autoload/RuntimeDiagnostics.gd")
const START_MENU_PREVIEW_SCRIPT := preload("res://UI/scripts/components/start_menu_backdrop.gd")
const WORLD_PREVIEW_COVER_SEC := 0.62
const WORLD_PREVIEW_SAFE_SCENE_CHANGE_SEC := 0.34
const ORDER := [
	"start_menu_ready", "prewarm_started", "prewarm_finished",
	"start_button_pressed", "threaded_load_started", "threaded_load_finished",
	"world_scene_changed", "world_ready", "first_stable_frame",
]

var enabled := OS.is_debug_build()
var _run_id := 0
var _flow := ""
var _current_phase := "idle"
var _marks: Dictionary = {}
var _segments: Dictionary = {}
var _long_frames: Array[Dictionary] = []
var _monitor_frames := false
var _world_build_overlay: CanvasLayer
var _world_build_overlay_root: ColorRect
var _world_build_label: Label
var _world_preview: Control
var _world_preview_handoff_active := false
var _world_preview_cover_tween: Tween
var _world_build_handoff_tween: Tween
var _world_preview_handoff_started_usec := 0

func _ready() -> void:
	_world_build_overlay = CanvasLayer.new()
	_world_build_overlay.name = "WorldBuildOverlay"
	_world_build_overlay.layer = 1000
	_world_build_overlay.visible = false
	add_child(_world_build_overlay)
	var background := ColorRect.new()
	_world_build_overlay_root = background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.015, 0.02, 0.03, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_world_build_overlay.add_child(background)
	_world_preview = Control.new()
	_world_preview.name = "WorldEntryRestPreview"
	_world_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_preview.set_script(START_MENU_PREVIEW_SCRIPT)
	_world_preview.visible = false
	background.add_child(_world_preview)
	var label := Label.new()
	_world_build_label = label
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = "Loading..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	background.add_child(label)

func _process(delta: float) -> void:
	if not enabled or not _monitor_frames:
		return
	var milliseconds := delta * 1000.0
	if milliseconds > LONG_FRAME_MS:
		var since_start_ms := -1.0
		if _marks.has("start_button_pressed"):
			since_start_ms = (Time.get_ticks_usec() - int(_marks["start_button_pressed"])) / 1000.0
		_long_frames.append({
			"phase": _current_phase,
			"milliseconds": milliseconds,
			"since_start_ms": since_start_ms,
		})

func begin_flow(flow: String) -> void:
	if _marks.has("start_button_pressed"):
		begin_menu_session()
	_flow = flow
	mark("start_button_pressed")
	_monitor_frames = true

func begin_menu_session() -> void:
	hide_world_build_overlay()
	_run_id += 1
	_flow = "menu"
	_current_phase = "menu_startup"
	_marks.clear()
	_segments.clear()
	_long_frames.clear()
	_monitor_frames = false
	mark("start_menu_ready")

func mark(label: String) -> void:
	if not enabled or _marks.has(label):
		return
	_marks[label] = Time.get_ticks_usec()
	_current_phase = _phase_after_mark(label)
	if RUNTIME_DIAGNOSTICS_SCRIPT.verbose_logs_enabled():
		print("[LoadingPerformance] run=%d flow=%s mark=%s" % [_run_id, _flow, label])

func show_world_build_overlay() -> void:
	if _world_build_overlay != null:
		_stop_world_build_handoff()
		if _world_preview_handoff_active:
			_world_build_overlay.visible = true
			_world_build_overlay_root.modulate.a = 1.0
			return
		_stop_world_preview_cover()
		_world_preview_handoff_active = false
		_world_build_overlay_root.color.a = 1.0
		_world_build_overlay_root.modulate.a = 1.0
		_world_preview.visible = false
		_world_build_label.visible = true
		_world_build_overlay.visible = true

func hide_world_build_overlay() -> void:
	if _world_build_overlay != null:
		_stop_world_build_handoff()
		_stop_world_preview_cover()
		_world_preview_handoff_active = false
		_world_build_overlay.visible = false
		_world_preview.visible = false
		_world_build_label.visible = false
		_world_build_overlay_root.color.a = 1.0
		_world_build_overlay_root.modulate.a = 1.0

func begin_world_preview_handoff() -> void:
	if _world_build_overlay == null or _world_build_overlay_root == null or _world_preview == null:
		return
	_stop_world_build_handoff()
	_stop_world_preview_cover()
	_world_preview_handoff_active = true
	_world_preview_handoff_started_usec = Time.get_ticks_usec()
	_world_build_overlay.visible = true
	_world_build_overlay_root.modulate.a = 1.0
	_world_build_overlay_root.color.a = 0.0
	_world_build_label.visible = false
	_world_preview.visible = true
	_world_preview.call("reset_handoff")
	_world_preview.call("begin_loading")
	_world_preview.call("set_loading_progress", 0.06)
	_world_preview_cover_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_world_preview_cover_tween.set_parallel(true)
	_world_preview_cover_tween.tween_property(
		_world_build_overlay_root,
		"color:a",
		1.0,
		0.34
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_world_preview_cover_tween.tween_method(
		Callable(self, "_set_world_preview_progress"),
		0.0,
		1.0,
		WORLD_PREVIEW_COVER_SEC
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func wait_for_world_preview_cover() -> void:
	var tween := _world_preview_cover_tween
	if tween != null and tween.is_valid():
		await tween.finished

func wait_for_world_preview_safe_scene_change() -> void:
	if not _world_preview_handoff_active:
		return
	var elapsed_sec := (Time.get_ticks_usec() - _world_preview_handoff_started_usec) / 1000000.0
	var remaining_sec := WORLD_PREVIEW_SAFE_SCENE_CHANGE_SEC - elapsed_sec
	if remaining_sec > 0.0:
		await get_tree().create_timer(remaining_sec).timeout

func cancel_world_preview_handoff() -> void:
	_stop_world_preview_cover()
	_world_preview_handoff_active = false
	if _world_build_overlay != null:
		_world_build_overlay.visible = false
		_world_build_overlay_root.color.a = 1.0
		_world_build_overlay_root.modulate.a = 1.0
	if _world_preview != null:
		_world_preview.visible = false
	if _world_build_label != null:
		_world_build_label.visible = false

func is_world_preview_handoff_active() -> bool:
	return _world_preview_handoff_active

func update_world_preview_loading_progress(value: float) -> void:
	if not _world_preview_handoff_active or _world_preview == null or not is_instance_valid(_world_preview):
		return
	_world_preview.call("set_loading_progress", value)

func _set_world_preview_progress(value: float) -> void:
	if _world_preview != null and is_instance_valid(_world_preview):
		_world_preview.call("set_handoff_progress", value)

func begin_world_build_handoff(duration: float = 0.12) -> void:
	if _world_build_overlay == null or not _world_build_overlay.visible:
		return
	update_world_preview_loading_progress(1.0)
	_stop_world_build_handoff()
	_world_build_handoff_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_world_build_handoff_tween.tween_property(
		_world_build_overlay_root,
		"modulate:a",
		0.0,
		maxf(duration, 0.0)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_world_build_handoff_tween.tween_callback(_complete_world_build_handoff)

func _complete_world_build_handoff() -> void:
	if _world_build_overlay != null:
		_world_build_overlay.visible = false
		_world_build_overlay_root.modulate.a = 1.0
		_world_build_overlay_root.color.a = 1.0
	_world_preview_handoff_active = false
	if _world_preview != null:
		_world_preview.visible = false
	if _world_build_label != null:
		_world_build_label.visible = false
	_world_build_handoff_tween = null

func _stop_world_build_handoff() -> void:
	if _world_build_handoff_tween != null and _world_build_handoff_tween.is_valid():
		_world_build_handoff_tween.kill()
	_world_build_handoff_tween = null

func _stop_world_preview_cover() -> void:
	if _world_preview_cover_tween != null and _world_preview_cover_tween.is_valid():
		_world_preview_cover_tween.kill()
	_world_preview_cover_tween = null

func begin_segment(label: String) -> void:
	if not enabled:
		return
	_segments[label] = Time.get_ticks_usec()
	if RUNTIME_DIAGNOSTICS_SCRIPT.verbose_logs_enabled():
		print("[LoadingPerformance] run=%d flow=%s segment=%s event=started" % [_run_id, _flow, label])

func end_segment(label: String) -> void:
	if not enabled:
		return
	if not _segments.has(label):
		push_warning("LoadingPerformance segment ended without a start: %s" % label)
		return
	var duration_us := Time.get_ticks_usec() - int(_segments[label])
	_segments.erase(label)
	if RUNTIME_DIAGNOSTICS_SCRIPT.verbose_logs_enabled():
		print("[LoadingPerformance] run=%d flow=%s segment=%s event=finished duration_us=%d duration_ms=%.3f" % [
			_run_id, _flow, label, duration_us, duration_us / 1000.0,
		])

func finish_flow() -> void:
	hide_world_build_overlay()
	if not enabled:
		return
	_monitor_frames = false
	print_summary()
	if OS.get_cmdline_user_args().has("--loading-benchmark"):
		get_tree().quit()

func print_summary() -> void:
	if not enabled:
		return
	var parts := PackedStringArray()
	var previous_label := ""
	for label in ORDER:
		if not _marks.has(label):
			parts.append("%s=missing" % label)
			continue
		if previous_label != "" and _marks.has(previous_label):
			var elapsed_ms := (int(_marks[label]) - int(_marks[previous_label])) / 1000.0
			parts.append("%s=%.2fms" % [label, elapsed_ms])
		else:
			parts.append("%s=marked" % label)
		previous_label = label
	var longest := 0.0
	var phase_totals: Dictionary = {}
	for frame in _long_frames:
		var frame_ms := float(frame.get("milliseconds", 0.0))
		var phase := str(frame.get("phase", "unknown"))
		longest = max(longest, frame_ms)
		var phase_summary: Dictionary = phase_totals.get(phase, {"count": 0, "longest": 0.0})
		phase_summary["count"] = int(phase_summary["count"]) + 1
		phase_summary["longest"] = max(float(phase_summary["longest"]), frame_ms)
		phase_totals[phase] = phase_summary
	print("[LoadingPerformance] run=%d flow=%s %s long_frames=%d longest=%.2fms" % [
		_run_id, _flow, " ".join(parts), _long_frames.size(), longest,
	])
	if RUNTIME_DIAGNOSTICS_SCRIPT.verbose_logs_enabled():
		for phase in phase_totals:
			var phase_summary: Dictionary = phase_totals[phase]
			print("[LoadingPerformance] long_frame_phase=%s count=%d longest=%.2fms" % [
				phase, int(phase_summary["count"]), float(phase_summary["longest"]),
			])
		for frame in _long_frames:
			print("[LoadingPerformance] long_frame phase=%s duration=%.2fms since_start=%.2fms" % [
				str(frame.get("phase", "unknown")),
				float(frame.get("milliseconds", 0.0)),
				float(frame.get("since_start_ms", -1.0)),
			])

func _phase_after_mark(label: String) -> String:
	match label:
		"start_menu_ready":
			return "menu_idle"
		"prewarm_started":
			return "menu_prewarm"
		"prewarm_finished":
			return "menu_ready"
		"start_button_pressed":
			return "run_state_preparation"
		"threaded_load_started":
			return "threaded_world_load"
		"threaded_load_finished":
			return "scene_transition"
		"world_scene_changed":
			return "world_build"
		"world_ready":
			return "stabilizing_first_frame"
		"first_stable_frame":
			return "interactive"
		_:
			return _current_phase
