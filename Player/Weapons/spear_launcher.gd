extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/spear.png")
var return_on_timeout = preload("res://Player/Weapons/Bullets/return_on_timeout.tscn")
@onready var sprite = get_node("%Sprite")
@onready var spear_cooldownTimer = $SpearCooldownTimer

# Weapon
var ITEM_NAME = "Spear Launcher"
var damage : int
var speed : int
var hp : int
var reload : float

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "10",
		"speed": "900",
		"hp": "10",
		"reload": "0.7",
		"cost": "1",
		"features": ["piercing"],
	},
	"2": {
		"level": "2",
		"damage": "15",
		"speed": "600",
		"hp": "10",
		"reload": "0.5",
		"cost": "1",
		"features": ["piercing"],
	},
	"3": {
		"level": "3",
		"damage": "20",
		"speed": "600",
		"hp": "10",
		"reload": "0.4",
		"cost": "1",
		"features": ["piercing"],
	},
	"4": {
		"level": "4",
		"damage": "30",
		"speed": "800",
		"hp": "10",
		"reload": "0.4",
		"cost": "1",
		"features": ["piercing"],
	},
	"5": {
		"level": "5",
		"damage": "40",
		"speed": "800",
		"hp": "20",
		"reload": "0.4",
		"cost": "1",
		"features": ["piercing"],
	}
}

func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	speed = int(weapon_data[lv]["speed"])
	hp = int(weapon_data[lv]["hp"])
	reload = float(weapon_data[lv]["reload"])
	spear_cooldownTimer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)


func _on_shoot():
	justAttacked = true
	spear_cooldownTimer.start()
	var spawn_bullet = bullet.instantiate()
	var bullet_direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.damage = damage
	spawn_bullet.hp = hp
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	apply_return_on_timeour(spawn_bullet)
	apply_linear(spawn_bullet, bullet_direction, speed)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func apply_return_on_timeour(blt_node, stop_time : float = 0.5, return_time : float = 1.0) -> void:
	var return_on_timeour_ins = return_on_timeout.instantiate()
	return_on_timeour_ins.return_time = return_time
	return_on_timeour_ins.stop_time = stop_time
	blt_node.call_deferred("add_child",return_on_timeour_ins)
	blt_node.module_list.append(return_on_timeour_ins)
	module_list.append(return_on_timeour_ins)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	justAttacked = true
	var start_direction = global_position.direction_to(get_random_target()).normalized()
	for i in 144 + (level * 36):
		var spawn_bullet = bullet.instantiate()
		var current_angle = i * deg_to_rad(5)
		var bullet_direction = start_direction.rotated(current_angle)
		spawn_bullet.damage = damage * 2
		spawn_bullet.hp = hp * 2
		spawn_bullet.global_position = global_position
		spawn_bullet.blt_texture = bul_texture
		apply_return_on_timeour(spawn_bullet)
		apply_linear(spawn_bullet, bullet_direction, speed)
		get_tree().root.call_deferred("add_child",spawn_bullet)
		await get_tree().create_timer(0.05).timeout
	
	remove_weapon()

func _on_spear_cooldown_timer_timeout():
	justAttacked = false
