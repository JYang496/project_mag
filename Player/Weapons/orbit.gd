extends Node2D

@onready var sprite = get_node("%OrbitSprite")
@onready var satellite_preload = preload("res://Player/Weapons/satellite.tscn")
@export var radius : float = 40.0
@export var angle : float = 0.0

var satellites : Array = []

signal over_charge()

# Weapon
var ITEM_NAME = "Orbit"
var level : int
var damage : int
var spin_speed : float = 5.0
var number = 4

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "5",
		"number": "1",
		"spin_speed": "3",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "7",
		"number": "2",
		"spin_speed": "4",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "10",
		"number": "3",
		"spin_speed": "5",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "15",
		"number": "3",
		"spin_speed": "6",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "25",
		"number": "4",
		"spin_speed": "6",
		"cost": "1",
	}
}

func _ready() -> void:
	set_level("1")

func set_level(lv) -> void:
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	spin_speed = int(weapon_data[lv]["spin_speed"])
	number = int(weapon_data[lv]["number"])
	for s in satellites:
		s.queue_free()
	satellites.clear()
	var offset_step = 2 * PI / number
	for n in range(number):
		var satellite_ins = satellite_preload.instantiate()
		satellite_ins.damage = damage
		satellite_ins.spin_speed = spin_speed
		call_deferred("add_child",satellite_ins)
		#get_tree().root.call_deferred("add_child",satellite_ins)
		satellites.append(satellite_ins)
	for n in range(number):
		satellites[n].angle_offset = offset_step * n

func remove_weapon() -> void:
	PlayerData.player_weapon_list.pop_at(PlayerData.on_select_weapon)
	PlayerData.on_select_weapon = -1
	queue_free()
	
func _on_over_charge() -> void:
	print(self,"OVER CHARGE")
	remove_weapon()
