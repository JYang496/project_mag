extends Resource
class_name WeaponSkillDefinition

enum ActivationType { PLAYER, AUTOMATIC }
enum RoleRequirement { ANY, MAIN_ONLY, SUPPORT_ONLY }

@export var skill_id: StringName
@export var display_name: String = ""
@export var activation_type: ActivationType = ActivationType.AUTOMATIC
@export var role_requirement: RoleRequirement = RoleRequirement.ANY
@export_range(0.05, 120.0, 0.05) var cooldown_sec: float = 10.0
@export_range(0.0, 100.0, 1.0) var energy_cost: float = 50.0
@export_range(0.05, 30.0, 0.05) var duration_sec: float = 4.0
@export_range(0.05, 10.0, 0.05) var damage_multiplier: float = 2.0
@export_range(0.1, 10.0, 0.05) var attack_speed_multiplier: float = 1.35
@export var skill_tags: Array[StringName] = [&"weapon", &"buff", &"duration"]

func allows_role(weapon: Weapon) -> bool:
	match role_requirement:
		RoleRequirement.MAIN_ONLY:
			return weapon.is_main_weapon()
		RoleRequirement.SUPPORT_ONLY:
			return weapon.is_support_weapon()
	return true
