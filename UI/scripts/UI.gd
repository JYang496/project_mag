extends CanvasLayer
class_name UI

const PANEL_TARGET_SIZE := Vector2(1000, 600)
const PANEL_MARGIN := Vector2(24, 24)
const PAUSE_PANEL_TARGET_SIZE := Vector2(400, 600)
const HUD_MARGIN := 16.0

#@onready var player : Player = get_tree().get_first_node_in_group("player")

# Roots
@onready var gui_root: Control = $GUI
@onready var character_root : Control = $GUI/CharacterRoot
@onready var shopping_rootv_2: Control = $GUI/ShoppingRootv2
@onready var upgrade_rootv_2: Control = $GUI/UpgradeRootv2
@onready var boss_root : Control = $GUI/BossRoot
@onready var inventory_root: Control = $GUI/InventoryRoot
@onready var pause_menu_root : Control = $GUI/PauseMenuRoot
@onready var module_root: Control = $GUI/ModuleRoot
@onready var gear_fuse_root: Control = $GUI/GearFuseRoot
@onready var shopping_panel: Panel = $GUI/ShoppingRootv2/Panel
@onready var upgrade_panel: Panel = $GUI/UpgradeRootv2/Panel
@onready var gear_fuse_panel: Panel = $GUI/GearFuseRoot/Panel
@onready var module_panel: Panel = $GUI/ModuleRoot/Panel
@onready var inventory_panel: Panel = $GUI/InventoryRoot/Panel
@onready var pause_menu_panel: Panel = $GUI/PauseMenuRoot/PauseMenuPanel
var game_over_root: Control
var game_over_status_label: Label
var game_over_coin_label: Label
var game_over_chip_label: Label


# Character
@onready var equipped_label = $GUI/CharacterRoot/Equipped
@onready var weapon_icons = $GUI/CharacterRoot/WeaponIcons
@onready var augments_label = $GUI/CharacterRoot/Augments
@onready var hp_label_label = $GUI/CharacterRoot/Hp
@onready var gold_label = $GUI/CharacterRoot/Gold
@onready var resource_label = $GUI/CharacterRoot/Resource
@onready var time_label = $GUI/CharacterRoot/Time
@onready var phase_label = $GUI/CharacterRoot/Phase


# Shopping
@onready var shop: VBoxContainer = $GUI/ShoppingRootv2/Panel/Shop
@onready var equipped_shop: GridContainer = $GUI/ShoppingRootv2/Panel/Equipped
@onready var shop_sell_button: Button = $GUI/ShoppingRootv2/Panel/ShopSellButton
@onready var shop_cancel_button: Button = $GUI/ShoppingRootv2/Panel/ShopCancelButton
signal reset_cost

# Upgrade
@onready var inventory_upg: GridContainer = $GUI/UpgradeRootv2/Panel/Inventory
@onready var equipped_upg: GridContainer = $GUI/UpgradeRootv2/Panel/Equipped
@onready var upgrade_preview: MarginContainer = $GUI/UpgradeRootv2/Panel/UpgradePreview


# Gear fuse
@onready var inventory_gf: GridContainer = $GUI/GearFuseRoot/Panel/Inventory
@onready var equipped_gf: GridContainer = $GUI/GearFuseRoot/Panel/Equipped
@onready var fuse_items: HBoxContainer = $GUI/GearFuseRoot/Panel/MarginContainer/VBoxContainer/ItemRow/Items


# Inventory
@onready var inventory: GridContainer = $GUI/InventoryRoot/Panel/Inventory
@onready var equipped_inv: GridContainer = $GUI/InventoryRoot/Panel/Equipped
@onready var equipped_m: GridContainer = $GUI/ModuleRoot/Panel/EquippedM
@onready var modules: GridContainer = $GUI/ModuleRoot/Panel/Modules

# Pause menu
@onready var resume_button = $GUI/PauseMenuRoot/PauseMenuPanel/ResumeButton

