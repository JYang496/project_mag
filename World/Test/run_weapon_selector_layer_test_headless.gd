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
	}
	var offhand_weapon := FakeWeapon.new()
	offhand_weapon.name = "OffhandPassiveWeapon"
	offhand_weapon.passive_status = {
		"id": "test_ready_no_charge",
		"display_name": "Ready No Charge Passive",
		"state": "waiting_refresh",
		"ready": false,
	}
	get_tree().root.add_child(main_weapon)
	get_tree().root.add_child(offhand_weapon)
	PlayerData.player_weapon_list = [main_weapon, offhand_weapon]
	PlayerData.main_weapon_index = 0
	selector.refresh_slots()
	selector.call("_update_slot_cooldown_progress")
	selector.call("_update_slot_passive_progress")

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
	var offhand_passive := overlay.get_node_or_null("PassiveDiamond3") as Control
	if offhand_passive == null or not offhand_passive.visible:
		_fail("Offhand passive layer should render while equipped.")
		return
	if str(offhand_passive.get("fill_color")) != str(WeaponSelector.PASSIVE_UNAVAILABLE_COLOR):
		_fail("Offhand non-ready passive layer should render as unavailable.")
		return
	offhand_weapon.passive_status = {
		"id": "test_ready_no_charge",
		"display_name": "Ready No Charge Passive",
		"state": "ready",
		"ready": true,
	}
	selector.call("_update_slot_passive_progress")
	if str(offhand_passive.get("fill_color")) != str(WeaponSelector.PASSIVE_READY_COLOR):
		_fail("No-charge ready weapons should keep a full ready inner ring.")
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
