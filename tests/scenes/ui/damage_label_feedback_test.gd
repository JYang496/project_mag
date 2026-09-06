extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HIT_LABEL_SCENE := preload("res://UI/labels/hit_label.tscn")
const PROJECTED_UI := preload("res://Visual/Oblique/projected_world_ui_service.gd")

class DummyDamageTarget:
	extends Node
	var hp := 100
	var max_hp := 100
	var dead := false

	func read_hp() -> int:
		return hp

	func write_hp(value: int) -> void:
		hp = value

	func read_max_hp() -> int:
		return max_hp

	func read_dead() -> bool:
		return dead

	func write_dead(value: bool) -> void:
		dead = value

class DummyFeedbackNpc:
	extends Node2D
	var is_dead := false
	var hit_label_merge_window_sec := 0.04
	var hit_label_periodic_merge_window_sec := 0.12

	func get_incoming_damage_max_hp() -> int:
		return 200

var _failed := false
var _hybrid_layer: CanvasLayer

func _ready() -> void:
	_test_typed_feedback_merge()
	_test_critical_metadata_round_trip()
	_test_killing_blow_marker_policy()
	_test_pipeline_critical_result()
	_test_pipeline_overkill_result()
	await _test_camera_projection_fallback()
	await _test_feedback_controller_contract()
	await _test_target_window_aggregation()
	if _failed:
		print("FAIL damage label feedback")
	else:
		print("PASS damage label feedback")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _test_typed_feedback_merge() -> void:
	var batch := DamageFeedbackEvent.new(30, Attack.TYPE_FIRE)
	batch.is_periodic = true
	var smaller_type := DamageFeedbackEvent.new(10, Attack.TYPE_FREEZE)
	smaller_type.is_periodic = true
	batch.merge(smaller_type)
	_expect(batch.final_damage == 40, "typed feedback must sum batched damage")
	_expect(
		batch.damage_type == Attack.TYPE_FIRE,
		"typed feedback must retain a damage type with a strict majority"
	)
	_expect(batch.is_periodic, "an all-periodic batch must remain periodic")
	var direct_hit := DamageFeedbackEvent.new(20, Attack.TYPE_FREEZE)
	direct_hit.is_critical = true
	direct_hit.is_killing_blow = true
	batch.merge(direct_hit)
	_expect(
		batch.damage_type == &"mixed",
		"typed feedback must classify a batch without a strict majority as mixed"
	)
	_expect(
		batch.is_critical and not batch.is_periodic,
		"typed feedback must merge critical and periodic flags deterministically"
	)
	_expect(batch.is_killing_blow, "typed feedback aggregation must preserve killing-blow semantics")

func _test_critical_metadata_round_trip() -> void:
	var previous_crit_rate := PlayerData.crit_rate
	var previous_bonus_crit_rate := PlayerData.bonus_crit_rate
	var previous_crit_damage := PlayerData.crit_damage
	var previous_bonus_crit_damage := PlayerData.bonus_crit_damage
	PlayerData.crit_rate = 1.0
	PlayerData.bonus_crit_rate = 0.0
	PlayerData.crit_damage = 2.0
	PlayerData.bonus_crit_damage = 1.0
	var modifier_system := PlayerStatusModifierSystem.new()
	var outgoing = modifier_system.compute_outgoing_damage_result(10)
	_expect(outgoing.is_critical, "guaranteed critical roll must expose metadata")
	_expect(outgoing.damage == 20, "critical roll must retain critical damage scaling")
	var data := DamageData.new().setup(
		outgoing.damage,
		Attack.TYPE_ENERGY,
		{},
		null
	)
	data.is_critical = outgoing.is_critical
	var attack := data.to_attack()
	_expect(attack.is_critical, "DamageData must carry critical metadata into Attack")
	var label = HIT_LABEL_SCENE.instantiate()
	var feedback := DamageFeedbackEvent.new(attack.damage, attack.damage_type)
	feedback.target_max_hp = 1000
	feedback.is_critical = attack.is_critical
	label.configure(feedback)
	_expect(label.is_critical_hit(), "critical metadata must reach HitLabel")
	_expect(label.get_display_text().ends_with("!"), "critical damage must have a non-color-only marker")
	_expect(label.get_pixel_scale() == 2, "critical damage must receive one integer scale step")
	label.free()
	PlayerData.crit_rate = previous_crit_rate
	PlayerData.bonus_crit_rate = previous_bonus_crit_rate
	PlayerData.crit_damage = previous_crit_damage
	PlayerData.bonus_crit_damage = previous_bonus_crit_damage

