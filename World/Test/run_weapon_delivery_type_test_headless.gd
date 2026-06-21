extends SceneTree

const MODULE_DIR := "res://Player/Weapons/Modules/"
const MODULE_MAX_LEVEL := 3
const EXPECTED_CLASSIFICATION_BY_SCENE_PATH := {
	"res://Player/Weapons/Instances/cannon.tscn": {
		"traits": [&"physical"], "delivery": [&"projectile", &"area"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/chainsaw_launcher.tscn": {
		"traits": [&"physical"], "delivery": [&"projectile"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/charged_blaster.tscn": {
		"traits": [&"energy", &"charge"], "delivery": [&"beam"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/dash_blade.tscn": {
		"traits": [&"physical", &"auto_fire"], "delivery": [&"melee_contact"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/flamethrower.tscn": {
		"traits": [&"fire", &"heat"], "delivery": [&"area"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/glacier_projector.tscn": {
		"traits": [&"freeze"], "delivery": [&"area"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/laser.tscn": {
		"traits": [&"energy"], "delivery": [&"beam"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/machine_gun.tscn": {
		"traits": [&"physical", &"heat"], "delivery": [&"projectile"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/orbit.tscn": {
		"traits": [&"physical"], "delivery": [&"projectile"], "capabilities": [&"summon"],
	},
	"res://Player/Weapons/Instances/pistol.tscn": {
		"traits": [&"physical", &"auto_fire"], "delivery": [&"projectile"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/plasma_lance.tscn": {
		"traits": [&"energy", &"heat"], "delivery": [&"projectile"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/rocket_launcher.tscn": {
		"traits": [&"physical", &"fire"], "delivery": [&"projectile", &"area"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/shotgun.tscn": {
		"traits": [&"physical"], "delivery": [&"projectile"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/sniper.tscn": {
		"traits": [&"physical"], "delivery": [&"projectile"], "capabilities": [],
	},
	"res://Player/Weapons/Instances/spear_launcher.tscn": {
		"traits": [&"physical"], "delivery": [&"projectile"], "capabilities": [],
	},
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: PackedStringArray = []
	var checked_count := 0
	var weapon_paths := _list_weapon_definition_paths()
	for weapon_path in weapon_paths:
		var weapon_def := load(weapon_path)
		if weapon_def == null:
			failures.append("%s: failed to load WeaponDefinition" % weapon_path)
			continue
		var scene: PackedScene = weapon_def.get("scene") as PackedScene
		if scene == null:
			failures.append("%s: missing scene" % weapon_path)
			continue
		var scene_path := str(scene.resource_path)
		if not EXPECTED_CLASSIFICATION_BY_SCENE_PATH.has(scene_path):
			failures.append("%s: no expected classification mapping for %s" % [weapon_path, scene_path])
			continue
		var weapon := scene.instantiate()
		if weapon == null:
			failures.append("%s: scene did not instantiate as Weapon" % weapon_path)
			continue
		checked_count += 1
		failures.append_array(
			_validate_weapon_classification(
				weapon_path,
				weapon,
				EXPECTED_CLASSIFICATION_BY_SCENE_PATH[scene_path]
			)
		)
		weapon.free()
	failures.append_array(_validate_delivery_trait_module_compatibility())
	failures.append_array(_validate_modules())

	if failures.is_empty():
		print("PASS: weapon classification and modules verified for %d weapons" % checked_count)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _list_weapon_definition_paths() -> PackedStringArray:
	var output: PackedStringArray = []
	var dir := DirAccess.open("res://data/weapons/")
	if dir == null:
		return output
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			output.append("res://data/weapons/%s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	output.sort()
	return output

func _validate_weapon_classification(
	label: String,
	weapon: Node,
	expected: Dictionary
) -> PackedStringArray:
	var failures: PackedStringArray = []
	if not weapon.has_method("get_explicit_delivery_types"):
		failures.append("%s: weapon missing get_explicit_delivery_types()" % label)
		return failures
	if not weapon.has_method("get_weapon_delivery_types"):
		failures.append("%s: weapon missing get_weapon_delivery_types()" % label)
		return failures
	if not weapon.has_method("get_normalized_weapon_traits"):
		failures.append("%s: weapon missing get_normalized_weapon_traits()" % label)
		return failures
	if not weapon.has_method("get_explicit_weapon_capabilities"):
		failures.append("%s: weapon missing get_explicit_weapon_capabilities()" % label)
		return failures
	var explicit_delivery: Array = weapon.call("get_explicit_delivery_types")
	var resolved_delivery: Array = weapon.call("get_weapon_delivery_types")
	var explicit_traits: Array = weapon.call("get_explicit_weapon_traits")
	var resolved_traits: Array = weapon.call("get_normalized_weapon_traits")
	var explicit_capabilities: Array = weapon.call("get_explicit_weapon_capabilities")
	var resolved_capabilities: Array = weapon.call("get_weapon_capabilities")
	if explicit_delivery.is_empty():
		failures.append("%s: explicit delivery_type_flags is empty" % label)
	if explicit_traits.is_empty():
		failures.append("%s: explicit weapon traits are empty" % label)
	failures.append_array(_compare_names(label, "base traits", explicit_traits, expected.traits))
	failures.append_array(_compare_names(label, "runtime traits", resolved_traits, expected.traits))
	failures.append_array(_compare_names(label, "base delivery", explicit_delivery, expected.delivery))
	failures.append_array(_compare_names(label, "runtime delivery", resolved_delivery, expected.delivery))
	failures.append_array(
		_compare_names(label, "base capabilities", explicit_capabilities, expected.capabilities)
	)
	failures.append_array(
		_compare_names(label, "runtime capabilities", resolved_capabilities, expected.capabilities)
	)
	for delivery_type in DamageDeliveryType.ALL:
		if resolved_traits.has(delivery_type):
			failures.append(
				"%s: delivery type %s leaked into weapon traits %s" %
				[label, delivery_type, resolved_traits]
			)
	return failures

func _compare_names(label: String, field: String, actual: Array, expected: Array) -> PackedStringArray:
	var actual_names := PackedStringArray()
	var expected_names := PackedStringArray()
	for value in actual:
		actual_names.append(str(value))
	for value in expected:
		expected_names.append(str(value))
	actual_names.sort()
	expected_names.sort()
	if actual_names == expected_names:
		return PackedStringArray()
	return PackedStringArray([
		"%s: %s expected %s, got %s" % [label, field, expected_names, actual_names]
	])

func _validate_delivery_trait_module_compatibility() -> PackedStringArray:
	var failures: PackedStringArray = []
	var sniper_scene := load("res://Player/Weapons/Instances/sniper.tscn") as PackedScene
	var module_scene := load("res://Player/Weapons/Modules/wmod_base.tscn") as PackedScene
	if sniper_scene == null or module_scene == null:
		failures.append("module compatibility: failed to load Sniper or base module scene")
		return failures
	var sniper := sniper_scene.instantiate()
	var module := module_scene.instantiate()
	if sniper == null or module == null:
		failures.append("module compatibility: failed to instantiate Sniper or base module")
		if sniper != null:
			sniper.free()
		if module != null:
			module.free()
		return failures

	module.set("required_delivery_types", DamageDeliveryType.types_to_flags([DamageDeliveryType.PROJECTILE]))
	if not bool(module.call("can_apply_to_weapon", sniper)):
		failures.append("Sniper: projectile delivery trait did not allow projectile module")

	module.set("required_delivery_types", 0)
	module.set("required_weapon_traits", WeaponTrait.traits_to_flags([WeaponTrait.HEAT]))
	if bool(module.call("can_apply_to_weapon", sniper)):
		failures.append("Sniper: unrelated heat trait unexpectedly allowed heat module")

	module.free()
	sniper.free()
	return failures

func _validate_modules() -> PackedStringArray:
	var failures: PackedStringArray = []
	var module_count := 0
	var allowed_trait_mask := (1 << WeaponTrait.ALL.size()) - 1
	var allowed_delivery_mask := (1 << DamageDeliveryType.ALL.size()) - 1
	var allowed_capability_mask := (1 << WeaponCapability.ALL.size()) - 1
	var allowed_hook_mask := (1 << ModuleHook.ALL.size()) - 1
	var dir := DirAccess.open(MODULE_DIR)
	if dir == null:
		return PackedStringArray(["modules: cannot open %s" % MODULE_DIR])
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn") and file_name != "wmod_base.tscn":
			var path := MODULE_DIR + file_name
			var source := FileAccess.get_file_as_string(path)
			for deprecated_field in ["module_traits", "supports_melee", "supports_ranged"]:
				if source.contains(deprecated_field):
					failures.append("%s: contains deprecated field %s" % [path, deprecated_field])
			var scene := load(path) as PackedScene
			var module := scene.instantiate() if scene != null else null
			if module == null:
				failures.append("%s: failed to instantiate module" % path)
			else:
				module_count += 1
				failures.append_array(
					_validate_mask(path, "required_weapon_traits", int(module.required_weapon_traits), allowed_trait_mask)
				)
				failures.append_array(
					_validate_mask(path, "required_delivery_types", int(module.required_delivery_types), allowed_delivery_mask)
				)
				failures.append_array(
					_validate_mask(
						path,
						"required_weapon_capabilities",
						int(module.required_weapon_capabilities),
						allowed_capability_mask
					)
				)
				failures.append_array(
					_validate_mask(path, "required_hooks", int(module.required_hooks), allowed_hook_mask)
				)
				var hook_error := str(module.call("get_hook_validation_error"))
				if hook_error != "":
					failures.append("%s: %s" % [path, hook_error])
				var level_effects: PackedStringArray = module.get("level_effects")
				if level_effects.size() != MODULE_MAX_LEVEL:
					failures.append(
						"%s: expected %d level effects, got %d" %
						[path, MODULE_MAX_LEVEL, level_effects.size()]
					)
				else:
					for level_index in range(MODULE_MAX_LEVEL):
						module.call("set_module_level", level_index + 1)
						var level_description := str(
							module.call("get_level_effect_description", level_index + 1)
						)
						if level_description.strip_edges() == "":
							failures.append(
								"%s: level %d effect description is empty" %
								[path, level_index + 1]
							)
				var unknown_tags: Array = module.call("get_unknown_module_tags")
				if not unknown_tags.is_empty():
					print("WARNING: %s uses extension module tags %s" % [path, unknown_tags])
				module.free()
		file_name = dir.get_next()
	dir.list_dir_end()
	if module_count != 56:
		failures.append("modules: expected 56 module scenes, got %d" % module_count)
	return failures

func _validate_mask(path: String, field: String, value: int, allowed_mask: int) -> PackedStringArray:
	var unknown_bits := value & ~allowed_mask
	if unknown_bits == 0:
		return PackedStringArray()
	return PackedStringArray(["%s: %s contains unknown bits %d" % [path, field, unknown_bits]])
