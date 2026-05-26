extends SceneTree

# One-off migration helper from legacy spawn profiles to SpawnCombatProfile.
# Default mode is dry-run. Pass --write to save generated resources/scenes.

const LEGACY_SPAWN_PROFILE := "res://data/spawns/spawn_balance_profile.tres"
const LEGACY_BUDGET_PROFILE := "res://data/spawns/level_combat_budget_profile.tres"
const TARGET_PROFILE := "res://data/spawns/spawn_combat_profile.tres"

func _initialize() -> void:
	var write := OS.get_cmdline_args().has("--write")
	print("Spawn profile migration %s" % ("write" if write else "dry-run"))
	if ResourceLoader.exists(TARGET_PROFILE) and not ResourceLoader.exists(LEGACY_SPAWN_PROFILE):
		print("Active legacy profiles are archived; %s already exists." % TARGET_PROFILE)
		quit(0)
		return
	var spawn_profile := load(LEGACY_SPAWN_PROFILE)
	var budget_profile := load(LEGACY_BUDGET_PROFILE)
	if spawn_profile == null or budget_profile == null:
		push_error("Legacy profiles are unavailable; migration cannot run.")
		quit(1)
		return
	var level_configs: Array = spawn_profile.get("level_configs")
	var target_hp: PackedInt32Array = budget_profile.get("level_target_total_hp")
	var time_out: PackedInt32Array = budget_profile.get("level_time_out_sec")
	print("Would migrate %d legacy levels into %s" % [level_configs.size(), TARGET_PROFILE])
	for i in range(level_configs.size()):
		var level = level_configs[i]
		var hp := int(target_hp[i]) if i < target_hp.size() else 0
		var timeout := int(time_out[i]) if i < time_out.size() else int(level.get("time_out"))
		print("Level %d: target_hp=%d time_out=%d entries=%d" % [i, hp, timeout, level.spawns.size()])
	if write:
		push_warning("This project has already been migrated manually; no files were written.")
	quit(0)
