extends Module

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

@export var damage_bonus_lv1: float = 0.20
@export var damage_bonus_lv2: float = 0.30
@export var damage_bonus_lv3: float = 0.40
@export var duration_sec: float = 4.0

var _active_until_msec: int = 0
var _source_id: StringName

func _ready() -> void:
	super._ready()
	_source_id = StringName("module:%s:%d" % [module_id, get_instance_id()])
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _active_until_msec:
		_clear_bonus(weapon)

func get_effect_descriptions() -> PackedStringArray:
	return with_level_effect_descriptions(PackedStringArray([
		LocalizationManager.get_module_detail(self, "detail.1", {}, "Spend at least 50 energy on a skill to gain weapon damage for 4 seconds"),
		LocalizationManager.get_module_detail(self, "detail.2", {}, "Refreshing the effect replaces its duration"),
	]))

func execute_trigger(_event: WeaponEvent) -> bool:
	weapon.remove_external_damage_mul(_source_id)
	weapon.apply_external_damage_mul(_source_id, 1.0 + _get_damage_bonus())
	_active_until_msec = Time.get_ticks_msec() + int(duration_sec * 1000.0)
	set_physics_process(true)
	return true

func on_weapon_unbound(previous_weapon: Weapon) -> void:
	_clear_bonus(previous_weapon)

func _clear_bonus(target_weapon: Weapon) -> void:
	if target_weapon != null:
		target_weapon.remove_external_damage_mul(_source_id)
	_active_until_msec = 0
	set_physics_process(false)

func _get_damage_bonus() -> float:
	return UTILS.get_value_by_level(module_level, damage_bonus_lv1, damage_bonus_lv2, damage_bonus_lv3)
