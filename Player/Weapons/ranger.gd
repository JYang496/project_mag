extends Node2D
class_name Ranger

@onready var player = get_tree().get_first_node_in_group("player")
var linear_movement = preload("res://Player/Weapons/Bullets/linear_movement.tscn")
var spiral_movement = preload("res://Player/Weapons/Bullets/spiral_movement.tscn")
var ricochet_module = preload("res://Player/Weapons/Bullets/ricochet_module.tscn")
var explosion_module = preload("res://Player/Weapons/Bullets/explosion_module.tscn")
var speed_change_on_hit = preload("res://Player/Weapons/Bullets/speed_change_on_hit.tscn")
var dmg_up_on_enemy_death_module = preload("res://Player/Weapons/Bullets/dmg_up_on_enemy_death.tscn")

var level : int
var base_damage : int
var damage : int
var speed : int
var hp : int
var dot_cd : float
var reload : float
var justAttacked = false

var module_list = []

var features = []
# object that needs to be overwrited in child class
var object

# Over charge
var casting_oc_skill : bool = false

signal shoot()
signal over_charge()
signal calculate_weapon_damage(damage)

func _ready():
	if level:
		set_level(level)
	else:
		set_level(1)

func _physics_process(_delta):
	if not justAttacked and Input.is_action_pressed("ATTACK"):
		emit_signal("shoot")

func _on_cooldown_timer_timeout():
	justAttacked = false

func _input(event: InputEvent) -> void:
	pass

func set_level(lv):
	pass

func _on_shoot():
	justAttacked = true
	var spawn_object = object.instantiate()
	spawn_object.target = get_random_target()
	spawn_object.global_position = global_position
	player.add_sibling(spawn_object)

func get_random_target():
		return get_global_mouse_position()

func apply_linear(blt_node : Node2D, direction : Vector2 = Vector2.UP, blt_speed : float = 400.0) -> void:
	var linear_movement_ins = linear_movement.instantiate()
	linear_movement_ins.direction = direction
	linear_movement_ins.speed = blt_speed
	blt_node.call_deferred("add_child",linear_movement_ins)
	blt_node.module_list.append(linear_movement_ins)
	module_list.append(linear_movement_ins)

func apply_spiral(blt_node : Node2D, blt_spin_rate : float = PI, blt_spin_speed : float = 100.0) -> void:
	var spiral_movement_ins = spiral_movement.instantiate()
	spiral_movement_ins.spin_rate = blt_spin_rate
	spiral_movement_ins.spin_speed = blt_spin_speed
	blt_node.call_deferred("add_child",spiral_movement_ins)
	blt_node.module_list.append(spiral_movement_ins)
	module_list.append(spiral_movement_ins)

func apply_ricochet(blt_node : Node2D) -> void:
	var ricochet_module_ins = ricochet_module.instantiate()
	blt_node.call_deferred("add_child",ricochet_module_ins)
	blt_node.module_list.append(ricochet_module_ins)
	module_list.append(ricochet_module_ins)

func apply_explosion(blt_node : Node2D) -> void:
	var explosion_module_ins = explosion_module.instantiate()
	blt_node.call_deferred("add_child",explosion_module_ins)
	blt_node.module_list.append(explosion_module_ins)
	module_list.append(explosion_module_ins)

func apply_speed_change_on_hit(blt_node : Node2D, speed_rate : float) -> void:
	var speed_change_on_hit_ins = speed_change_on_hit.instantiate()
	speed_change_on_hit_ins.speed_rate = speed_rate
	blt_node.call_deferred("add_child",speed_change_on_hit_ins)
	blt_node.module_list.append(speed_change_on_hit_ins)
	module_list.append(speed_change_on_hit_ins)
	
func apply_knock_back(blt_node : Node2D, direction : Vector2, amount : float) -> void:
	pass

func apply_dmg_up_on_enemy_death(blt_node) -> void:
	var dmg_up_on_enemy_death_ins = dmg_up_on_enemy_death_module.instantiate()
	dmg_up_on_enemy_death_ins.module_parent = blt_node
	blt_node.call_deferred("add_child",dmg_up_on_enemy_death_ins)
	blt_node.module_list.append(dmg_up_on_enemy_death_ins)
	module_list.append(dmg_up_on_enemy_death_ins)

func apply_affects(bullet) -> void:
	for feature in features:
		match feature:
			"spiral":
				apply_spiral(bullet)
			"ricochet":
				apply_ricochet(bullet)
			"explosion":
				apply_explosion(bullet)
			"speed_change_on_hit":
				apply_speed_change_on_hit(bullet, 0.5)

func calculate_damage(damage : int) -> void:
	calculate_weapon_damage.emit(damage)

func remove_weapon() -> void:
	PlayerData.player_weapon_list.pop_at(PlayerData.on_select_weapon)
	PlayerData.overcharge_time = 0
	PlayerData.on_select_weapon = -1
	queue_free()

func _on_over_charge() -> void:
	print(self,"over charge")
