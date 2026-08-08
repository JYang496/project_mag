extends Node

const AREA_EFFECT_SCENE := preload("res://Combat/area_effect/area_effect.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures: PackedStringArray = []


func _ready() -> void:
	_test_event_driven_target_tracking()
	_test_trail_requires_enemy_registry()
	await _test_persistent_terrain_fade_lifecycle()
	if _failures.is_empty():
		print("PASS combat.area_effect_tracking")
		await TEST_TEARDOWN.finish(self, 0)
		return
	for failure in _failures:
		push_error(failure)
	print("FAIL combat.area_effect_tracking (%d assertions)" % _failures.size())
	await TEST_TEARDOWN.finish(self, 1)


func _test_event_driven_target_tracking() -> void:
	var effect := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	effect.duration = 10.0
	effect.tick_damage = 1
	effect.target_group = AreaEffect.TargetGroup.ENEMIES
	add_child(effect)

	var target := Node2D.new()
	target.name = "TrackedEnemyTarget"
	add_child(target)
	var first_hurt_box := _make_enemy_hurt_box(target, "FirstHurtBox")
	var second_hurt_box := _make_enemy_hurt_box(target, "SecondHurtBox")

	effect.call("_on_area_entered", first_hurt_box)
	effect.call("_on_area_entered", second_hurt_box)
	var tracked: Dictionary = effect.get("_tracked_targets")
	_expect(tracked.size() == 1, "multiple hurt boxes for one target must produce one tracked damage target")

	effect.call("_on_area_exited", first_hurt_box)
	tracked = effect.get("_tracked_targets")
	_expect(tracked.size() == 1, "target must remain tracked while another hurt box is still inside")

	effect.call("_on_area_exited", second_hurt_box)
	tracked = effect.get("_tracked_targets")
	_expect(tracked.is_empty(), "target must be removed after its final hurt box exits")


func _test_trail_requires_enemy_registry() -> void:
	var trail := TrailAreaEffect.new()
	add_child(trail)
	var grouped_enemy := Node2D.new()
	grouped_enemy.add_to_group(&"enemies")
	add_child(grouped_enemy)
	var candidates: Array = trail.call("_collect_enemy_candidates", get_tree())
	_expect(candidates.is_empty(), "trail damage must not fall back to scanning the enemies group")


func _test_persistent_terrain_fade_lifecycle() -> void:
	var effect := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	effect.duration = 0.24
	effect.fade_out_duration = 0.12
	add_child(effect)
	await get_tree().create_timer(0.15).timeout
	_expect(is_instance_valid(effect), "persistent area gameplay must remain active while its fade is playing")
	_expect(effect.get_visual_alpha_multiplier() < 0.9, "persistent areas must fade from their authoritative lifetime timer")
	await get_tree().create_timer(0.12).timeout
	await get_tree().process_frame
	_expect(not is_instance_valid(effect), "persistent area fade and node expiration must end together")


func _make_enemy_hurt_box(target: Node2D, node_name: String) -> HurtBox:
	var hurt_box := HurtBox.new()
	hurt_box.name = node_name
	hurt_box.set_collision_layer_value(3, true)
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.shape = CircleShape2D.new()
	hurt_box.add_child(collision_shape)
	target.add_child(hurt_box)
	return hurt_box


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
