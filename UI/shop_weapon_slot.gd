extends MarginContainer
class_name ShopWeaponSlot

# Properties
@onready var background: ColorRect = $Background
@onready var image: TextureRect = $Background/Image
@onready var equip_name: Label = $Background/EquipName
@onready var price_label = $Background/Socket1
@onready var socket_2: Label = $Background/Socket2
@onready var lbl_description: Label = $Background/Socket3
@export var inventory_index : int = 0
@onready var equipped: GridContainer = $"../../Equipped"

var item
var item_id = null
var purchasable := true
var price : int


# Border properties
@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

# UI and player data
@onready var ui : UI = get_tree().get_first_node_in_group("ui")
@onready var player = get_tree().get_first_node_in_group("player")

signal select_weapon(item_id)
var hover_over : bool = false

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
	else:
		width = 0
	draw_rect(rect, border_color, false, width)

func update() -> void:
	queue_redraw()

# When player clicks on card, a weapon will be CREATED for player.
func _ready():
	if not item_id:
		new_item()

func empty_item() -> void:
	item = null
	item_id = null
	equip_name.text = "Sold"
	image.texture = null
	lbl_description.text = ""
	price_label.text = ""
	price = 0
	update()

func new_item() -> void:
	if not self.is_connected("select_weapon",Callable(player,"create_weapon")):
		connect("select_weapon",Callable(player,"create_weapon"))
	item_id = var_to_str(randi_range(1,10))
	equip_name.text = WeaponData.weapon_list.data[item_id]["name"]
	image.texture = load(WeaponData.weapon_list.data[item_id]["img"])
	lbl_description.text = WeaponData.weapon_list.data[item_id]["description"]
	price_label.text = WeaponData.weapon_list.data[item_id]["price"]
	price = int(WeaponData.weapon_list.data[item_id]["price"])
	

func _physics_process(_delta) -> void:
	if PlayerData.player_gold < price: # Unable to purchase if player does not have enough gold
		price_label.set("theme_override_colors/font_color",Color(1.0,0.0,0.0,1.0))
		purchasable = false
	else:
		price_label.set("theme_override_colors/font_color",Color(1.0,1.0,1.0,1.0))
		purchasable = true

func _on_color_rect_mouse_entered() -> void:
	hover_over = true
	update()

func _on_color_rect_mouse_exited() -> void:
	hover_over = false
	update()

func _on_background_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK") and item_id != null and purchasable :
		PlayerData.player_gold -= price
		select_weapon.emit(item_id)
		for eq : EquipmentSlotShop in equipped.get_children():
			eq.reset_sell_status()
		#ui.shopping_panel_out()
		self.empty_item()
