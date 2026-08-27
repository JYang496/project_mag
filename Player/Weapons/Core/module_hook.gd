extends RefCounted
class_name ModuleHook

const PROJECTILE_SPAWN := &"projectile_spawn"
const HIT := &"hit"
const DAMAGE_DEALT := &"damage_dealt"
const AREA_DAMAGE := &"area_damage"
const BEAM_HIT := &"beam_hit"
const RELOAD_START := &"reload_start"
const RELOAD_DURATION := &"reload_duration"
const KILL := &"kill"
const SKILL_CAST := &"skill_cast"
const SKILL_FINISH := &"skill_finish"

const ALL: Array[StringName] = [
	PROJECTILE_SPAWN,
	HIT,
	DAMAGE_DEALT,
	AREA_DAMAGE,
	BEAM_HIT,
	RELOAD_START,
	RELOAD_DURATION,
	KILL,
	SKILL_CAST,
	SKILL_FINISH,
]

const METHOD_BY_HOOK := {
	PROJECTILE_SPAWN: &"on_projectile_spawned",
	HIT: &"apply_on_hit",
	DAMAGE_DEALT: &"on_damage_dealt",
	AREA_DAMAGE: &"on_area_damage",
	BEAM_HIT: &"on_beam_hit",
	RELOAD_START: &"_on_weapon_passive_triggered",
	RELOAD_DURATION: &"get_reload_duration_multiplier",
	KILL: &"on_kill",
	SKILL_CAST: &"on_skill_cast",
	SKILL_FINISH: &"on_skill_finished",
}

const EVENT_BY_HOOK := {
	PROJECTILE_SPAWN: &"projectile_spawned",
	HIT: &"hit_confirmed",
	DAMAGE_DEALT: &"damage_dealt",
	AREA_DAMAGE: &"damage_dealt",
	BEAM_HIT: &"hit_confirmed",
	RELOAD_START: &"reload_started",
	KILL: &"target_killed",
	SKILL_CAST: &"skill_cast_committed",
	SKILL_FINISH: &"skill_cast_finished",
}

# Presentation tags are derived from the same event names used by the runtime
# dispatcher. Keep this mapping here so UI callers never recreate Hook semantics.
const DISPLAY_TAG_BY_EVENT := {
	&"projectile_spawned": &"projectile",
	&"hit_confirmed": &"on_hit",
	&"damage_dealt": &"on_hit",
	&"critical_hit": &"on_hit",
	&"cross_weapon_hit": &"on_hit",
	&"continuous_hit_threshold": &"on_hit",
	&"target_killed": &"execute",
	&"reload_started": &"reload",
}

static func flags_to_hooks(mask: int) -> Array[StringName]:
	var output: Array[StringName] = []
	for i in range(ALL.size()):
		if (mask & (1 << i)) != 0:
			output.append(ALL[i])
	return output

static func hooks_to_events(hooks: Array[StringName]) -> Array[StringName]:
	var output: Array[StringName] = []
	for hook in hooks:
		var event_type: StringName = EVENT_BY_HOOK.get(hook, StringName())
		if event_type != StringName() and not output.has(event_type):
			output.append(event_type)
	return output

static func display_tag_for_event(event_type: StringName) -> StringName:
	return DISPLAY_TAG_BY_EVENT.get(event_type, StringName())

static func display_tags_for_events(events: Array[StringName]) -> Array[StringName]:
	var output: Array[StringName] = []
	var has_unmapped_event := false
	for event_type in events:
		var tag := display_tag_for_event(event_type)
		if tag == StringName():
			has_unmapped_event = true
		elif not output.has(tag):
			output.append(tag)
	# A concrete trigger label is more useful than the generic Trigger tag.
	if output.is_empty() and has_unmapped_event:
		output.append(&"trigger")
	return output
