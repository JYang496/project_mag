extends Node

const WeaponScene := preload("res://Player/Weapons/weapon.tscn")
const ProjectileScene := preload("res://Player/Weapons/Projectiles/projectile.tscn")
const FeedbackProfile := preload("res://Player/Weapons/Feedback/weapon_fire_feedback_profile.gd")
const ProjectileTexture := preload("res://asset/images/weapons/projectiles/pistol_projectile.png")
const MachineGunScene := preload("res://Player/Weapons/Instances/machine_gun.tscn")
const SniperProjectileScene := preload("res://Player/Weapons/Projectiles/sniper_projectile.tscn")
const PlasmaProjectileScene := preload("res://Player/Weapons/Projectiles/plasma_lance_projectile.tscn")
const EnemySpikeScene := preload("res://Npc/enemy/scenes/enemy_spike_projectile.tscn")
const BeamScene := preload("res://Player/Weapons/Projectiles/beam.tscn")
const BeamBlastScene := preload("res://Player/Weapons/Projectiles/beam_blast.tscn")
const ConeSprayScene := preload("res://Player/Weapons/Effects/cone_spray_vfx.tscn")
const DashBladeScene := preload("res://Player/Weapons/Instances/dash_blade.tscn")

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
	var projectile := ObjectPool.acquire(ProjectileScene) as Projectile
	projectile.projectile_texture = ProjectileTexture
	projectile.base_displacement = Vector2.RIGHT * 100.0
	add_child(projectile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	failed = _check(projectile.projectile_root.has_method("set_logical_local_position"), "projectile visual must be billboard") or failed
	failed = _check(projectile.hitbox_ins != null and projectile.hitbox_ins.get_parent() == projectile.hitbox_anchor, "projectile hitbox must stay under logical anchor") or failed
	var pooled_projectile_id := projectile.get_instance_id()
	ObjectPool.release(projectile)
	await get_tree().process_frame
	var reused_projectile := ObjectPool.acquire(ProjectileScene) as Projectile
	reused_projectile.projectile_texture = ProjectileTexture
	add_child(reused_projectile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	failed = _check(reused_projectile.get_instance_id() == pooled_projectile_id, "projectile pool must reuse the released instance") or failed
	failed = _check(reused_projectile.get_node_or_null("HitboxAnchor") == reused_projectile.hitbox_anchor, "pooled projectile must preserve its logical HitboxAnchor") or failed
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
	var sniper := SniperProjectileScene.instantiate() as Projectile
	failed = _check(float(sniper.get_node("Bullet").get("directional_forward_degrees")) == -90.0, "sniper projectile must declare its upward art axis") or failed
	sniper.free()
	var plasma := PlasmaProjectileScene.instantiate() as Projectile
	failed = _check(int(plasma.visual_mode) == int(Projectile.ProjectileVisualMode.UPRIGHT), "plasma orb must classify as upright") or failed
	failed = _check(int(plasma.get_node("Bullet").get("mode")) == int(BillboardVisual2D.BillboardMode.UPRIGHT), "plasma orb billboard must be upright") or failed
	plasma.free()
	var enemy_spike := EnemySpikeScene.instantiate() as EnemySpikeProjectile
	add_child(enemy_spike)
	await get_tree().process_frame
	failed = _check(enemy_spike.sprite.has_method("world_direction_to_screen"), "enemy spike visual must be directional billboard") or failed
	failed = _check(float(enemy_spike.sprite.get("directional_forward_degrees")) == -90.0, "enemy spike must declare its upward art axis") or failed
	var beam := BeamScene.instantiate()
	beam.set("target_position", Vector2.RIGHT * 120.0)
	add_child(beam)
	var beam_blast := BeamBlastScene.instantiate()
	beam_blast.set("target_position", Vector2.RIGHT * 20.0)
	beam_blast.set("hit_cd", 0.2)
	add_child(beam_blast)
	await get_tree().process_frame
	var beam_line := beam.get_node("RayCast2D/Line2D") as Line2D
	var blast_line := beam_blast.get_node("Line2D") as Line2D
	failed = _check(beam_line.is_in_group(&"hybrid_ground_segment") and beam_line.get_meta("hybrid_segment_style") == &"beam", "laser beam must request the flowing 3D beam style") or failed
	failed = _check(blast_line.is_in_group(&"hybrid_ground_segment") and bool(blast_line.get_meta("hybrid_segment_endpoints")), "charged beam must request 3D endpoint glows") or failed
	var cone := ConeSprayScene.instantiate() as ConeSprayVfx
	add_child(cone)
	cone.start_or_refresh(Vector2.ZERO, Vector2.RIGHT, 280.0, 40.0)
	failed = _check(cone.is_in_group(&"hybrid_ground_cone_effect"), "cone spray must register one 3D fan mesh source") or failed
	var dash_blade := DashBladeScene.instantiate()
	failed = _check(dash_blade.get_node("BladeAnchor/BladeSprite").has_method("world_direction_to_screen"), "dash blade subvisual must use directional billboard") or failed
	dash_blade.free()
	failed = _validate_all_weapon_fuse_visuals() or failed
	failed = _validate_all_projectile_scenes() or failed
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

func _validate_all_weapon_fuse_visuals() -> bool:
	var failed := false
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Instances"):
		if not file_name.ends_with(".tscn"):
			continue
		var packed := load("res://Player/Weapons/Instances/%s" % file_name) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate()
		if not instance is Weapon:
			instance.free()
			continue
		var sprite := instance.get_node_or_null("Sprite") as Sprite2D
		failed = _check(sprite != null and sprite.has_method("world_direction_to_screen"), "%s Fuse/main Sprite must use directional billboard" % file_name) or failed
		var holder := instance.get_node_or_null("FuseSprites")
		failed = _check(holder == null or not holder is CanvasItem, "%s FuseSprites must remain a resource holder, not a transformed visual" % file_name) or failed
		instance.free()
	return failed

func _validate_all_projectile_scenes() -> bool:
	var failed := false
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Projectiles"):
		if not file_name.ends_with(".tscn"):
			continue
		var packed := load("res://Player/Weapons/Projectiles/%s" % file_name) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate()
		if not instance is Projectile:
			instance.free()
			continue
		failed = _check(instance.get_node_or_null("HitboxAnchor") != null, "%s must keep a logical HitboxAnchor" % file_name) or failed
		var bullet := instance.get_node_or_null("Bullet")
		failed = _check(bullet != null and bullet.has_method("reset_projection_state"), "%s must classify its Billboard visual" % file_name) or failed
		instance.free()
	return failed