# Misc
@onready var move_out_timer = $GUI/MoveOutTimer
@onready var weapon_list = GlobalVariables.weapon_list
@onready var upgradable_weapon_list = PlayerData.player_weapon_list
@onready var item_card = preload("res://UI/scenes/margin_item_card.tscn")
@onready var upgrade_card = preload("res://UI/scenes/margin_upgrade_card.tscn")
@onready var empty_weapon_pic = preload("res://Textures/test/empty_wp.png")
@onready var equipped_weapons = null
@onready var drag_item_icon: TextureRect = $GUI/DragItemRoot/DragItemIcon


func _ready():
	GlobalVariables.ui = self
	_create_game_over_layout()
	_connect_viewport_signals()
	_apply_responsive_layout()
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	refresh_border()


func _physics_process(_delta):
	#Character
	hp_label_label.text = "HP: " + str(PlayerData.player_hp)
	equipped_label.text = "Equipped:"
	augments_label.text = str(PlayerData.player_augment_list)
	gold_label.text = "Gold: " + str(PlayerData.player_gold)
	time_label.text = "Time: " + str(PhaseManager.battle_time)
	phase_label.text = "Phase: " + str(PhaseManager.current_state())
	drag_item_icon.set_position(get_viewport().get_mouse_position())
func _input(_event) -> void:
	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		return
	
	# Pause / Menu
	if Input.is_action_just_pressed("ESC"):
		if get_tree().paused:
			# Unpause and hide UI
			get_tree().paused = false
			pause_menu_root.visible = false
		else:
			# Pause and show UI
			get_tree().paused = true
			pause_menu_root.visible = true
	
	# Switch weapon
	if Input.is_action_just_pressed("SWITCH_LEFT") and PlayerData.overcharge_enable and not (PlayerData.is_overcharged or PlayerData.is_overcharging):
		PlayerData.on_select_weapon -= 1
		refresh_border()
	if Input.is_action_just_pressed("SWITCH_RIGHT") and PlayerData.overcharge_enable and not (PlayerData.is_overcharged or PlayerData.is_overcharging):
		PlayerData.on_select_weapon += 1
		refresh_border()
		
func refresh_border() -> void:
	var valid_weapons: Array = []
	for weapon in PlayerData.player_weapon_list:
		if is_instance_valid(weapon):
			valid_weapons.append(weapon)
	PlayerData.player_weapon_list = valid_weapons

	for weapon_index in weapon_icons.get_child_count():
		if weapon_index < PlayerData.player_weapon_list.size():
			var weapon = PlayerData.player_weapon_list[weapon_index]
			if is_instance_valid(weapon) and weapon.has_node("Sprite"):
				weapon_icons.get_child(weapon_index).texture = weapon.get_node("Sprite").texture
			else:
				weapon_icons.get_child(weapon_index).texture = empty_weapon_pic
		else:
			weapon_icons.get_child(weapon_index).texture = empty_weapon_pic
	for i in weapon_icons.get_child_count():
		var icon = weapon_icons.get_child(i)
		if i == PlayerData.on_select_weapon:
			icon.display = true
		else:
			icon.display = false
		icon.update()

func shopping_panel_in() -> void:
	if shopping_rootv_2 == null:
		return
	move_out_timer.stop()
	shop_cancel_button._on_button_up()
	update_shop()
	shopping_rootv_2.visible = true

func shopping_panel_out() -> void:
	shopping_rootv_2.visible = false
	InventoryData.clear_on_select()
	refresh_border()
	move_out_timer.start()

func reset_shopping_refresh_cost() -> void:
	reset_cost.emit()

#func upgrade_panel_in() -> void:
	#upgradable_weapon_list = PlayerData.player_weapon_list.duplicate()
	#
	## Remove MAX level weapon from the list
	#var pointer = 0
	#while pointer < len(upgradable_weapon_list):
		#var weapon = upgradable_weapon_list[pointer]
		#if weapon.level >= len(weapon.weapon_data):
			#upgradable_weapon_list.remove_at(pointer)
		#else:
			#pointer += 1
