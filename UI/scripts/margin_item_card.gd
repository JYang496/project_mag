extends Control

@onready var lbl_name = $ItemCard/LabelName
@onready var lbl_description = $ItemCard/Description
@onready var item_icon = $ItemCard/ItemImage/Icon
@onready var price_label = $ItemCard/Price

var mouse_over = false
var item_id = null
var purchasable := true
var price : int

#@onready var player = get_tree().get_first_node_in_group("player")
#@onready var ui = get_tree().get_first_node_in_group("ui")

signal select_weapon(item_id)

func _physics_process(_delta) -> void:
	if PlayerData.player_gold < price: # Unable to purchase if player does not have enough gold
		price_label.set("theme_override_colors/font_color",Color(1.0,0.0,0.0,1.0))
		purchasable = false
	else:
		price_label.set("theme_override_colors/font_color",Color(1.0,1.0,1.0,1.0))
		purchasable = true


# When player clicks on card, a weapon will be CREATED for player.
func _ready():
	connect("select_weapon",Callable(PlayerData.player,"create_weapon"))
	if item_id == null:
		item_id = var_to_str(randi_range(1,10))
	lbl_name.text = DataHandler.weapon_list.data[item_id]["name"]
	item_icon.texture = load(DataHandler.weapon_list.data[item_id]["img"])
	lbl_description.text = DataHandler.weapon_list.data[item_id]["description"]
	price_label.text = DataHandler.weapon_list.data[item_id]["price"]
	price = int(DataHandler.weapon_list.data[item_id]["price"])

func _input(_event):
	if Input.is_action_just_released("CLICK"):
		if mouse_over and purchasable and PlayerData.player_gold >= price:
			PlayerData.player_gold -= price
			#emit_signal("select_weapon",item_id)
			select_weapon.emit(item_id)
			GlobalVariables.ui.shopping_panel_out()


func _on_item_card_mouse_entered():
	mouse_over = true


func _on_item_card_mouse_exited():
	mouse_over = false
