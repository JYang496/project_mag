extends CanvasLayer
class_name UI

@onready var player = get_tree().get_first_node_in_group("player")

# Roots
@onready var character_root : Control = $GUI/CharacterRoot
@onready var shopping_root : Control = $GUI/ShoppingRoot
@onready var upgrade_root : Control = $GUI/UpgradeRoot
@onready var boss_root : Control = $GUI/BossRoot
@onready var inventory_root: Control = $GUI/InventoryRoot
@onready var pause_menu_root : Control = $GUI/PauseMenuRoot
@onready var module_root: Control = $GUI/ModuleRoot


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
@onready var shopping_panel = $GUI/ShoppingRoot/ShoppingPanel
@onready var shopping_options = $GUI/ShoppingRoot/ShoppingPanel/ShoppingOptions

# Upgrade
@onready var upgrade_panel = $GUI/UpgradeRoot/UpgradePanel
@onready var upgrade_options = $GUI/UpgradeRoot/UpgradePanel/UpgradeOptions

# Inventory
@onready var inventory: VBoxContainer = $GUI/InventoryRoot/Panel/Inventory
@onready var equipped: GridContainer = $GUI/InventoryRoot/Panel/Equipped
@onready var equipped_m: GridContainer = $GUI/ModuleRoot/Panel/EquippedM
@onready var modules: GridContainer = $GUI/ModuleRoot/Panel/Modules

# Pause menu
@onready var resume_button = $GUI/PauseMenuRoot/PauseMenuPanel/ResumeButton

# Misc
@onready var move_out_timer = $GUI/MoveOutTimer
@onready var weapon_list = WeaponData.weapon_list
@onready var upgradable_weapon_list = PlayerData.player_weapon_list
@onready var item_card = preload("res://UI/margin_item_card.tscn")
@onready var upgrade_card = preload("res://UI/margin_upgrade_card.tscn")
@onready var empty_weapon_pic = preload("res://Textures/test/empty_wp.png")
@onready var equipped_weapons = null
@onready var drag_item_icon: TextureRect = $GUI/DragItemRoot/DragItemIcon


func _ready():
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
	for weapon_index in weapon_icons.get_child_count():
		if weapon_index < PlayerData.player_weapon_list.size():
			weapon_icons.get_child(weapon_index).texture = PlayerData.player_weapon_list[weapon_index].sprite.texture
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
	if shopping_root == null:
		return
	move_out_timer.stop()
	shopping_root.visible = true
	var options = 0
	var optionsmax = 4
	free_childern(shopping_options)
	while options < optionsmax:
		var option_choice = item_card.instantiate()
		shopping_options.add_child(option_choice)
		options += 1


func shopping_panel_out() -> void:
	shopping_root.visible = false
	refresh_border()
	move_out_timer.start()

func upgrade_panel_in() -> void:
	upgradable_weapon_list = PlayerData.player_weapon_list.duplicate()
	
	# Remove MAX level weapon from the list
	var pointer = 0
	while pointer < len(upgradable_weapon_list):
		var weapon = upgradable_weapon_list[pointer]
		if weapon.level >= len(weapon.weapon_data):
			upgradable_weapon_list.remove_at(pointer)
		else:
			pointer += 1

	var weapon_counts = len(upgradable_weapon_list)
	move_out_timer.stop()
	upgrade_root.visible = true
	var options = 0
	var optionsmax = 4
	free_childern(upgrade_options)
	while options < optionsmax and options < weapon_counts:
		var rand_index = randi_range(0,len(upgradable_weapon_list)-1)
		var random_weapon = upgradable_weapon_list.pop_at(rand_index)
		var upgrade_choice = upgrade_card.instantiate()
		upgrade_choice.weapon_node = random_weapon
		upgrade_options.add_child(upgrade_choice)
		options += 1

func upgrade_panel_out() -> void:
	upgrade_root.visible = false
	refresh_border()
	move_out_timer.start()

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
	for eq in equipped.get_children():
		eq.update()
	for inv in inventory.get_children():
		inv.update()

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
