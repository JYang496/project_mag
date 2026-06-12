extends PanelContainer
class_name WeaponReplacementPanel

@onready var title_label: Label = $Margin/Root/Title
@onready var description_label: Label = $Margin/Root/Description
@onready var slots: VBoxContainer = $Margin/Root/Slots
@onready var cancel_button: Button = $Margin/Root/Cancel

var _new_weapon: Weapon
var _cancel_to_gold := true
var _on_complete := Callable()

func _ready() -> void:
	visible = false
	cancel_button.pressed.connect(_on_cancel_pressed)

func open_for_weapon(
	new_weapon: Weapon,
	cancel_to_gold: bool = true,
	on_complete: Callable = Callable()
) -> bool:
	if new_weapon == null or not is_instance_valid(new_weapon):
		return false
	_new_weapon = new_weapon
	_cancel_to_gold = cancel_to_gold
	_on_complete = on_complete
	InventoryData.begin_pending_transaction({
		"id": "weapon_replacement",
		"type": "weapon_replacement",
		"weapon": DataHandler.build_weapon_save_payload(new_weapon),
		"cancel_to_gold": cancel_to_gold,
	})
	title_label.text = LocalizationManager.tr_key("ui.weapon.replace.title", "Choose Weapon Slot")
	description_label.text = LocalizationManager.tr_format(
		"ui.weapon.replace.description",
		{"weapon": LocalizationManager.get_weapon_name_from_node(new_weapon)},
		"Equip %s or replace an equipped weapon." % LocalizationManager.get_weapon_name_from_node(new_weapon)
	)
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	_rebuild_slots()
	visible = true
	return true

func _rebuild_slots() -> void:
	for child in slots.get_children():
		child.queue_free()
	for index in range(PlayerData.max_weapon_num):
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 52)
		if index < PlayerData.player_weapon_list.size():
			var old_weapon := PlayerData.player_weapon_list[index] as Weapon
			button.text = LocalizationManager.tr_format(
				"ui.weapon.replace.slot",
				{
					"slot": index + 1,
					"old": LocalizationManager.get_weapon_name_from_node(old_weapon),
					"new": LocalizationManager.get_weapon_name_from_node(_new_weapon),
				},
				"Slot %d: %s -> %s" % [
					index + 1,
					LocalizationManager.get_weapon_name_from_node(old_weapon),
					LocalizationManager.get_weapon_name_from_node(_new_weapon),
				]
			)
			button.pressed.connect(_on_replace_selected.bind(old_weapon))
		else:
			button.text = LocalizationManager.tr_format(
				"ui.weapon.replace.empty_slot",
				{"slot": index + 1},
				"Slot %d: Empty" % [index + 1]
			)
			button.pressed.connect(_on_empty_slot_selected)
		slots.add_child(button)

func _on_empty_slot_selected() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var weapon := _new_weapon
	_new_weapon = null
	PlayerData.player.create_weapon(weapon)
	_complete(true, {"result": "equipped"})

func _on_replace_selected(old_weapon: Weapon) -> void:
	var result := InventoryData.replace_equipped_weapon(old_weapon, _new_weapon)
	if not result.get("ok", false):
		return
	_new_weapon = null
	_complete(true, result)

func _on_cancel_pressed() -> void:
	var result := {"result": "cancelled"}
	if _new_weapon and is_instance_valid(_new_weapon):
		if _cancel_to_gold:
			var weapon_id := DataHandler.get_weapon_id_from_instance(_new_weapon)
			var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
			var base_price := int(weapon_def.price) if weapon_def else 0
			var gold := (GlobalVariables.economy_data if GlobalVariables.economy_data else EconomyConfig.new()).get_duplicate_weapon_gold(base_price)
			PlayerData.player_gold += gold
			PlayerData.run_gold_earned += gold
			result["gold"] = gold
			result["result"] = "converted_to_gold"
		_new_weapon.queue_free()
	_new_weapon = null
	_complete(false, result)

func _complete(accepted: bool, result: Dictionary) -> void:
	visible = false
	InventoryData.finish_pending_transaction("weapon_replacement")
	if _on_complete.is_valid():
		_on_complete.call_deferred(accepted, result)
	_on_complete = Callable()
