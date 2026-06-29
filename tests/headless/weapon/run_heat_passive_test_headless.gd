extends SceneTree

func _initialize() -> void:
	var packed := load("res://tests/scenes/weapon/heat_passive_test.tscn") as PackedScene
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
	_assert_decay_rate(scene, 10.0, "Flamethrower")
	scene.call("_set_main_weapon", "Plasma Lance")
	await physics_frame
	_assert_decay_rate(scene, 15.0, "Plasma Lance")
	if not await _assert_machine_gun_shared_heat_speed_contract(scene):
		quit(1)
		return
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
	if not await _assert_plasma_lance_rift_projectile_contract(scene):
		quit(1)
		return
	if not await _assert_plasma_lance_branch_contract(scene):
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
	var pool := player.call("get_shared_heat_pool") as SharedHeatPool
	if pool == null:
		push_error("FAIL: missing shared heat pool")
		return false
	pool.heat_value = 0.0
	pool.overheated = false
	flamethrower.call("_on_passive_event", &"on_reload_started", {"source_weapon": flamethrower})
	if not bool(player.call("has_heat_prepared")):
		push_error("FAIL: Flamethrower Heat Prepared did not trigger when reload started after accumulated heat threshold")
		return false
	if not is_equal_approx(float(pool.heat_value), 0.0):
		push_error("FAIL: Flamethrower Heat Prepared added shared heat")
		return false
	if bool(flamethrower.get("_heat_prepared_reload_ready")):
		push_error("FAIL: Flamethrower Heat Prepared accumulation stayed ready during reload")
		return false
	if not is_equal_approx(float(flamethrower.get("_heat_prepared_accumulated_heat")), 0.0):
		push_error("FAIL: Flamethrower reload start did not clear accumulated Heat Prepared progress")
		return false
	flamethrower.call("_on_passive_event", &"on_reload_finished", {"source_weapon": flamethrower})
	if not bool(flamethrower.get("_heat_prepared_reload_ready")):
		push_error("FAIL: Flamethrower reload finish did not unlock Heat Prepared accumulation")
		return false
	pool.heat_value = maxf(float(plasma_lance.get("plasma_heat_spend_amount")), 20.0)
	pool.overheated = false
	var heat_spend_multiplier := float(plasma_lance.call("_consume_heat_spend_multiplier"))
	var expected_heat_spend_multiplier := 1.0 + float(plasma_lance.get("plasma_heat_spend_damage_bonus"))
	if not is_equal_approx(heat_spend_multiplier, expected_heat_spend_multiplier):
		push_error("FAIL: Heat Prepared changed Plasma Lance heat spend multiplier expected %.3f got %.3f" % [expected_heat_spend_multiplier, heat_spend_multiplier])
		return false
	if not bool(player.call("has_heat_prepared")):
		push_error("FAIL: Heat Prepared was consumed by heat spend")
		return false
	player.call("clear_heat_statuses")
	flamethrower.set("_heat_prepared_accumulated_heat", maxf(required_heat - heat_per_shot, 0.0))
	flamethrower.call("_on_passive_event", &"on_reload_started", {"source_weapon": flamethrower})
	if bool(player.call("has_heat_prepared")):
		push_error("FAIL: Flamethrower Heat Prepared triggered on reload start below accumulated heat threshold")
		return false
	flamethrower.call("_on_passive_event", &"on_reload_finished", {"source_weapon": flamethrower})
	print("PASS: flamethrower reload-start-gated accumulated Heat Prepared trigger, persistence, and reset")
	return true

