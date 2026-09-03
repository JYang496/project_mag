extends RefCounted
class_name WeaponSkillRuntime

const DEFAULT_SKILL_ID: StringName = &"weapon_overdrive"
const DEFAULT_COOLDOWN_SEC: float = 10.0
const DEFAULT_DURATION_SEC: float = 4.0
const DEFAULT_ENERGY_COST: float = 50.0
const DEFAULT_DAMAGE_MULTIPLIER: float = 2.0
const DEFAULT_ATTACK_SPEED_MULTIPLIER: float = 1.35

var weapon: Weapon
var _cooldown_remaining: float = 0.0
var _active_remaining: float = 0.0
var _active_context: SkillActionContext
var _damage_source_id: StringName
var _speed_source_id: StringName


func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon
	if weapon == null:
		return
	_damage_source_id = StringName("weapon_skill_damage:%d" % weapon.get_instance_id())
	_speed_source_id = StringName("weapon_skill_speed:%d" % weapon.get_instance_id())


func update(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_cooldown_remaining = maxf(_cooldown_remaining - step, 0.0)
	if _active_remaining <= 0.0:
		return
	_active_remaining = maxf(_active_remaining - step, 0.0)
	if _active_remaining <= 0.0:
		_finish_active_skill()


func request() -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if not weapon.is_attack_phase_allowed() or _cooldown_remaining > 0.0:
		return false
	var definition := _get_player_skill_definition()
	if definition != null and not definition.allows_role(weapon):
		return false
	var player := _resolve_player()
	if player == null or not is_instance_valid(player):
		return false
	var energy_cost := _read_energy_cost(definition)
	if energy_cost > 0.0:
		if not player.has_method("consume_energy") or not bool(player.call("consume_energy", energy_cost)):
			return false
	_finish_active_skill(false)
	var damage_multiplier := _read_float(definition, &"damage_multiplier", DEFAULT_DAMAGE_MULTIPLIER, 0.05)
	var attack_speed_multiplier := _read_float(
		definition,
		&"attack_speed_multiplier",
		DEFAULT_ATTACK_SPEED_MULTIPLIER,
		0.1
	)
	var duration_sec := _read_float(definition, &"duration_sec", DEFAULT_DURATION_SEC, 0.05)
	weapon.apply_external_damage_mul(_damage_source_id, damage_multiplier)
	if weapon.has_method("apply_external_attack_speed_mul"):
		weapon.call("apply_external_attack_speed_mul", _speed_source_id, attack_speed_multiplier)
	_active_remaining = duration_sec
	_cooldown_remaining = _read_float(definition, &"cooldown_sec", DEFAULT_COOLDOWN_SEC, 0.05)
	_active_context = SkillActionContext.create(
		weapon,
		player,
		weapon,
		_read_tags(definition),
		energy_cost
	)
	weapon.emit_weapon_event(
		WeaponEvent.create(WeaponEvent.SKILL_CAST_COMMITTED, weapon).with_context(_active_context)
	)
	return true


func get_status() -> Dictionary:
	var definition := _get_player_skill_definition()
	var cooldown_sec := _read_float(definition, &"cooldown_sec", DEFAULT_COOLDOWN_SEC, 0.05)
	var energy_cost := _read_energy_cost(definition)
	var player := _resolve_player()
	var current_energy := 0.0
	if player != null and is_instance_valid(player) and player.has_method("get_current_energy"):
		current_energy = maxf(float(player.call("get_current_energy")), 0.0)
	var role_allowed := definition == null or definition.allows_role(weapon)
	var phase_allowed := weapon != null and weapon.is_attack_phase_allowed()
	var has_energy := energy_cost <= 0.0 or current_energy >= energy_cost - 0.001
	var ready := _cooldown_remaining <= 0.0 and role_allowed and phase_allowed and has_energy
	return {
		"id": str(_read_skill_id(definition)),
		"display_name": _read_display_name(definition),
		"available": role_allowed,
		"ready": ready,
		"active": _active_remaining > 0.0,
		"cooldown_remaining": _cooldown_remaining,
		"cooldown_duration": cooldown_sec,
		"cooldown_progress": clampf(1.0 - _cooldown_remaining / cooldown_sec, 0.0, 1.0),
		"active_remaining": _active_remaining,
		"energy_cost": energy_cost,
		"has_energy": has_energy,
	}


func force_ready() -> void:
	_cooldown_remaining = 0.0


func clear_active() -> void:
	_finish_active_skill(false)


func clear_for_weapon_exit() -> void:
	_finish_active_skill(false)
	_cooldown_remaining = 0.0
	weapon = null


func _finish_active_skill(emit_finished: bool = true) -> void:
	if weapon != null and is_instance_valid(weapon):
		weapon.remove_external_damage_mul(_damage_source_id)
		if weapon.has_method("remove_external_attack_speed_mul"):
			weapon.call("remove_external_attack_speed_mul", _speed_source_id)
		if emit_finished and _active_context != null:
			_active_context.finish_at(weapon.global_position)
			weapon.emit_weapon_event(
				WeaponEvent.create(WeaponEvent.SKILL_CAST_FINISHED, weapon).with_context(_active_context)
			)
	_active_remaining = 0.0
	_active_context = null


func _get_player_skill_definition() -> WeaponSkillDefinition:
	if weapon == null:
		return null
	for definition in weapon.weapon_skills:
		if definition != null and definition.activation_type == WeaponSkillDefinition.ActivationType.PLAYER:
			return definition
	return null


func _resolve_player() -> Node:
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		return PlayerData.player
	if weapon != null:
		return DamageManager.resolve_source_player(weapon)
	return null


func _read_skill_id(definition: WeaponSkillDefinition) -> StringName:
	if definition != null and definition.skill_id != StringName():
		return definition.skill_id
	return DEFAULT_SKILL_ID


func _read_display_name(definition: WeaponSkillDefinition) -> String:
	if definition != null and not definition.display_name.is_empty():
		return definition.display_name
	if LocalizationManager != null and LocalizationManager.has_method("tr_key"):
		return LocalizationManager.tr_key("ui.weapon.skill.overdrive", "Weapon Overdrive")
	return "Weapon Overdrive"


func _read_energy_cost(definition: WeaponSkillDefinition) -> float:
	return _read_float(definition, &"energy_cost", DEFAULT_ENERGY_COST, 0.0)


func _read_tags(definition: WeaponSkillDefinition) -> Array[StringName]:
	if definition != null and not definition.skill_tags.is_empty():
		return definition.skill_tags.duplicate()
	return [&"weapon", &"buff", &"duration"]


func _read_float(
	definition: WeaponSkillDefinition,
	property_name: StringName,
	fallback: float,
	minimum: float
) -> float:
	if definition == null:
		return fallback
	return maxf(float(definition.get(property_name)), minimum)
