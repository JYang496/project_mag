extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

# Weapon
var ITEM_NAME = "Machine Gun"
var attack_speed : float = 1.0

var max_speed_factor : float = 10.0

const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "5",
		"speed": "600",
		"hp": "1",
		"reload": "2",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "6",
		"speed": "600",
		"hp": "1",
		"reload": "1.8",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "7",
		"speed": "600",
		"hp": "1",
		"reload": "1.6",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "9",
		"speed": "800",
		"hp": "1",
		"reload": "1.3",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "11",
		"speed": "800",
		"hp": "2",
		"reload": "1.0",
		"cost": "1",
		"features": [],
	}
}

var weapon_file
var minigun_data = JSON.new()


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	for feature in weapon_data[lv]["features"]:
		if not weapon_features.has(feature):
			weapon_features.append(feature)

func _on_shoot():
	is_on_cooldown = true
	cooldown_timer.wait_time = attack_cooldown / attack_speed
	cooldown_timer.start()
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	var spawn_projectile = projectile_template.instantiate()
	damage = base_damage
	calculate_damage(damage)
	spawn_projectile.damage = damage
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child",spawn_projectile)
	adjust_attack_speed(1.2)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	speed *= 2
	damage *= 2
	projectile_hits += 2
	max_speed_factor *= 2
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


func _on_as_timer_timeout() -> void:
	if not is_on_cooldown:
		adjust_attack_speed(0.5)
