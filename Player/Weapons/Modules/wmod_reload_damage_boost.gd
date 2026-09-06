extends Module
# Starting a reload primes a fixed number of empowered attacks for the next magazine.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Reloaded Force"

@export var bonus_lv1: float = 0.20
@export var bonus_lv2: float = 0.30
@export var bonus_lv3: float = 0.40
@export var empowered_attacks_lv1: int = 3
@export var empowered_attacks_lv2: int = 4
@export var empowered_attacks_lv3: int = 5

var _empowered_attacks_remaining: int = 0

func _exit_tree() -> void:
	_clear_bonus()
	super._exit_tree()

func get_subscribed_weapon_events() -> Array[StringName]:
	return [WeaponEvent.RELOAD_STARTED, WeaponEvent.PRIMARY_ATTACK_FIRED]

func handle_weapon_event(event: WeaponEvent) -> bool:
	if event.type == WeaponEvent.RELOAD_STARTED:
		_prime_next_magazine(event.to_detail())
		return true
	if event.type == WeaponEvent.PRIMARY_ATTACK_FIRED:
		_consume_empowered_attack()
		return true
	return false

func get_effect_descriptions() -> PackedStringArray:
	return with_level_effect_descriptions(PackedStringArray([
		LocalizationManager.get_module_detail(
			self, "detail.1", {}, "Starting a reload empowers attacks in the next magazine"
		),
		LocalizationManager.get_module_detail(
			self, "detail.2", {}, "Bonus scales with spent ammo"
		),
	]))

func _prime_next_magazine(detail: Dictionary) -> void:
	if detail == null or detail.get("source_weapon", null) != weapon:
		return
	var spent_ratio := UTILS.get_spent_ratio(detail)
	if spent_ratio <= 0.0:
		return
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("apply_external_damage_mul") or not weapon.has_method("remove_external_damage_mul"):
		return
	var next_mul := 1.0 + _get_bonus_ratio() * spent_ratio
	var source_id := _get_source_id()
	weapon.call("remove_external_damage_mul", source_id)
	weapon.call("apply_external_damage_mul", source_id, next_mul)
	_empowered_attacks_remaining = _get_empowered_attack_count()

func _consume_empowered_attack() -> void:
	if _empowered_attacks_remaining <= 0:
		return
	_empowered_attacks_remaining -= 1
	if _empowered_attacks_remaining <= 0:
		_clear_bonus()

func _clear_bonus() -> void:
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("remove_external_damage_mul"):
		weapon.call("remove_external_damage_mul", _get_source_id())
	_empowered_attacks_remaining = 0

func _get_bonus_ratio() -> float:
	return UTILS.get_value_by_level(module_level, bonus_lv1, bonus_lv2, bonus_lv3)

func _get_empowered_attack_count() -> int:
	match module_level:
		3:
			return maxi(empowered_attacks_lv3, 1)
		2:
			return maxi(empowered_attacks_lv2, 1)
		_:
			return maxi(empowered_attacks_lv1, 1)

func _get_source_id() -> StringName:
	return StringName("wmod_reload_damage_boost_%s" % str(get_instance_id()))
