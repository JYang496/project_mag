extends SceneTree

const EXPECTED_DELIVERY_BY_SCENE_PATH := {
	"res://Player/Weapons/Instances/cannon.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/chainsaw_launcher.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/charged_blaster.tscn": [&"beam"],
	"res://Player/Weapons/Instances/dash_blade.tscn": [&"melee_contact"],
	"res://Player/Weapons/Instances/flamethrower.tscn": [&"area"],
	"res://Player/Weapons/Instances/glacier_projector.tscn": [&"area"],
	"res://Player/Weapons/Instances/laser.tscn": [&"beam"],
	"res://Player/Weapons/Instances/machine_gun.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/orbit.tscn": [&"projectile", &"summon"],
	"res://Player/Weapons/Instances/pistol.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/plasma_lance.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/rocket_launcher.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/shotgun.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/sniper.tscn": [&"projectile"],
	"res://Player/Weapons/Instances/spear_launcher.tscn": [&"projectile"],
}

const DELIVERY_TRAITS := {
	&"projectile": &"projectile",
	&"melee_contact": &"melee",
	&"beam": &"beam",
	&"area": &"area_of_effect",
	&"summon": &"summon",
	&"trap": &"trap",
	&"support": &"support",
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
		if not EXPECTED_DELIVERY_BY_SCENE_PATH.has(scene_path):
			failures.append("%s: no expected delivery mapping for %s" % [weapon_path, scene_path])
			continue
		var weapon := scene.instantiate()
		if weapon == null:
			failures.append("%s: scene did not instantiate as Weapon" % weapon_path)
			continue
		checked_count += 1
		failures.append_array(_validate_weapon_delivery(weapon_path, weapon, EXPECTED_DELIVERY_BY_SCENE_PATH[scene_path]))
		weapon.free()

	if failures.is_empty():
		print("PASS: weapon delivery types verified for %d weapons" % checked_count)
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

func _validate_weapon_delivery(label: String, weapon: Node, expected_delivery_types: Array) -> PackedStringArray:
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
	var explicit_delivery: Array = weapon.call("get_explicit_delivery_types")
	var resolved_delivery: Array = weapon.call("get_weapon_delivery_types")
	var normalized_traits: Array = weapon.call("get_normalized_weapon_traits")
	if explicit_delivery.is_empty():
		failures.append("%s: explicit delivery_type_flags is empty" % label)
	for expected_type in expected_delivery_types:
		var expected := StringName(str(expected_type))
		if expected == StringName():
			failures.append("%s: expected delivery type is empty" % label)
			continue
		if not explicit_delivery.has(expected):
			failures.append("%s: explicit delivery missing %s, got %s" % [label, expected, explicit_delivery])
		if not resolved_delivery.has(expected):
			failures.append("%s: resolved delivery missing %s, got %s" % [label, expected, resolved_delivery])
		var expected_trait := StringName(DELIVERY_TRAITS.get(expected, StringName()))
		if expected_trait != StringName() and not normalized_traits.has(expected_trait):
			failures.append("%s: normalized traits missing %s for delivery %s, got %s" % [label, expected_trait, expected, normalized_traits])
	return failures
