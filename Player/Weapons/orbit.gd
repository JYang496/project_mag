extends Node2D

@onready var sprite: Sprite2D = %Sprite
@onready var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
@onready var bul_texture = preload("res://Textures/test/bullet.png")
@export var radius : float = 80.0
@export var angle : float = 0.0
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
# Module
@onready var rotate_around_player = preload("res://Player/Weapons/Bullets/rotate_around_player.tscn")

var module_list = []

var satellites : Array = []

var casting_oc_skill = false
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

func _ready():
	if level:
		set_level(level)
	else:
		set_level(1)

func set_level(lv) -> void:
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	spin_speed = int(weapon_data[lv]["spin_speed"])
	number = int(weapon_data[lv]["number"])
	module_list.clear()
	for s in satellites:
		s.queue_free()
	satellites.clear()
	var offset_step = 2 * PI / number
	for n in range(number):
		var spawn_bullet = bullet.instantiate()
		spawn_bullet.damage = damage
		spawn_bullet.hp = 9999
		spawn_bullet.expire_time = 9999
		spawn_bullet.blt_texture = bul_texture
		apply_rotate_around_player(spawn_bullet, offset_step, n)
		get_tree().root.call_deferred("add_child",spawn_bullet)
		satellites.append(spawn_bullet)

func apply_rotate_around_player(blt_node : Node2D, offset_step : float, n : int) -> void:
	var rotate_around_player_ins = rotate_around_player.instantiate()
	rotate_around_player_ins.spin_speed = spin_speed
	rotate_around_player_ins.radius = radius
	rotate_around_player_ins.angle_offset = offset_step * n
	
	blt_node.call_deferred("add_child",rotate_around_player_ins)
	blt_node.module_list.append(rotate_around_player_ins)
	module_list.append(rotate_around_player_ins)
	pass


func _on_over_charge() -> void:
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	print(self,"OVER CHARGE")
	for module in module_list:
		if module is RotateAroundPlayer:
			module.oc_mode = true
	
	await get_tree().create_timer(1).timeout
	remove_weapon()

func remove_weapon() -> void:
	module_list.clear()
	# Remove by OC
	PlayerData.player_weapon_list.pop_at(PlayerData.on_select_weapon)
	PlayerData.overcharge_time = 0
	PlayerData.on_select_weapon = -1
	queue_free()

func _on_tree_exiting() -> void:
	if not self.casting_oc_skill:
		# Remove when not OC, ex: put in inv
		for s in satellites:
			s.queue_free()
