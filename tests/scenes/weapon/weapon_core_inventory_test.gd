extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_runtime()
	DataHandler.prepare_world_data(true)
	_test_core_normalization_and_queries()
	_test_enhanced_contract_core_reward_preview()
	_test_duplicate_weapon_dismantling()
	_test_runtime_save_and_legacy_restore()
	_test_all_fusion_recipe_tags_have_core_sources()
	_test_fusion_recipe_and_transaction()
	_test_enhanced_branch_save_migration()
	_finish()

func _test_core_normalization_and_queries() -> void:
	var first := InventoryData.add_weapon_cores([&"area", &"fire", &"area"], 1, false)
	var second := InventoryData.add_weapon_cores([&"fire", &"area"], 2, false)
	_expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "valid core tags must be accepted")
	_expect(str(first.get("core_key", "")) == str(second.get("core_key", "")), "tag order and duplicates must not change core identity")
	_expect(InventoryData.get_weapon_core_count([&"fire", &"area"]) == 3, "identical tag sets must stack")
	InventoryData.add_weapon_cores([&"fire", &"projectile"], 1, false)
	_expect(InventoryData.get_weapon_core_stacks().size() == 2, "different tag sets must remain separate")
	_expect(InventoryData.find_weapon_cores_containing_tag(&"fire").size() == 2, "tag query must return every matching core stack")
	_expect(not bool(InventoryData.add_weapon_cores([&"unknown_core_tag"], 1, false).get("ok", true)), "unknown-only core tags must be rejected")

func _test_enhanced_contract_core_reward_preview() -> void:
	var weapon := _instantiate_weapon("1")
	_expect(weapon != null, "enhanced contract core reward test needs a valid equipped weapon")
	if weapon == null:
		return
	add_child(weapon)
	PlayerData.player_weapon_list.append(weapon)
	var reward: Dictionary = BattleContractManager.call("_build_equipped_weapon_core_reward")
	var definition := DataHandler.read_weapon_data("1") as WeaponDefinition
	_expect(str(reward.get("type", "")) == "equipped_weapon_core", "enhanced contract must build a core reward from an equipped weapon")
	_expect(str(reward.get("weapon_name", "")) == LocalizationManager.get_weapon_name_from_definition(definition), "enhanced core reward must use the WeaponDefinition display-name contract")
	PlayerData.player_weapon_list.erase(weapon)
	weapon.queue_free()

func _test_duplicate_weapon_dismantling() -> void:
	InventoryData.weapon_core_inventory.clear()
	var first_weapon := _instantiate_weapon("1")
	var first_result := InventoryData.obtain_weapon_reward(first_weapon)
	_expect(str(first_result.get("result", "")) == "stored", "first weapon obtain must keep the weapon")
	var stored := first_result.get("weapon", null) as Weapon
	_expect(stored != null and int(stored.fuse) == 1, "first weapon must remain at Fuse 1")
	var duplicate := _instantiate_weapon("1")
	var duplicate_result := InventoryData.obtain_weapon_reward(duplicate)
	_expect(str(duplicate_result.get("result", "")) == "dismantled_to_core", "duplicate weapon must dismantle into a core")
	_expect(stored != null and int(stored.fuse) == 1, "duplicate weapon must not increase Fuse")
	var definition := DataHandler.read_weapon_data("1") as WeaponDefinition
	_expect(definition != null and duplicate_result.get("core_tags", []) == definition.get_normalized_core_tags(), "core must contain every configured weapon tag")
	_expect(int(duplicate_result.get("core_count", 0)) == 1, "first duplicate must create one core")
	if stored != null:
		stored.fuse = Weapon.MAX_FUSE_LEVEL
	var max_fuse_duplicate := _instantiate_weapon("1")
	var max_result := InventoryData.obtain_weapon_reward(max_fuse_duplicate)
	_expect(str(max_result.get("result", "")) == "dismantled_to_core", "max-Fuse duplicate must still dismantle into a core")
	_expect(int(max_result.get("core_count", 0)) == 2, "max-Fuse duplicate must stack its core")

