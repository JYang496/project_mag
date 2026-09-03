extends RefCounted
class_name WeaponEvent

const SKILL_CAST_COMMITTED := &"skill_cast_committed"
const SKILL_CAST_FINISHED := &"skill_cast_finished"
const PROJECTILE_SPAWNED := &"projectile_spawned"
const HIT_CONFIRMED := &"hit_confirmed"
const DAMAGE_DEALT := &"damage_dealt"
const CRITICAL_HIT := &"critical_hit"
const TARGET_KILLED := &"target_killed"
const RELOAD_STARTED := &"reload_started"
const RELOAD_FINISHED := &"reload_finished"
const PRIMARY_ATTACK_FIRED := &"primary_attack_fired"
const WEAPON_ENTERED_MAIN := &"weapon_entered_main"
const WEAPON_ENTERED_SUPPORT := &"weapon_entered_support"
const MAGAZINE_QUARTER_SPENT := &"magazine_quarter_spent"
const SUPPORT_CHARGE_READY := &"support_charge_ready"
const CROSS_WEAPON_HIT := &"cross_weapon_hit"
const CONTINUOUS_HIT_THRESHOLD := &"continuous_hit_threshold"
const SHARED_RESOURCE_RELEASE := &"shared_resource_release"

const ALL: Array[StringName] = [
	SKILL_CAST_COMMITTED,
	SKILL_CAST_FINISHED,
	PROJECTILE_SPAWNED,
	HIT_CONFIRMED,
	DAMAGE_DEALT,
	CRITICAL_HIT,
	TARGET_KILLED,
	RELOAD_STARTED,
	RELOAD_FINISHED,
	PRIMARY_ATTACK_FIRED,
	WEAPON_ENTERED_MAIN,
	WEAPON_ENTERED_SUPPORT,
	MAGAZINE_QUARTER_SPENT,
	SUPPORT_CHARGE_READY,
	CROSS_WEAPON_HIT,
	CONTINUOUS_HIT_THRESHOLD,
	SHARED_RESOURCE_RELEASE,
]

var type: StringName
var source_weapon: Node
var action_context: SkillActionContext
var target: Node
var projectile: Node2D
var damage_data: DamageData
var damage_result: DamageResult
var detail: Dictionary = {}

static func create(event_type: StringName, weapon: Node = null) -> WeaponEvent:
	assert(ALL.has(event_type), "Unknown weapon event type: %s" % event_type)
	var event := WeaponEvent.new()
	event.type = event_type
	event.source_weapon = weapon
	return event

func with_context(context: SkillActionContext) -> WeaponEvent:
	action_context = context
	return self

func to_legacy_detail() -> Dictionary:
	var output := detail.duplicate(true)
	output["source_weapon"] = source_weapon
	if target != null:
		output["target"] = target
	if projectile != null:
		output["projectile"] = projectile
	if damage_data != null:
		output["damage_data"] = damage_data
	if damage_result != null:
		output["damage_result"] = damage_result
	if action_context != null:
		output["action_context"] = action_context
	return output
