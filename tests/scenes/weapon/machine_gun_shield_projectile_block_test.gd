extends Node

const MACHINE_GUN_SCENE := preload("res://Player/Weapons/Instances/machine_gun.tscn")
const SHIELD_SCENE := preload("res://Player/Weapons/Branches/machine_gun_front_shield.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://Npc/enemy/scenes/enemy_spike_projectile.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false

func _ready() -> void:
	var player := Node2D.new()
	player.name = "ShieldTestPlayer"
	add_child(player)
	PlayerData.player = player

	var weapon := MACHINE_GUN_SCENE.instantiate() as Weapon
	add_child(weapon)
	var shield := SHIELD_SCENE.instantiate() as MachineGunFrontShield
	weapon.add_child(shield)
	shield.setup(weapon)
	await get_tree().physics_frame

	_expect(shield.current_charges == 2, "shield must start with two charges")

	var projectile := ENEMY_PROJECTILE_SCENE.instantiate() as EnemySpikeProjectile
	projectile.position = Vector2(0.0, -90.0)
	projectile.direction = Vector2.DOWN
	projectile.speed = 300.0
	projectile.life_time = 2.0
	add_child(projectile)
	var projectile_id := projectile.get_instance_id()

	for frame_index in range(30):
		await get_tree().physics_frame
		if not is_instance_id_valid(projectile_id):
			break

	_expect(
		not is_instance_id_valid(projectile_id),
		"front-facing enemy projectile must be removed before crossing the shield"
	)
	_expect(shield.current_charges == 1, "blocking one projectile must consume one shield charge")

	var rear_projectile := ENEMY_PROJECTILE_SCENE.instantiate() as EnemySpikeProjectile
	rear_projectile.position = Vector2(0.0, 20.0)
	rear_projectile.direction = Vector2.DOWN
	rear_projectile.speed = 0.0
	rear_projectile.life_time = 2.0
	add_child(rear_projectile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(
		is_instance_valid(rear_projectile) and not rear_projectile.is_queued_for_deletion(),
		"projectile behind the player must remain outside the frontal block arc"
	)
	_expect(shield.current_charges == 1, "rear projectile must not consume a shield charge")

	print(
		"FAIL machine gun shield projectile block"
		if _failed
		else "PASS machine gun shield projectile block"
	)
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, PlayerData.reset_runtime_state)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
