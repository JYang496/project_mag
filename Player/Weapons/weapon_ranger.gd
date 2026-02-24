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
var base_projectile_hits : int
var projectile_hits : int
var dot_cd : float
var base_attack_cooldown : float
var attack_cooldown : float
var cooldown_timer : Timer
var size : float = 1.0
var projectile_direction
var is_on_cooldown = false

var module_list = []
var projectile_modifiers : Dictionary  = {}
var effect_sample = {"name":{"key1":123,"key2":234}}
var _effect_scene_cache: Dictionary = {
	"linear_movement": linear_movement,
}

var weapon_features = []
# Projectile scene that needs to be overwritten in child class.
var projectile_scene

# Over charge
var casting_oc_skill : bool = false

const SPRITE_TARGET_HEIGHT := 30.0
const AIM_ROTATION_OFFSET := deg_to_rad(90)

signal shoot()
signal over_charge()
signal calculate_weapon_damage(damage)
signal calculate_weapon_projectile_hits(projectile_hits)
signal calculate_weapon_speed(speed)
signal calculate_attack_cooldown(attack_cooldown)
signal calculate_projectile_size(size)


func _ready():
	setup_timer()
	_apply_fuse_sprite()
	_adjust_sprite_height()
	if level:
		set_level(level)
	else:
		# New weapon, create a weapon with level 1
		set_level(1)

func setup_timer() -> void:
	cooldown_timer = self.get_node("CooldownTimer")

func _physics_process(_delta):
	_update_weapon_rotation()
	if not is_on_cooldown and Input.is_action_pressed("ATTACK"):
		emit_signal("shoot")

func _on_cooldown_timer_timeout():
	is_on_cooldown = false

func _input(event: InputEvent) -> void:
	pass


func _on_shoot():
	is_on_cooldown = true
	var projectile = projectile_scene.instantiate()
	projectile.target = get_mouse_target()
	projectile.global_position = global_position
	get_projectile_spawn_parent().call_deferred("add_child", projectile)

func get_mouse_target():
	return get_global_mouse_position()

# This function calls before a projectile is added.
func apply_effects_on_projectile(projectile : Node2D) -> void:
	if projectile is Projectile:
		projectile.source_weapon = self

	# Update linear movement if exist; it is prerequisite effect of some effects.
	if projectile_direction and speed:
		var linear_load_ins = linear_movement.instantiate()
		linear_load_ins.set("direction", projectile_direction)
		linear_load_ins.set("speed", speed)
		projectile.call_deferred("add_child", linear_load_ins)
		projectile.effect_list.append(linear_load_ins)
	else:
		if projectile_modifiers.has("linear_movement"):
			projectile_modifiers.erase("linear_movement")
	for effect in projectile_modifiers:
		var effect_scene := _get_effect_scene(effect)
		if effect_scene == null:
			continue
		var effect_ins = effect_scene.instantiate()
		for attribute in projectile_modifiers.get(effect):
			effect_ins.set(attribute, projectile_modifiers.get(effect).get(attribute))
		if not projectile:
			printerr("Projectile not found")
		projectile.call_deferred("add_child", effect_ins)
		projectile.effect_list.append(effect_ins)

func _get_effect_scene(effect_name: String) -> PackedScene:
	if _effect_scene_cache.has(effect_name):
		return _effect_scene_cache[effect_name]
	var effect_path := "res://Player/Weapons/Effects/%s.tscn" % effect_name
	if not ResourceLoader.exists(effect_path):
		return null
	var loaded_scene := load(effect_path)
	if loaded_scene is PackedScene:
		_effect_scene_cache[effect_name] = loaded_scene
		return loaded_scene
	return null

func get_projectile_spawn_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene:
		return current_scene
	if PlayerData.player and PlayerData.player.get_parent():
		return PlayerData.player.get_parent()
	return get_tree().root

func apply_effects(projectile) -> void:
	pass

func sync_stats() -> void:
	damage = base_damage
	projectile_hits = base_projectile_hits
	attack_cooldown = base_attack_cooldown
	speed = base_speed
	set_cd_timer(cooldown_timer)
	set_projectile_size(size)
	calculate_damage(damage)
	calculate_projectile_hits(projectile_hits)

func calculate_damage(pre_damage : int) -> void:
	calculate_weapon_damage.emit(pre_damage)

func calculate_projectile_hits(pre_projectile_hits : int) -> void:
	calculate_weapon_projectile_hits.emit(pre_projectile_hits)

func calculate_speed(pre_speed) -> void:
	calculate_weapon_speed.emit(pre_speed)

func set_cd_timer(timer : Timer) -> void:
	calculate_attack_cooldown.emit(attack_cooldown)
	if attack_cooldown > 0:
		timer.wait_time = attack_cooldown

func set_projectile_size(projectile_size : float) -> void:
	calculate_projectile_size.emit(projectile_size)

func remove_weapon() -> void:
	PlayerData.player_weapon_list.pop_at(PlayerData.on_select_weapon)
	PlayerData.overcharge_time = 0
	PlayerData.on_select_weapon = -1
	queue_free()

func _on_over_charge() -> void:
	print(self, "over charge")

func _adjust_sprite_height() -> void:
	if not sprite or not sprite.texture:
		return
	var tex_height := float(sprite.texture.get_height())
	if tex_height <= 0.0:
		return
	var scale_factor := SPRITE_TARGET_HEIGHT / tex_height
	sprite.scale = Vector2(scale_factor, scale_factor)

func _update_weapon_rotation() -> void:
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction == Vector2.ZERO:
		return
	rotation = mouse_direction.angle() + AIM_ROTATION_OFFSET

func supports_projectiles() -> bool:
	return true
