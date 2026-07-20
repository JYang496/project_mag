extends Control

@onready var lblName = $UpgradeCard/LabelName
@onready var itemIcon = $UpgradeCard/ItemImage/Icon
@onready var cost = $UpgradeCard/Cost
@onready var status_container = $UpgradeCard/StatusContainer
@onready var upgrade_card: Control = $UpgradeCard
#@onready var ui : UI = get_tree().get_first_node_in_group("ui")

var weapon_node
var weapon_data
var cost_price : int
var upgradable := true
var curr_status = {}
var next_status = {}
var comb_status = {}
var mouse_over := false

signal upgrade_level(level)

# By default, weapons in upgrade cards are upgradable
func _ready():
	if upgrade_card:
		CursorManager.register_control_rule(upgrade_card, Callable(self, "_cursor_can_click"))
	_connect_gold_signal()
	if weapon_node != null:
		connect("upgrade_level",Callable(weapon_node,"set_level"))
		cost_price = _get_upgrade_cost(weapon_node)
		cost.text = LocalizationManager.tr_format("ui.upgrade.cost", {"value": cost_price}, "Cost: %s" % cost_price)
		comb_status = combine_status(weapon_node)
		for key in comb_status:
			var status_label = Label.new()
			status_label.text = LocalizationManager.tr_format(
				"ui.upgrade.status_line",
				{"key": key, "from": comb_status[key][0], "to": comb_status[key][1]},
				"%s: %s => %s" % [key, comb_status[key][0], comb_status[key][1]]
			)
			status_container.add_child(status_label)
		itemIcon.texture = weapon_node.sprite.texture
		lblName.text = LocalizationManager.get_weapon_instance_display_name(weapon_node)
	refresh_affordability()

func _exit_tree() -> void:
	if upgrade_card:
		CursorManager.unregister_control_rule(upgrade_card)
	_disconnect_gold_signal()

func refresh_affordability(_value: int = 0) -> void:
	if PlayerData.player_gold < cost_price: # Unable to purchase if player does not have enough gold
		cost.set("theme_override_colors/font_color",Color(1.0,0.0,0.0,1.0))
		upgradable = false
	else:
		cost.set("theme_override_colors/font_color",Color(1.0,1.0,1.0,1.0))
		upgradable = true

func _connect_gold_signal() -> void:
	var callback := Callable(self, "refresh_affordability")
	if not PlayerData.player_gold_changed.is_connected(callback):
		PlayerData.player_gold_changed.connect(callback)

func _disconnect_gold_signal() -> void:
	var callback := Callable(self, "refresh_affordability")
	if PlayerData.player_gold_changed.is_connected(callback):
		PlayerData.player_gold_changed.disconnect(callback)
		

		
func _input(_event):
	if Input.is_action_just_released("CLICK"):
		if mouse_over and upgradable:
			if not PlayerData.spend_gold(cost_price):
				return
			upgrade_level.emit(int(weapon_node.level) + 1)
			var ui = GlobalVariables.ui
			if ui:
				ui._init_rest_area_ui_controller()
				ui.rest_area_ui_controller.upgrade_panel_out()

func combine_status(node):
	weapon_data = node.weapon_data
	curr_status = node.get_weapon_level_data(node.level, weapon_data)
	next_status = node.get_weapon_level_data(node.level + 1, weapon_data)
	var combined_output = {}
	# Combine array that stores both current and next status {"k":[v_curr,v_next],...}
	for key in curr_status:
		if key in next_status:
			combined_output[key] = [curr_status[key],next_status[key]]
		else:
			combined_output[key] = [curr_status[key], null]
	for key in next_status:
		if key not in curr_status:
			combined_output[key] = [null, next_status[key]]
	return combined_output


func _on_upgrade_card_mouse_entered():
	mouse_over = true


func _on_upgrade_card_mouse_exited():
	mouse_over = false

func _cursor_can_click() -> bool:
	return weapon_node != null and is_instance_valid(weapon_node) and upgradable

func _get_upgrade_cost(weapon: Weapon) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 1
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return 1
	if GlobalVariables.economy_data == null:
		return maxi(1, int(round(float(weapon_def.price) * 0.5)))
	return GlobalVariables.economy_data.get_weapon_upgrade_gold(int(weapon_def.price))
