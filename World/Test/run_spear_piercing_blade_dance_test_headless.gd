extends SceneTree

class TestTarget:
	extends Node2D

	var hp: int = 100
	var is_dead: bool = false
	var knockback := {
		"amount": 0.0,
		"angle": Vector2.ZERO,
	}
	var status_effects: Array[StatusEffect] = []

	func apply_status_effect(effect: StatusEffect) -> void:
		if effect == null:
			return
		for existing in status_effects:
			if existing.effect_id == effect.effect_id:
				existing.merge_from(effect)
				return
		status_effects.append(effect)

	func apply_mark(mark_id: StringName, duration_sec: float, data: Dictionary = {}) -> void:
		apply_status_effect(MarkStatusEffect.new().setup_mark(mark_id, duration_sec, data))

	func has_mark(mark_id: StringName) -> bool:
		return _get_mark_effect(mark_id) != null

	func get_mark_value(mark_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
		var effect := _get_mark_effect(mark_id)
		if effect == null:
			return default_value
		return effect.get_value(key, default_value)

	func _get_mark_effect(mark_id: StringName) -> MarkStatusEffect:
		for i in range(status_effects.size() - 1, -1, -1):
			var effect := status_effects[i]
			if effect == null:
				status_effects.remove_at(i)
				continue
			if effect is MarkStatusEffect:
				var mark_effect := effect as MarkStatusEffect
				if not mark_effect.is_active():
					status_effects.remove_at(i)
					continue
				if mark_effect.mark_id == mark_id:
					return mark_effect
		return null


var _weapon: Node
var _player: Node2D
var _player_data: Node
var _events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var spear_scene := load("res://Player/Weapons/spear_launcher.tscn") as PackedScene
	if spear_scene == null:
		_fail("unable to load Spear Launcher scene")
		return
	_player = Node2D.new()
	_player.global_position = Vector2.ZERO
	root.add_child(_player)
	_player_data = root.get_node_or_null("/root/PlayerData")
	if _player_data == null:
		_fail("missing PlayerData autoload")
		return
	_player_data.set("player", _player)

	_weapon = spear_scene.instantiate()
	root.add_child(_weapon)
	await process_frame
	_weapon.call("set_weapon_role", "main")
	_weapon.passive_triggered.connect(_on_passive_triggered)

	if not _assert_repeat_damage_charge_contract():
		return
	if not await _assert_reload_tiers_and_consumption():
		return
	if not _assert_radial_mark_and_knockback():
		return

	print("PASS: Spear Piercing Blade Dance core charge, reload tiers, mark, and knockback")
	_player_data.set("player", null)
	quit(0)


func _assert_repeat_damage_charge_contract() -> bool:
	var projectile := Node2D.new()
	var target_a := TestTarget.new()
	var target_b := TestTarget.new()
	root.add_child(projectile)
	root.add_child(target_a)
	root.add_child(target_b)

	_weapon.call("on_projectile_hit_damage_dealt", projectile, target_a, &"physical", 1)
	if _get_charge() != 0:
		return _fail("first direct damage unexpectedly granted charge")
	_weapon.call("on_projectile_hit_damage_dealt", projectile, target_a, &"physical", 1)
	if _get_charge() != 1:
		return _fail("second direct damage did not grant one charge")
	_weapon.call("on_projectile_hit_damage_dealt", projectile, target_a, &"physical", 1)
	if _get_charge() != 1:
		return _fail("same projectile-target pair granted charge more than once")
	_weapon.call("on_projectile_hit_damage_dealt", projectile, target_b, &"physical", 1)
	_weapon.call("on_projectile_hit_damage_dealt", projectile, target_b, &"physical", 1)
	if _get_charge() != 2:
		return _fail("same projectile did not gain independent charge from another target")

	var reload_projectile := Node2D.new()
	var reload_target := TestTarget.new()
	root.add_child(reload_projectile)
	root.add_child(reload_target)
	_weapon.call("on_projectile_hit_damage_dealt", reload_projectile, reload_target, &"physical", 1)
	_weapon.set("is_reloading", true)
	_weapon.call("on_projectile_hit_damage_dealt", reload_projectile, reload_target, &"physical", 1)
	if _get_charge() != 2:
		return _fail("damage during reload granted charge")
	_weapon.set("is_reloading", false)
	_weapon.call("on_projectile_hit_damage_dealt", reload_projectile, reload_target, &"physical", 1)
	if _get_charge() != 3:
		return _fail("pre-reload hit progress was not preserved")
	return true


func _assert_reload_tiers_and_consumption() -> bool:
	_events.clear()
	_weapon.set("_piercing_blade_dance_charge", 15)
	_weapon.set("current_ammo", maxi(0, int(_weapon.get("magazine_capacity")) - 1))
	if not bool(_weapon.call("request_reload")):
		return _fail("15 charge reload did not start")
	if _get_charge() != 5:
		return _fail("8-direction volley did not consume exactly 10 charge")
	var first_trigger := _find_latest_event(&"piercing_blade_dance_triggered")
	if int(first_trigger.get("projectile_count", 0)) != 8:
		return _fail("15 charge did not select 8-direction volley")
	await create_timer(0.7).timeout
	var first_projectile_count := _count_live_radial_projectiles()
	if first_projectile_count != 8:
		return _fail("8-direction volley spawned %d projectiles instead of 8" % first_projectile_count)
	_clear_live_radial_projectiles()
	await process_frame
	_weapon.call("_finish_reload")

	_events.clear()
	_weapon.set("_piercing_blade_dance_charge", 20)
	_weapon.set("current_ammo", maxi(0, int(_weapon.get("magazine_capacity")) - 1))
	if not bool(_weapon.call("request_reload")):
		return _fail("20 charge reload did not start")
	if _get_charge() != 0:
		return _fail("16-direction volley did not consume exactly 20 charge")
	var second_trigger := _find_latest_event(&"piercing_blade_dance_triggered")
	if int(second_trigger.get("projectile_count", 0)) != 16:
		return _fail("20 charge did not select 16-direction volley")
	await create_timer(1.0).timeout
	var second_projectile_count := _count_live_radial_projectiles()
	if second_projectile_count != 16:
		return _fail("16-direction volley spawned %d projectiles instead of 16" % second_projectile_count)
	_weapon.call("_finish_reload")
	return true


func _assert_radial_mark_and_knockback() -> bool:
	var radial_projectile := Node2D.new()
	radial_projectile.set_meta("piercing_blade_dance_radial", true)
	var target := TestTarget.new()
	target.global_position = Vector2(100.0, 0.0)
	root.add_child(radial_projectile)
	root.add_child(target)
	_weapon.call("on_projectile_hit_damage_dealt", radial_projectile, target, &"physical", 1)
	if not bool(target.call("has_mark", &"spear_pierce")):
		return _fail("radial damage did not apply a 20-second mark")
	var threshold := int(target.call("get_mark_value", &"spear_pierce", &"threshold", 0))
	if threshold != 4:
		return _fail("radial mark did not preserve the pierce threshold")
	var multiplier := float(target.call("get_mark_value", &"spear_pierce", &"bonus_multiplier", 0.0))
	if not is_equal_approx(multiplier, 1.35):
		return _fail("radial mark did not preserve the damage multiplier")
	if not target.has_node("SpearPierceMarkVisual"):
		return _fail("radial damage did not attach mark visual")
	var mark_visual := target.get_node("SpearPierceMarkVisual")
	if mark_visual == null or mark_visual.get("texture") == null:
		return _fail("mark visual did not use the Spear weapon icon")
	if not is_equal_approx(float(target.knockback.get("amount", 0.0)), 100.0):
		return _fail("radial damage did not apply 100 knockback")
	if not (target.knockback.get("angle", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.RIGHT):
		return _fail("radial knockback did not push away from player")
	return true


func _get_charge() -> int:
	var status := _weapon.call("get_passive_status") as Dictionary
	return int(status.get("current", -1))


func _on_passive_triggered(event_name: StringName, detail: Dictionary) -> void:
	var record := detail.duplicate(true)
	record["event_name"] = event_name
	_events.append(record)


func _find_latest_event(event_name: StringName) -> Dictionary:
	for index in range(_events.size() - 1, -1, -1):
		var event: Dictionary = _events[index]
		if StringName(event.get("event_name", StringName())) == event_name:
			return event
	return {}


func _count_live_radial_projectiles() -> int:
	var count := 0
	for child in root.get_children():
		if bool(child.get_meta("piercing_blade_dance_radial", false)):
			count += 1
	return count


func _clear_live_radial_projectiles() -> void:
	for child in root.get_children():
		if bool(child.get_meta("piercing_blade_dance_radial", false)):
			child.queue_free()


func _fail(message: String) -> bool:
	push_error("FAIL: Spear Piercing Blade Dance: %s" % message)
	if _player_data != null:
		_player_data.set("player", null)
	quit(1)
	return false
