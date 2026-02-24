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
		"reload": "2",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "4",
		"reload": "1.6",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "6",
		"reload": "1.1",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "7",
		"reload": "0.8",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "8",
		"reload": "0.6",
		"cost": "1",
		"features": [],
	},
	"6": {
		"level": "11",
		"damage": "8",
		"reload": "0.6",
		"cost": "1",
		"features": [],
	},
	"7": {
		"level": "15",
		"damage": "8",
		"reload": "0.6",
		"cost": "1",
		"features": [],
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	for feature in weapon_data[lv]["features"]:
		if not weapon_features.has(feature):
			weapon_features.append(feature)

func _on_shoot():
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	beam_ins.target_position = get_global_mouse_position() - self.global_position
	beam_ins.damage = damage
	beam_ins.source_weapon = self
	self.get_tree().root.call_deferred("add_child",beam_ins)
	is_on_cooldown = true
	cooldown_timer.start()

func _on_over_charge():
	if self.casting_oc_skill or PlayerData.cloestest_enemy == null:
		return
	self.casting_oc_skill = true
	is_on_cooldown = true
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	beam_ins.target_position = to_local(PlayerData.cloestest_enemy.global_position)
	beam_ins.damage = damage
	beam_ins.oc_mode = true
	beam_ins.beam_owner = self
	beam_ins.source_weapon = self
	self.get_tree().root.call_deferred("add_child",beam_ins)
	oc_timer.start()


func _on_oc_timer_timeout() -> void:
	remove_weapon()
