extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var plasma_lance_scene := load("res://Player/Weapons/Instances/plasma_lance.tscn") as PackedScene
	var cannon_scene := load("res://Player/Weapons/Instances/cannon.tscn") as PackedScene
	var failed := false
	var plasma_ok := await _assert_weapon_ammo_gate("Plasma Lance", plasma_lance_scene)
	failed = not plasma_ok or failed
	var cannon_ok := await _assert_weapon_ammo_gate("Cannon", cannon_scene)
	failed = not cannon_ok or failed
	if failed:
		quit(1)
		return
	print("PASS: weapon ammo gate consumes ammo and blocks reload firing")
	quit(0)

func _assert_weapon_ammo_gate(label: String, scene: PackedScene) -> bool:
	var weapon := scene.instantiate() as Node
	if weapon == null:
		push_error("%s ammo gate: failed to instantiate weapon" % label)
		return false
	root.add_child(weapon)
	await process_frame
	if weapon.has_method("set_weapon_role"):
		weapon.call("set_weapon_role", "main")
	var phase_manager := root.get_node_or_null("PhaseManager")
	if phase_manager != null and phase_manager.has_method("enter_battle"):
		phase_manager.call("enter_battle")
	weapon.set_meta("_benchmark_mouse_target", Vector2(640.0, 360.0))
	if weapon.get("is_on_cooldown") != null:
		weapon.set("is_on_cooldown", false)
	if weapon.get("windup_sec") != null:
		weapon.set("windup_sec", 0.0)

	var ammo_before := int(weapon.get("current_ammo"))
	var fired := bool(weapon.call("request_primary_fire"))
	await process_frame
	var ammo_after := int(weapon.get("current_ammo"))
	if not fired:
		push_error("%s ammo gate: expected first shot to fire" % label)
		weapon.queue_free()
		return false
	if ammo_after != ammo_before - 1:
		push_error("%s ammo gate: expected ammo %d after shot, got %d" % [label, ammo_before - 1, ammo_after])
		weapon.queue_free()
		return false

	weapon.set("is_on_cooldown", false)
	weapon.set("current_ammo", maxi(1, int(weapon.get("current_ammo"))))
	weapon.set("is_reloading", true)
	weapon.set("reload_time_left", 1.0)
	var ammo_reload_before := int(weapon.get("current_ammo"))
	var fired_while_reloading := bool(weapon.call("request_primary_fire"))
	await process_frame
	var ammo_reload_after := int(weapon.get("current_ammo"))
	if fired_while_reloading:
		push_error("%s ammo gate: should not fire while reloading" % label)
		weapon.queue_free()
		return false
	if ammo_reload_after != ammo_reload_before:
		push_error("%s ammo gate: ammo changed while reload fire was blocked" % label)
		weapon.queue_free()
		return false

	weapon.set("is_reloading", false)
	weapon.set("current_ammo", 0)
	weapon.set("is_on_cooldown", false)
	var fired_empty := bool(weapon.call("request_primary_fire"))
	await process_frame
	if fired_empty:
		push_error("%s ammo gate: should not fire with empty magazine" % label)
		weapon.queue_free()
		return false
	if not bool(weapon.get("is_reloading")):
		push_error("%s ammo gate: empty fire should start reload" % label)
		weapon.queue_free()
		return false

	weapon.queue_free()
	return true