func _assert_machine_gun_shared_heat_speed_contract(scene: Node) -> bool:
	var player_data := root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		push_error("FAIL: missing PlayerData autoload")
		return false
	var player := player_data.get("player") as Node
	if player == null or not is_instance_valid(player):
		push_error("FAIL: missing PlayerData.player")
		return false
	var weapons_by_name: Dictionary = scene.get("_weapons_by_name")
	var machine_gun := weapons_by_name.get("Machine Gun", null) as Node
	if machine_gun == null or not is_instance_valid(machine_gun):
		push_error("FAIL: missing Machine Gun weapon")
		return false
	var pool := player.call("get_shared_heat_pool") as SharedHeatPool
	if pool == null:
		push_error("FAIL: missing shared heat pool")
		return false
	player.call("clear_heat_statuses")
	scene.call("_set_main_weapon", "Machine Gun")
	await physics_frame
	var base_heat_max := maxf(float(player.call("get_total_heat_max")), 1.0)
	pool.overheated = false
	pool.heat_value = 90.0
	var speed_at_mid_heat := float(machine_gun.call("_resolve_shared_heat_attack_speed"))
	if not is_equal_approx(speed_at_mid_heat, 7.0):
		push_error("FAIL: Machine Gun shared heat speed expected 7.0 at 90 heat got %.3f" % speed_at_mid_heat)
		return false
	pool.heat_value = 0.0
	pool.overheated = false
	machine_gun.is_reloading = false
	machine_gun.is_on_cooldown = true
	machine_gun.current_ammo = 10
	machine_gun.call("_add_held_trigger_heat", 1.0)
	if not is_equal_approx(pool.heat_value, 28.0):
		push_error("FAIL: Machine Gun held trigger heat expected 28.0 got %.3f" % pool.heat_value)
		return false
	machine_gun.is_on_cooldown = false
	machine_gun.current_ammo = 10
	pool.heat_value = 0.0
	pool.overheated = false
	machine_gun.call("request_primary_fire")
	if not is_equal_approx(pool.heat_value, 0.0):
		push_error("FAIL: Machine Gun shot added per-shot heat got %.3f" % pool.heat_value)
		return false
	pool.heat_value = 180.0
	pool.overheated = false
	machine_gun.is_reloading = false
	machine_gun.is_on_cooldown = true
	machine_gun.current_ammo = 10
	machine_gun.call("_add_held_trigger_heat", 1.0)
	if not is_equal_approx(pool.heat_value, 208.0):
		push_error("FAIL: Machine Gun held trigger heat expected 208.0 above 180 heat got %.3f" % pool.heat_value)
		return false
	player.call("clear_heat_statuses")
	pool.heat_value = 40.0
	pool.overheated = false
	machine_gun.call("refresh_passive_on_reload")
	machine_gun.current_ammo = machine_gun.magazine_capacity / 2
	machine_gun.call("_on_passive_event", &"on_reload_started", {
		"source_weapon": machine_gun,
		"spent_ratio": 0.5,
		"ammo_after": machine_gun.current_ammo,
	})
	if not bool(player.call("has_heat_expansion")):
		push_error("FAIL: Machine Gun Heat Expansion did not trigger from partial-mag reload start")
		return false
	var expected_partial_max := base_heat_max * 1.5
	if not is_equal_approx(float(player.call("get_total_heat_max")), expected_partial_max):
		push_error("FAIL: partial Heat Expansion max expected %.3f got %.3f" % [expected_partial_max, float(player.call("get_total_heat_max"))])
		return false
	if not is_equal_approx(pool.heat_value, 60.0):
		push_error("FAIL: partial Heat Expansion current heat expected 60.0 got %.3f" % pool.heat_value)
		return false
	player.call("clear_heat_statuses")
	machine_gun.call("refresh_passive_on_reload")
	machine_gun.current_ammo = 0
	pool.heat_value = base_heat_max * 0.9
	pool.overheated = true
	machine_gun.call("_on_passive_event", &"on_reload_started", {
		"source_weapon": machine_gun,
		"spent_ratio": 1.0,
		"ammo_after": 0,
	})
	if not bool(player.call("has_heat_expansion")):
		push_error("FAIL: Machine Gun Heat Expansion did not reach full strength from empty-mag reload start")
		return false
	if not is_equal_approx(float(player.call("get_total_heat_max")), base_heat_max * 2.0):
		push_error("FAIL: Heat Expansion max expected %.3f got %.3f" % [base_heat_max * 2.0, float(player.call("get_total_heat_max"))])
		return false
	var expected_trigger_heat := base_heat_max * 2.0 * 0.8
	if not is_equal_approx(pool.heat_value, expected_trigger_heat):
		push_error("FAIL: Heat Expansion trigger clamp expected %.3f got %.3f" % [expected_trigger_heat, pool.heat_value])
		return false
	if bool(pool.overheated):
		push_error("FAIL: Heat Expansion trigger clamp did not clear overheat")
		return false
	machine_gun.call("refresh_passive_on_reload")
	pool.heat_value = 120.0
	machine_gun.call("_on_passive_event", &"on_reload_started", {
		"source_weapon": machine_gun,
		"spent_ratio": 1.0,
		"ammo_after": 0,
	})
	if not is_equal_approx(pool.heat_value, 120.0):
		push_error("FAIL: Heat Expansion refresh rescaled current heat to %.3f" % pool.heat_value)
		return false
	pool.heat_value = base_heat_max * 1.4
	pool.overheated = true
	player.call("apply_heat_expansion", 0.05, 2.0)
	await create_timer(0.08).timeout
	player.call("get_heat_expansion_max_multiplier")
	var expected_end_heat := base_heat_max * 0.8
	if not is_equal_approx(float(player.call("get_total_heat_max")), base_heat_max):
		push_error("FAIL: Heat Expansion end max expected %.3f got %.3f" % [base_heat_max, float(player.call("get_total_heat_max"))])
		return false
	if pool.heat_value > expected_end_heat or absf(pool.heat_value - expected_end_heat) > 1.0:
		push_error("FAIL: Heat Expansion end clamp expected %.3f got %.3f" % [expected_end_heat, pool.heat_value])
		return false
	if bool(pool.overheated):
		push_error("FAIL: Heat Expansion end clamp did not clear overheat")
		return false
	pool.heat_value = 35.0
	pool.overheated = false
	player.call("apply_heat_expansion", 8.0, 2.0)
	player.call("clear_heat_statuses")
	if not is_equal_approx(float(player.call("get_total_heat_max")), base_heat_max):
		push_error("FAIL: Heat Expansion prepare clear did not restore max heat")
		return false
	if not is_equal_approx(pool.heat_value, 0.0):
		push_error("FAIL: Heat Expansion prepare clear expected zero heat got %.3f" % pool.heat_value)
		return false
	pool.heat_value = 0.0
	pool.overheated = false
	print("PASS: machine gun shared heat speed curve, held trigger heat, and Heat Expansion")
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
	plasma_lance.set("_heat_spend_chain_pending", false)
	plasma_lance.set("_heat_spend_chain_last_spent", 0.0)
	player.call("clear_heat_statuses")
	plasma_lance.call("_try_trigger_heat_spend_chain", 20.0)
	plasma_lance.call("_try_trigger_heat_spend_chain", 20.0)
	plasma_lance.call("_try_trigger_heat_spend_chain", 20.0)
	if bool(player.call("has_plasma_lance_heat_feedback")):
		push_error("FAIL: Plasma Lance heat feedback triggered before reload finished")
		return false
	plasma_lance.call("_on_passive_event", &"on_reload_finished", {"source_weapon": plasma_lance})
	if not bool(player.call("has_plasma_lance_heat_feedback")):
		push_error("FAIL: Plasma Lance heat spend chain did not apply heat feedback after reload")
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

