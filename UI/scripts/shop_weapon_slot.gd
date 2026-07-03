extends MarginContainer
class_name ShopWeaponSlot

const RARITY_UTIL := preload("res://data/LootRarity.gd")
# Properties
@onready var background: ColorRect = $Background
@onready var image: TextureRect = $Background/Image
@onready var equip_name: Label = $Background/EquipName
@onready var price_label = $Background/Socket1
@onready var socket_2: Label = $Background/Socket2
@onready var lbl_description: Label = $Background/Socket3
@export var inventory_index : int = 0

var item
var item_id = null
var purchasable := true
var price : int


# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

# UI and player data
#@onready var ui : UI = get_tree().get_first_node_in_group("ui")
#@onready var player = get_tree().get_first_node_in_group("player")

signal select_weapon(item_id)
var hover_over : bool = false
var selected := false

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if selected:
		draw_rect(rect, Color(1.0, 0.78, 0.22, 0.14), true)
	if hover_over:
		width = border_width
		border_color = Color(0.95, 0.98, 1.0, 1.0)
	elif selected:
		width = border_width + 1.0
		border_color = Color(1.0, 0.78, 0.22, 1.0)
	elif item_id != null:
		width = 2.0
		border_color = _get_weapon_definition_rarity_color()
	else:
		width = 0
	draw_rect(rect, border_color, false, width)
	if selected:
		draw_rect(rect.grow(-4.0), Color(1.0, 0.92, 0.45, 0.65), false, 1.0)

func update() -> void:
	queue_redraw()

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

# When player clicks on card, a weapon will be CREATED for player.
func _ready():
	if background:
		CursorManager.register_control_rule(background, Callable(self, "_cursor_can_click"))
	_connect_gold_signal()
	if not item_id and PlayerData.player != null:
		new_item()
	else:
		refresh_affordability()

func _exit_tree() -> void:
	if background:
		CursorManager.unregister_control_rule(background)
	_disconnect_gold_signal()

func empty_item() -> void:
	_notify_shop_clear()
	set_selected(false)
	item = null
	item_id = null
	equip_name.text = LocalizationManager.tr_key("ui.module.sold", "Sold")
	image.texture = null
	lbl_description.text = ""
	price_label.text = ""
	price = 0
	refresh_affordability()
	update()

func new_item() -> void:
	_notify_shop_clear()
	set_selected(false)
	if not self.is_connected("select_weapon",Callable(PlayerData.player,"create_weapon")):
		connect("select_weapon",Callable(PlayerData.player,"create_weapon"))
	var candidate_ids: Array[String] = DataHandler.get_weapon_ids()
	if PlayerData.player and is_instance_valid(PlayerData.player):
		candidate_ids = candidate_ids.filter(func(candidate_id: String) -> bool:
			var prediction: Dictionary = PlayerData.player.predict_auto_fuse_weapon_obtain(candidate_id)
			return str(prediction.get("result", "")) != "converted_to_gold"
		)
	if candidate_ids.is_empty():
		push_warning("ShopWeaponSlot has no valid weapon candidates.")
		empty_item()
		equip_name.text = LocalizationManager.tr_key(
			"ui.shop.no_valid_weapons",
			"No weapons available"
		)
		return
	item_id = candidate_ids.pick_random()
	var weapon_def = DataHandler.read_weapon_data(item_id)
	if weapon_def == null:
		push_warning("ShopWeaponSlot failed to load weapon id=%s" % item_id)
		empty_item()
		return
	var rarity: String = weapon_def.get_rarity()
	equip_name.text = LocalizationManager.get_weapon_name_from_definition(weapon_def)
	equip_name.set("theme_override_colors/font_color", RARITY_UTIL.get_color(rarity))
	image.texture = weapon_def.icon
	socket_2.text = LocalizationManager.get_weapon_description_from_definition(weapon_def)
	lbl_description.text = ""
	var base_price := int(weapon_def.price)
	var final_price := int(round(float(base_price) * _get_purchase_price_multiplier()))
	price = max(1, final_price)
	price_label.text = LocalizationManager.tr_format("ui.shop.weapon.price", {"value": price}, "Price: %s" % price)
	refresh_affordability()
	

func refresh_affordability(_value: int = 0) -> void:
	purchasable = item_id != null and PlayerData.player_gold >= price
	price_label.set(
		"theme_override_colors/font_color",
		Color(1.0, 1.0, 1.0, 1.0) if purchasable else Color(1.0, 0.0, 0.0, 1.0)
	)

