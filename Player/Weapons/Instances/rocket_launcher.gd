extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/rocket_projectile.png")


# Weapon
var ITEM_NAME = "Rocket Launcher"
var explosion_scale : float = 2.0
@export var cluster_kill_radius: float = 180.0

func _init() -> void:
	super._init()
	range_mode = RangeMode.FIXED_DISTANCE
	configured_attack_range = 800.0


var weapon_data = {
	"1": {"damage": "42", "speed": "460", "projectile_hits": "1", "fire_interval_sec": "2.4", "ammo": "6", "explosion_scale": "2.20"},
	"2": {"damage": "53", "speed": "500", "projectile_hits": "1", "fire_interval_sec": "2.3", "ammo": "6", "explosion_scale": "2.35"},
	"3": {"damage": "68", "speed": "540", "projectile_hits": "1", "fire_interval_sec": "2.2", "ammo": "6", "explosion_scale": "2.50"},
	"4": {"damage": "84", "speed": "580", "projectile_hits": "1", "fire_interval_sec": "2.1", "ammo": "8", "explosion_scale": "2.70"},
	"5": {"damage": "105", "speed": "620", "projectile_hits": "1", "fire_interval_sec": "2.0", "ammo": "8", "explosion_scale": "2.90"},
	"6": {"damage": "131", "speed": "650", "projectile_hits": "1", "fire_interval_sec": "1.9", "ammo": "8", "explosion_scale": "3.10"},
	"7": {"damage": "158", "speed": "680", "projectile_hits": "1", "fire_interval_sec": "1.8", "ammo": "10", "explosion_scale": "3.35"},
	"8": {"damage": "189", "speed": "700", "projectile_hits": "1", "fire_interval_sec": "1.7", "ammo": "10", "explosion_scale": "3.60"},
	"9": {"damage": "226", "speed": "720", "projectile_hits": "1", "fire_interval_sec": "1.6", "ammo": "10", "explosion_scale": "3.90"}
}


func set_level(lv):
	lv = str(lv)
	var level_data := get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	explosion_scale = float(level_data["explosion_scale"])
	sync_stats()
	_sync_explosion_effect_config()
	branch_runtime.notify_branch_level_applied(level)

func _on_shoot():
	is_on_cooldown = true
	var cooldown := attack_cooldown / maxf(get_external_attack_speed_multiplier(), 0.1)
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var base_direction := global_position.direction_to(get_mouse_target()).normalized()
	var shot_directions: Array[Vector2] = [base_direction]
	shot_directions = branch_runtime.get_branch_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]
	var damage_multiplier := branch_runtime.get_branch_projectile_damage_multiplier()
	for dir in shot_directions:
		_fire_single_rocket(dir.normalized(), damage_multiplier)
	branch_runtime.notify_branch_weapon_shot(base_direction)

func supports_multi_launcher_module() -> bool:
	return true

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
	spawn_projectile.expire_time = get_effective_projectile_lifetime()
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
		explosion_config.draw_enabled = false
		branch_runtime.apply_branch_explosion_modifiers(explosion_config)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_enemy_killed":
		return
	var source_weapon := detail.get("source_weapon", null) as Weapon
	if source_weapon != self:
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
	if not is_passive_ready():
		state = "waiting_refresh"
	var charge_current := passive_controller.get_passive_charge_current()
	var charge_max := passive_controller.get_passive_charge_max()
	return with_passive_charge_status({
		"id": "rocket_cluster_kill_triggered",
		"display_name": "Cluster Kill",
		"state": state,
		"progress": float(charge_current) / float(maxi(charge_max, 1)),
		"ready": state == "ready",
		"trigger_hint": "enemy_killed_nearby_enemy",
		"refresh_hint": "reload",
		"charge_current": charge_current,
		"charge_max": charge_max,
		"charges_current": charge_current,
		"charges_max": charge_max,
		"radius": maxf(cluster_kill_radius, 0.0),
	})

func get_passive_max_charges() -> int:
	return 3

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
