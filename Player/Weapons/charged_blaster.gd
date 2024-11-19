extends Ranger

# Bullet
@onready var beam_blast = preload("res://Player/Weapons/Bullets/beam_blast.tscn")
@onready var sprite = get_node("%GunSprite")
@export var gun_cooldownTimer : Timer
@export var charge_timer : Timer

# Weapon
var ITEM_NAME = "Beam Blaster"
var level : int
var damage : int
var dot_cd : float
var reload : float
var max_charge_level : int

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "1",
		"speed": "200",
		"dot_cd": "0.1",
		"reload": "1",
		"max_charge_level": "3",
		"cost": "1",
		"features": [],
	},
}


func _ready():
	set_level("1")


func set_level(lv):
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	dot_cd = float(weapon_data[lv]["dot_cd"])
	reload = float(weapon_data[lv]["reload"])
	max_charge_level = int(weapon_data[lv]["max_charge_level"])
	gun_cooldownTimer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)

	
func _on_shoot():
	pass


func _on_charged_blast_timer_timeout() -> void:
	pass # Replace with function body.


func _on_charge_timer_timeout() -> void:
	pass # Replace with function body.
