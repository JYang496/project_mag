extends Button

@onready var shop: VBoxContainer = $"../Shop"
var module_shop: VBoxContainer
var starting_cost: int = 2
var cost: int = 2
var step_cost: int = 2
var max_cost: int = 99999

func _ready() -> void:
	_reload_refresh_settings()
	cost = starting_cost
	refresh_button_label()

func _on_button_up() -> void:
	if PlayerData.player_gold >= cost:
		PlayerData.player_gold -= cost
		cost = _compute_next_refresh_cost(cost)
		refresh_shop_items()
		refresh_button_label()


func _on_ui_reset_cost() -> void:
	_reload_refresh_settings()
	cost = starting_cost
	refresh_button_label()

func refresh_shop_items() -> void:
	for slot: ShopWeaponSlot in shop.get_children():
		slot.new_item()
		slot.update()
	if module_shop == null:
		module_shop = get_node_or_null("../ModuleShop") as VBoxContainer
	if module_shop == null:
		module_shop = get_node_or_null("../ModuleShopScroll/ModuleShop") as VBoxContainer
	if module_shop:
		for child in module_shop.get_children():
			if child.has_method("new_item"):
				child.call("new_item")
			if child.has_method("update"):
				child.call("update")

func _reload_refresh_settings() -> void:
	if GlobalVariables.economy_data == null:
		starting_cost = 2
		step_cost = 2
		max_cost = 99999
		return
	starting_cost = max(1, int(GlobalVariables.economy_data.shop_refresh_start_cost))
	step_cost = max(0, int(GlobalVariables.economy_data.shop_refresh_step))
	max_cost = max(starting_cost, int(GlobalVariables.economy_data.shop_refresh_cost_cap))

func _compute_next_refresh_cost(current_cost: int) -> int:
	var next_cost: int = current_cost + step_cost
	return mini(next_cost, max_cost)

func refresh_button_label() -> void:
	text = LocalizationManager.tr_format(
		"ui.panel.refresh_cost",
		{"value": cost},
		"Refresh: %s" % cost
	)
