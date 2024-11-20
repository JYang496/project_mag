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
var charge_level :int
var charge_time : float = 0.0
var time_per_level : float = 1.0
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

func _physics_process(delta):
	if not justAttacked:
		if Input.is_action_pressed("ATTACK"):
			charge_time += delta
			if charge_time >= time_per_level:
				charge_level = clampi(charge_level + 1, 0, max_charge_level)
				charge_time -= time_per_level
		if Input.is_action_just_released("ATTACK"):
			emit_signal("shoot")

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
	if charge_level < 1:
		return
	var beam_blast_ins = beam_blast.instantiate()
	beam_blast_ins.target_position = get_local_mouse_position()
	beam_blast_ins.damage = damage
	call_deferred("add_child",beam_blast_ins)
	charge_level = 0



func _on_charged_blast_timer_timeout() -> void:
	pass # Replace with function body.


func _on_charge_timer_timeout() -> void:
	pass # Replace with function body.
