extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/minigun_bullet.png")
@onready var sprite = get_node("%Sprite")
@onready var gun_cooldownTimer = $MachineGunTimer

# Weapon
var ITEM_NAME = "Machine Gun"
var damage : int
var speed : int
var hp : int
var reload : float
var attack_speed : float = 1.0

var max_speed_factor : float = 10.0


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "5",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "5",
		"speed": "600",
		"hp": "1",
		"reload": "0.8",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "7",
		"speed": "600",
		"hp": "1",
		"reload": "0.7",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "9",
		"speed": "800",
		"hp": "1",
		"reload": "0.65",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "11",
		"speed": "800",
		"hp": "2",
		"reload": "0.6",
		"cost": "1",
		"features": ["piercing"],
	}
}

var weapon_file
var minigun_data = JSON.new()


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	speed = int(weapon_data[lv]["speed"])
	hp = int(weapon_data[lv]["hp"])
	reload = float(weapon_data[lv]["reload"])
	gun_cooldownTimer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)
	
func _on_shoot():
	justAttacked = true
	gun_cooldownTimer.wait_time = reload / attack_speed
	gun_cooldownTimer.start()
	var spawn_bullet = bullet.instantiate()
	var bullet_direction = global_position.direction_to(get_random_target()).normalized()
	damage = base_damage
	calculate_damage(base_damage)
	spawn_bullet.damage = damage
	spawn_bullet.hp = hp
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	apply_linear(spawn_bullet, bullet_direction, speed)
	apply_affects(spawn_bullet)
	get_tree().root.call_deferred("add_child",spawn_bullet)
	adjust_attack_speed(1.2)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	speed *= 1.6
	damage *= 2
	hp += 2
	max_speed_factor *= 1.6
	var remove_timer = Timer.new()
	remove_timer.wait_time = 8.0
	remove_timer.one_shot = true
	remove_timer.connect("timeout",Callable(self,"_on_remove_timer_timeout"))
	self.add_child(remove_timer)
	remove_timer.start()

func _on_remove_timer_timeout() -> void:
	remove_weapon()

func adjust_attack_speed(rate : float) -> void:
	attack_speed = clampf(attack_speed * rate, 1.0, max_speed_factor)

func _on_machine_gun_timer_timeout() -> void:
	justAttacked = false


func _on_as_timer_timeout() -> void:
	if not justAttacked:
		adjust_attack_speed(0.5)
