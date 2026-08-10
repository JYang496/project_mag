extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PROFILE := preload("res://Combat/Vfx/enemy_death_vfx_profile.gd")
const SERVICE := preload("res://Combat/Vfx/enemy_death_vfx_service.gd")
const BASE_ENEMY_SCENE := preload("res://Npc/enemy/scenes/base_enemy.tscn")

var _failed := false


func _ready() -> void:
	_test_profile_semantics()
	await _test_runtime_signal_and_detached_visual_lifecycle()
	print("FAIL: enemy death vfx" if _failed else "PASS: enemy death vfx")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _test_profile_semantics() -> void:
	_expect(PROFILE.resolve_type(Attack.TYPE_PHYSICAL) == PROFILE.DeathType.PHYSICAL_SHATTER, "physical kills must use directional shatter feedback")
	_expect(PROFILE.resolve_type(Attack.TYPE_ENERGY) == PROFILE.DeathType.ENERGY_COLLAPSE, "energy kills must use collapse feedback")
	_expect(PROFILE.resolve_type(Attack.TYPE_FIRE) == PROFILE.DeathType.FIRE_BURNOUT, "fire kills must use burnout feedback")
	_expect(PROFILE.resolve_type(Attack.TYPE_FREEZE) == PROFILE.DeathType.FREEZE_SHATTER, "freeze kills must use brittle shatter feedback")
	_expect(PROFILE.resolve_scale_class(false, false, Vector2(24, 24), 2) == PROFILE.ScaleClass.SMALL, "small enemies must retain compact VFX scale")
	_expect(PROFILE.resolve_scale_class(false, false, Vector2(52, 44), 8) == PROFILE.ScaleClass.HEAVY, "large enemies must retain heavy VFX scale")
	_expect(PROFILE.resolve_scale_class(true, false, Vector2(40, 40), 4) == PROFILE.ScaleClass.ELITE, "elite rank must affect scale without replacing damage type")
	_expect(PROFILE.resolve_scale_class(true, true, Vector2(80, 80), 12) == PROFILE.ScaleClass.BOSS, "boss rank must retain its scale class")
	for type in PROFILE.DeathType.values():
		for rank in PROFILE.ScaleClass.values():
			var profile := PROFILE.create(type, rank)
			_expect([32, 64, 128].has(int(profile.source_size)), "death source size must follow pixel-art policy")
			_expect(float(profile.duration_sec) <= 0.50, "every damage-type death effect must remain brief")
	var elite_fire := PROFILE.create(PROFILE.DeathType.FIRE_BURNOUT, PROFILE.ScaleClass.ELITE)
	_expect(elite_fire.death_type == PROFILE.DeathType.FIRE_BURNOUT, "elite rank must not hide the killing damage type")


func _test_runtime_signal_and_detached_visual_lifecycle() -> void:
	var enemy := BASE_ENEMY_SCENE.instantiate() as BaseEnemy
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.position = Vector2(80.0, 120.0)
	add_child(enemy)
	await get_tree().process_frame
	var death_signal_state := [false]
	enemy.enemy_death.connect(func(was_killed: bool): death_signal_state[0] = was_killed)
	enemy.death_runtime.finalize_death(null, false)
	_expect(bool(death_signal_state[0]), "authoritative enemy death signal must remain immediate")
	var service := get_tree().get_first_node_in_group(&"enemy_death_vfx_service")
	_expect(service != null, "death runtime must route visuals through the shared service")
	if service != null:
		var active := service.call("get_pool_metrics") as Dictionary
		_expect(int(active.get("active", 0)) == 1, "death visual must survive independently after enemy release")
		_expect(int(active.get("ground_effects", -1)) == 0, "death feedback must not leave ground circles")
	await get_tree().process_frame
	_expect(not is_instance_valid(enemy), "enemy gameplay node must still release without waiting for VFX")
	await get_tree().create_timer(0.72).timeout
	if service != null and is_instance_valid(service):
		var settled := service.call("get_pool_metrics") as Dictionary
		_expect(int(settled.get("active", -1)) == 0, "death visual must return to its pool")
		for index in range(SERVICE.MAX_ACTIVE_EFFECTS + 4):
			var type := index % PROFILE.DeathType.size()
			service.call("play", Vector2(index, 0), PROFILE.create(type, PROFILE.ScaleClass.SMALL))
		var saturated := service.call("get_pool_metrics") as Dictionary
		_expect(int(saturated.get("pooled", 0)) == SERVICE.MAX_ACTIVE_EFFECTS, "death effects must cap allocation at ten")
		var active_types: Array = service.call("get_active_effect_types") as Array
		for type in PROFILE.DeathType.values():
			_expect(active_types.has(type), "pooled service must preserve every damage-type exit style")
		_expect(int(saturated.get("ground_effects", -1)) == 0, "saturated death effects must still create no ground residue")
		service.queue_free()
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
