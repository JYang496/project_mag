extends MarginContainer

const RARITY_UTIL := preload("res://data/LootRarity.gd")

@onready var lblName = $UpgradeCard/LabelName
@onready var itemIcon: TextureRect = $UpgradeCard/Icon
@onready var cost = $UpgradeCard/Cost
@onready var status_container = $UpgradeCard/StatusContainer
@onready var upgrade_card: Control = $UpgradeCard
#@onready var ui : UI = get_tree().get_first_node_in_group("ui")

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

func _ready() -> void:
	if upgrade_card:
		CursorManager.register_control_rule(upgrade_card, Callable(self, "_cursor_can_click"))

func _exit_tree() -> void:
	if upgrade_card:
		CursorManager.unregister_control_rule(upgrade_card)

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
		border_color = hover_over_color
	elif weapon_node != null and is_instance_valid(weapon_node):
		width = 2.0
		border_color = RARITY_UTIL.get_color(_get_weapon_rarity(weapon_node))
	else:
		width = hover_off_width
		border_color = hover_off_color
	draw_rect(rect, border_color, false, width)

func update() -> void:
	weapon_node = InventoryData.on_select_upg
	cost_price = 0
	upgradable = false
	for connection in get_signal_connection_list("upgrade_level"):
		var callable: Callable = connection.get("callable", Callable())
		if callable.is_valid():
			disconnect("upgrade_level", callable)
	for stats in status_container.get_children():
		stats.queue_free()
	if weapon_node != null:
		comb_status = {}
		itemIcon.texture = weapon_node.get_node("Sprite").texture
		lblName.text = _build_weapon_header(weapon_node)
	if weapon_node != null and weapon_node.level < weapon_node.max_level:
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
	elif weapon_node != null:
		cost.text = _build_cap_reason(weapon_node)
		upgradable = false
	else:
		weapon_node = null
		cost.text = ""
		lblName.text = ""
		itemIcon.texture = null
	if weapon_node != null and is_instance_valid(weapon_node) and weapon_node.level < weapon_node.max_level and PlayerData.player_gold >= cost_price:
		cost.set("theme_override_colors/font_color",Color(1.0,1.0,1.0,1.0))
		upgradable = true
	elif weapon_node != null and is_instance_valid(weapon_node) and weapon_node.level < weapon_node.max_level:
		cost.set("theme_override_colors/font_color",Color(1.0,0.0,0.0,1.0))
		upgradable = false
	else:
		cost.set("theme_override_colors/font_color",Color(1.0,1.0,1.0,1.0))
	queue_redraw()

func _input(_event):
	if Input.is_action_just_released("CLICK") and weapon_node:
		if hover_over and upgradable:
			try_upgrade_selected_weapon()

func try_upgrade_selected_weapon() -> bool:
	if weapon_node == null or not is_instance_valid(weapon_node) or not upgradable:
		return false
	PlayerData.player_gold -= cost_price
	upgrade_level.emit(int(weapon_node.level) + 1)
	GlobalVariables.ui.update_upg()
	return true

func combine_status(node):
	var weapon_data = node.weapon_data
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
	hover_over = true
	update()


func _on_upgrade_card_mouse_exited():
	hover_over = false
	update()

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


func _cursor_can_click() -> bool:
	return hover_over and weapon_node != null and is_instance_valid(weapon_node) and upgradable

func _build_weapon_header(weapon: Weapon) -> String:
	var weapon_name := LocalizationManager.get_weapon_name_from_node(weapon)
	var rarity: String = _get_weapon_rarity(weapon)
	lblName.set("theme_override_colors/font_color", RARITY_UTIL.get_color(rarity))
	return "[%s] %s  Fuse %d  Lv.%d/%d" % [
		RARITY_UTIL.get_display_name(rarity),
		weapon_name,
		int(weapon.fuse),
		int(weapon.level),
		int(weapon.max_level),
	]

func _build_cap_reason(weapon: Weapon) -> String:
	return LocalizationManager.tr_key("ui.upgrade.fully_upgraded", "Fully upgraded.")

func _get_weapon_rarity(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return RARITY_UTIL.COMMON
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return RARITY_UTIL.COMMON
	return weapon_def.get_rarity()