func _test_runtime_save_and_legacy_restore() -> void:
	InventoryData.save_runtime_state()
	var expected := InventoryData.get_weapon_core_stacks()
	InventoryData.weapon_core_inventory.clear()
	InventoryData.load_runtime_state()
	_expect(InventoryData.get_weapon_core_stacks() == expected, "runtime save must restore core inventory")
	InventoryData.restore_weapon_core_inventory(null)
	_expect(InventoryData.get_weapon_core_stacks().is_empty(), "legacy save without core field must migrate to an empty inventory")
	InventoryData.restore_weapon_core_inventory([
		{"tags": ["fire", "not_a_real_tag"], "count": 4},
		{"tags": ["fire"], "count": 0},
	])
	_expect(InventoryData.get_weapon_core_stacks().is_empty(), "malformed or unknown saved core entries must be skipped")

func _test_all_fusion_recipe_tags_have_core_sources() -> void:
	var available_tags: Array[StringName] = []
	for weapon_id in DataHandler.get_weapon_ids():
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if weapon_def == null:
			continue
		for tag in weapon_def.get_normalized_core_tags():
			if not available_tags.has(tag):
				available_tags.append(tag)
	var branch_count := 0
	for scene_path_variant in GlobalVariables.weapon_branch_list.keys():
		for branch_variant in GlobalVariables.weapon_branch_list.get(scene_path_variant, []):
			var branch := branch_variant as WeaponBranchDefinition
			if branch == null:
				continue
			branch_count += 1
			var recipe := branch.get_normalized_fusion_required_tags()
			_expect(not recipe.is_empty(), "every fusion branch must define a recipe: %s" % branch.branch_id)
			for required_tag in recipe:
				_expect(available_tags.has(required_tag), "fusion recipe tag must have a current weapon-core source: %s/%s" % [branch.branch_id, required_tag])
	_expect(branch_count == 28, "fusion recipe audit must cover all 28 registered branches")

func _test_fusion_recipe_and_transaction() -> void:
	_reset_runtime()
	DataHandler.prepare_world_data(true)
	var weapon := _store_test_weapon("1", 2)
	var heat_core := InventoryData.add_weapon_cores([&"fire", &"heat"], 1, false)
	var projectile_core := InventoryData.add_weapon_cores([&"physical", &"projectile"], 1, false)
	var unrelated_core := InventoryData.add_weapon_cores([&"freeze", &"control"], 1, false)
	var heat_key := str(heat_core.get("core_key", ""))
	var projectile_key := str(projectile_core.get("core_key", ""))
	var unrelated_key := str(unrelated_core.get("core_key", ""))
	var low_level := InventoryData.preview_weapon_fusion(weapon, "gatling_mg", [heat_key, projectile_key])
	_expect(str(low_level.get("reason_code", "")) == "level_too_low", "Fuse 2 must require weapon level 3")
	weapon.set_level(3)
	var short_selection := InventoryData.preview_weapon_fusion(weapon, "gatling_mg", [heat_key])
	_expect(str(short_selection.get("reason_code", "")) == "core_count_mismatch", "Fuse 2 must require exactly two cores")
	var unrelated_selection := InventoryData.preview_weapon_fusion(weapon, "gatling_mg", [heat_key, unrelated_key])
	_expect(str(unrelated_selection.get("reason_code", "")) == "core_unrelated", "unrelated cores must not fill recipe count")
	var ready := InventoryData.preview_weapon_fusion(weapon, "gatling_mg", [heat_key, projectile_key])
	_expect(bool(ready.get("ok", false)), "two different cores must satisfy the recipe through their tag union")
	_expect((ready.get("missing_tags", []) as Array).is_empty(), "ready recipe must report no missing tags")
	var fused := InventoryData.commit_weapon_fusion(weapon, "gatling_mg", [heat_key, projectile_key])
	_expect(bool(fused.get("ok", false)) and int(weapon.fuse) == 2, "Fuse 2 transaction must advance the weapon")
	_expect(weapon.branch_runtime.has_branch("gatling_mg"), "Fuse 2 transaction must apply the selected branch")
	_expect(InventoryData.get_weapon_core_count([&"fire", &"heat"]) == 0, "successful transaction must consume selected heat core")
	_expect(InventoryData.get_weapon_core_count([&"physical", &"projectile"]) == 0, "successful transaction must consume selected projectile core")
	var before_failed_count := InventoryData.get_weapon_core_count([&"freeze", &"control"])
	var repeated := InventoryData.commit_weapon_fusion(weapon, "gatling_mg", [unrelated_key, unrelated_key, unrelated_key])
	_expect(not bool(repeated.get("ok", false)), "invalid repeated submission must fail")
	_expect(InventoryData.get_weapon_core_count([&"freeze", &"control"]) == before_failed_count, "failed transaction must not consume cores")
	weapon.set_level(6)
	var branch_core := InventoryData.add_weapon_cores([&"heat", &"projectile"], 3, false)
	var branch_key := str(branch_core.get("core_key", ""))
	var before_enhancement := weapon.branch_runtime.get_branch_projectile_damage_multiplier()
	var enhanced := InventoryData.commit_weapon_fusion(weapon, "gatling_mg", [branch_key, branch_key, branch_key])
	_expect(bool(enhanced.get("ok", false)) and int(weapon.fuse) == 3, "Fuse 3 transaction must require and consume three cores")
	_expect(weapon.branch_runtime.is_branch_enhanced("gatling_mg"), "Fuse 3 must enhance the existing branch")
	_expect(weapon.branch_runtime.branch_ids.size() == 1, "Fuse 3 must not add a second branch")
	var after_enhancement := weapon.branch_runtime.get_branch_projectile_damage_multiplier()
	_expect(absf(after_enhancement - 1.0) > absf(before_enhancement - 1.0), "Fuse 3 must strengthen the selected branch effect")
	var duplicate_submit := InventoryData.commit_weapon_fusion(weapon, "gatling_mg", [branch_key, branch_key, branch_key])
	_expect(str(duplicate_submit.get("reason_code", "")) == "fusion_maxed", "completed Fuse 3 must reject repeat submission")

