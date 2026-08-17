extends Module

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")
const DAMAGE_STATE_META := &"_incoming_damage_state"

@export var radius: float = 120.0
@export var damage_ratio_lv1: float = 0.45
@export var damage_ratio_lv2: float = 0.65
@export var damage_ratio_lv3: float = 0.85

func get_effect_descriptions() -> PackedStringArray:
	return with_level_effect_descriptions(PackedStringArray([
		LocalizationManager.get_module_detail(self, "detail.1", {}, "Skill damage against a frosted target triggers a freeze burst"),
		LocalizationManager.get_module_detail(self, "detail.2", {}, "Each target can trigger once per skill use"),
	]))

func can_trigger_event(event: WeaponEvent) -> bool:
	if event.target == null or event.damage_result == null or not event.damage_result.applied:
		return false
	var state: Dictionary = event.target.get_meta(DAMAGE_STATE_META, {})
	return int(state.get("frost_stacks", 0)) > 0

func execute_trigger(event: WeaponEvent) -> bool:
	var target := event.target as Node2D
	var damage: int = maxi(1, int(round(float(UTILS.get_runtime_weapon_damage(weapon)) * _get_damage_ratio())))
	var child_context: SkillActionContext = event.action_context.create_triggered_child(module_id)
	for enemy in UTILS.get_nearby_enemies(get_tree(), target.global_position, radius):
		var data: DamageData = DamageManager.build_damage_data(
			weapon,
			damage,
			Attack.TYPE_FREEZE,
			{"amount": 0.0, "angle": Vector2.ZERO},
			DamageData.SOURCE_PLAYER_WEAPON,
			DamageDeliveryType.AREA
		)
		data.action_context = child_context
		DamageManager.apply_to_target(enemy, data)
	return true

func _get_damage_ratio() -> float:
	return UTILS.get_value_by_level(module_level, damage_ratio_lv1, damage_ratio_lv2, damage_ratio_lv3)
