extends Node

const ShieldScene := preload("res://Npc/enemy/scenes/enemy_shield_core.tscn")
const RepairScene := preload("res://Npc/enemy/scenes/enemy_repair_unit.tscn")
const InterceptorScene := preload("res://Npc/enemy/scenes/enemy_interceptor_heavy.tscn")
const RollingScene := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")

var _spawned: Array[Node] = []

func _ready() -> void:
	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.wait_time = 8.0
	timeout.timeout.connect(func() -> void: _fail("support behavior test timed out"))
	add_child(timeout)
	timeout.start()
	call_deferred("_run")

func _run() -> void:
	var player := Node2D.new()
	player.name = "SupportProbePlayer"
	get_tree().root.add_child(player)
	_spawned.append(player)
	PlayerData.player = player

	var shield := _spawn_enemy(ShieldScene, Vector2.ZERO) as EnemyShieldCore
	var shield_peer := _spawn_enemy(ShieldScene, Vector2(30.0, 0.0)) as EnemyShieldCore
	var rolling := _spawn_enemy(RollingScene, Vector2(60.0, 0.0)) as BaseEnemy
	var repair := _spawn_enemy(RepairScene, Vector2(80.0, 0.0)) as EnemyRepairUnit
	var interceptor := _spawn_enemy(InterceptorScene, Vector2(50.0, 0.0)) as EnemyInterceptorHeavy
	await get_tree().physics_frame

	shield.call("_sync_protected_targets")
	if not is_equal_approx(rolling.get_support_damage_taken_multiplier(), 0.65):
		_fail("shield core did not protect a normal ally")
		return
	if not is_equal_approx(repair.get_support_damage_taken_multiplier(), 0.65):
		_fail("shield core did not cross-protect a different support role")
		return
	if not is_equal_approx(shield_peer.get_support_damage_taken_multiplier(), 1.0):
		_fail("shield core protected another shield core")
		return
	shield_peer.call("_sync_protected_targets")
	if not is_equal_approx(rolling.get_support_damage_taken_multiplier(), 0.65):
		_fail("shield core reductions stacked")
		return
	rolling.global_position = Vector2(500.0, 0.0)
	shield.call("_sync_protected_targets")
	shield_peer.call("_sync_protected_targets")
	if not is_equal_approx(rolling.get_support_damage_taken_multiplier(), 1.0):
		_fail("shield reduction remained after leaving aura")
		return

	rolling.global_position = Vector2(100.0, 0.0)
	var damaged_hp := maxi(int(round(float(rolling.get_incoming_damage_max_hp()) * 0.4)), 1)
	rolling.hp = damaged_hp
	var chosen := repair.call("_find_lowest_health_target") as BaseEnemy
	if chosen != rolling:
		_fail("repair unit did not choose the lowest-health valid ally")
		return
	repair.set("_heal_target", rolling)
	repair.call("_complete_heal")
	if int(rolling.hp) <= damaged_hp:
		_fail("repair unit did not heal its target")
		return
	rolling.hp = damaged_hp
	repair.set("_heal_target", rolling)
	repair.set("_cast_remaining", 0.8)
	repair.apply_stun(0.5)
	repair.call("_physics_process", 0.1)
	if repair.get("_heal_target") != null:
		_fail("stun did not interrupt repair cast")
		return
	if int(rolling.hp) != damaged_hp:
		_fail("interrupted repair cast still healed")
		return

	player.global_position = Vector2.ZERO
	repair.global_position = Vector2(200.0, 0.0)
	interceptor.global_position = Vector2(50.0, 0.0)
	interceptor.set("_guard_target", repair)
	var guard_velocity := interceptor.call("_resolve_guard_velocity") as Vector2
	if guard_velocity.x <= 0.0:
		_fail("interceptor did not move between player and support")
		return
	interceptor.set("_guard_target", null)
	var chase_velocity := interceptor.call("_resolve_guard_velocity") as Vector2
	if chase_velocity.x >= 0.0:
		_fail("interceptor did not chase player without support")
		return

	if not _validate_spawn_profile():
		return
	print("PASS: support enemies protect, heal, interrupt, intercept, and appear in the intended level pools")
	_cleanup()
	get_tree().quit(0)

func _spawn_enemy(scene: PackedScene, position: Vector2) -> BaseEnemy:
	var enemy := scene.instantiate() as BaseEnemy
	get_tree().root.add_child(enemy)
	enemy.global_position = position
	_spawned.append(enemy)
	return enemy

func _validate_spawn_profile() -> bool:
	var profile := load("res://data/spawns/spawn_combat_profile.tres") as SpawnCombatProfile
	if profile == null or profile.levels.size() != 10:
		_fail("spawn profile did not load ten configured levels")
		return false
	var shield_path := ShieldScene.resource_path
	var repair_path := RepairScene.resource_path
	var interceptor_path := InterceptorScene.resource_path
	if not _level_has(profile, 2, shield_path) or _level_has(profile, 2, repair_path) or _level_has(profile, 2, interceptor_path):
		_fail("level 3 is not a shield-core-only support tutorial")
		return false
	if not _level_has(profile, 3, repair_path) or _level_has(profile, 3, shield_path) or _level_has(profile, 3, interceptor_path):
		_fail("level 4 is not a repair-only support tutorial")
		return false
	if not _level_has(profile, 4, interceptor_path):
		_fail("level 5 does not introduce the interceptor")
		return false
	if not _level_has(profile, 7, interceptor_path) or not _level_has(profile, 7, "res://Npc/enemy/scenes/enemy_orbit_support.tscn"):
		_fail("level 8 does not pair the interceptor with a support target")
		return false
	for level_index in [8, 9]:
		if not _level_has(profile, level_index, shield_path) or not _level_has(profile, level_index, repair_path) or not _level_has(profile, level_index, interceptor_path):
			_fail("late-game level %d does not combine all new enemy roles" % (level_index + 1))
			return false
	if not _scene_has_cap(ShieldScene, 1) or not _scene_has_cap(RepairScene, 1) or not _scene_has_cap(InterceptorScene, 2):
		_fail("new enemy alive caps do not match the design")
		return false
	return true

func _level_has(profile: SpawnCombatProfile, level_index: int, scene_path: String) -> bool:
	for entry in profile.levels[level_index].spawns:
		if entry != null and entry.enemy != null and entry.enemy.resource_path == scene_path:
			return true
	return false

func _scene_has_cap(scene: PackedScene, expected: int) -> bool:
	var enemy := scene.instantiate() as BaseEnemy
	var matches := enemy != null and enemy.spawn_alive_cap == expected
	if enemy != null:
		enemy.free()
	return matches

func _fail(message: String) -> void:
	push_error("FAIL: %s" % message)
	_cleanup()
	get_tree().quit(1)

func _cleanup() -> void:
	for node in _spawned:
		if node != null and is_instance_valid(node):
			node.free()
	_spawned.clear()
	PlayerData.player = null