func _test_killing_blow_marker_policy() -> void:
	var label = HIT_LABEL_SCENE.instantiate()
	label.configure({
		"final_damage": 30,
		"target_max_hp": 100,
		"is_killing_blow": true,
	})
	_expect(label.get_display_text() == "30", "non-critical killing blows must not show an exclamation marker")
	label.configure({
		"final_damage": 30,
		"target_max_hp": 100,
		"is_critical": true,
		"is_killing_blow": true,
	})
	_expect(label.get_display_text() == "30!", "critical killing blows must retain the critical marker")
	label.free()

func _test_pipeline_critical_result() -> void:
	var target := DummyDamageTarget.new()
	var profile := DamageProfile.new()
	profile.use_damage_reduction = false
	profile.use_armor = false
	profile.get_hp = Callable(target, "read_hp")
	profile.set_hp = Callable(target, "write_hp")
	profile.get_max_hp = Callable(target, "read_max_hp")
	profile.get_is_dead = Callable(target, "read_dead")
	profile.set_is_dead = Callable(target, "write_dead")
	var attack := Attack.new()
	attack.damage = 10
	attack.damage_type = Attack.TYPE_ENERGY
	attack.is_critical = true
	var result := DamagePipeline.new().apply_incoming_damage(target, attack, profile)
	_expect(result.applied and result.final_damage == 10, "critical metadata must not alter pipeline damage")
	_expect(result.health_damage == 10 and result.overkill_damage == 0, "a nonlethal hit must consume all resolved damage without overkill")
	_expect(result.is_critical, "DamagePipeline must carry Attack critical metadata into DamageResult")
	target.free()

func _test_pipeline_overkill_result() -> void:
	var target := DummyDamageTarget.new()
	target.hp = 10
	var profile := DamageProfile.new()
	profile.use_damage_reduction = false
	profile.use_armor = false
	profile.get_hp = Callable(target, "read_hp")
	profile.set_hp = Callable(target, "write_hp")
	profile.get_max_hp = Callable(target, "read_max_hp")
	profile.get_is_dead = Callable(target, "read_dead")
	profile.set_is_dead = Callable(target, "write_dead")
	var attack := Attack.new()
	attack.damage = 100
	attack.damage_type = Attack.TYPE_ENERGY
	var result := DamagePipeline.new().apply_incoming_damage(target, attack, profile)
	_expect(result.applied and result.killed, "an overkill hit must apply and kill the target")
	_expect(result.final_damage == 100, "resolved damage must not be capped by remaining enemy HP")
	_expect(result.health_damage == 10, "health damage must remain capped by the target's remaining HP")
	_expect(result.overkill_damage == 90, "overkill damage must expose the resolved excess")
	_expect(target.hp == -90, "enemy HP must retain the overkill amount for lifecycle compatibility")
	var label = HIT_LABEL_SCENE.instantiate()
	label.configure({
		"final_damage": result.final_damage,
		"damage_type": result.damage_type,
		"is_killing_blow": result.killed,
	})
	_expect(label.get_display_text() == "100", "enemy damage feedback must display full resolved overkill damage")
	label.free()
	target.free()

func _test_camera_projection_fallback() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(400.0, 300.0)
	add_child(camera)
	camera.make_current()
	await get_tree().process_frame
	var projected := PROJECTED_UI.project_to_screen(get_tree(), camera.global_position, Vector2.ZERO)
	var expected := get_viewport().get_visible_rect().size * 0.5
	_expect(
		projected.distance_to(expected) <= 1.0,
		"2D projection fallback must apply the active Camera2D canvas transform"
	)
	camera.queue_free()
	await get_tree().process_frame

