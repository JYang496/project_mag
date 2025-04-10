extends MarginContainer

@onready var lblName = $UpgradeCard/LabelName
@onready var itemIcon: TextureRect = $UpgradeCard/Icon
@onready var cost = $UpgradeCard/Cost
@onready var status_container = $UpgradeCard/StatusContainer
@onready var ui : UI = get_tree().get_first_node_in_group("ui")

var weapon_node : Weapon
var cost_price : int
var upgradable := true
var curr_status = {}
var next_status = {}
var comb_status = {}

var hover_over : bool = false

# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var hover_over_color: Color = Color(1,1,0)
var hover_off_color: Color = Color(0,0,0,0)
var hover_over_width : float = 4.0
var hover_off_width : float = 0

signal upgrade_level(level)


func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
		border_color = hover_over_color
	else:
		width = hover_off_width
		border_color = hover_off_color
	draw_rect(rect, border_color, false, width)

func update() -> void:
	weapon_node = InventoryData.on_select_upg
	if self.is_connected("upgrade_level",Callable(weapon_node,"set_level")):
		self.disconnect("upgrade_level",Callable(weapon_node,"set_level"))
	for stats in status_container.get_children():
		stats.queue_free()
	if weapon_node != null and weapon_node.level < weapon_node.max_level:
		connect("upgrade_level",Callable(weapon_node,"set_level"))
		comb_status = combine_status(weapon_node)
		itemIcon.texture = weapon_node.get_node("Sprite").texture
		lblName.text = weapon_node.ITEM_NAME
		for key in comb_status:
			if key == "cost":
				cost_price = int(comb_status[key][1])
				cost.text = "Cost: %s" % comb_status[key][1]
			else:
				var status_label = Label.new()
				status_label.text = "%s: %s => %s" % [key, comb_status[key][0], comb_status[key][1]]
				status_container.add_child(status_label)
	else:
		weapon_node = null
		cost.text = ""
		lblName.text = ""
		itemIcon.texture = null
	if PlayerData.player_gold < cost_price: # Unable to purchase if player does not have enough gold
		cost.set("theme_override_colors/font_color",Color(1.0,0.0,0.0,1.0))
		upgradable = false
	else:
		cost.set("theme_override_colors/font_color",Color(1.0,1.0,1.0,1.0))
		upgradable = true
	queue_redraw()

func _input(_event):
	if Input.is_action_just_released("CLICK") and weapon_node:
		if hover_over and upgradable:
			PlayerData.player_gold -= cost_price
			upgrade_level.emit(int(comb_status["level"][1]))
			ui.update_upg()

func combine_status(node):
	var weapon_data = node.weapon_data
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
	hover_over = true
	update()


func _on_upgrade_card_mouse_exited():
	hover_over = false
	update()
