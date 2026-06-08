extends SceneTree

var _player_data: Node
var _player: Node2D
var _sniper_events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_player_data = root.get_node_or_null("/root/PlayerData")
	if _player_data == null:
		_fail("missing PlayerData autoload")
		return
	_player = Node2D.new()
	_player.global_position = Vector2.ZERO
	root.add_child(_player)
	_player_data.set("player", _player)

	if not await _assert_mark_api_and_expiry():
		return
	if not _assert_spear_hitbox_bonus():
		return
	if not await _assert_sniper_reads_spear_mark():
		return
	if not _assert_pistol_mark_preserves_projectile_durability():
		return

	_player_data.set("player", null)
	_player.free()
	print("PASS: Mark status effect API, Spear/Sniper/Pistol mark integrations")
	quit(0)


func _make_target() -> Node2D:
	var scene := load("res://Npc/base_npc.tscn") as PackedScene
	var target := scene.instantiate() as Node2D
	target.set("hp", 100)
	target.global_position = Vector2(100.0, 0.0)
	root.add_child(target)
	return target


func _assert_mark_api_and_expiry() -> bool:
	var target := _make_target()
	target.call("apply_mark", &"test_mark", 0.1, {&"value": 12})
	if not bool(target.call("has_mark", &"test_mark")):
		return _fail("target did not report an active mark")
	if int(target.call("get_mark_value", &"test_mark", &"value", 0)) != 12:
		return _fail("target did not return mark data")
	var wait_until_msec := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < wait_until_msec:
		await process_frame
	if bool(target.call("has_mark", &"test_mark")):
		return _fail("expired mark still reported active")
	target.free()
	return true


func _assert_spear_hitbox_bonus() -> bool:
	var target := _make_target()
	target.call("apply_mark", &"spear_pierce", 5.0, {
		&"bonus_multiplier": 1.35,
		&"threshold": 4,
	})
	var projectile_scene := load("res://Player/Weapons/Projectiles/projectile.tscn") as PackedScene
	var projectile := projectile_scene.instantiate() as Node2D
	projectile.set("hp", 5)
	projectile.set_meta("initial_projectile_hits", 5)
	var hitbox_scene := load("res://Utility/hit_hurt_box/hit_box.tscn") as PackedScene
	var hitbox := hitbox_scene.instantiate()
	hitbox.set("hitbox_owner", projectile)
	var boosted := int(hitbox.call("_apply_spear_pierce_mark_bonus", target, 100))
	if boosted != 135:
		return _fail("Spear mark hitbox bonus expected 135, got %d" % boosted)
	projectile.free()
	hitbox.free()
	target.free()
	return true


func _assert_sniper_reads_spear_mark() -> bool:
	var sniper_scene := load("res://Player/Weapons/Instances/sniper.tscn") as PackedScene
	var sniper := sniper_scene.instantiate()
	root.add_child(sniper)
	sniper.global_position = Vector2.ZERO
	await process_frame
	sniper.call("set_weapon_role", "main")
	sniper.passive_triggered.connect(_on_sniper_passive_triggered)
	var target := _make_target()
	target.global_position = Vector2(100.0, 0.0)
	target.call("apply_mark", &"pistol_pierce", 5.0, {})
	var hp_before := int(target.get("hp"))
	sniper.call("set_last_projectile_hit_damage", 10)
	sniper.call("_try_trigger_far_hit", target)
	sniper.call("_apply_distance_bonus_damage", target)
	if _sniper_events.is_empty():
		return _fail("Sniper did not trigger Far Hit from Pistol mark at close range")
	var latest := _sniper_events[_sniper_events.size() - 1]
	if not bool(latest.get("forced_full_bonus_by_mark", false)):
		return _fail("Sniper Far Hit did not report forced full bonus by mark")
	var damage_taken := hp_before - int(target.get("hp"))
	if damage_taken != 8:
		return _fail("Sniper marked close-range bonus expected 8 damage, got %d" % damage_taken)
	var wait_until_msec := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < wait_until_msec:
		await process_frame
	sniper.free()
	target.free()
	return true


func _assert_pistol_mark_preserves_projectile_durability() -> bool:
	var target := _make_target()
	target.call("apply_mark", &"pistol_pierce", 5.0, {})
	var projectile_scene := load("res://Player/Weapons/Projectiles/projectile.tscn") as PackedScene
	var projectile := projectile_scene.instantiate()
	projectile.set("hp", 2)
	projectile.call("consume_projectile_durability", 1, target)
	if int(projectile.get("hp")) != 2:
		return _fail("Pistol mark did not preserve projectile durability")
	projectile.free()
	target.free()
	return true


func _on_sniper_passive_triggered(event_name: StringName, detail: Dictionary) -> void:
	var record := detail.duplicate(true)
	record["event_name"] = event_name
	_sniper_events.append(record)


func _fail(message: String) -> bool:
	push_error("FAIL: Mark status effect: %s" % message)
	if _player_data != null:
		_player_data.set("player", null)
	if _player != null and is_instance_valid(_player):
		_player.free()
	quit(1)
	return false
