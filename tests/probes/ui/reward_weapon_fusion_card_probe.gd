extends Node

var _failed := false

class FusionPredictionStub:
	extends Node
	func predict_auto_fuse_weapon_obtain(weapon_id: String) -> Dictionary:
		if weapon_id == "1":
			return {
				"result": "fused",
				"weapon_id": "1",
				"from_fuse": 1,
				"target_fuse": 2,
				"has_branch_options": false,
			}
		return {"result": "not_applicable", "weapon_id": weapon_id}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	LocalizationManager.set_locale("en", false)
	var previous_player = PlayerData.player
	var stub := FusionPredictionStub.new()
	get_tree().root.add_child(stub)
	PlayerData.player = stub

	var panel := RewardSelectionPanel.new()
	var fusion_reward := RewardInfo.new()
	fusion_reward.item_id = "1"
	fusion_reward.item_level = 1
	var fusion_data: Dictionary = panel.call("_build_reward_display_data", fusion_reward)
	_assert_eq(str(fusion_data.get("type_label", "")), "Weapon Fusion", "duplicate weapon card type")
	_assert_eq(str(fusion_data.get("icon_badge_text", "")), "^", "duplicate weapon badge")
	_assert_contains(str(fusion_data.get("meta_text", "")), "Fuse 1 -> 2", "duplicate weapon meta")
	_assert_contains(str(fusion_data.get("outcome_text", "")), "Fuse equipped", "duplicate weapon outcome")
	if _failed:
		return

	var new_reward := RewardInfo.new()
	new_reward.item_id = "2"
	new_reward.item_level = 1
	var new_data: Dictionary = panel.call("_build_reward_display_data", new_reward)
	_assert_eq(str(new_data.get("icon_badge_text", "")), "+", "new weapon badge")
	_assert_eq(panel.call("_get_reward_action_color", new_reward), Color(0.42, 0.78, 0.48, 1.0), "new weapon action color")
	if _failed:
		return

	var upgrade_reward := RewardInfo.new()
	upgrade_reward.reward_kind = RewardInfo.KIND_WEAPON_UPGRADE
	upgrade_reward.target_weapon_name = "Machine Gun"
	upgrade_reward.target_weapon_id = "1"
	upgrade_reward.target_weapon_from_level = 1
	upgrade_reward.target_weapon_to_level = 2
	var upgrade_data: Dictionary = panel.call("_build_reward_display_data", upgrade_reward)
	_assert_eq(str(upgrade_data.get("icon_badge_text", "")), "Lv", "upgrade badge")
	_assert_eq(panel.call("_get_reward_action_color", upgrade_reward), Color(0.36, 0.62, 0.95, 1.0), "upgrade action color")
	if _failed:
		return

	panel.free()
	PlayerData.player = previous_player
	stub.queue_free()
	print("PASS: reward weapon fusion card semantics")
	printerr("PASS: reward weapon fusion card semantics")
	get_tree().quit()

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %s got %s" % [label, str(expected), str(actual)])

func _assert_contains(actual: String, expected: String, label: String) -> void:
	if actual.contains(expected):
		return
	_fail("%s expected to contain %s got %s" % [label, expected, actual])

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("FAIL: ", message)
	get_tree().quit(1)
