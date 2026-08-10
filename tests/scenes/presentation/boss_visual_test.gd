extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const BASE_ENEMY := preload("res://Npc/enemy/scenes/base_enemy.tscn")

var _failed := false


func _ready() -> void:
	var boss := BASE_ENEMY.instantiate() as BaseEnemy
	boss.is_boss = true
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(boss)
	await get_tree().process_frame
	var runtime := boss.boss_visual_runtime
	_expect(runtime != null, "boss metadata must install the shared visual runtime")
	_expect(runtime != null and runtime.get_node_or_null("BossHudLayer/BossHpHud") != null, "boss runtime must provide a dedicated HP HUD")
	_expect(runtime != null and bool(runtime.get_meta(&"boss_entrance_visual_active", false)), "boss runtime must begin with a brief environment entrance transition")
	if runtime != null:
		var footprint := runtime.call("get_hybrid_aura_visual") as Dictionary
		_expect(footprint.get("relationship_kind") == &"boss_footprint", "boss must expose a rank-specific ground footprint")
		boss.set_boss_visual_phase(1, 3)
		var overlay := runtime.get_node_or_null("BossHudLayer/BossEnvironmentOverlay") as ColorRect
		_expect(overlay != null and overlay.color.a > 0.0, "boss phase change must briefly affect the environment channel")
		boss.begin_boss_attack_telegraph(0.7)
		var warning := runtime.call("get_hybrid_aura_visual") as Dictionary
		_expect(warning.get("relationship_kind") == &"boss_attack_warning", "boss attack must begin in WARNING state")
		runtime.call("_process", 0.56)
		_expect(boss.is_boss_attack_damage_confirmed(), "boss damage gate must open only after the confirm threshold")
		var confirm := runtime.call("get_hybrid_aura_visual") as Dictionary
		_expect(confirm.get("relationship_kind") == &"boss_attack_confirm", "boss telegraph must visibly enter CONFIRM before damage")
	boss.death_runtime.finalize_death(null, false)
	_expect(bool(boss.get_meta(&"boss_death_release_active", false)), "boss death must enter the delayed release state")
	_expect(not boss.is_queued_for_deletion(), "boss gameplay signal may resolve immediately but the death silhouette must not queue_free immediately")
	await get_tree().create_timer(0.20).timeout
	_expect(is_instance_valid(boss), "boss death silhouette must survive the opening impact stage")
	await get_tree().create_timer(1.42).timeout
	_expect(not is_instance_valid(boss), "boss death silhouette must release after the 1.2-1.8 second sequence")
	print("FAIL: boss visual" if _failed else "PASS: boss visual")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
