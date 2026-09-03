extends Resource
class_name ModuleTriggerSpec

@export_enum(
	"skill_cast_committed",
	"skill_cast_finished",
	"projectile_spawned",
	"hit_confirmed",
	"damage_dealt",
	"critical_hit",
	"target_killed",
	"reload_started",
	"weapon_entered_main",
	"weapon_entered_support",
	"magazine_quarter_spent",
	"support_charge_ready",
	"cross_weapon_hit",
	"continuous_hit_threshold",
	"shared_resource_release"
) var event_type: String = "skill_cast_committed"
@export var required_skill_tags: Array[StringName] = []
@export var requires_action_context: bool = false
@export var minimum_energy_spent: float = 0.0
@export var minimum_distance: float = 0.0
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 1.0
@export var internal_cooldown_sec: float = 0.0
@export var once_per_action: bool = false
@export var once_per_target: bool = false
@export var allow_triggered_actions: bool = false
@export_range(0, 8, 1) var maximum_trigger_depth: int = 0

func matches(event: WeaponEvent) -> bool:
	if event.type != StringName(event_type):
		return false
	var context := event.action_context
	if context == null:
		return not requires_action_context and required_skill_tags.is_empty() \
			and minimum_energy_spent <= 0.0 and minimum_distance <= 0.0
	if context.is_triggered_action and not allow_triggered_actions:
		return false
	if context.trigger_depth > maximum_trigger_depth or context.proc_budget <= 0:
		return false
	for tag in required_skill_tags:
		if not context.has_tag(tag):
			return false
	return context.energy_spent >= minimum_energy_spent and context.distance_travelled >= minimum_distance
