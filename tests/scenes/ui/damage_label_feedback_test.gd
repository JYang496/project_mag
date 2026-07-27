extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HIT_LABEL_SCENE := preload("res://UI/labels/hit_label.tscn")
const DIGIT_ATLAS_PATH := "res://UI/labels/assets/damage_digits_12px.png"

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
	var hit_label_merge_window_sec := 0.0

	func get_incoming_damage_max_hp() -> int:
		return 200

var _failed := false
var _hybrid_layer: CanvasLayer

func _ready() -> void:
	_test_png_atlas_contract()
	_test_magnitude_tiers_and_layout()
	_test_damage_type_and_periodic_styles()
	_test_typed_feedback_merge()
	_test_critical_metadata_round_trip()
	_test_killing_blow_marker_policy()
	_test_pipeline_critical_result()
	await _test_feedback_controller_contract()
	if _failed:
		print("FAIL damage label feedback")
	else:
		print("PASS damage label feedback")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _test_png_atlas_contract() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DIGIT_ATLAS_PATH))
	_expect(image != null and not image.is_empty(), "12px damage digit atlas must load")
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == Vector2i(104, 12), "damage digit atlas must use thirteen 8x12 cells")
	var saw_opaque := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			_expect(
				pixel.a == 0.0 or pixel.a == 1.0,
				"damage digit atlas alpha must stay on a binary pixel grid"
			)
			if pixel.a == 1.0:
				saw_opaque = true
				_expect(
					pixel.r == 1.0 and pixel.g == 1.0 and pixel.b == 1.0,
					"opaque atlas pixels must be pure white for runtime tinting"
				)
	_expect(saw_opaque, "damage digit atlas must contain opaque glyph pixels")

func _test_magnitude_tiers_and_layout() -> void:
	var label = HIT_LABEL_SCENE.instantiate()
	label.configure({"final_damage": 1, "target_max_hp": 1000})
	_expect(label.get_pixel_scale() == 1, "minor damage must render at 1x")
	var one_digit_width: float = label.size.x
	label.configure({"final_damage": 50, "target_max_hp": 1000})
	_expect(label.get_pixel_scale() == 1, "normal damage must render at 1x")
	label.configure({"final_damage": 100, "target_max_hp": 1000})
	_expect(label.get_pixel_scale() == 2, "heavy damage must render at 2x")
	label.configure({"final_damage": 250, "target_max_hp": 1000})
	_expect(label.get_pixel_scale() == 3, "burst damage must render at 3x")
	_expect(label.size.x > one_digit_width, "multi-digit damage layout must grow instead of clipping")
	label.free()

func _test_damage_type_and_periodic_styles() -> void:
	var label = HIT_LABEL_SCENE.instantiate()
	label.configure({
		"final_damage": 30,
		"damage_type": Attack.TYPE_FIRE,
		"target_max_hp": 1000,
		"is_periodic": true,
	})
	_expect(label.get_damage_type() == Attack.TYPE_FIRE, "fire damage type must reach HitLabel")
	_expect(label.is_periodic_hit(), "periodic damage flag must reach HitLabel")
	var fire_color: Color = label.get_font_color()
	label.configure({
		"final_damage": 30,
		"damage_type": Attack.TYPE_FREEZE,
		"target_max_hp": 1000,
	})
	_expect(label.get_font_color() != fire_color, "damage types must have distinct colors")
	label.configure({
		"final_damage": 30,
		"damage_type": &"mixed",
		"target_max_hp": 1000,
	})
	_expect(label.get_damage_type() == &"mixed", "mixed damage must retain its visual classification")
	label.free()

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
	batch.merge(direct_hit)
	_expect(
		batch.damage_type == &"mixed",
		"typed feedback must classify a batch without a strict majority as mixed"
	)
	_expect(
		batch.is_critical and not batch.is_periodic,
		"typed feedback must merge critical and periodic flags deterministically"
	)

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
	_expect(result.is_critical, "DamagePipeline must carry Attack critical metadata into DamageResult")
	target.free()

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
	await get_tree().process_frame
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

func _reset_runtime_state() -> void:
	if _hybrid_layer != null and is_instance_valid(_hybrid_layer):
		_hybrid_layer.queue_free()
	_hybrid_layer = null

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
