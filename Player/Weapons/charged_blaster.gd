extends Ranger

# Bullet
@onready var beam_blast = preload("res://Player/Weapons/Bullets/beam_blast.tscn")
@onready var sprite = get_node("%GunSprite")
@onready var gun_cooldownTimer : Timer = $ChargedBlastTimer

# Weapon
var ITEM_NAME = "Beam Blaster"
var level : int
var damage : int
var hit_cd : float
var reload : float
var duration : float
var charge_level :int
var charge_time : float = 0.0
var time_per_level : float = 1.0
var max_charge_level : int

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "2",
		"hit_cd": "0.1",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "2",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "1",
		"damage": "4",
		"hit_cd": "0.1",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "2",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "1",
		"damage": "4",
		"hit_cd": "0.1",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "3",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "1",
		"damage": "4",
		"hit_cd": "0.08",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "3",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "1",
		"damage": "6",
		"speed": "200",
		"hit_cd": "0.08",
		"reload": "5",
		"duration": "3.0",
		"max_charge_level": "4",
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

func set_level(lv : String):
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	hit_cd = float(weapon_data[lv]["hit_cd"])
	reload = float(weapon_data[lv]["reload"])
	duration = float(weapon_data[lv]["duration"])
	max_charge_level = int(weapon_data[lv]["max_charge_level"])
	gun_cooldownTimer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)

func _on_shoot():
	if charge_level < 1 or justAttacked:
		return
	justAttacked = true
	var beam_blast_ins = beam_blast.instantiate()
	beam_blast_ins.target_position = get_local_mouse_position()
	beam_blast_ins.width = charge_level * 6
	beam_blast_ins.damage = damage * (charge_level * 2) 
	beam_blast_ins.duration = duration
	beam_blast_ins.hit_cd = hit_cd
	call_deferred("add_child",beam_blast_ins)
	charge_level = 0
	gun_cooldownTimer.start()

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	charge_level = max_charge_level *2
	duration *= 2
	emit_signal("shoot")
	var remove_timer = Timer.new()
	remove_timer.wait_time = duration
	remove_timer.one_shot = true
	remove_timer.connect("timeout",Callable(self,"_on_remove_timer_timeout"))
	self.add_child(remove_timer)
	remove_timer.start()

func _on_remove_timer_timeout() -> void:
	remove_weapon()

func _on_charged_blast_timer_timeout() -> void:
	justAttacked = false
