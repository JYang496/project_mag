extends Weapon
class_name Ranger

const explosion_effect = preload("res://Player/Weapons/Effects/explosion_effect.tscn")
const speed_change_on_hit = preload("res://Player/Weapons/Effects/speed_change_on_hit.tscn")
const d_up_on_emy_d_effect = preload("res://Player/Weapons/Effects/dmg_up_on_enemy_death.tscn")
const linear_movement = preload("res://Player/Weapons/Effects/linear_movement.tscn")
const spiral_movement = preload("res://Player/Weapons/Effects/spiral_movement.tscn")
var ricochet_effect = preload("res://Player/Weapons/Effects/ricochet_effect.tscn")




# Common variables for rangers
var base_damage : int
var damage : int
var base_speed : int
var speed : int
var base_hp : int
var hp : int
var dot_cd : float
var base_reload : float
var reload : float
var cooldown_timer : Timer
var size : float = 1.0
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
signal calculate_weapon_hp(hp)
signal calculate_weapon_speed(speed)
signal calculate_cd_timer(reload)
signal calculate_bullet_size(size)

func _ready():
	setup_timer()
	if level:
		set_level(level)
	else:
		# New weapon, create a weapon with level 1
		set_level(1)

func setup_timer() -> void:
	cooldown_timer = self.get_node("CooldownTimer")

func _physics_process(_delta):
	if not justAttacked and Input.is_action_pressed("ATTACK"):
		emit_signal("shoot")

func _on_cooldown_timer_timeout():
	justAttacked = false

func _input(event: InputEvent) -> void:
	pass


func _on_shoot():
	justAttacked = true
	var spawn_object = object.instantiate()
	spawn_object.target = get_random_target()
	spawn_object.global_position = global_position
	PlayerData.player.add_sibling(spawn_object)

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
	var ricochet_effect_ins = ricochet_effect.instantiate()
	blt_node.call_deferred("add_child",ricochet_effect_ins)
	blt_node.module_list.append(ricochet_effect_ins)
	module_list.append(ricochet_effect_ins)

func apply_explosion(blt_node : Node2D) -> void:
	var explosion_effect_ins = explosion_effect.instantiate()
	blt_node.call_deferred("add_child",explosion_effect_ins)
	blt_node.module_list.append(explosion_effect_ins)
	module_list.append(explosion_effect_ins)

func apply_speed_change_on_hit(blt_node : Node2D, speed_rate : float) -> void:
	var speed_change_on_hit_ins = speed_change_on_hit.instantiate()
	speed_change_on_hit_ins.speed_rate = speed_rate
	blt_node.call_deferred("add_child",speed_change_on_hit_ins)
	blt_node.module_list.append(speed_change_on_hit_ins)
	module_list.append(speed_change_on_hit_ins)
	
func apply_knock_back(blt_node : Node2D, direction : Vector2, amount : float) -> void:
	pass

func apply_dmg_up_on_enemy_death(blt_node) -> void:
	var dmg_up_on_enemy_death_ins = d_up_on_emy_d_effect.instantiate()
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

func calculate_status() -> void:
	damage = base_damage
	hp = base_hp
	reload = base_reload
	speed = base_speed
	set_cd_timer(cooldown_timer)
	set_bullet_size(size)
	calculate_damage(damage)
	calculate_hp(hp)

func calculate_damage(pre_damage : int) -> void:
	calculate_weapon_damage.emit(pre_damage)

func calculate_hp(pre_hp : int) -> void:
	calculate_weapon_hp.emit(pre_hp)

func calculate_speed(pre_speed) -> void:
	calculate_weapon_speed.emit(pre_speed)

func set_cd_timer(timer : Timer) -> void:
	calculate_cd_timer.emit(reload)
	if reload > 0:
		timer.wait_time = reload

func set_bullet_size(size : float) -> void:
	calculate_bullet_size.emit(size)

func remove_weapon() -> void:
	PlayerData.player_weapon_list.pop_at(PlayerData.on_select_weapon)
	PlayerData.overcharge_time = 0
	PlayerData.on_select_weapon = -1
	queue_free()

func _on_over_charge() -> void:
	print(self,"over charge")
