extends Node

const LONG_FRAME_MS := 33.0
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

func _ready() -> void:
	_world_build_overlay = CanvasLayer.new()
	_world_build_overlay.name = "WorldBuildOverlay"
	_world_build_overlay.layer = 1000
	_world_build_overlay.visible = false
	add_child(_world_build_overlay)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.015, 0.02, 0.03, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	_world_build_overlay.add_child(background)
	var label := Label.new()
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
	if label == "world_ready":
		hide_world_build_overlay()
	if not enabled or _marks.has(label):
		return
	_marks[label] = Time.get_ticks_usec()
	_current_phase = _phase_after_mark(label)
	print("[LoadingPerformance] run=%d flow=%s mark=%s" % [_run_id, _flow, label])

func show_world_build_overlay() -> void:
	if _world_build_overlay != null:
		_world_build_overlay.visible = true

func hide_world_build_overlay() -> void:
	if _world_build_overlay != null:
		_world_build_overlay.visible = false

func begin_segment(label: String) -> void:
	if not enabled:
		return
	_segments[label] = Time.get_ticks_usec()
	print("[LoadingPerformance] run=%d flow=%s segment=%s event=started" % [_run_id, _flow, label])

func end_segment(label: String) -> void:
	if not enabled:
		return
	if not _segments.has(label):
		push_warning("LoadingPerformance segment ended without a start: %s" % label)
		return
	var duration_us := Time.get_ticks_usec() - int(_segments[label])
	_segments.erase(label)
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
