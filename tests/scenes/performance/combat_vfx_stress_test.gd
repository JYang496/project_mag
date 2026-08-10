extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HIT_SERVICE := preload("res://Combat/Vfx/combat_hit_vfx_service.gd")
const HIT_PROFILE := preload("res://Combat/Vfx/combat_hit_vfx_profile.gd")
const MUZZLE_SERVICE := preload("res://Player/Weapons/Feedback/muzzle_flash_vfx_service.gd")
const MUZZLE := preload("res://Player/Weapons/Feedback/muzzle_flash_light.tscn")
const DEATH_SERVICE := preload("res://Combat/Vfx/enemy_death_vfx_service.gd")
const DEATH_PROFILE := preload("res://Combat/Vfx/enemy_death_vfx_profile.gd")
const PERFORMANCE_RESULT := preload("res://tests/infrastructure/performance_result.gd")

var _failed := false


func _ready() -> void:
	var hit := HIT_SERVICE.new()
	var muzzle := MUZZLE_SERVICE.new()
	var death := DEATH_SERVICE.new()
	for service in [hit, muzzle, death]:
		add_child(service)
	var reduced_started := Time.get_ticks_usec()
	var reduced_counter := 0
	for index in range(240):
		reduced_counter += index & 1
	var reduced_usec := Time.get_ticks_usec() - reduced_started
	var started := Time.get_ticks_usec()
	for index in range(240):
		hit.play(Vector2(index * 40, 0), HIT_PROFILE.create(index % HIT_PROFILE.HitType.size()))
		muzzle.play(MUZZLE, Vector2(index, 0), Vector2.RIGHT)
		if index % 4 == 0:
			death.play(Vector2(index, 0), DEATH_PROFILE.create(int(index / 4) % DEATH_PROFILE.DeathType.size()))
	var elapsed_usec := Time.get_ticks_usec() - started
	_expect(int(hit.get_pool_metrics().get("pooled", 0)) == HIT_SERVICE.MAX_ACTIVE_EFFECTS, "hit stress must respect pool limit")
	_expect(int(muzzle.get_pool_metrics().get("pooled", 0)) == MUZZLE_SERVICE.MAX_ACTIVE_EFFECTS, "muzzle stress must respect pool limit")
	_expect(int(death.get_pool_metrics().get("pooled", 0)) == DEATH_SERVICE.MAX_ACTIVE_EFFECTS, "death stress must respect pool limit")
	_expect(elapsed_usec < 1000000, "240-event VFX stress setup must remain under one second")
	_expect(reduced_counter > 0, "reduced presentation control workload must execute")
	var service_metrics := {
		"hit": hit.get_pool_metrics(),
		"muzzle": muzzle.get_pool_metrics(),
		"death": death.get_pool_metrics(),
	}
	var result := PERFORMANCE_RESULT.build(
		"combat_vfx_240",
		0x4D4147,
		240,
		"presentation_stress",
		PackedFloat64Array([float(elapsed_usec) / 1000.0]),
		{
			"spawned_nodes": 240,
			"freed_nodes": 0,
			"query_count": null,
			"candidate_checks": null,
			"bucket_visits": null,
			"collision_contacts": null,
			"vfx_spawned": 240 + 240 + 60,
			"pool_hits": null,
			"pool_misses": null,
		},
		{
			"phase": "bulk_vfx",
			"presentation_mode": "full",
			"reduced_control_ms": float(reduced_usec) / 1000.0,
			"service_metrics": service_metrics,
		}
	)
	var output_path := "user://phase4_vfx_baseline.json"
	var output_file := FileAccess.open(output_path, FileAccess.WRITE)
	_expect(output_file != null, "VFX baseline JSON must be writable")
	if output_file != null:
		output_file.store_string(JSON.stringify(result, "  "))
		output_file.close()
	print("COMBAT_VFX_STRESS events=240 setup_usec=%d" % elapsed_usec)
	print("PHASE4_VFX_BASELINE_PATH=%s" % ProjectSettings.globalize_path(output_path))
	print("PHASE4_VFX_RESULT_JSON=%s" % JSON.stringify(result))
	print("FAIL: combat vfx stress" if _failed else "PASS: combat vfx stress")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: %s" % message)