#
	#var weapon_counts = len(upgradable_weapon_list)
	#move_out_timer.stop()
	#upgrade_root.visible = true
	#var options = 0
	#var optionsmax = 4
	#free_childern(upgrade_options)
	#while options < optionsmax and options < weapon_counts:
		#var rand_index = randi_range(0,len(upgradable_weapon_list)-1)
		#var random_weapon = upgradable_weapon_list.pop_at(rand_index)
		#var upgrade_choice = upgrade_card.instantiate()
		#upgrade_choice.weapon_node = random_weapon
		#upgrade_options.add_child(upgrade_choice)
		#options += 1
#
#func upgrade_panel_out() -> void:
	#upgrade_root.visible = false
	#refresh_border()
	#move_out_timer.start()

func upg_panel_in() -> void:
	update_upg()
	upgrade_rootv_2.visible = true
	inventory_upg.visible = false
	equipped_upg.visible = true

func upg_panel_out() -> void:
	upgrade_rootv_2.visible = false
	InventoryData.clear_on_select()
	refresh_border()

func gf_panel_in() -> void:
	update_gf()
	gear_fuse_root.visible = true
	inventory_gf.visible = false
	equipped_gf.visible = true

func gf_panel_out() -> void:
	InventoryData.ready_to_fuse_list.clear()
	gear_fuse_root.visible = false

func inventory_panel_in() -> void:
	move_out_timer.stop()
	update_inventory()
	inventory_root.visible = true

func inventory_panel_out() -> void:
	InventoryData.clear_on_select()
	move_out_timer.start()
	inventory_root.visible = false

func module_panel_in() -> void:
	update_modules()
	module_root.visible = true

func module_panel_out() -> void:
	module_root.visible = false

func inv_mod_panel_out() -> void:
	inventory_panel_out()
	module_panel_out()
	
func update_inventory() -> void:
	for eq in equipped_inv.get_children():
		eq.update()
	for inv in inventory.get_children():
		inv.update()

func update_shop() -> void:
	for eq in equipped_shop.get_children():
		eq.update()
	for sh in shop.get_children():
		sh.update()

func update_upg() -> void:
	for eq in equipped_upg.get_children():
		eq.update()
	for inv in inventory_upg.get_children():
		inv.update()
	upgrade_preview.update()
func update_gf() -> void:
	for eq in equipped_gf.get_children():
		eq.update()
	for inv in inventory_gf.get_children():
		inv.update()
	for item in fuse_items.get_children():
		item.update()

func update_modules() -> void:
	for eq in equipped_m.get_children():
		eq.update()
	for mod in modules.get_children():
		mod.update()

func free_childern(parent) -> void:
	var children = parent.get_children()
	for child in children:
		child.queue_free()

func _on_move_out_timer_timeout():
	# Would be useful when animation is applied
	#PlayerData.is_interacting = false
	pass # Replace with function body.


func _on_resume_button_pressed() -> void:
	if get_tree().paused:
		# Unpause and hide UI
		get_tree().paused = false
		pause_menu_root.visible = false


func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		_show_game_over()


func _show_game_over() -> void:
	if game_over_root == null:
		return
	pause_menu_root.visible = false
	shopping_rootv_2.visible = false
	upgrade_rootv_2.visible = false
	inventory_root.visible = false
	module_root.visible = false
	gear_fuse_root.visible = false
	game_over_status_label.text = "Status  HP: %s/%s  Level: %s  EXP: %s" % [
		str(PlayerData.player_hp),
		str(PlayerData.player_max_hp),
		str(PlayerData.player_level),
		str(PlayerData.player_exp)
	]
	game_over_coin_label.text = "Coin Collected: %s" % str(PlayerData.round_coin_collected)
	game_over_chip_label.text = "Chip Collected: %s" % str(PlayerData.round_chip_collected)
	game_over_root.visible = true
	get_tree().paused = true


