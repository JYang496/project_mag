extends SceneTree

func _initialize() -> void:
	var packed := load("res://World/Test/heat_passive_test.tscn") as PackedScene
	if packed == null:
		push_error("FAIL: unable to load heat_passive_test.tscn")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	call_deferred("_run_probe", scene)

func _run_probe(scene: Node) -> void:
	await process_frame
	await physics_frame
	await physics_frame
	var dummy := scene.get("_dummy") as Node
	if dummy == null or not is_instance_valid(dummy):
		push_error("FAIL: heat passive test dummy was not spawned")
		quit(1)
		return
	scene.call("_set_main_weapon", "Flamethrower")
	await physics_frame
	_assert_decay_rate(scene, 26.0, "Flamethrower")
	scene.call("_set_main_weapon", "Plasma Lance")
	await physics_frame
	_assert_decay_rate(scene, 15.0, "Plasma Lance")
	var hp_before := int(dummy.get("hp"))
	scene.call("_fire_flamethrower")
	await create_timer(0.35).timeout
	if dummy == null or not is_instance_valid(dummy):
		print("PASS: heat passive test dummy took lethal damage")
		quit(0)
		return
	var hp_after := int(dummy.get("hp"))
	if hp_after >= hp_before:
		push_error("FAIL: heat passive test dummy did not take damage. before=%d after=%d" % [hp_before, hp_after])
		quit(1)
		return
	if not await _assert_flamethrower_heat_prepared_contract(scene):
		quit(1)
		return
	scene.call("_ready_cannon_body_passive")
	await physics_frame
	var target_root := scene.get_node_or_null("SpawnRoot/Targets")
	if target_root == null:
		push_error("FAIL: missing heat passive target root")
		quit(1)
		return
	var primary := scene.get("_dummy") as Node
	var spectator_before: Dictionary = {}
	for child in target_root.get_children():
		var node := child as Node
		if node == null or node == primary:
			continue
		spectator_before[node.get_instance_id()] = int(node.get("hp"))
	scene.call("_fire_cannon_thermal")
	await create_timer(0.75).timeout
	var spectator_damaged := false
	for child in target_root.get_children():
		var node := child as Node
		if node == null or node == primary:
			continue
		var before_hp := int(spectator_before.get(node.get_instance_id(), int(node.get("hp"))))
		if int(node.get("hp")) < before_hp:
			spectator_damaged = true
			break
	if not spectator_damaged:
		push_error("FAIL: Cannon idle empowered AOE did not damage any spectator dummy")
		quit(1)
		return
	if not await _assert_plasma_lance_heat_feedback(scene):
		quit(1)
		return
	print("PASS: heat passive test dummy damage before=%d after=%d" % [hp_before, hp_after])
	quit(0)

func _assert_flamethrower_heat_prepared_contract(scene: Node) -> bool:
	var player_data := root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		push_error("FAIL: missing PlayerData autoload")
		return false
	var player := player_data.get("player") as Node
	if player == null or not is_instance_valid(player):
		push_error("FAIL: missing PlayerData.player")
		return false
	var weapons_by_name: Dictionary = scene.get("_weapons_by_name")
	var flamethrower := weapons_by_name.get("Flamethrower", null) as Node
	var plasma_lance := weapons_by_name.get("Plasma Lance", null) as Node
	if flamethrower == null or not is_instance_valid(flamethrower):
		push_error("FAIL: missing Flamethrower weapon")
		return false
	if plasma_lance == null or not is_instance_valid(plasma_lance):
		push_error("FAIL: missing Plasma Lance weapon")
		return false
	scene.call("_set_main_weapon", "Flamethrower")
	player.call("clear_heat_statuses")
	player.call("consume_shared_heat", 999999.0)
	flamethrower.set("_heat_prepared_reload_ready", true)
	flamethrower.set("_heat_prepared_accumulated_heat", 0.0)
	var heat_per_shot := maxf(float(flamethrower.get("heat_per_shot")), 0.001)
	var required_heat := maxf(float(flamethrower.get("heat_max_value")), 1.0)
	var shots_before_trigger := maxi(0, int(ceil(required_heat / heat_per_shot)) - 1)
	for i in range(shots_before_trigger):
		flamethrower.call("register_shot_heat")
	if bool(player.call("has_heat_prepared")):
		push_error("FAIL: Flamethrower Heat Prepared triggered before reload")
		return false
	flamethrower.call("register_shot_heat")
	if bool(player.call("has_heat_prepared")):
		push_error("FAIL: Flamethrower Heat Prepared triggered from accumulated heat without reload")
		return false
	if float(flamethrower.get("_heat_prepared_accumulated_heat")) < required_heat:
		push_error("FAIL: Flamethrower accumulated heat did not reach reload trigger threshold")
		return false
	flamethrower.call("_on_passive_event", &"on_reload_finished", {"source_weapon": flamethrower})
	if not bool(player.call("has_heat_prepared")):
		push_error("FAIL: Flamethrower Heat Prepared did not trigger on reload after accumulated heat threshold")
		return false
	if not bool(flamethrower.get("_heat_prepared_reload_ready")):
		push_error("FAIL: Flamethrower reload did not unlock Heat Prepared accumulation")
		return false
	if not is_equal_approx(float(flamethrower.get("_heat_prepared_accumulated_heat")), 0.0):
		push_error("FAIL: Flamethrower reload did not clear accumulated Heat Prepared progress")
		return false
	var pool := player.call("get_shared_heat_pool") as SharedHeatPool
	if pool == null:
		push_error("FAIL: missing shared heat pool")
		return false
	pool.heat_value = maxf(float(plasma_lance.get("plasma_heat_spend_amount")), 20.0)
	pool.overheated = false
	plasma_lance.call("_consume_heat_spend_multiplier")
	if not bool(player.call("has_heat_prepared")):
		push_error("FAIL: Heat Prepared was consumed by heat spend")
		return false
	player.call("clear_heat_statuses")
	flamethrower.set("_heat_prepared_accumulated_heat", maxf(required_heat - heat_per_shot, 0.0))
	flamethrower.call("_on_passive_event", &"on_reload_finished", {"source_weapon": flamethrower})
	if bool(player.call("has_heat_prepared")):
		push_error("FAIL: Flamethrower Heat Prepared triggered on reload below accumulated heat threshold")
		return false
	print("PASS: flamethrower reload-gated accumulated Heat Prepared trigger, persistence, and reset")
	return true

