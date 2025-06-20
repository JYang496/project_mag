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
var bullet_direction
var justAttacked = false

var module_list = []
var bullet_effects : Dictionary  = {}
var effect_sample = {"name":"effect_name", "attribute":{"key1":123,"key2":234}}

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

# This function calls before a bullet is added
func apply_effects_on_bullet(bullet : Node2D) -> void:

	# Update linear movement if exist, it is prerequestive effect of some effects
	if bullet_direction and speed:
		#bullet_effects.set("linear_movement",{"direction":bullet_direction, "speed": speed})
		var linear_load = load("res://Player/Weapons/Effects/linear_movement.tscn")
		var linear_load_ins = linear_load.instantiate()
		linear_load_ins.set("direction", bullet_direction)
		linear_load_ins.set("speed", speed)
		bullet.call_deferred("add_child", linear_load_ins)
		bullet.effect_list.append(linear_load_ins)
	else:
		if bullet_effects.has("linear_movement"):
			bullet_effects.erase("linear_movement")
	for effect in bullet_effects:
		var effect_load = load("res://Player/Weapons/Effects/%s.tscn" %effect)
		var effect_ins = effect_load.instantiate()
		for attribute in bullet_effects.get(effect):
			prints("attr",attribute,bullet_effects.get(effect).get(attribute))
			effect_ins.set(attribute,bullet_effects.get(effect).get(attribute))
		if not bullet:
			printerr("Bullet not found")
		bullet.call_deferred("add_child", effect_ins)
		bullet.effect_list.append(effect_ins)

func apply_effects(bullet) -> void:
	pass

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