func _test_enhanced_branch_save_migration() -> void:
	var weapon := InventoryData.weapon_storage[0] as Weapon if not InventoryData.weapon_storage.is_empty() else null
	_expect(weapon != null, "enhanced branch save test needs the fused weapon")
	if weapon == null:
		return
	var payload := DataHandler.build_weapon_save_payload(weapon)
	_expect(str(payload.get("enhanced_branch_id", "")) == "gatling_mg", "save payload must persist the enhanced branch id")
	var restored := DataHandler.instantiate_weapon_from_save_payload(payload)
	add_child(restored)
	DataHandler.restore_weapon_runtime_from_save_payload(restored, payload)
	_expect(restored.branch_runtime.is_branch_enhanced("gatling_mg"), "saved enhanced branch must restore")
	restored.queue_free()
	var legacy_payload := payload.duplicate(true)
	legacy_payload.erase("enhanced_branch_id")
	var legacy := DataHandler.instantiate_weapon_from_save_payload(legacy_payload)
	add_child(legacy)
	DataHandler.restore_weapon_runtime_from_save_payload(legacy, legacy_payload)
	_expect(legacy.branch_runtime.is_branch_enhanced("gatling_mg"), "legacy Fuse 3 save must migrate its existing branch to enhanced")
	legacy.queue_free()

func _store_test_weapon(weapon_id: String, level: int) -> Weapon:
	var weapon := _instantiate_weapon(weapon_id)
	InventoryData.add_child(weapon)
	weapon.visible = false
	weapon.process_mode = Node.PROCESS_MODE_DISABLED
	InventoryData.weapon_storage.append(weapon)
	weapon.set_level(level)
	return weapon

func _instantiate_weapon(weapon_id: String) -> Weapon:
	var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	return definition.scene.instantiate() as Weapon if definition and definition.scene else null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var exit_code := 0
	if _failures.is_empty():
		print("PASS: weapon core inventory")
	else:
		exit_code = 1
		for failure in _failures:
			push_error(failure)
		print("FAIL: weapon core inventory")
	await TEST_TEARDOWN.finish(self, exit_code, _reset_runtime)

func _reset_runtime() -> void:
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
	GlobalVariables.ui = null