func _connect_gold_signal() -> void:
	var callback := Callable(self, "refresh_affordability")
	if not PlayerData.player_gold_changed.is_connected(callback):
		PlayerData.player_gold_changed.connect(callback)

func _disconnect_gold_signal() -> void:
	var callback := Callable(self, "refresh_affordability")
	if PlayerData.player_gold_changed.is_connected(callback):
		PlayerData.player_gold_changed.disconnect(callback)

func _on_color_rect_mouse_entered() -> void:
	hover_over = true
	_notify_shop_hover()
	update()

func _on_color_rect_mouse_exited() -> void:
	hover_over = false
	_notify_shop_hover_clear()
	update()

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK") and item_id != null:
		_notify_shop_selected()

func can_purchase() -> bool:
	return item_id != null and purchasable

func try_purchase() -> bool:
	if item_id == null:
		return false
	if not purchasable:
		var active_ui := GlobalVariables.ui
		if active_ui and is_instance_valid(active_ui) and active_ui.has_method("show_item_message"):
			active_ui.show_item_message(LocalizationManager.tr_key("ui.shop.not_enough_gold", "Not enough gold."), 1.4)
		return false
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("is_branch_selection_blocking_interactions") and ui.is_branch_selection_blocking_interactions():
		ui.show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return false
	var outcome := {}
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("try_auto_fuse_weapon_obtain"):
		var prediction: Dictionary = PlayerData.player.predict_auto_fuse_weapon_obtain(str(item_id))
		if str(prediction.get("result", "not_applicable")) != "not_applicable":
			PlayerData.player_gold -= price
			outcome = PlayerData.player.try_auto_fuse_weapon_obtain(str(item_id))
		else:
			var weapon_def := DataHandler.read_weapon_data(str(item_id)) as WeaponDefinition
			var new_weapon: Weapon
			if weapon_def and weapon_def.scene:
				new_weapon = weapon_def.scene.instantiate() as Weapon
			if new_weapon == null:
				return false
			var opened := ui != null and ui.has_method("request_weapon_replacement") \
				and bool(ui.request_weapon_replacement(
					new_weapon,
					false,
					Callable(self, "_on_purchase_replacement_completed").bind(price)
				))
			if not opened:
				new_weapon.queue_free()
				return false
	if str(outcome.get("result", "not_applicable")) != "not_applicable":
		self.empty_item()
	return true

func _on_purchase_replacement_completed(accepted: bool, _result: Dictionary, purchase_price: int) -> void:
	if not accepted:
		return
	PlayerData.player_gold -= purchase_price
	empty_item()

func _get_purchase_price_multiplier() -> float:
	if GlobalVariables.economy_data == null:
		return 1.0
	return maxf(0.01, float(GlobalVariables.economy_data.weapon_purchase_price_multiplier))

func _cursor_can_click() -> bool:
	return item_id != null

func _get_weapon_definition_rarity_color() -> Color:
	var weapon_def := DataHandler.read_weapon_data(str(item_id)) as WeaponDefinition
	if weapon_def == null:
		return RARITY_UTIL.get_color(RARITY_UTIL.COMMON)
	return RARITY_UTIL.get_color(weapon_def.get_rarity())

func _build_shop_item_data() -> Dictionary:
	if item_id == null:
		return {}
	var weapon_def := DataHandler.read_weapon_data(str(item_id)) as WeaponDefinition
	if weapon_def == null:
		return {}
	var rarity := weapon_def.get_rarity()
	return {
		"type": "weapon",
		"id": str(item_id),
		"name": LocalizationManager.get_weapon_name_from_definition(weapon_def),
		"description": LocalizationManager.get_weapon_description_from_definition(weapon_def),
		"price": price,
		"definition": weapon_def,
		"slot": self,
		"rarity": rarity,
		"rarity_color": RARITY_UTIL.get_color(rarity),
	}

func _notify_shop_hover() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		ui.purchase_management_controller.set_hover_item(_build_shop_item_data())

func _notify_shop_hover_clear() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		ui.purchase_management_controller.clear_hover_item(_build_shop_item_data())

func _notify_shop_selected() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		ui.purchase_management_controller.set_selected_item(_build_shop_item_data())
		ui.purchase_management_controller.mark_purchase_action_dirty()

func _notify_shop_clear() -> void:
	var ui := GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.purchase_management_controller:
		var data := _build_shop_item_data()
		ui.purchase_management_controller.clear_hover_item(data)
		ui.purchase_management_controller.clear_selected_item(data)
		ui.purchase_management_controller.mark_purchase_action_dirty()
