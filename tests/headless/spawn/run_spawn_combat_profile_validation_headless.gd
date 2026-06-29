extends SceneTree

const ValidatorScript := preload("res://tools/validate_spawn_combat_profile.gd")

func _initialize() -> void:
	var profile := load("res://data/spawns/spawn_combat_profile.tres") as SpawnCombatProfile
	var validator := ValidatorScript.new()
	var ok := validator.validate(profile)
	for warning in validator.warnings:
		push_warning(warning)
	for error in validator.errors:
		push_error(error)
	if ok:
		print("PASS: spawn combat profile validation")
		quit(0)
		return
	push_error("FAIL: spawn combat profile validation")
	quit(1)
