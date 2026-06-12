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

const ALL: Array[StringName] = [
	PROJECTILE_SPAWN,
	HIT,
	DAMAGE_DEALT,
	AREA_DAMAGE,
	BEAM_HIT,
	RELOAD_START,
	RELOAD_DURATION,
	KILL,
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
}

static func flags_to_hooks(mask: int) -> Array[StringName]:
	var output: Array[StringName] = []
	for i in range(ALL.size()):
		if (mask & (1 << i)) != 0:
			output.append(ALL[i])
	return output
