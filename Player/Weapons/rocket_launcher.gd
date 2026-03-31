extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/minigun_bullet.png")
#@onready var sprite = get_node("%Sprite")

#OC
@onready var fall_effect = preload("res://Player/Weapons/Effects/fall.tscn")
@onready var oc_booming_area: Area2D = $OCBoomingArea

# Weapon
var ITEM_NAME = "Rocket Luncher"
var explosion_scale : float = 2.0


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "10",
		"speed": "500",
		"hp": "1",
		"reload": "2.4",
		"explosion_scale": "2.0",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "13",
		"speed": "560",
		"hp": "1",
		"reload": "2.2",
		"explosion_scale": "2.1",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "16",
		"speed": "600",
		"hp": "1",
		"reload": "2.0",
		"explosion_scale": "2.2",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "20",
		"speed": "650",
		"hp": "1",
		"reload": "1.8",
		"explosion_scale": "2.35",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "25",
		"speed": "700",
		"hp": "2",
		"reload": "1.6",
		"explosion_scale": "2.5",
		"cost": "1",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	explosion_scale = float(weapon_data[lv]["explosion_scale"])
	sync_stats()
	_sync_explosion_effect_config()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)

func _on_shoot():
	is_on_cooldown = true
	var cooldown := attack_cooldown
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= branch_behavior.get_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var base_direction := global_position.direction_to(get_mouse_target()).normalized()
	var shot_directions: Array[Vector2] = [base_direction]
	if branch_behavior and is_instance_valid(branch_behavior):
		shot_directions = branch_behavior.get_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]
	var damage_multiplier := 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_multiplier = branch_behavior.get_projectile_damage_multiplier()
	for dir in shot_directions:
		_fire_single_rocket(dir.normalized(), damage_multiplier)
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_weapon_shot(base_direction)

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
		if branch_behavior and is_instance_valid(branch_behavior) and branch_behavior.has_method("modify_explosion_config"):
			branch_behavior.call("modify_explosion_config", explosion_config)