func _test_feedback_controller_contract() -> void:
	var npc := DummyFeedbackNpc.new()
	npc.position = Vector2(200.0, 160.0)
	add_child(npc)
	var controller := NpcDamageFeedbackController.new()
	controller.setup(npc)
	var feedback := DamageFeedbackEvent.new(40, Attack.TYPE_FIRE)
	feedback.feedback_batch_id = 77
	feedback.is_critical = true
	controller.queue_hit_label_event(feedback)
	await get_tree().create_timer(0.06).timeout
	await get_tree().process_frame
	_hybrid_layer = get_tree().root.get_node_or_null("HybridWorldUi") as CanvasLayer
	_expect(_hybrid_layer != null, "damage feedback controller must create the projected UI layer")
	var found_label: Node = null
	for candidate in get_tree().get_nodes_in_group(&"active_hit_labels"):
		if candidate.has_method("get_target_instance_id") \
				and int(candidate.call("get_target_instance_id")) == npc.get_instance_id():
			found_label = candidate
			break
	_expect(found_label != null, "damage feedback controller must emit a HitLabel")
	if found_label != null:
		_expect(bool(found_label.call("is_critical_hit")), "controller must forward batched critical metadata")
		_expect(
			StringName(found_label.call("get_damage_type")) == Attack.TYPE_FIRE,
			"controller must forward the dominant damage type"
		)
		_expect(int(found_label.call("get_feedback_batch_id")) == 77, "controller must preserve feedback batch id")
	controller.shutdown()

func _test_target_window_aggregation() -> void:
	var npc := DummyFeedbackNpc.new()
	npc.position = Vector2(360.0, 180.0)
	add_child(npc)
	var controller := NpcDamageFeedbackController.new()
	controller.setup(npc)
	var direct := DamageFeedbackEvent.new(12, Attack.TYPE_FIRE)
	direct.feedback_batch_id = 101
	controller.queue_hit_label_event(direct)
	var direct_critical := DamageFeedbackEvent.new(18, Attack.TYPE_FIRE)
	direct_critical.feedback_batch_id = 102
	direct_critical.is_critical = true
	controller.queue_hit_label_event(direct_critical)
	await get_tree().create_timer(0.06).timeout
	await get_tree().process_frame
	var direct_labels := _labels_for_target(npc.get_instance_id())
	_expect(direct_labels.size() == 1, "separate direct attack batches on one target must collapse into one short-window label")
	if direct_labels.size() == 1:
		_expect(int(direct_labels[0].call("get_damage_value")) == 30, "direct target-window feedback must sum resolved damage without changing it")
		_expect(bool(direct_labels[0].call("is_critical_hit")), "a merged direct window must preserve critical semantics")

	var dot_a := DamageFeedbackEvent.new(3, Attack.TYPE_FIRE)
	dot_a.is_periodic = true
	controller.queue_hit_label_event(dot_a)
	var dot_b := DamageFeedbackEvent.new(4, Attack.TYPE_FIRE)
	dot_b.is_periodic = true
	controller.queue_hit_label_event(dot_b)
	await get_tree().create_timer(0.14).timeout
	await get_tree().process_frame
	var all_labels := _labels_for_target(npc.get_instance_id())
	_expect(all_labels.size() == 2, "multiple DOT ticks must produce one additional low-frequency label")
	var periodic_labels: Array[Node] = []
	for label in all_labels:
		if bool(label.call("is_periodic_hit")):
			periodic_labels.append(label)
	_expect(periodic_labels.size() == 1, "DOT aggregation must retain its periodic visual channel")
	if periodic_labels.size() == 1:
		_expect(int(periodic_labels[0].call("get_damage_value")) == 7, "DOT aggregation must preserve the exact resolved total")
	controller.shutdown()
	npc.queue_free()

func _labels_for_target(target_id: int) -> Array[Node]:
	var labels: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group(&"active_hit_labels"):
		if candidate.has_method("get_target_instance_id") and int(candidate.call("get_target_instance_id")) == target_id:
			labels.append(candidate)
	return labels

func _reset_runtime_state() -> void:
	if _hybrid_layer != null and is_instance_valid(_hybrid_layer):
		_hybrid_layer.queue_free()
	_hybrid_layer = null

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
