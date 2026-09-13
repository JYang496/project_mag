extends Node

const LONG_FRAME_MS := 33.0
const RUNTIME_DIAGNOSTICS_SCRIPT := preload("res://autoload/RuntimeDiagnostics.gd")
const OVERLAY_SCRIPT := preload("res://UI/scripts/components/world_loading_overlay.gd")
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
var _world_build_overlay_root: Control
var _world_preview_handoff_active := false
var _world_build_handoff_tween: Tween
var _world_preview_cover_tween: Tween
var _world_preview_handoff_started_usec := 0
var _world_input_locked := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world_build_overlay = CanvasLayer.new()
	_world_build_overlay.name = "WorldBuildOverlay"
	_world_build_overlay.layer = 1000
	_world_build_overlay.visible = false
	add_child(_world_build_overlay)
	_world_build_overlay_root = OVERLAY_SCRIPT.new()
	_world_build_overlay.add_child(_world_build_overlay_root)
	_world_build_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_build_overlay_root.stop()

func is_world_input_locked() -> bool:
	return _world_input_locked

func _input(_event: InputEvent) -> void:
	if _world_input_locked:
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	hide_world_build_overlay()

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

# Legacy API retained for world/continue callers; presentation is terminal-only.
func show_world_build_overlay() -> void:
	if not _world_preview_handoff_active:
		begin_world_preview_handoff()
	_stop_world_preview_cover()
	_world_build_overlay_root.modulate.a = 1.0

func hide_world_build_overlay() -> void:
	_stop_world_build_handoff()
	_stop_world_preview_cover()
	_world_preview_handoff_active = false
	if is_instance_valid(_world_build_overlay):
		_world_build_overlay.visible = false
	if is_instance_valid(_world_build_overlay_root):
		_world_build_overlay_root.stop()
		_world_build_overlay_root.modulate.a = 1.0
	_world_input_locked = false

func begin_world_preview_handoff() -> void:
	hide_world_build_overlay()
	_world_input_locked = true
	_world_preview_handoff_active = true
	_world_preview_handoff_started_usec = Time.get_ticks_usec()
	_world_build_overlay_root.begin_loading(str(PlayerData.select_mecha_id))
	_world_build_overlay.visible = true
	_world_build_overlay_root.modulate.a = 0.0
	_world_preview_cover_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_world_preview_cover_tween.tween_property(_world_build_overlay_root, "modulate:a", 1.0, 0.18)

func wait_for_world_preview_cover() -> void:
	await wait_for_world_preview_safe_scene_change()

func wait_for_world_preview_safe_scene_change() -> void:
	while _world_preview_handoff_active and Time.get_ticks_usec() - _world_preview_handoff_started_usec < 180000:
		await get_tree().process_frame

func cancel_world_preview_handoff() -> void:
	hide_world_build_overlay()
	_monitor_frames = false

func is_world_preview_handoff_active() -> bool:
	return _world_preview_handoff_active

func update_world_preview_loading_progress(value: float) -> void:
	if _world_preview_handoff_active:
		_world_build_overlay_root.set_loading_progress(value)

# Accept an already available portrait without loading/instantiating a mech.
func set_world_loading_emblem(texture: Texture2D) -> void:
	_world_build_overlay_root.set_emblem(texture)

func begin_world_build_handoff(duration: float = 0.20) -> void:
	if not _world_preview_handoff_active or _world_build_handoff_tween != null:
		return
	_stop_world_preview_cover()
	_world_build_overlay_root.modulate.a = 1.0
	_world_build_overlay_root.complete_loading()
	_world_build_handoff_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_world_build_handoff_tween.tween_interval(0.12)
	_world_build_handoff_tween.tween_property(_world_build_overlay_root, "modulate:a", 0.0, maxf(duration, 0.0))
	_world_build_handoff_tween.tween_callback(_complete_world_build_handoff)

func wait_for_world_build_handoff() -> void:
	while _world_input_locked and is_inside_tree():
		await get_tree().process_frame

func _complete_world_build_handoff() -> void:
	_world_build_handoff_tween = null
	hide_world_build_overlay()

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
	await wait_for_world_build_handoff()
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
