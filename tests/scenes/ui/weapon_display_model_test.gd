extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const STAT_CATALOG := preload("res://UI/scripts/presentation/weapon_stat_catalog.gd")
const STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")
const REPLACEMENT_SCENE := preload("res://UI/scenes/weapon_replacement_panel.tscn")

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	LocalizationManager.set_locale("en", false)
	var prepare_result := DataHandler.prepare_world_data(true)
	_expect(bool(prepare_result.get("ok", false)), "weapon presentation test requires a valid startup catalog")
	var weapon_ids := DataHandler.get_weapon_ids()
	_expect(weapon_ids.size() == 15, "all 15 visible weapon definitions must be covered")
	for weapon_id in weapon_ids:
		var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		_expect(definition != null, "weapon %s definition must load" % weapon_id)
		if definition == null:
			continue
		var definition_model = DISPLAY_BUILDER.build_from_definition(definition, 1)
		_expect(definition_model.weapon_id == weapon_id, "weapon %s model must preserve identity" % weapon_id)
		_expect(definition_model.display_name.strip_edges() != "", "weapon %s must have a display name" % weapon_id)
		_expect(definition_model.description.strip_edges() != "", "weapon %s must have a localized description" % weapon_id)
		for key_variant in definition_model.current_stats.keys():
			var key := StringName(str(key_variant))
			_expect(STAT_CATALOG.DEFINITIONS.has(key), "weapon stat %s must be registered centrally" % str(key))
			var label := STAT_FORMATTER.format_label(key)
			_expect(label.strip_edges() != "" and not label.contains("_"), "weapon stat %s must have a player-facing label" % str(key))
		var weapon := definition.scene.instantiate() as Weapon
		_expect(weapon != null, "weapon %s runtime scene must instantiate" % weapon_id)
		if weapon != null:
			var instance_model = DISPLAY_BUILDER.build_from_instance(weapon, true)
			_expect(instance_model.weapon_id == definition_model.weapon_id, "definition and instance model IDs must match for %s" % weapon_id)
			_expect(instance_model.description == definition_model.description, "definition and instance descriptions must match for %s" % weapon_id)
			weapon.free()

	_expect(STAT_FORMATTER.format_value(&"fire_interval_sec", "1.25").contains("1.25"), "seconds must preserve decimal precision")
	_expect(STAT_FORMATTER.format_value(&"ammo", "6").contains("6"), "ammo must format as a count")
	_test_upgrade_semantics("1", 1, 2, &"damage", &"positive")
	_test_upgrade_semantics("11", 1, 2, &"fire_interval_sec", &"positive")
	await _test_replacement_comparison()
	if _failed:
		return
	print("PASS: unified weapon display model and stat formatting")
	await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state)


func _test_upgrade_semantics(weapon_id: String, from_level: int, to_level: int, key: StringName, expected_benefit: StringName) -> void:
	var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if definition == null:
		_fail("missing weapon definition %s" % weapon_id)
		return
	var model = DISPLAY_BUILDER.build_at_levels(definition, from_level, to_level)
	for delta_data in model.upgrade_deltas:
		if StringName(str(delta_data.get("key", ""))) != key:
			continue
		_expect(bool(delta_data.get("changed", false)), "%s must change between tested levels" % str(key))
		_expect(StringName(str(delta_data.get("benefit", ""))) == expected_benefit, "%s direction must map to semantic benefit" % str(key))
		_expect(STAT_FORMATTER.format_delta_line(delta_data).contains("→"), "%s upgrade line must show before and after" % str(key))
		return
	_fail("upgrade delta did not include %s" % str(key))


func _test_replacement_comparison() -> void:
	var incoming_definition := DataHandler.read_weapon_data("25") as WeaponDefinition
	var current_definition := DataHandler.read_weapon_data("1") as WeaponDefinition
	if incoming_definition == null or current_definition == null:
		_fail("replacement comparison fixtures must load")
		return
	var incoming := incoming_definition.scene.instantiate() as Weapon
	var current := current_definition.scene.instantiate() as Weapon
	var panel := REPLACEMENT_SCENE.instantiate() as WeaponReplacementPanel
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	host.add_child(panel)
	panel.visible = true
	await get_tree().process_frame
	var slots_scroll := panel.get_node_or_null("Margin/Root/SlotsScroll") as ScrollContainer
	_expect(slots_scroll != null and slots_scroll.size.y > 0.0, "replacement choices must use a visible scroll region at 1280x720")
	_expect(panel.size == Vector2(920, 580), "replacement panel must preserve the intended 1280x720 safe margins")
	var comparison := str(panel.call("_format_replacement_comparison", incoming, current))
	_expect(comparison.contains("→"), "replacement rows must compare incoming and current weapon values")
	_expect(not comparison.contains("fire_interval_sec"), "replacement comparison must not expose raw stat keys")
	host.queue_free()
	incoming.free()
	current.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("FAIL: ", message)
	await TEST_TEARDOWN.finish(self, 1, _reset_runtime_state)


func _reset_runtime_state() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