func _assert_plasma_lance_rift_projectile_contract(scene: Node) -> bool:
	var projectile_scene := load("res://Player/Weapons/Projectiles/plasma_lance_projectile.tscn") as PackedScene
	if projectile_scene == null:
		push_error("FAIL: missing Plasma Lance projectile scene")
		return false
	var weapons_by_name: Dictionary = scene.get("_weapons_by_name")
	var plasma_lance := weapons_by_name.get("Plasma Lance", null) as Weapon
	if plasma_lance == null or not is_instance_valid(plasma_lance):
		push_error("FAIL: missing Plasma Lance weapon for rift contract")
		return false
	var target_root := scene.get_node_or_null("SpawnRoot/Targets")
	if target_root == null:
		push_error("FAIL: missing heat passive target root for rift contract")
		return false
	var anchor := _find_dummy_by_role(target_root, "Primary")
	var linked := _find_dummy_by_role(target_root, "Spectator")
	if anchor == null or linked == null:
		push_error("FAIL: missing Plasma Lance rift dummy pair")
		return false
	var projectile := projectile_scene.instantiate() as PlasmaLanceProjectile
	if projectile == null:
		push_error("FAIL: Plasma Lance projectile scene did not instantiate PlasmaLanceProjectile")
		return false
	projectile.source_weapon = plasma_lance
	projectile.damage = 100
	projectile.damage_type = Attack.TYPE_ENERGY
	projectile.rift_damage_ratio = 0.5
	projectile.rift_width = 24.0
	projectile.expire_time = 10.0
	projectile.projectile_texture = load("res://asset/images/weapons/projectiles/plasma.png") as Texture2D
	projectile.desired_pixel_size = Vector2(10.0, 10.0)
	scene.add_child(projectile)
	await physics_frame
	var anchor_before := int(anchor.get("hp"))
	var linked_before := int(linked.get("hp"))
	projectile.call("on_hit_target", anchor)
	await physics_frame
	if int(anchor.get("hp")) != anchor_before or int(linked.get("hp")) != linked_before:
		push_error("FAIL: Plasma Lance rift damaged enemies on first anchor hit")
		projectile.queue_free()
		return false
	projectile.call("on_hit_target", linked)
	await physics_frame
	var anchor_damage := anchor_before - int(anchor.get("hp"))
	var linked_damage := linked_before - int(linked.get("hp"))
	if anchor_damage != 50:
		push_error("FAIL: Plasma Lance rift anchor damage expected 50 got %d" % anchor_damage)
		projectile.queue_free()
		return false
	if linked_damage != 50:
		push_error("FAIL: Plasma Lance rift linked damage expected 50 got %d" % linked_damage)
		projectile.queue_free()
		return false
	projectile.call("despawn")
	await physics_frame
	if is_instance_valid(projectile) and not Array(projectile.get("_rift_hit_positions")).is_empty():
		push_error("FAIL: Plasma Lance rift positions were not cleared on despawn")
		return false
	print("PASS: plasma lance projectile rift anchor, line damage, and cleanup")
	return true

