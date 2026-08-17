extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const MODULE_OFFER_CATALOG := preload("res://Player/Weapons/Core/module_offer_catalog.gd")
const REWARD_MANAGER := preload("res://World/rewards/reward_manager.gd")
const SHOP_MODULE_SLOT := preload("res://UI/scripts/shop_module_slot.gd")

var _failed := false

func _ready() -> void:
	_test_catalog_contract()
	_test_unlock_boundaries()
	_test_new_tier_weight_window()
	_test_runtime_consumers_share_catalog()
	await _test_chapter_reward_guarantee()
	print("FAIL module progression catalog" if _failed else "PASS module progression catalog")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _test_catalog_contract() -> void:
	var errors := MODULE_OFFER_CATALOG.validate_catalog()
	_expect(errors.is_empty(), "module progression catalog must cover every loadable module scene exactly once: %s" % errors)
	_expect(MODULE_OFFER_CATALOG.get_all_scene_paths().size() == 58, "catalog must contain all 58 weapon modules")
	var sample_scene := load("res://Player/Weapons/Modules/wmod_area_expander.tscn") as PackedScene
	var sample := sample_scene.instantiate() as Module if sample_scene else null
	_expect(sample != null and sample.get_stable_module_id() == &"wmod_area_expander", "legacy modules must expose a filename-derived stable id")
	if sample:
		sample.free()

func _test_unlock_boundaries() -> void:
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(0, false).size() == 14, "level 0 must expose only foundation modules")
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(2, false).size() == 14, "chapter one must retain the foundation pool")
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(3, false).size() == 30, "level 3 must unlock trigger modules")
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(5, false).size() == 30, "chapter two must retain the trigger pool")
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(6, false).size() == 46, "level 6 must unlock build modules")
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(8, false).size() == 46, "chapter three must retain the build pool")
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(9, false).size() == 58, "level 9 must unlock conversion modules")
	_expect(MODULE_OFFER_CATALOG.get_unlocked_scene_paths(0, true).size() == 58, "endless mode must expose the full module pool")

func _test_new_tier_weight_window() -> void:
	var trigger_path := "res://Player/Weapons/Modules/wmod_damage_up_stat.tscn"
	_expect(is_equal_approx(MODULE_OFFER_CATALOG.get_offer_weight_multiplier(trigger_path, 2), 1.0), "locked tiers must not receive an early weight boost")
	_expect(is_equal_approx(MODULE_OFFER_CATALOG.get_offer_weight_multiplier(trigger_path, 3), 3.0), "new tier must receive its configured weight boost")
	_expect(is_equal_approx(MODULE_OFFER_CATALOG.get_offer_weight_multiplier(trigger_path, 4), 3.0), "weight boost must last for two level opportunities")
	_expect(is_equal_approx(MODULE_OFFER_CATALOG.get_offer_weight_multiplier(trigger_path, 5), 1.0), "weight boost must expire after its window")

func _test_runtime_consumers_share_catalog() -> void:
	var reward_manager := REWARD_MANAGER.new()
	var shop_slot := SHOP_MODULE_SLOT.new()
	PhaseManager.current_level = 0
	_expect(reward_manager._build_module_candidates_uncached(false).size() == 14, "reward and special-drop candidates must respect the foundation pool")
	_expect(shop_slot._build_module_candidates().size() == 14, "shop candidates must respect the foundation pool")
	PhaseManager.current_level = 6
	_expect(reward_manager._build_module_candidates_uncached(false).size() == 46, "reward candidates must refresh at chapter unlock boundaries")
	_expect(shop_slot._build_module_candidates().size() == 46, "shop candidates must refresh at chapter unlock boundaries")
	reward_manager.free()
	shop_slot.free()

func _test_chapter_reward_guarantee() -> void:
	PhaseManager.current_level = 3
	var weapon_scene := load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene
	var weapon := weapon_scene.instantiate() as Weapon if weapon_scene else null
	_expect(weapon != null, "chapter guarantee fixture weapon must load")
	if weapon == null:
		return
	add_child(weapon)
	await get_tree().process_frame
	PlayerData.player_weapon_list.append(weapon)
	var reward_manager := REWARD_MANAGER.new()
	var candidates: Array[Dictionary] = reward_manager._build_module_candidates_uncached(true)
	var reward: RewardInfo = reward_manager._build_new_tier_compatible_module_reward(candidates, {})
	_expect(reward != null and reward.module_scene != null, "chapter start must guarantee one installable new-tier module when a compatible candidate exists")
	if reward != null and reward.module_scene != null:
		_expect(MODULE_OFFER_CATALOG.is_new_tier_scene(reward.module_scene.resource_path, 3), "guaranteed module must come from the newly unlocked tier")
	PlayerData.player_weapon_list.erase(weapon)
	weapon.queue_free()
	reward_manager.free()

func _reset_runtime_state() -> void:
	PhaseManager.reset_runtime_state()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