func _create_game_over_layout() -> void:
	game_over_root = Control.new()
	game_over_root.name = "GameOverRoot"
	game_over_root.visible = false
	game_over_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	game_over_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	$GUI.add_child(game_over_root)

	var panel := Panel.new()
	panel.name = "GameOverPanel"
	panel.custom_minimum_size = Vector2(480, 320)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240
	panel.offset_top = -160
	panel.offset_right = 240
	panel.offset_bottom = 160
	game_over_root.add_child(panel)

	var title := Label.new()
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_left = 0
	title.offset_top = 24
	title.offset_right = 480
	title.offset_bottom = 56
	panel.add_child(title)

	game_over_status_label = Label.new()
	game_over_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_status_label.offset_left = 20
	game_over_status_label.offset_top = 92
	game_over_status_label.offset_right = 460
	game_over_status_label.offset_bottom = 124
	panel.add_child(game_over_status_label)

	game_over_coin_label = Label.new()
	game_over_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_coin_label.offset_left = 20
	game_over_coin_label.offset_top = 136
	game_over_coin_label.offset_right = 460
	game_over_coin_label.offset_bottom = 168
	panel.add_child(game_over_coin_label)

	game_over_chip_label = Label.new()
	game_over_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_chip_label.offset_left = 20
	game_over_chip_label.offset_top = 176
	game_over_chip_label.offset_right = 460
	game_over_chip_label.offset_bottom = 208
	panel.add_child(game_over_chip_label)

	var new_game_button := Button.new()
	new_game_button.text = "New Game"
	new_game_button.offset_left = 170
	new_game_button.offset_top = 250
	new_game_button.offset_right = 310
	new_game_button.offset_bottom = 286
	new_game_button.pressed.connect(_on_game_over_new_game_pressed)
	panel.add_child(new_game_button)


func _on_game_over_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://World/Start.tscn")


func _connect_viewport_signals() -> void:
	var viewport := get_viewport()
	if viewport and not viewport.is_connected("size_changed", Callable(self, "_on_viewport_size_changed")):
		viewport.connect("size_changed", Callable(self, "_on_viewport_size_changed"))

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_fit_center_panel(shopping_panel, viewport_size, PANEL_TARGET_SIZE)
	_fit_center_panel(upgrade_panel, viewport_size, PANEL_TARGET_SIZE)
	_fit_center_panel(gear_fuse_panel, viewport_size, PANEL_TARGET_SIZE)
	_fit_center_panel(module_panel, viewport_size, PANEL_TARGET_SIZE)
	_fit_center_panel(inventory_panel, viewport_size, PANEL_TARGET_SIZE)
	_fit_pause_layout(viewport_size)
	_layout_hud(viewport_size)

func _fit_center_panel(panel: Control, viewport_size: Vector2, target_size: Vector2) -> void:
	if panel == null:
		return
	var available_size: Vector2 = viewport_size - PANEL_MARGIN * 2.0
	var width: float = minf(target_size.x, available_size.x)
	var height: float = minf(target_size.y, available_size.y)
	panel.size = Vector2(maxf(width, 0.0), maxf(height, 0.0))
	panel.position = (viewport_size - panel.size) * 0.5

func _fit_pause_layout(viewport_size: Vector2) -> void:
	pause_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu_root.offset_left = 0
	pause_menu_root.offset_top = 0
	pause_menu_root.offset_right = 0
	pause_menu_root.offset_bottom = 0
	_fit_center_panel(pause_menu_panel, viewport_size, PAUSE_PANEL_TARGET_SIZE)

func _layout_hud(viewport_size: Vector2) -> void:
	equipped_label.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	weapon_icons.position = Vector2(HUD_MARGIN + 82.0, HUD_MARGIN + 6.0)
	hp_label_label.position = Vector2(HUD_MARGIN, viewport_size.y - 36.0)
	gold_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN)
	time_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN + 56.0)
	phase_label.position = Vector2(viewport_size.x - 220.0, HUD_MARGIN)
	resource_label.position = Vector2(viewport_size.x - 110.0, viewport_size.y - 54.0)
