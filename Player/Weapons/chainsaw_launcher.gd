extends Ranger

var spin_effect = preload("res://Player/Weapons/Effects/spin_effect.tscn")
var scale_up_by_time_effect = preload("res://Player/Weapons/Effects/scale_up_by_time.tscn")
var chase_closest_enemy_effect = preload("res://Player/Weapons/Effects/chase_closest_enemy.tscn")

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/chainsaw_spin.png")
#@onready var sprite = get_node("%Sprite")

# Weapon
var ITEM_NAME = "Chainsaw Luncher"

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "2",
		"speed": "200",
		"hp": "15",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "4",
		"speed": "200",
		"hp": "15",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "7",
		"speed": "200",
		"hp": "20",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "10",
		"speed": "200",
		"hp": "25",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "15",
		"speed": "200",
		"hp": "25",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	},
	"6": {
		"level": "6",
		"damage": "20",
		"speed": "200",
		"hp": "30",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	},
	"7": {
		"level": "25",
		"damage": "15",
		"speed": "200",
		"hp": "30",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])
	dot_cd = float(weapon_data[lv]["dot_cd"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	_sync_speed_change_effect_config()


func _on_shoot():
	is_on_cooldown = true
	cooldown_timer.start()
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	spawn_projectile.damage = get_runtime_shot_damage()
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	spawn_projectile.hitbox_type = "dot"
	spawn_projectile.dot_cd = dot_cd
	apply_spin(spawn_projectile)
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child",spawn_projectile)

func apply_spin(projectile_node) -> void:
	var spin_movement_ins = spin_effect.instantiate()
	projectile_node.call_deferred("add_child",spin_movement_ins)
	projectile_node.module_list.append(spin_movement_ins)
	module_list.append(spin_movement_ins)

func apply_scale_up_by_time(projectile_node) -> void:
	var scale_up_by_time = scale_up_by_time_effect.instantiate()
	projectile_node.call_deferred("add_child",scale_up_by_time)
	projectile_node.module_list.append(scale_up_by_time)
	module_list.append(scale_up_by_time)

func apply_chase_closest_enemy(projectile_node) -> void:
	var chase_ins = chase_closest_enemy_effect.instantiate()
	projectile_node.call_deferred("add_child",chase_ins)
	projectile_node.module_list.append(chase_ins)
	module_list.append(chase_ins)

func _on_chainsaw_luncher_timer_timeout() -> void:
	is_on_cooldown = false

# Ensures the typed speed-change effect config exists and stays synced.
func _sync_speed_change_effect_config() -> void:
	var config := ensure_effect_config(&"speed_change_on_hit")
	if config is SpeedChangeOnHitEffectConfig:
		var speed_config := config as SpeedChangeOnHitEffectConfig
		speed_config.speed_rate = 0.3
