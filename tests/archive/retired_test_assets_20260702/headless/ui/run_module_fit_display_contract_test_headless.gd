extends Node

const PANEL_SCENE := preload("res://UI/scenes/reward_selection_panel.tscn")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var weapon := _instantiate_first_weapon()
	if weapon == null:
		_fail("ModuleFitDisplayContractTest: missing weapon fixture.")
		return
	get_tree().root.add_child(weapon)
	await get_tree().process_frame
	PlayerData.player_weapon_list = [weapon]
	PlayerData.main_weapon_index = 0
	PlayerData.on_select_weapon = 0
	var compatible_module := _find_module_for_weapon(weapon, true)
	var incompatible_module := _find_module_for_weapon(weapon, false)
	if compatible_module == null:
		_fail("ModuleFitDisplayContractTest: missing compatible module fixture.")
		return
	if incompatible_module == null:
		_fail("ModuleFitDisplayContractTest: missing incompatible module fixture.")
		return
	if not _assert_formatter_matches_module_rules(compatible_module, weapon, true):
		return
	if not _assert_formatter_matches_module_rules(incompatible_module, weapon, false):
		return
	if not _assert_unknown_chip_fallback():
		return
	if not _assert_reward_panel_display_data(compatible_module):
		return
	if not _assert_non_module_reward_display_data():
		return
	compatible_module.queue_free()
	incompatible_module.queue_free()
	weapon.queue_free()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	await get_tree().process_frame
	print("ModuleFitDisplayContractTest: PASS")
	get_tree().quit(0)

func _assert_formatter_matches_module_rules(module_instance: Module, weapon: Weapon, expected_fit: bool) -> bool:
	var data: Dictionary = MODULE_FIT_FORMATTER.build_display_data(module_instance, weapon)
	if data.has("effect_tags"):
		_fail("ModuleFitDisplayContractTest: formatter still exposes the retired effect_tags field.")
		return false
	var effect_chips: Array = data.get("effect_chips", [])
	if effect_chips.is_empty():
		_fail("ModuleFitDisplayContractTest: formatter produced no effect chips for %s." % module_instance.scene_file_path)
		return false
	var fit_badge: Dictionary = data.get("fit_badge", {})
	if fit_badge.is_empty():
		_fail("ModuleFitDisplayContractTest: formatter produced no fit badge for %s." % module_instance.scene_file_path)
		return false
	var actual_fit := str(data.get("fit_status", "")) == str(MODULE_FIT_FORMATTER.STATUS_FITS)
	if actual_fit != expected_fit:
		_fail("ModuleFitDisplayContractTest: formatter fit status disagrees with module rule for %s." % module_instance.scene_file_path)
		return false
	if actual_fit != module_instance.can_apply_to_weapon(weapon):
		_fail("ModuleFitDisplayContractTest: formatter fit status disagrees with can_apply_to_weapon for %s." % module_instance.scene_file_path)
		return false
	if not expected_fit and PackedStringArray(data.get("fit_warnings", PackedStringArray())).is_empty():
		_fail("ModuleFitDisplayContractTest: incompatible module produced no warning.")
		return false
	return true

func _assert_unknown_chip_fallback() -> bool:
	var chip: Dictionary = BUILD_TAG_DISPLAY.build_tag_chip(&"phase_shift")
	if str(chip.get("source_key", "")) != "phase_shift":
		_fail("ModuleFitDisplayContractTest: unknown chip lost source key.")
		return false
	if str(chip.get("icon_key", "")) != "generic":
		_fail("ModuleFitDisplayContractTest: unknown chip did not use generic icon key.")
		return false
	if str(chip.get("label", "")) != "Phase Shift":
		_fail("ModuleFitDisplayContractTest: unknown chip did not generate readable fallback label.")
		return false
	return true

