extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/minigun_bullet.png")
@onready var sprite = get_node("%Sprite")
@onready var gun_cooldownTimer = $RocketLuncherTimer

#OC
@onready var fall_module = preload("res://Player/Weapons/Bullets/fall.tscn")
@onready var oc_booming_area: Area2D = $OCBoomingArea

# Weapon
var ITEM_NAME = "Rocket Luncher"
var damage : int
var speed : int
var hp : int
var reload : float


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "1",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": ["explosion"],
	},
	"2": {
		"level": "2",
		"damage": "1",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": ["explosion"],
	},
	"3": {
		"level": "3",
		"damage": "1",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": ["explosion"],
	},
	"4": {
		"level": "4",
		"damage": "2",
		"speed": "800",
		"hp": "1",
		"reload": "0.75",
		"cost": "1",
		"features": ["explosion"],
	},
	"5": {
		"level": "5",
		"damage": "2",
		"speed": "800",
		"hp": "1",
		"reload": "0.75",
		"cost": "1",
		"features": ["explosion"],
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	speed = int(weapon_data[lv]["speed"])
	hp = int(weapon_data[lv]["hp"])
	reload = float(weapon_data[lv]["reload"])
	gun_cooldownTimer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)
	
func _on_shoot():
	justAttacked = true
	gun_cooldownTimer.start()
	var spawn_bullet = bullet.instantiate()
	var bullet_direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.damage = damage
	spawn_bullet.hp = hp
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	apply_linear(spawn_bullet, bullet_direction, speed)
	apply_affects(spawn_bullet)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	print(self,"OVER CHARGE")
	var n = 0
	var max_n = 20
	while n < max_n:
		if len(oc_booming_area.get_overlapping_areas()) == 0:
			n += 1
			break
		for area in oc_booming_area.get_overlapping_areas():
			if n >= max_n:
				break
			if area is not HurtBox:
				break
			var spawn_bullet = bullet.instantiate()
			spawn_bullet.damage = damage
			spawn_bullet.blt_texture = bul_texture
			var fall_ins = fall_module.instantiate()
			fall_ins.destination = area.global_position
			apply_affects(spawn_bullet)
			spawn_bullet.call_deferred("add_child",fall_ins)
			get_tree().root.call_deferred("add_child",spawn_bullet)
			n += 1
		await get_tree().create_timer(0.2).timeout		


	remove_weapon()


	self.casting_oc_skill = false
	#remove_weapon()

func _on_rocket_luncher_timer_timeout() -> void:
	justAttacked = false
