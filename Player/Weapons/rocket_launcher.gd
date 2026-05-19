extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/minigun_bullet.png")


# Weapon
var ITEM_NAME = "Rocket Luncher"
var explosion_scale : float = 2.0
@export var cluster_kill_radius: float = 180.0


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "10",
		"speed": "500",
		"hp": "1",
		"fire_interval_sec": "2.4",
		"ammo": "14",
		"explosion_scale": "2.0",
		"cost": "6",
	},
	"2": {
		"level": "2",
		"damage": "13",
		"speed": "560",
		"hp": "1",
		"fire_interval_sec": "2.2",
		"ammo": "16",
		"explosion_scale": "2.1",
		"cost": "6",
	},
	"3": {
		"level": "3",
		"damage": "16",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "2.0",
		"ammo": "18",
		"explosion_scale": "2.2",
		"cost": "6",
	},
	"4": {
		"level": "4",
		"damage": "20",
		"speed": "650",
		"hp": "1",
		"fire_interval_sec": "1.8",
		"ammo": "20",
		"explosion_scale": "2.35",
		"cost": "6",
	},
	"5": {
		"level": "5",
		"damage": "25",
		"speed": "700",
		"hp": "2",
		"fire_interval_sec": "1.6",
		"ammo": "22",
		"explosion_scale": "2.5",
		"cost": "6",
	},
	"6": {
		"level": "6",
		"damage": "31",
		"speed": "750",
		"hp": "2",
		"fire_interval_sec": "1.4",
		"ammo": "24",
		"explosion_scale": "2.65",
		"cost": "6",
	},
	"7": {
		"level": "7",
		"damage": "39",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "1.2",
		"ammo": "26",
		"explosion_scale": "2.8",
		"cost": "6",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])

	base_attack_cooldown = float(weapon_data[lv]["fire_interval_sec"])
	apply_level_ammo(weapon_data[lv])
	explosion_scale = float(weapon_data[lv]["explosion_scale"])
	sync_stats()
	_sync_explosion_effect_config()
	notify_branch_level_applied(level)

func _on_shoot():
	is_on_cooldown = true
	var cooldown := attack_cooldown / maxf(get_external_attack_speed_multiplier(), 0.1)
	cooldown *= get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var base_direction := global_position.direction_to(get_mouse_target()).normalized()
	var shot_directions: Array[Vector2] = [base_direction]
	shot_directions = get_branch_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]
	var damage_multiplier := get_branch_projectile_damage_multiplier()
	for dir in shot_directions:
		_fire_single_rocket(dir.normalized(), damage_multiplier)
	notify_branch_weapon_shot(base_direction)

func _fire_single_rocket(direction: Vector2, damage_multiplier: float = 1.0) -> void:
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	projectile_direction = direction
	var runtime_damage := get_runtime_shot_damage()
	var projectile_damage: int = maxi(1, int(round(float(runtime_damage) * maxf(damage_multiplier, 0.05))))
	spawn_projectile.damage = projectile_damage
	spawn_projectile.damage_type = Attack.TYPE_PHYSICAL
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	_sync_explosion_effect_config(projectile_damage)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

# Keeps the typed explosion config synced with current weapon runtime stats.
func _sync_explosion_effect_config(projectile_damage: int = damage) -> void:
	var config := ensure_effect_config(&"explosion_effect")
	if config is ExplosionEffectConfig:
		var explosion_config := config as ExplosionEffectConfig
		explosion_config.damage = projectile_damage
		explosion_config.damage_type = Attack.TYPE_FIRE
		explosion_config.explosion_size = size * explosion_scale
		apply_branch_explosion_modifiers(explosion_config)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_enemy_killed":
		return
	var source_weapon := detail.get("source_weapon", null) as Weapon
	if source_weapon != self or not is_main_weapon():
		return
	var death_position_variant: Variant = detail.get("position", null)
	if not (death_position_variant is Vector2):
		return
	var nearby_count := _count_other_enemies_near(death_position_variant as Vector2, detail.get("enemy", null))
	if nearby_count <= 0:
		return
	if not is_offhand_skill_ready():
		return
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"rocket_cluster_kill_triggered", {
		"enemy": detail.get("enemy", null),
		"position": death_position_variant,
		"radius": maxf(cluster_kill_radius, 0.0),
		"nearby_enemy_count": nearby_count,
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var state := "ready"
	if not is_main_weapon():
		state = "inactive"
	elif not is_passive_ready():
		state = "waiting_refresh"
	return {
		"id": "rocket_cluster_kill_triggered",
		"display_name": "Cluster Kill",
		"state": state,
		"ready": state == "ready",
		"trigger_hint": "enemy_killed_nearby_enemy",
		"refresh_hint": "reload",
		"radius": maxf(cluster_kill_radius, 0.0),
	}

func _count_other_enemies_near(position: Vector2, killed_enemy: Variant) -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var count := 0
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(tree, position, maxf(cluster_kill_radius, 0.0)):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if killed_enemy is Object and enemy == killed_enemy:
			continue
		count += 1
	return count
