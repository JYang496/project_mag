extends Node2D

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/heavy_assault.tscn")
const MODULE_DAMAGE_UP := preload("res://Player/Weapons/Modules/damage_up.tscn")
const MODULE_PIERCE := preload("res://Player/Weapons/Modules/pierce.tscn")

@onready var info_label: Label = $CanvasLayer/InfoLabel
var spawned_player: Node
var spawned_ui: Node

func _ready() -> void:
	await _bootstrap_runtime()
	_render_status("Manual test scene ready.")

func _bootstrap_runtime() -> void:
	if spawned_player and is_instance_valid(spawned_player):
		spawned_player.queue_free()
		spawned_player = null
	if spawned_ui and is_instance_valid(spawned_ui):
		spawned_ui.queue_free()
		spawned_ui = null
	await get_tree().process_frame

	if GlobalVariables.has_method("reset_runtime_state"):
		GlobalVariables.reset_runtime_state()
	if InventoryData.has_method("reset_runtime_state"):
		InventoryData.reset_runtime_state()
	if PlayerData.has_method("reset_runtime_state"):
		PlayerData.reset_runtime_state()

	spawned_player = PLAYER_SCENE.instantiate()
	spawned_player.add_to_group("player")
	add_child(spawned_player)
	spawned_ui = UI_SCENE.instantiate()
	add_child(spawned_ui)
	await get_tree().process_frame

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			_gain_module(MODULE_DAMAGE_UP, "Damage Up")
		KEY_2:
			_gain_module(MODULE_PIERCE, "Pierce")
		KEY_3:
			_force_max_and_convert("Damage Up")
		KEY_R:
			await _bootstrap_runtime()
			_render_status("Runtime reset.")
		_:
			return

func _gain_module(module_scene: PackedScene, module_name: String) -> void:
	var module_instance: Module = module_scene.instantiate() as Module
	if module_instance == null:
		_render_status("Failed to instantiate module: %s" % module_name)
		return
	InventoryData.obtain_module(module_instance)
	_render_status("Obtained '%s'." % module_name)

func _force_max_and_convert(module_name: String) -> void:
	var module_ref: Module = _find_module_by_name(module_name)
	if module_ref == null:
		var seeded: Module = MODULE_DAMAGE_UP.instantiate() as Module
		if seeded:
			InventoryData.obtain_module(seeded)
		module_ref = _find_module_by_name(module_name)
	if module_ref == null:
		_render_status("Could not seed module '%s'." % module_name)
		return
	module_ref.set_module_level(Module.MAX_LEVEL)
	var duplicate: Module = MODULE_DAMAGE_UP.instantiate() as Module
	if duplicate:
		InventoryData.obtain_module(duplicate)
	_render_status("Forced '%s' to max and applied duplicate." % module_name)

func _find_module_by_name(target_name: String) -> Module:
	var normalized_target: String = target_name.strip_edges().to_lower()
	for module_ref in InventoryData.moddule_slots:
		var module_instance: Module = module_ref as Module
		if module_instance == null or not is_instance_valid(module_instance):
			continue
		if module_instance.get_module_display_name().strip_edges().to_lower() == normalized_target:
			return module_instance
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon: Weapon = weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon) or weapon.modules == null:
			continue
		for child in weapon.modules.get_children():
			var module_instance: Module = child as Module
			if module_instance == null:
				continue
			if module_instance.get_module_display_name().strip_edges().to_lower() == normalized_target:
				return module_instance
	return null

func _render_status(last_action: String) -> void:
	var lines: PackedStringArray = []
	lines.append("Weapon Module Manual Test")
	lines.append("Keys: [1] Obtain Damage Up, [2] Obtain Pierce, [3] Force Damage Up max + duplicate convert, [R] Reset")
	lines.append("Last action: %s" % last_action)
	lines.append("Gold: %d" % int(PlayerData.player_gold))
	lines.append("Inventory modules:")

	if InventoryData.moddule_slots.is_empty():
		lines.append("  - (empty)")
	else:
		for module_ref in InventoryData.moddule_slots:
			var module_instance: Module = module_ref as Module
			if module_instance == null or not is_instance_valid(module_instance):
				continue
			lines.append("  - %s Lv.%d" % [module_instance.get_module_display_name(), int(module_instance.module_level)])

	info_label.text = "\n".join(lines)
