extends RefCounted
class_name SpawnPerformanceMetrics

var requested := 0
var instantiated := 0
var scheduled_for_activation := 0
var batches := 0
var peak_batch_size := 0
var ticks := 0
var peak_tick_instantiated := 0
var peak_tick_ms := 0.0
var metadata_ms := 0.0
var instantiate_ms := 0.0
var position_ms := 0.0
var signal_ms := 0.0
var spawn_call_ms := 0.0
var vanguard_candidates_ms := 0.0
var vanguard_loop_ms := 0.0
var _tick_instantiated_before := 0
var _tick_started_usec := 0

func reset() -> void:
	requested = 0
	instantiated = 0
	scheduled_for_activation = 0
	batches = 0
	peak_batch_size = 0
	ticks = 0
	peak_tick_instantiated = 0
	peak_tick_ms = 0.0
	metadata_ms = 0.0
	instantiate_ms = 0.0
	position_ms = 0.0
	signal_ms = 0.0
	spawn_call_ms = 0.0
	vanguard_candidates_ms = 0.0
	vanguard_loop_ms = 0.0
	_tick_instantiated_before = 0
	_tick_started_usec = 0

func begin_tick() -> void:
	_tick_instantiated_before = instantiated
	_tick_started_usec = Time.get_ticks_usec()

func end_tick() -> void:
	if _tick_started_usec == 0:
		return
	ticks += 1
	peak_tick_instantiated = maxi(peak_tick_instantiated, instantiated - _tick_instantiated_before)
	peak_tick_ms = maxf(peak_tick_ms, float(Time.get_ticks_usec() - _tick_started_usec) / 1000.0)
	_tick_started_usec = 0

func begin_batch(count: int) -> void:
	var safe_count := maxi(count, 0)
	requested += safe_count
	batches += 1
	peak_batch_size = maxi(peak_batch_size, safe_count)

func record_instantiated() -> void:
	instantiated += 1

func record_scheduled_for_activation() -> void:
	scheduled_for_activation += 1

func record_metadata_usec(elapsed: int) -> void:
	metadata_ms += float(elapsed) / 1000.0

func record_instantiate_usec(elapsed: int) -> void:
	instantiate_ms += float(elapsed) / 1000.0

func record_position_usec(elapsed: int) -> void:
	position_ms += float(elapsed) / 1000.0

func record_signal_usec(elapsed: int) -> void:
	signal_ms += float(elapsed) / 1000.0

func record_spawn_call_usec(elapsed: int) -> void:
	spawn_call_ms += float(elapsed) / 1000.0

func record_vanguard_candidates_usec(elapsed: int) -> void:
	vanguard_candidates_ms += float(elapsed) / 1000.0

func record_vanguard_loop_usec(elapsed: int) -> void:
	vanguard_loop_ms += float(elapsed) / 1000.0

func snapshot() -> Dictionary:
	return {
		"requested": requested,
		"instantiated": instantiated,
		"scheduled_for_activation": scheduled_for_activation,
		"batches": batches,
		"peak_batch_size": peak_batch_size,
		"ticks": ticks,
		"peak_tick_instantiated": peak_tick_instantiated,
		"peak_tick_ms": peak_tick_ms,
		"metadata_ms": metadata_ms,
		"instantiate_ms": instantiate_ms,
		"position_ms": position_ms,
		"signal_ms": signal_ms,
		"spawn_call_ms": spawn_call_ms,
		"vanguard_candidates_ms": vanguard_candidates_ms,
		"vanguard_loop_ms": vanguard_loop_ms,
	}
