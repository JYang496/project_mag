extends Weapon
class_name TestWeapon

signal calculate_weapon_damage(damage)
signal calculate_attack_cooldown(attack_cooldown)
signal calculate_weapon_projectile_hits(projectile_hits)
signal calculate_weapon_hp(hp)

var ITEM_NAME := "Test Weapon"

@export var base_damage: int = 10
@export var base_attack_cooldown: float = 2.0
@export var base_projectile_hits: int = 1
@export var base_hp: int = 3

@export var projectile_enabled: bool = true
@export var melee_enabled: bool = false

var damage: int = 1
var attack_cooldown: float = 1.0
var projectile_hits: int = 1
var hp: int = 1

func _ready() -> void:
	super._ready()
	sync_stats()

func sync_stats() -> void:
	damage = base_damage
	attack_cooldown = base_attack_cooldown
	projectile_hits = base_projectile_hits
	hp = base_hp
	calculate_weapon_damage.emit(damage)
	calculate_attack_cooldown.emit(attack_cooldown)
	calculate_weapon_projectile_hits.emit(projectile_hits)
	calculate_weapon_hp.emit(hp)

func supports_projectiles() -> bool:
	return projectile_enabled

func supports_melee_contact() -> bool:
	return melee_enabled
