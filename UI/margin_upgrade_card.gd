extends Control

@onready var lblName = $UpgradeCard/LabelName
@onready var itemIcon = $UpgradeCard/ItemImage/Icon
@onready var cost = $UpgradeCard/Cost
@onready var status_container = $UpgradeCard/StatusContainer
@onready var ui : UI = get_tree().get_first_node_in_group("ui")

var weapon_node
var weapon_data
var cost_price : int
var upgradable := true
var curr_status = {}
var next_status = {}
var comb_status = {}
var mouse_over := false

signal close_label()
signal upgrade_level(level)

# By default, weapons in upgrade cards are upgradable
func _ready():
	if weapon_node != null:
		connect("upgrade_level",Callable(weapon_node,"set_level"))
		comb_status = combine_status(weapon_node)
		for key in comb_status:
			if key == "cost":
				cost_price = int(comb_status[key][1])
				cost.text = "Cost: %s" % comb_status[key][1]
			else:
				var status_label = Label.new()
				status_label.text = "%s: %s => %s" % [key, comb_status[key][0], comb_status[key][1]]
				status_container.add_child(status_label)
		itemIcon.texture = weapon_node.sprite.texture
		lblName.text = weapon_node.ITEM_NAME
		

func _physics_process(delta: float) -> void:
	if PlayerData.player_gold < cost_price: # Unable to purchase if player does not have enough gold
		cost.set("theme_override_colors/font_color",Color(1.0,0.0,0.0,1.0))
		upgradable = false
	else:
		cost.set("theme_override_colors/font_color",Color(1.0,1.0,1.0,1.0))
		upgradable = true
		

		
func _input(_event):
	if Input.is_action_just_released("CLICK"):
		if mouse_over and upgradable:
			PlayerData.player_gold -= cost_price
			emit_signal("upgrade_level",int(comb_status["level"][1]))
			ui.upgrade_panel_out()

func combine_status(node):
	weapon_data = node.weapon_data
	curr_status = weapon_data[str(node.level)]
	next_status = weapon_data[str(node.level+1)]
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
