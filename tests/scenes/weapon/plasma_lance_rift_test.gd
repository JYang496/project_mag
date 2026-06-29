extends Node

@export var heat_passive_test_scene: PackedScene = preload("res://tests/scenes/weapon/heat_passive_test.tscn")
@export var projectile_scene: PackedScene = preload("res://Player/Weapons/Projectiles/plasma_lance_projectile.tscn")
@export var projectile_texture: Texture2D = preload("res://asset/images/weapons/projectiles/plasma.png")

var _scene: Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if heat_passive_test_scene == null:
		_fail("missing heat passive test scene")
		return
	_scene = heat_passive_test_scene.instantiate()
	add_child(_scene)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not await _assert_rift_contract():
		return
	await _wait_for_rift_vfx_clear(0.4)
	if not await _assert_anchor_tracks_enemy_current_position():
		return
	await _wait_for_rift_vfx_clear(0.4)
	if not await _assert_anchor_falls_back_to_recorded_position():
		return
	await _wait_for_rift_vfx_clear(0.4)
	if not await _assert_real_fire_rift_contract():
		return
	await _wait_for_rift_vfx_clear(0.4)
	print("PASS: plasma lance rift scene contract")
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _assert_rift_contract() -> bool:
	if projectile_scene == null:
		_fail("missing Plasma Lance projectile scene")
		return false
	var weapons_by_name: Dictionary = _scene.get("_weapons_by_name")
	var plasma_lance := weapons_by_name.get("Plasma Lance", null) as Weapon
	if plasma_lance == null or not is_instance_valid(plasma_lance):
		_fail("missing Plasma Lance weapon")
		return false
	var target_root := _scene.get_node_or_null("SpawnRoot/Targets")
	if target_root == null:
		_fail("missing target root")
		return false
	var anchor := _find_dummy_by_role(target_root, "Primary")
	var linked := _find_dummy_by_role(target_root, "Spectator")
	if anchor == null or linked == null:
		_fail("missing dummy pair")
		return false
	var projectile := projectile_scene.instantiate() as PlasmaLanceProjectile
	if projectile == null:
		_fail("projectile scene did not instantiate PlasmaLanceProjectile")
		return false
	projectile.source_weapon = plasma_lance
	projectile.damage = 100
	projectile.damage_type = Attack.TYPE_ENERGY
	projectile.rift_damage_ratio = 0.5
	projectile.rift_width = 24.0
	projectile.expire_time = 10.0
	projectile.projectile_texture = projectile_texture
	projectile.desired_pixel_size = Vector2(10.0, 10.0)
	_scene.add_child(projectile)
	await get_tree().physics_frame
	var anchor_before := int(anchor.get("hp"))
	var linked_before := int(linked.get("hp"))
	projectile.call("on_hit_target", anchor)
	await get_tree().physics_frame
	if int(anchor.get("hp")) != anchor_before or int(linked.get("hp")) != linked_before:
		_fail("rift damaged enemies on first anchor hit")
		projectile.queue_free()
		return false
	projectile.call("on_hit_target", linked)
	if _count_rift_vfx_nodes(self) <= 0:
		_fail("rift VFX node was not spawned")
		projectile.queue_free()
		return false
	await get_tree().physics_frame
	var anchor_damage := anchor_before - int(anchor.get("hp"))
	var linked_damage := linked_before - int(linked.get("hp"))
	if anchor_damage != 50:
		_fail("anchor damage expected 50 got %d" % anchor_damage)
		projectile.queue_free()
		return false
	if linked_damage != 50:
		_fail("linked damage expected 50 got %d" % linked_damage)
		projectile.queue_free()
		return false
	projectile.call("despawn")
	await get_tree().physics_frame
	if is_instance_valid(projectile) and not Array(projectile.get("_rift_hit_positions")).is_empty():
		_fail("rift positions were not cleared on despawn")
		return false
	return true


