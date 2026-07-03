extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")

class FakeWeapon:
	extends Node

	signal passive_triggered(event_name: StringName, detail: Dictionary)
	signal weapon_reload_completed(weapon)

	var passive_status: Dictionary = {}

	func get_ammo_status() -> Dictionary:
		return {
			"enabled": true,
			"current": 4,
			"max": 8,
			"is_reloading": false,
			"reload_left": 0.0,
		}

	func get_passive_status() -> Dictionary:
		return passive_status

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.GAMEOVER
	var ui := UI_SCENE.instantiate() as UI
	if ui == null:
		_fail("Failed to instantiate UI.")
		return
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	var selector := ui.weapon_selector as WeaponSelector
	if selector == null:
		_fail("Weapon selector is missing.")
		return
	var main_weapon := FakeWeapon.new()
	main_weapon.name = "MainPassiveWeapon"
	main_weapon.passive_status = {
		"id": "test_ready",
		"display_name": "Ready Passive",
		"state": "ready_pending_action",
		"progress": 1.0,
		"ready": true,
		"trigger_hint": "test_trigger_hint",
		"refresh_hint": "test_refresh_hint",
		"charge_current": 2,
		"charge_max": 3,
		"charge_based": true,
	}
	var offhand_weapon := FakeWeapon.new()
	offhand_weapon.name = "OffhandPassiveWeapon"
	offhand_weapon.passive_status = {
		"id": "test_ready_single_charge",
		"display_name": "Ready Single Charge Passive",
		"state": "waiting_refresh",
		"ready": false,
		"trigger_hint": "test_single_trigger",
		"refresh_hint": "test_single_refresh",
		"charge_based": true,
	}
	get_tree().root.add_child(main_weapon)
	get_tree().root.add_child(offhand_weapon)
	PlayerData.player_weapon_list = [main_weapon, offhand_weapon]
	PlayerData.main_weapon_index = 0
	selector.refresh_slots()
	selector.call("_update_slot_cooldown_progress")
	selector.call("_update_slot_passive_progress")
	if ui.weapon_passive_presenter == null:
		_fail("Weapon passive presenter should be initialized.")
		return
	var presenter_statuses: Array = ui.weapon_passive_presenter.get_equipped_weapon_passive_statuses()
	if presenter_statuses.size() < 2:
		_fail("Weapon passive presenter should expose equipped weapon passive statuses.")
		return
	var main_presenter_status := presenter_statuses[0] as Dictionary
	if str(main_presenter_status.get("trigger_hint", "")) != "test_trigger_hint":
		_fail("Passive presenter should preserve trigger_hint from get_passive_status().")
		return
	if str(main_presenter_status.get("refresh_hint", "")) != "test_refresh_hint":
		_fail("Passive presenter should preserve refresh_hint from get_passive_status().")
		return
	if int(main_presenter_status.get("charge_current", 0)) != 2 or int(main_presenter_status.get("charge_max", 0)) != 3:
		_fail("Passive presenter should preserve charge fields from get_passive_status().")
		return

	var overlay := selector.get_node_or_null("CooldownOverlay") as Control
	if overlay == null or overlay.get_parent() != selector:
		_fail("Cooldown overlay must be a direct child of WeaponSelector.")
		return
	if overlay.z_index != 0:
		_fail("Cooldown overlay must share WeaponSelector z layer.")
		return
	for child in overlay.get_children():
		var canvas_item := child as CanvasItem
		if canvas_item != null and canvas_item.z_index != 0:
			_fail("Cooldown ring children must stay on WeaponSelector z layer.")
			return
	var main_passive := overlay.get_node_or_null("PassiveDiamond0") as Control
	if main_passive == null or not main_passive.visible:
		_fail("Main weapon passive layer should be visible inside the selector overlay.")
		return
	if str(main_passive.get("fill_color")) != str(WeaponSelector.PASSIVE_READY_COLOR):
		_fail("Main weapon ready passive state should use the ready color.")
		return
	var main_charges := overlay.get_node_or_null("PassiveChargeBeans0") as Control
	if main_charges == null or not main_charges.visible:
		_fail("Charge-based passive weapons should render beans below the passive ring.")
		return
	if int(main_charges.get("max_charges")) != 3 or int(main_charges.get("current_charges")) != 2:
		_fail("Charge beans should mirror current and max passive charges.")
		return
	var offhand_passive := overlay.get_node_or_null("PassiveDiamond3") as Control
	if offhand_passive == null or not offhand_passive.visible:
		_fail("Offhand passive layer should render while equipped.")
		return
	if str(offhand_passive.get("fill_color")) != str(WeaponSelector.PASSIVE_COOLDOWN_COLOR):
		_fail("Offhand waiting-refresh passive layer should render its real cooldown state.")
		return
	var offhand_charges := overlay.get_node_or_null("PassiveChargeBeans3") as Control
	if offhand_charges == null:
		_fail("Offhand charge bean node should exist inside the selector overlay.")
		return
	if not offhand_charges.visible:
		_fail("Single-charge passive weapons should render one charge bean.")
		return
	if int(offhand_charges.get("max_charges")) != 1 or int(offhand_charges.get("current_charges")) != 0:
		_fail("Default single-charge passive beans should render as 0/1 while waiting refresh.")
		return
	offhand_weapon.passive_status = {
		"id": "test_ready_single_charge",
		"display_name": "Ready Single Charge Passive",
		"state": "ready",
		"ready": true,
	}
	selector.call("_update_slot_passive_progress")
	if int(offhand_charges.get("max_charges")) != 1 or int(offhand_charges.get("current_charges")) != 1:
		_fail("Default single-charge passive beans should refill to 1/1 when ready.")
		return
	if str(offhand_passive.get("fill_color")) != str(WeaponSelector.PASSIVE_READY_COLOR):
		_fail("Single-charge ready weapons should keep a full ready inner ring.")
		return
	var offhand_flash := overlay.get_node_or_null("PassiveFlash3") as Control
	if offhand_flash == null or not offhand_flash.visible:
		_fail("Ready transition should play a subtle flash for offhand weapons too.")
		return
	offhand_flash.visible = false
	if ui.weapon_passive_panel != null and ui.weapon_passive_panel.visible:
		_fail("Legacy weapon passive text panel should be hidden by default.")
		return
	var main_flash := overlay.get_node_or_null("PassiveFlash0") as Control
	if main_flash == null:
		_fail("Passive trigger flash node should exist for the main slot.")
		return
	main_weapon.passive_triggered.emit(&"on_hit", {})
	if main_flash.visible:
		_fail("Generic on_hit passive broadcasts should not flash the HUD passive layer.")
		return
	main_weapon.passive_triggered.emit(&"test_heat_spend", {})
	if main_flash.visible:
		_fail("Non-triggered spend events should not flash the HUD passive layer.")
		return
	main_weapon.passive_triggered.emit(&"machine_gun_heat_expansion", {})
	if not main_flash.visible:
		_fail("Machine Gun heat expansion should flash even though its event id has no _triggered suffix.")
		return
	main_flash.visible = false
	offhand_weapon.passive_triggered.emit(&"test_ready_triggered", {})
	if not offhand_flash.visible:
		_fail("Offhand triggered passive events should flash while equipped.")
		return
	offhand_flash.visible = false
	main_weapon.passive_triggered.emit(&"test_ready_triggered", {})
	if not main_flash.visible:
		_fail("Main weapon passive trigger events should flash the HUD passive layer.")
		return
	print("WeaponSelectorLayerTest: PASS")
	main_weapon.queue_free()
	offhand_weapon.queue_free()
	ui.queue_free()
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("WeaponSelectorLayerTest: %s" % message)
	get_tree().quit(1)
