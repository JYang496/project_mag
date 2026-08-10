extends RefCounted
class_name PerformanceResult

const SCHEMA_VERSION := 1

static func percentile(samples: PackedFloat64Array, ratio: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := Array(samples)
	sorted.sort()
	var index := clampi(ceili(clampf(ratio, 0.0, 1.0) * sorted.size()) - 1, 0, sorted.size() - 1)
	return float(sorted[index])

static func summarize(samples: PackedFloat64Array) -> Dictionary:
	if samples.is_empty():
		return {"average_frame_ms": 0.0, "p95_frame_ms": 0.0, "p99_frame_ms": 0.0, "maximum_frame_ms": 0.0}
	var total := 0.0
	var maximum := 0.0
	for sample in samples:
		total += sample
		maximum = maxf(maximum, sample)
	return {
		"average_frame_ms": total / float(samples.size()),
		"p95_frame_ms": percentile(samples, 0.95),
		"p99_frame_ms": percentile(samples, 0.99),
		"maximum_frame_ms": maximum,
	}

static func build(
	scenario_id: String,
	seed_value: int,
	enemy_count: int,
	density_profile: String,
	samples: PackedFloat64Array,
	counters: Dictionary,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"revision": OS.get_environment("PHASE4_REVISION"),
		"scenario_id": scenario_id,
		"seed": seed_value,
		"enemy_count": enemy_count,
		"enemy_composition": "registry_probe",
		"density_profile": density_profile,
		"protocol_id": "none",
		"active_cell_rules": [],
		"warmup_frames": int(extra.get("warmup_frames", 0)),
		"sample_frames": samples.size(),
		"raw_frame_ms": Array(samples),
		"spawned_nodes": counters.get("spawned_nodes"),
		"freed_nodes": counters.get("freed_nodes"),
		"registry_queries": counters.get("query_count"),
		"scanned_candidates": counters.get("candidate_checks"),
		"bucket_visits": counters.get("bucket_visits"),
		"collision_contacts": counters.get("collision_contacts"),
		"vfx_spawned": counters.get("vfx_spawned"),
		"pool_hits": counters.get("pool_hits"),
		"pool_misses": counters.get("pool_misses"),
		"shutdown_diagnostics": counters.get("shutdown_diagnostics", 0),
	}
	result.merge(summarize(samples), true)
	result.merge(extra, true)
	return result