func _assert_anchor_tracks_enemy_current_position() -> bool:
	var plasma_lance := _get_plasma_lance_weapon()
	if plasma_lance == null:
		_fail("missing Plasma Lance weapon for moving anchor")
		return false
	var anchor := _spawn_test_dummy(Vector2(560.0, 520.0), "RiftMovingAnchor")
	var linked := _spawn_test_dummy(Vector2(656.0, 520.0), "RiftMovingLinked")
	var old_line_probe := _spawn_test_dummy(Vector2(560.0, 520.0), "RiftOldLineProbe")
	var updated_fallback_probe := _spawn_test_dummy(Vector2(656.0, 424.0), "RiftUpdatedFallbackProbe")
	var third := _spawn_test_dummy(Vector2(760.0, 424.0), "RiftMovingThird")
	if anchor == null or linked == null or old_line_probe == null or updated_fallback_probe == null or third == null:
		_fail("unable to spawn moving anchor dummies")
		return false
	var projectile := _make_test_projectile(plasma_lance)
	if projectile == null:
		return false
	_scene.add_child(projectile)
	await get_tree().physics_frame
	projectile.call("on_hit_target", anchor)
	anchor.global_position = Vector2(656.0, 424.0)
	linked.global_position = Vector2(656.0, 520.0)
	old_line_probe.global_position = Vector2(560.0, 520.0)
	updated_fallback_probe.global_position = Vector2(656.0, 424.0)
	third.global_position = Vector2(760.0, 424.0)
	await get_tree().physics_frame
	var anchor_before := int(anchor.get("hp"))
	var linked_before := int(linked.get("hp"))
	var old_probe_before := int(old_line_probe.get("hp"))
	var updated_fallback_probe_before := int(updated_fallback_probe.get("hp"))
	var third_before := int(third.get("hp"))
	projectile.call("on_hit_target", linked)
	await get_tree().physics_frame
	if anchor_before - int(anchor.get("hp")) != 50:
		_fail("moving rift anchor did not use current enemy position")
		projectile.queue_free()
		return false
	if linked_before - int(linked.get("hp")) != 50:
		_fail("moving rift linked target damage expected 50")
		projectile.queue_free()
		return false
	if old_probe_before - int(old_line_probe.get("hp")) != 0:
		_fail("moving rift incorrectly used recorded fallback position")
		projectile.queue_free()
		return false
	updated_fallback_probe_before = int(updated_fallback_probe.get("hp"))
	anchor.set("is_dead", true)
	projectile.call("on_hit_target", third)
	await get_tree().physics_frame
	if updated_fallback_probe_before - int(updated_fallback_probe.get("hp")) != 50:
		_fail("moving rift did not update recorded fallback position")
		projectile.queue_free()
		return false
	if third_before - int(third.get("hp")) != 50:
		_fail("moving rift third target damage expected 50")
		projectile.queue_free()
		return false
	projectile.call("despawn")
	return true


func _assert_anchor_falls_back_to_recorded_position() -> bool:
	var plasma_lance := _get_plasma_lance_weapon()
	if plasma_lance == null:
		_fail("missing Plasma Lance weapon for fallback anchor")
		return false
	var anchor := _spawn_test_dummy(Vector2(560.0, 640.0), "RiftFallbackAnchor")
	var linked := _spawn_test_dummy(Vector2(656.0, 640.0), "RiftFallbackLinked")
	var fallback_probe := _spawn_test_dummy(Vector2(560.0, 640.0), "RiftFallbackProbe")
	if anchor == null or linked == null or fallback_probe == null:
		_fail("unable to spawn fallback anchor dummies")
		return false
	var projectile := _make_test_projectile(plasma_lance)
	if projectile == null:
		return false
	_scene.add_child(projectile)
	await get_tree().physics_frame
	projectile.call("on_hit_target", anchor)
	anchor.set("is_dead", true)
	anchor.global_position = Vector2(656.0, 544.0)
	linked.global_position = Vector2(656.0, 640.0)
	fallback_probe.global_position = Vector2(560.0, 640.0)
	await get_tree().physics_frame
	var linked_before := int(linked.get("hp"))
	var fallback_probe_before := int(fallback_probe.get("hp"))
	projectile.call("on_hit_target", linked)
	await get_tree().physics_frame
	if linked_before - int(linked.get("hp")) != 50:
		_fail("fallback rift linked target damage expected 50")
		projectile.queue_free()
		return false
	if fallback_probe_before - int(fallback_probe.get("hp")) != 50:
		_fail("fallback rift did not use recorded anchor position")
		projectile.queue_free()
		return false
	projectile.call("despawn")
	return true


