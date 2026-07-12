extends Node

const WeaponScene := preload("res://Player/Weapons/weapon.tscn")
const ProjectileScene := preload("res://Player/Weapons/Projectiles/projectile.tscn")
const FeedbackProfile := preload("res://Player/Weapons/Feedback/weapon_fire_feedback_profile.gd")
const ProjectileTexture := preload("res://asset/images/weapons/projectiles/pistol_projectile.png")
const MachineGunScene := preload("res://Player/Weapons/Instances/machine_gun.tscn")
const SniperProjectileScene := preload("res://Player/Weapons/Projectiles/sniper_projectile.tscn")
const PlasmaProjectileScene := preload("res://Player/Weapons/Projectiles/plasma_lance_projectile.tscn")
const EnemySpikeScene := preload("res://Npc/enemy/scenes/enemy_spike_projectile.tscn")

func _ready() -> void:
	var failed := false
	var weapon := WeaponScene.instantiate() as Weapon
	var muzzle := Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(0.0, -24.0)
	weapon.add_child(muzzle)
	add_child(weapon)
	await get_tree().process_frame
	failed = _check(weapon.sprite.has_method("world_direction_to_screen"), "weapon sprite must be directional billboard") or failed
	var muzzle_before := weapon.get_muzzle_global_position()
	var profile := FeedbackProfile.new()
	profile.recoil_distance = 8.0
	profile.recoil_duration = 0.02
	profile.recoil_recover_duration = 0.02
	weapon.fire_feedback_profile = profile
	weapon.play_fire_feedback(Vector2.RIGHT)
	await get_tree().create_timer(0.03).timeout
	failed = _check(weapon.get_muzzle_global_position().is_equal_approx(muzzle_before), "visual recoil must not move logical muzzle") or failed
	var projectile := ProjectileScene.instantiate() as Projectile
	projectile.projectile_texture = ProjectileTexture
	projectile.base_displacement = Vector2.RIGHT * 100.0
	add_child(projectile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	failed = _check(projectile.projectile_root.has_method("set_logical_local_position"), "projectile visual must be billboard") or failed
	failed = _check(projectile.hitbox_ins != null and projectile.hitbox_ins.get_parent() == projectile.hitbox_anchor, "projectile hitbox must stay under logical anchor") or failed
	var machine_gun := MachineGunScene.instantiate() as Weapon
	add_child(machine_gun)
	await get_tree().process_frame
	failed = _check(machine_gun.sprite.has_method("world_direction_to_screen"), "machine gun sprite must inherit directional billboard") or failed
	failed = _check(machine_gun.get_node_or_null("Muzzle") != null, "machine gun logical muzzle must remain available") or failed
	for packed: PackedScene in [SniperProjectileScene, PlasmaProjectileScene]:
		var specialized := packed.instantiate() as Projectile
		failed = _check(specialized != null and specialized.get_node_or_null("HitboxAnchor") != null, "specialized projectile must inherit logical hitbox anchor") or failed
		failed = _check(specialized != null and specialized.get_node_or_null("Bullet") != null and specialized.get_node("Bullet").has_method("reset_projection_state"), "specialized projectile must inherit billboard reset") or failed
		specialized.free()
	var enemy_spike := EnemySpikeScene.instantiate() as EnemySpikeProjectile
	add_child(enemy_spike)
	await get_tree().process_frame
	failed = _check(enemy_spike.sprite.has_method("world_direction_to_screen"), "enemy spike visual must be directional billboard") or failed
	if failed:
		print("FAIL hybrid weapon chain")
		get_tree().quit(1)
	else:
		print("PASS hybrid weapon chain")
		get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
