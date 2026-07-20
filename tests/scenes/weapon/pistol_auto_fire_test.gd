extends Node

const PistolScene := preload("res://Player/Weapons/Instances/pistol.tscn")

var _shot_count := 0

func _ready() -> void:
	PhaseManager.enter_battle()
	var pistol := PistolScene.instantiate() as Weapon
	add_child(pistol)
	pistol.global_position = Vector2.ZERO
	pistol.shoot.connect(func() -> void: _shot_count += 1)

	# A group-only enemy exercises the fallback used when the registry misses an entry.
	var enemy := Node2D.new()
	enemy.add_to_group(&"enemies")
	add_child(enemy)
	# Reproduce the live failure mode where aim and muzzle positions briefly
	# coincide. A valid shot must still be emitted instead of only spending ammo.
	enemy.global_position = Vector2.ZERO

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var found_target := pistol.call("_find_closest_enemy") as Node2D
	var spawned_projectile: Projectile
	for child in get_children():
		if child is Projectile:
			spawned_projectile = child as Projectile
			break
	var failed := false
	failed = _check(found_target == enemy, "Auto Pistol must find a nearby group-only enemy") or failed
	failed = _check(_shot_count > 0, "Auto Pistol must automatically fire at a nearby enemy") or failed
	failed = _check(spawned_projectile != null, "Auto Pistol must add a projectile after spending ammo") or failed
	if spawned_projectile != null:
		failed = _check(spawned_projectile.base_displacement.length_squared() > 0.0, "Auto Pistol projectile must receive non-zero movement") or failed
		failed = _check(spawned_projectile.global_position != pistol.global_position, "Auto Pistol projectile must move away from the muzzle") or failed
	if failed:
		print("FAIL pistol auto fire")
		get_tree().quit(1)
	else:
		print("PASS pistol auto fire")
		get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
