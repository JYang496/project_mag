extends Node

const SCENARIO := preload("res://tests/showcases/weapon/weapon_performance_scenario.gd")
const RESULT := preload("res://tests/infrastructure/performance_result.gd")
const REPORT := preload("res://tests/showcases/weapon/weapon_performance_report.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false


func _ready() -> void:
	var first := SCENARIO.quick_suite(3)
	var second := SCENARIO.quick_suite(3)
	_expect(first.size() == 4, "quick suite must expose four deterministic scenarios")
	_expect(first[0].to_dictionary() == second[0].to_dictionary(), "scenario construction must be deterministic")
	_expect(first[1].weapon_index == 3, "quick suite must retain selected weapon")
	var stress_suite := SCENARIO.stress_suite(2)
	_expect(stress_suite.size() == 8, "stress suite must cover all eight designed workloads")
	_expect(&"enemy_density" in stress_suite[4].tags, "high-density scenario must retain typed tags")
	_expect(&"lifecycle" in stress_suite[7].tags, "lifecycle scenario must retain typed tags")
	_expect(SCENARIO.all_weapon_suite(15).size() == 15, "weapon matrix must create one standard sequence per weapon")
	var extreme := SCENARIO.extreme_performance_suite(15)
	_expect(extreme.size() == 15, "performance button must cover every weapon")
	_expect(extreme[0].target_count == 120 and extreme[0].real_enemy_count == 120, "extreme mode must spawn real high-density enemies")
	_expect(extreme[0].to_dictionary() == SCENARIO.extreme_performance_suite(15)[0].to_dictionary(), "extreme workload must stay deterministic")
	_expect(REPORT.get_base_directory("extreme_performance") == "res://docs/performance/weapon_lab", "extreme reports must target project docs")
	var summary := RESULT.summarize(PackedFloat64Array([4.0, 8.0, 12.0, 16.0, 20.0]))
	_expect(is_equal_approx(float(summary.p50_frame_ms), 12.0), "p50 calculation drifted")
	_expect(is_equal_approx(float(summary.p95_frame_ms), 20.0), "p95 calculation drifted")
	var scenario_result := RESULT.build("contract", 7, 0, "none", PackedFloat64Array([8.0]), {}, {})
	var report := REPORT.build_suite("contract", [scenario_result], "2026-09-19T00:00:00")
	_expect(int(report.schema_version) == 2, "suite report schema must be v2")
	_expect(int(report.scenario_count) == 1, "suite report must retain scenario results")
	print("FAIL: weapon performance lab contract" if _failed else "PASS: weapon performance lab contract")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