func _assert_decay_rate(scene: Node, expected: float, label: String) -> void:
	var player_data := root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		push_error("FAIL: missing PlayerData autoload")
		quit(1)
		return
	var player := player_data.get("player") as Node
	if player == null or not is_instance_valid(player):
		push_error("FAIL: missing PlayerData.player")
		quit(1)
		return
	var actual := float(player.call("get_selected_heat_decay_rate"))
	if not is_equal_approx(actual, expected):
		push_error("FAIL: %s selected heat decay expected %.1f got %.1f" % [label, expected, actual])
		quit(1)

func _assert_plasma_lance_heat_feedback(scene: Node) -> bool:
	var player_data := root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		push_error("FAIL: missing PlayerData autoload")
		return false
	var player := player_data.get("player") as Node
	if player == null or not is_instance_valid(player):
		push_error("FAIL: missing PlayerData.player")
		return false
	var pool := player.call("get_shared_heat_pool") as SharedHeatPool
	if pool == null:
		push_error("FAIL: missing shared heat pool")
		return false
	if not player.has_method("apply_plasma_lance_heat_feedback"):
		push_error("FAIL: player missing apply_plasma_lance_heat_feedback")
		return false
	scene.call("_set_main_weapon", "Plasma Lance")
	var weapons_by_name: Dictionary = scene.get("_weapons_by_name")
	var plasma_lance := weapons_by_name.get("Plasma Lance", null) as Node
	if plasma_lance == null or not is_instance_valid(plasma_lance):
		push_error("FAIL: missing Plasma Lance weapon")
		return false
	plasma_lance.call("force_skill_cooldowns_ready")
	plasma_lance.set("_heat_spend_attack_count", 0)
	player.call("clear_heat_statuses")
	plasma_lance.call("_try_trigger_heat_spend_chain", 20.0)
	plasma_lance.call("_try_trigger_heat_spend_chain", 20.0)
	plasma_lance.call("_try_trigger_heat_spend_chain", 20.0)
	if not bool(player.call("has_plasma_lance_heat_feedback")):
		push_error("FAIL: Plasma Lance heat spend chain did not apply heat feedback")
		return false
	var heat_max := maxf(float(player.call("get_total_heat_max")), 1.0)
	player.call("clear_heat_statuses")
	pool.heat_value = 0.0
	pool.overheated = false
	player.call("apply_plasma_lance_heat_feedback", 10.0, 1.2, 0.8, 0.7)
	pool.call("add_heat_amount", 10.0)
	if not is_equal_approx(pool.heat_value, 12.0):
		push_error("FAIL: heat feedback low heat gain expected 12.0 got %.3f" % pool.heat_value)
		return false
	pool.heat_value = heat_max * 0.8
	pool.overheated = false
	var before_high := pool.heat_value
	pool.call("add_heat_amount", 10.0)
	var expected_high := minf(before_high + 8.0, heat_max)
	if not is_equal_approx(pool.heat_value, expected_high):
		push_error("FAIL: heat feedback high heat gain expected %.3f got %.3f" % [expected_high, pool.heat_value])
		return false
	player.call("apply_plasma_lance_heat_feedback", 0.2, 1.2, 0.8, 0.7)
	await create_timer(0.08).timeout
	var remaining_before := float(player.call("get_plasma_lance_heat_feedback_remaining_sec"))
	player.call("apply_plasma_lance_heat_feedback", 10.0, 1.2, 0.8, 0.7)
	var remaining_after := float(player.call("get_plasma_lance_heat_feedback_remaining_sec"))
	if remaining_after <= remaining_before:
		push_error("FAIL: heat feedback refresh did not extend duration before=%.3f after=%.3f" % [remaining_before, remaining_after])
		return false
	if remaining_after < 9.0:
		push_error("FAIL: heat feedback refresh expected near 10s remaining got %.3f" % remaining_after)
		return false
	player.call("clear_heat_statuses")
	print("PASS: plasma lance heat feedback low/high gain and refresh")
	return true
