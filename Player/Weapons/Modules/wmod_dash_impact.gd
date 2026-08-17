extends Module

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

@export var radius: float = 150.0
@export var damage_ratio_lv1: float = 0.70
@export var damage_ratio_lv2: float = 0.95
@export var damage_ratio_lv3: float = 1.20

func get_effect_descriptions() -> PackedStringArray:
	return with_level_effect_descriptions(PackedStringArray([
		LocalizationManager.get_module_detail(self, "detail.1", {}, "Travel at least 180 px with a movement skill to trigger a 150 px shockwave"),
		LocalizationManager.get_module_detail(self, "detail.2", {}, "Triggers once per skill use"),
	]))

func execute_trigger(event: WeaponEvent) -> bool:
	var context: SkillActionContext = event.action_context
	var origin: Vector2 = context.source_player.global_position
	var damage: int = maxi(1, int(round(float(UTILS.get_runtime_weapon_damage(weapon)) * _get_damage_ratio())))
	var child_context: SkillActionContext = context.create_triggered_child(module_id)
	for enemy in UTILS.get_nearby_enemies(get_tree(), origin, radius):
		var data: DamageData = DamageManager.build_damage_data(
			weapon,
			damage,
			Attack.TYPE_PHYSICAL,
			{"amount": 0.0, "angle": Vector2.ZERO},
			DamageData.SOURCE_PLAYER_WEAPON,
			DamageDeliveryType.AREA
		)
		data.action_context = child_context
		DamageManager.apply_to_target(enemy, data)
	return true

func _get_damage_ratio() -> float:
	return UTILS.get_value_by_level(module_level, damage_ratio_lv1, damage_ratio_lv2, damage_ratio_lv3)
