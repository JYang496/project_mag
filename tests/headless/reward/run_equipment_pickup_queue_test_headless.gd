extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	DataHandler.prepare_world_data()
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PlayerData.player = _PlayerStub.new()
	add_child(PlayerData.player)

	var rest_area_stub := _RestAreaModuleAccessStub.new()
	rest_area_stub.name = "RestAreaModuleAccessStub"
	rest_area_stub.add_to_group("rest_area")
	add_child(rest_area_stub)

	var ui := UI_SCENE.instantiate() as UI
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var equipped_weapon_id := _first_weapon_id("")
	var pickup_weapon_id := _first_weapon_id(equipped_weapon_id)
	if equipped_weapon_id == "" or pickup_weapon_id == "":
		_fail(1, "EquipmentPickupQueueTest: missing weapon fixtures.")
		return
	var equipped_weapon := _instantiate_weapon(equipped_weapon_id)
	var pickup_weapon := _instantiate_weapon(pickup_weapon_id)
	if equipped_weapon == null or pickup_weapon == null:
		_fail(2, "EquipmentPickupQueueTest: failed to instantiate weapon fixtures.")
		return
	PlayerData.max_weapon_num = 1
	PlayerData.player_weapon_list.append(equipped_weapon)
	add_child(equipped_weapon)

	var module_scene := load("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn") as PackedScene
	var module_instance := module_scene.instantiate() as Module if module_scene else null
	if module_instance == null:
		_fail(3, "EquipmentPickupQueueTest: failed to instantiate module fixture.")
		return
	add_child(module_instance)

	var module_result := {
		"completed": false,
		"assigned": false,
	}
	if not ui.request_module_pickup_selection(module_instance, func(assigned: bool) -> void:
		module_result["completed"] = true
		module_result["assigned"] = assigned
		if not assigned and module_instance and is_instance_valid(module_instance):
			InventoryData.obtain_module(module_instance)
	):
		_fail(4, "EquipmentPickupQueueTest: module pickup request was rejected.")
		return
	if not ui.request_weapon_pickup_selection(pickup_weapon):
		_fail(5, "EquipmentPickupQueueTest: weapon pickup request was rejected.")
		return

	await get_tree().process_frame
	await get_tree().process_frame
	if ui.weapon_replacement_panel == null or not ui.weapon_replacement_panel.visible:
		_fail(6, "EquipmentPickupQueueTest: weapon replacement did not open first.")
		return
	if ui.module_equip_selection_panel != null and ui.module_equip_selection_panel.visible:
		_fail(7, "EquipmentPickupQueueTest: module panel opened while weapon panel was active.")
		return

	ui.weapon_replacement_panel.call("_on_store_selected")
	await get_tree().process_frame
	await get_tree().process_frame
	if ui.weapon_replacement_panel.visible:
		_fail(8, "EquipmentPickupQueueTest: weapon replacement panel stayed open after storing.")
		return
	if ui.module_equip_selection_panel == null or not ui.module_equip_selection_panel.visible:
		_fail(9, "EquipmentPickupQueueTest: module panel did not open after weapon completion.")
		return

	ui.module_equip_selection_panel.close_without_assignment()
	for _i in range(6):
		await get_tree().process_frame
	if not bool(module_result["completed"]) or bool(module_result["assigned"]):
		_fail(10, "EquipmentPickupQueueTest: module completion callback did not run as cancelled.")
		return
	if not InventoryData.temporary_modules.has(module_instance):
		_fail(11, "EquipmentPickupQueueTest: cancelled module pickup was not stored temporarily.")
		return

	InventoryData.reset_runtime_state()
	print("EquipmentPickupQueueTest: PASS")
	get_tree().quit(0)

func _first_weapon_id(excluded_id: String) -> String:
	for weapon_id in DataHandler.get_weapon_ids():
		if weapon_id != excluded_id:
			return weapon_id
	return ""

func _instantiate_weapon(weapon_id: String) -> Weapon:
	var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	return definition.scene.instantiate() as Weapon if definition and definition.scene else null

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)

class _RestAreaModuleAccessStub:
	extends Node

	func is_module_management_available() -> bool:
		return true

class _PlayerStub:
	extends Node

	var active_skill_holder := Node.new()

	func create_weapon(_weapon_or_id: Variant) -> void:
		pass

	func predict_auto_fuse_weapon_obtain(_weapon_id: String) -> Dictionary:
		return {"result": "not_applicable"}

	func try_auto_fuse_weapon_obtain(_weapon_id: String) -> Dictionary:
		return {"result": "not_applicable"}
