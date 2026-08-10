extends Node

const SAMPLE_WINDOW := 600

var _frame_samples := PackedFloat64Array()
var _physics_samples := PackedFloat64Array()
var _peaks := {
	"enemies": 0,
	"projectiles": 0,
	"collectables": 0,
	"area_effects": 0,
	"frame_ms": 0.0,
	"physics_ms": 0.0,
}
var _last_snapshot: Dictionary = {}
var _last_battle_snapshot: Dictionary = {}
var _was_in_battle := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"combat_runtime_metrics")
	var phase_manager := get_node_or_null("/root/PhaseManager")
	if phase_manager != null and phase_manager.has_signal("phase_changed"):
		phase_manager.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	var frame_ms := maxf(delta, 0.0) * 1000.0
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	_append_sample(_frame_samples, frame_ms)
	_append_sample(_physics_samples, physics_ms)
	var enemies := _safe_count(&"EnemyRegistry", &"get_enemy_count")
	var collectables := _safe_count(&"CollectableRegistry", &"get_collectable_count")
	var projectiles := get_tree().get_node_count_in_group(&"runtime_projectiles")
	var area_effects := get_tree().get_node_count_in_group(&"runtime_area_effects")
	_peaks.enemies = maxi(int(_peaks.enemies), enemies)
	_peaks.collectables = maxi(int(_peaks.collectables), collectables)
	_peaks.projectiles = maxi(int(_peaks.projectiles), projectiles)
	_peaks.area_effects = maxi(int(_peaks.area_effects), area_effects)
	_peaks.frame_ms = maxf(float(_peaks.frame_ms), frame_ms)
	_peaks.physics_ms = maxf(float(_peaks.physics_ms), physics_ms)
	_last_snapshot = {
		"enemies": enemies,
		"projectiles": projectiles,
		"collectables": collectables,
		"area_effects": area_effects,
		"frame_ms": frame_ms,
		"physics_ms": physics_ms,
	}

func reset() -> void:
	_frame_samples.clear()
	_physics_samples.clear()
	for key in _peaks:
		_peaks[key] = 0.0 if str(key).ends_with("_ms") else 0
	_last_snapshot.clear()

func get_snapshot() -> Dictionary:
	var output := _last_snapshot.duplicate(true)
	output["peaks"] = _peaks.duplicate(true)
	output["frame_average_ms"] = _average(_frame_samples)
	output["frame_p95_ms"] = _percentile(_frame_samples, 0.95)
	output["frame_p99_ms"] = _percentile(_frame_samples, 0.99)
	output["sample_count"] = _frame_samples.size()
	var enemy_system := get_node_or_null("/root/EnemySimulationSystem")
	var projectile_system := get_node_or_null("/root/ProjectileSimulationSystem")
	var collectable_system := get_node_or_null("/root/CollectableRegistry")
	if enemy_system != null and enemy_system.has_method("get_metrics_snapshot"):
		output["enemy_simulation"] = enemy_system.call("get_metrics_snapshot")
	if projectile_system != null and projectile_system.has_method("get_metrics_snapshot"):
		output["projectile_simulation"] = projectile_system.call("get_metrics_snapshot")
	if collectable_system != null and collectable_system.has_method("get_batch_metrics_snapshot"):
		output["collectable_simulation"] = collectable_system.call("get_batch_metrics_snapshot")
	return output

func get_last_battle_snapshot() -> Dictionary:
	return _last_battle_snapshot.duplicate(true)

func _on_phase_changed(new_phase: String) -> void:
	var is_battle := new_phase == "battle"
	if is_battle and not _was_in_battle:
		reset()
	elif not is_battle and _was_in_battle:
		_last_battle_snapshot = get_snapshot()
		if OS.is_debug_build():
			print("[CombatRuntimeMetrics] battle_summary=", JSON.stringify(_last_battle_snapshot))
	_was_in_battle = is_battle

func _safe_count(node_name: StringName, method_name: StringName) -> int:
	var owner := get_node_or_null(NodePath("/root/%s" % node_name))
	return maxi(int(owner.call(method_name)), 0) if owner != null and owner.has_method(method_name) else 0

func _append_sample(samples: PackedFloat64Array, value: float) -> void:
	samples.append(value)
	if samples.size() > SAMPLE_WINDOW:
		samples.remove_at(0)

func _average(samples: PackedFloat64Array) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for value in samples:
		total += value
	return total / float(samples.size())

func _percentile(samples: PackedFloat64Array, percentile: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := Array(samples)
	sorted.sort()
	return float(sorted[clampi(ceili(float(sorted.size()) * percentile) - 1, 0, sorted.size() - 1)])