func _assert_real_fire_rift_contract() -> bool:
	var plasma_lance := _get_plasma_lance_weapon()
	if plasma_lance == null or not is_instance_valid(plasma_lance):
		_fail("missing Plasma Lance weapon for real fire")
		return false
	var target_root := _scene.get_node_or_null("SpawnRoot/Targets")
	var target_spawn := _scene.get_node_or_null("SpawnRoot/TargetSpawn") as Node2D
	if target_root == null or target_spawn == null:
		_fail("missing target nodes for real fire")
		return false
	var anchor := _find_dummy_by_role(target_root, "Primary")
	var linked := _find_dummy_by_role(target_root, "Spectator")
	if anchor == null or linked == null:
		_fail("missing dummy pair for real fire")
		return false
	anchor.global_position = target_spawn.global_position
	linked.global_position = target_spawn.global_position + Vector2(96.0, 0.0)
	_scene.call("_set_main_weapon", "Plasma Lance")
	plasma_lance.call("set_level", 7)
	plasma_lance.set("current_ammo", maxi(1, int(plasma_lance.get("magazine_capacity"))))
	plasma_lance.set("is_on_cooldown", false)
	plasma_lance.set("is_reloading", false)
	plasma_lance.call("force_skill_cooldowns_ready")
	var vfx_count_before := _count_rift_vfx_nodes(self)
	var anchor_hp_before := int(anchor.get("hp"))
	var linked_hp_before := int(linked.get("hp"))
	_scene.call("_fire_plasma_lance")
	var spawned := await _wait_for_rift_vfx_count_above(vfx_count_before, 0.6)
	if not spawned:
		_fail("real Plasma Lance fire did not spawn rift VFX through aligned enemies; anchor_damage=%d linked_damage=%d projectiles=%d" % [
			anchor_hp_before - int(anchor.get("hp")),
			linked_hp_before - int(linked.get("hp")),
			_count_plasma_projectiles(self),
		])
		return false
	return true


func _get_plasma_lance_weapon() -> Weapon:
	var weapons_by_name: Dictionary = _scene.get("_weapons_by_name")
	return weapons_by_name.get("Plasma Lance", null) as Weapon


func _make_test_projectile(plasma_lance: Weapon) -> PlasmaLanceProjectile:
	var projectile := projectile_scene.instantiate() as PlasmaLanceProjectile
	if projectile == null:
		_fail("projectile scene did not instantiate PlasmaLanceProjectile")
		return null
	projectile.source_weapon = plasma_lance
	projectile.damage = 100
	projectile.damage_type = Attack.TYPE_ENERGY
	projectile.rift_damage_ratio = 0.5
	projectile.rift_width = 24.0
	projectile.expire_time = 10.0
	projectile.projectile_texture = projectile_texture
	projectile.desired_pixel_size = Vector2(10.0, 10.0)
	return projectile


func _spawn_test_dummy(position_value: Vector2, role: String) -> Node2D:
	if not _scene.has_method("_spawn_dummy_at"):
		return null
	var dummy := _scene.call("_spawn_dummy_at", position_value, role) as Node2D
	if dummy != null:
		dummy.global_position = position_value
	return dummy


func _wait_for_rift_vfx_count_above(previous_count: int, timeout_sec: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if _count_rift_vfx_nodes(self) > previous_count:
			return true
	return false


func _wait_for_rift_vfx_clear(timeout_sec: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		if _count_rift_vfx_nodes(self) <= 0:
			return


func _find_dummy_by_role(target_root: Node, role: String) -> Node2D:
	for child in target_root.get_children():
		var node := child as Node2D
		if node == null:
			continue
		if str(node.get_meta("heat_passive_test_role", "")) == role:
			return node
	return null


func _count_rift_vfx_nodes(root_node: Node) -> int:
	var count := 0
	if root_node is PlasmaLanceRiftVfx:
		count += 1
	for child in root_node.get_children():
		count += _count_rift_vfx_nodes(child)
	return count


func _count_plasma_projectiles(root_node: Node) -> int:
	var count := 0
	if root_node is PlasmaLanceProjectile:
		count += 1
	for child in root_node.get_children():
		count += _count_plasma_projectiles(child)
	return count


func _fail(message: String) -> void:
	push_error("FAIL: %s" % message)
	get_tree().quit(1)