func _find_dummy_by_role(target_root: Node, role: String) -> Node2D:
	for child in target_root.get_children():
		var node := child as Node2D
		if node == null:
			continue
		if str(node.get_meta("heat_passive_test_role", "")) == role:
			return node
	return null

func _assert_plasma_lance_branch_contract(scene: Node) -> bool:
	var player_data := root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		push_error("FAIL: missing PlayerData autoload")
		return false
	var player := player_data.get("player") as Node
	if player == null or not is_instance_valid(player):
		push_error("FAIL: missing PlayerData.player")
		return false
	var weapons_by_name: Dictionary = scene.get("_weapons_by_name")
	var plasma_lance := weapons_by_name.get("Plasma Lance", null) as Node
	if plasma_lance == null or not is_instance_valid(plasma_lance):
		push_error("FAIL: missing Plasma Lance weapon")
		return false
	scene.call("_set_main_weapon", "Plasma Lance")
	plasma_lance.fuse = 3
	plasma_lance.call("set_level", 7)
	plasma_lance.call("force_skill_cooldowns_ready")
	plasma_lance.set("_heat_spend_attack_count", 0)
	plasma_lance.set("_heat_spend_chain_pending", false)
	plasma_lance.set("_heat_spend_chain_last_spent", 0.0)
	var pool := player.call("get_shared_heat_pool") as SharedHeatPool
	if pool == null:
		push_error("FAIL: missing shared heat pool")
		return false
	player.call("clear_heat_statuses")
	if int(plasma_lance.call("_get_effective_projectile_hits")) != 2:
		push_error("FAIL: base Plasma Lance expected 2 projectile hits got %d" % int(plasma_lance.call("_get_effective_projectile_hits")))
		return false
	if int(plasma_lance.branch_runtime.get_branch_pierce_damage_gain_per_hit()) != 0:
		push_error("FAIL: base Plasma Lance should not gain damage per pierce")
		return false
	pool.heat_value = 40.0
	pool.overheated = false
	var base_multiplier := float(plasma_lance.call("_consume_heat_spend_multiplier"))
	if not is_equal_approx(base_multiplier, 1.25):
		push_error("FAIL: base Plasma Lance heat spend expected 1.25x got %.3f" % base_multiplier)
		return false
	if not is_equal_approx(pool.heat_value, 20.0):
		push_error("FAIL: base Plasma Lance should spend exactly 20 heat, remaining %.3f" % pool.heat_value)
		return false
	if not bool(plasma_lance.branch_runtime.add_branch("plasma_piercing_lance")):
		push_error("FAIL: unable to add Plasma Lance Piercing branch")
		return false
	if int(plasma_lance.call("_get_effective_projectile_hits")) != 12:
		push_error("FAIL: Piercing Lance expected 12 projectile hits got %d" % int(plasma_lance.call("_get_effective_projectile_hits")))
		return false
	if int(plasma_lance.branch_runtime.get_branch_pierce_damage_gain_per_hit()) != 4:
		push_error("FAIL: Piercing Lance expected +4 damage per pierce")
		return false
	pool.heat_value = 40.0
	pool.overheated = false
	var piercing_multiplier := float(plasma_lance.call("_consume_heat_spend_multiplier"))
	if not is_equal_approx(piercing_multiplier, 1.25):
		push_error("FAIL: Piercing Lance should keep base 20-heat spend, got %.3f" % piercing_multiplier)
		return false
	if not is_equal_approx(pool.heat_value, 20.0):
		push_error("FAIL: Piercing Lance should spend exactly 20 heat, remaining %.3f" % pool.heat_value)
		return false
	if not bool(plasma_lance.call("add_branch", "plasma_overcharge_lance")):
		push_error("FAIL: unable to add Plasma Lance Overcharge branch")
		return false
	pool.heat_value = 40.0
	pool.overheated = false
	var overcharge_multiplier := float(plasma_lance.call("_consume_heat_spend_multiplier"))
	if not is_equal_approx(overcharge_multiplier, 1.25):
		push_error("FAIL: first Overcharge Lance heat spend should only build a stack, got %.3f" % overcharge_multiplier)
		return false
	if not is_equal_approx(pool.heat_value, 20.0):
		push_error("FAIL: first Overcharge Lance heat spend should spend base 20 heat, remaining %.3f" % pool.heat_value)
		return false
	if int(plasma_lance.call("_get_overcharge_lance_stack_count")) != 1:
		push_error("FAIL: first Overcharge Lance heat spend should add one stack")
		return false
	await create_timer(0.2).timeout
	var remaining_before_refresh := float(plasma_lance.call("_get_overcharge_lance_remaining_sec"))
	pool.heat_value = 60.0
	pool.overheated = false
	var stacked_multiplier := float(plasma_lance.call("_consume_heat_spend_multiplier"))
	if not is_equal_approx(stacked_multiplier, 1.5):
		push_error("FAIL: Overcharge Lance one active stack expected 1.5x got %.3f" % stacked_multiplier)
		return false
	if not is_equal_approx(pool.heat_value, 35.0):
		push_error("FAIL: Overcharge Lance one active stack should spend 25 heat, remaining %.3f" % pool.heat_value)
		return false
	if int(plasma_lance.call("_get_overcharge_lance_stack_count")) != 2:
		push_error("FAIL: second Overcharge Lance heat spend should add a second non-consumed stack")
		return false
	var remaining_after_refresh := float(plasma_lance.call("_get_overcharge_lance_remaining_sec"))
	if remaining_after_refresh <= remaining_before_refresh:
		push_error("FAIL: Overcharge Lance retrigger did not refresh duration before=%.3f after=%.3f" % [remaining_before_refresh, remaining_after_refresh])
		return false
	pool.heat_value = 24.0
	pool.overheated = false
	var short_heat_multiplier := float(plasma_lance.call("_consume_heat_spend_multiplier"))
	if not is_equal_approx(short_heat_multiplier, 1.25):
		push_error("FAIL: Overcharge Lance should skip extra stack spend when less than 5 heat remains, got %.3f" % short_heat_multiplier)
		return false
	if not is_equal_approx(pool.heat_value, 4.0):
		push_error("FAIL: Overcharge Lance short heat shot should only spend base 20 heat, remaining %.3f" % pool.heat_value)
		return false
	if int(plasma_lance.call("_get_overcharge_lance_stack_count")) != 3:
		push_error("FAIL: Overcharge Lance short heat shot should still add a stack")
		return false
	plasma_lance.call("_clear_overcharge_lance_stacks")
	pool.heat_value = 80.0
	pool.overheated = false
	float(plasma_lance.call("_consume_heat_spend_multiplier"))
	await create_timer(5.1).timeout
	if int(plasma_lance.call("_get_overcharge_lance_stack_count")) != 0:
		push_error("FAIL: Overcharge Lance stack did not expire after 5 seconds")
		return false
	plasma_lance.call("_add_overcharge_lance_stack", 5.0)
	if int(plasma_lance.call("_get_overcharge_lance_stack_count")) != 1:
		push_error("FAIL: Overcharge Lance test stack not added before prepare clear")
		return false
	plasma_lance.call("clear_timed_effects_for_prepare")
	if int(plasma_lance.call("_get_overcharge_lance_stack_count")) != 0:
		push_error("FAIL: prepare clear did not remove Overcharge Lance stacks")
		return false
	print("PASS: plasma lance base, Piercing Lance, and Overcharge Lance branch contracts")
	return true
