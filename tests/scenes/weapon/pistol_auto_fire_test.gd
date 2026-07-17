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
	enemy.global_position = Vector2(100.0, 0.0)

	await get_tree().physics_frame
	await get_tree().physics_frame
	var found_target := pistol.call("_find_closest_enemy") as Node2D
	var failed := false
	failed = _check(found_target == enemy, "Auto Pistol must find a nearby group-only enemy") or failed
	failed = _check(_shot_count > 0, "Auto Pistol must automatically fire at a nearby enemy") or failed
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
