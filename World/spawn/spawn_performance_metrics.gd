extends RefCounted
class_name SpawnPerformanceMetrics

var requested := 0
var instantiated := 0
var scheduled_for_activation := 0
var batches := 0
var peak_batch_size := 0

func reset() -> void:
	requested = 0
	instantiated = 0
	scheduled_for_activation = 0
	batches = 0
	peak_batch_size = 0

func begin_batch(count: int) -> void:
	var safe_count := maxi(count, 0)
	requested += safe_count
	batches += 1
	peak_batch_size = maxi(peak_batch_size, safe_count)

func record_instantiated() -> void:
	instantiated += 1

func record_scheduled_for_activation() -> void:
	scheduled_for_activation += 1

func snapshot() -> Dictionary:
	return {
		"requested": requested,
		"instantiated": instantiated,
		"scheduled_for_activation": scheduled_for_activation,
		"batches": batches,
		"peak_batch_size": peak_batch_size,
	}