func _assert_reward_panel_display_data(module_instance: Module) -> bool:
	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_STANDARD
	reward.module_scene = load(module_instance.scene_file_path) as PackedScene
	reward.module_level = 1
	var panel := PANEL_SCENE.instantiate() as RewardSelectionPanel
	get_tree().root.add_child(panel)
	var data: Dictionary = panel.call("_build_reward_display_data", reward)
	panel.queue_free()
	var short_tag := str(data.get("short_tag", ""))
	var detail_text := str(data.get("detail_text", ""))
	var meta_text := str(data.get("meta_text", ""))
	var fallback_icon_key := str(data.get("fallback_icon_key", ""))
	var icon_texture := data.get("icon_texture", null) as Texture2D
	var chips: Array = data.get("chips", [])
	if short_tag == "" or short_tag.find(" / ") < 0:
		_fail("ModuleFitDisplayContractTest: module reward card did not expose fit/effect short summary.")
		return false
	if meta_text.find("Lv.") < 0 or meta_text.find("Module") < 0:
		_fail("ModuleFitDisplayContractTest: module reward card did not expose level/type meta text.")
		return false
	if icon_texture == null and fallback_icon_key != "module":
		_fail("ModuleFitDisplayContractTest: module reward card has neither icon texture nor module fallback icon key.")
		return false
	if chips.is_empty():
		_fail("ModuleFitDisplayContractTest: module reward card did not expose display chips.")
		return false
	var first_chip := chips[0] as Dictionary
	if str(first_chip.get("status", "")) != str(BUILD_TAG_DISPLAY.STATUS_FIT):
		_fail("ModuleFitDisplayContractTest: module reward fit badge was not the first chip.")
		return false
	if detail_text.find("Effect Tags:") < 0:
		_fail("ModuleFitDisplayContractTest: module reward detail did not expose effect tags.")
		return false
	if detail_text.find("Fit:") < 0:
		_fail("ModuleFitDisplayContractTest: module reward detail did not expose fit status.")
		return false
	if detail_text.find("Best On:") >= 0:
		_fail("ModuleFitDisplayContractTest: module reward detail still exposes Best On recommendation.")
		return false
	return true

func _assert_non_module_reward_display_data() -> bool:
	var reward := RewardInfo.new()
	reward.reward_kind = RewardInfo.KIND_ECONOMY
	reward.total_chip_value = 25
	var panel := PANEL_SCENE.instantiate() as RewardSelectionPanel
	get_tree().root.add_child(panel)
	var data: Dictionary = panel.call("_build_reward_display_data", reward)
	panel.queue_free()
	var meta_text := str(data.get("meta_text", ""))
	var fallback_icon_key := str(data.get("fallback_icon_key", ""))
	var chips: Array = data.get("chips", [])
	if meta_text == "":
		_fail("ModuleFitDisplayContractTest: economy reward card did not expose meta text.")
		return false
	if fallback_icon_key != "economy":
		_fail("ModuleFitDisplayContractTest: economy reward card did not expose economy fallback icon key.")
		return false
	if chips.is_empty() or str((chips[0] as Dictionary).get("source_key", "")) != "economy":
		_fail("ModuleFitDisplayContractTest: economy reward card did not expose economy chip.")
		return false
	return true

func _instantiate_first_weapon() -> Weapon:
	for weapon_id in DataHandler.get_weapon_ids():
		var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if definition != null and definition.scene != null:
			return definition.scene.instantiate() as Weapon
	return null

func _find_module_for_weapon(weapon: Weapon, should_fit: bool) -> Module:
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Modules"):
		if not file_name.ends_with(".tscn") or file_name == "wmod_base.tscn":
			continue
		var scene_path := "res://Player/Weapons/Modules/%s" % file_name
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var module_instance := scene.instantiate() as Module
		if module_instance == null:
			continue
		var fits := module_instance.can_apply_to_weapon(weapon)
		var has_requirements := not module_instance.get_normalized_required_weapon_traits().is_empty() \
				or not module_instance.get_normalized_required_delivery_types().is_empty() \
				or not module_instance.get_normalized_required_weapon_capabilities().is_empty()
		if fits == should_fit and (should_fit or has_requirements):
			return module_instance
		module_instance.queue_free()
	return null

func _fail(message: String) -> void:
	push_error(message)
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	get_tree().quit(1)
