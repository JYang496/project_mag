extends Node

const MODULE_DIR := "res://Player/Weapons/Modules"

func _ready() -> void:
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization == null:
		push_error("FAIL: LocalizationManager autoload was not available.")
		get_tree().quit(1)
		return
	localization.set_locale("zh_CN", false)
	var failures := PackedStringArray()
	var checked_names := 0
	var checked_effects := 0
	for file_name in DirAccess.get_files_at(MODULE_DIR):
		if not file_name.begins_with("wmod_") or not file_name.ends_with(".tscn"):
			continue
		var scene := load("%s/%s" % [MODULE_DIR, file_name]) as PackedScene
		var module_instance := scene.instantiate() as Module if scene else null
		if module_instance == null:
			failures.append("Failed to instantiate %s" % file_name)
			continue
		var fallback_name := module_instance.get_module_display_name()
		var localized_name: String = localization.get_module_name(module_instance)
		checked_names += 1
		if localized_name == "" or localized_name == fallback_name:
			failures.append("%s name was not localized" % file_name)
		for level in range(1, module_instance.level_effects.size() + 1):
			var fallback_effect := str(module_instance.level_effects[level - 1])
			var localized_effect := module_instance.get_level_effect_description(level)
			checked_effects += 1
			if localized_effect == "" or localized_effect == fallback_effect:
				failures.append("%s level %d effect was not localized" % [file_name, level])
		module_instance.free()
	if localization.get_module_term(&"heat", "Heat") != "热量":
		failures.append("Module term localization was not loaded")
	var sample_scene := load(
		"res://Player/Weapons/Modules/wmod_reload_blast_damage.tscn"
	) as PackedScene
	var sample_module := sample_scene.instantiate() as Module if sample_scene else null
	if sample_module == null:
		failures.append("Failed to instantiate module UI localization sample")
	else:
		var display_data := ModuleFitFormatter.build_display_data(sample_module)
		if str(display_data.get("fit_label", "")) != "当前未选择武器":
			failures.append("Module fit label was not localized")
		var chip_labels := BuildTagDisplay.chip_labels(display_data.get("effect_chips", []))
		for english_label in PackedStringArray(["Trigger", "Area", "Physical", "Reload"]):
			if chip_labels.has(english_label):
				failures.append("Module chip remained in English: %s" % english_label)
		var detail_lines := sample_module.get_effect_descriptions()
		if detail_lines.has("Reload burst damages nearby enemies") \
				or detail_lines.has("Damage scales with spent ammo"):
			failures.append("Module detail text was not localized")
		sample_module.free()
	var localized_reason: String = localization.localize_module_reason(
		"Requires one of: heat, projectile"
	)
	if not localized_reason.contains("热量") or not localized_reason.contains("投射物"):
		failures.append("Module incompatibility reason terms were not localized")
	if failures.is_empty() and checked_names == 57 and checked_effects == 168:
		print("PASS: localized %d module names and %d level effects." % [checked_names, checked_effects])
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("FAIL: checked %d module names and %d level effects." % [checked_names, checked_effects])
	get_tree().quit(1)
