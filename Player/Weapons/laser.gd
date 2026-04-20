extends Ranger

# Projectile
@onready var beam = preload("res://Player/Weapons/Projectiles/beam.tscn")

@onready var detect_area: Area2D = $DetectArea
@onready var oc_timer: Timer = $OCTimer

# Weapon
var ITEM_NAME = "Laser"

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "3",
		"fire_interval_sec": "2",
		"ammo": "45",
		"cost": "5",
	},
	"2": {
		"level": "2",
		"damage": "4",
		"fire_interval_sec": "1.6",
		"ammo": "50",
		"cost": "5",
	},
	"3": {
		"level": "3",
		"damage": "6",
		"fire_interval_sec": "1.1",
		"ammo": "55",
		"cost": "5",
	},
	"4": {
		"level": "4",
		"damage": "7",
		"fire_interval_sec": "0.8",
		"ammo": "60",
		"cost": "5",
	},
	"5": {
		"level": "5",
		"damage": "8",
		"fire_interval_sec": "0.6",
		"ammo": "65",
		"cost": "5",
	},
	"6": {
		"level": "6",
		"damage": "9",
		"fire_interval_sec": "0.5",
		"ammo": "70",
		"cost": "5",
	},
	"7": {
		"level": "7",
		"damage": "10",
		"fire_interval_sec": "0.45",
		"ammo": "75",
		"cost": "5",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])

	base_attack_cooldown = float(weapon_data[lv]["fire_interval_sec"])
	apply_level_ammo(weapon_data[lv])
	sync_stats()

func _on_shoot():
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	beam_ins.target_position = get_global_mouse_position() - self.global_position
	beam_ins.damage = get_runtime_shot_damage()
	beam_ins.source_weapon = self
	self.get_tree().root.call_deferred("add_child",beam_ins)
	is_on_cooldown = true
	cooldown_timer.start()


func _on_oc_timer_timeout() -> void:
	remove_weapon()

