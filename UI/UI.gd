extends CanvasLayer

@onready var player = get_tree().get_first_node_in_group("player")

# Roots
@onready var character_root = $GUI/CharacterRoot
@onready var shopping_root = $GUI/ShoppingRoot
@onready var upgrade_root = $GUI/UpgradeRoot
@onready var boss_root = $GUI/BossRoot

# Character
@onready var equipped_label = $GUI/CharacterRoot/Equipped
@onready var weapon_icons = $GUI/CharacterRoot/WeaponIcons
@onready var augments_label = $GUI/CharacterRoot/Augments
@onready var hp_label_label = $GUI/CharacterRoot/Hp
@onready var gold_label = $GUI/CharacterRoot/Gold
@onready var resource_label = $GUI/CharacterRoot/Resource
@onready var time_label = $GUI/CharacterRoot/Time


# Shopping
@onready var shopping_panel = $GUI/ShoppingRoot/ShoppingPanel
@onready var shopping_options = $GUI/ShoppingRoot/ShoppingPanel/ShoppingOptions

# Upgrade
@onready var upgrade_panel = $GUI/UpgradeRoot/UpgradePanel
@onready var upgrade_options = $GUI/UpgradeRoot/UpgradePanel/UpgradeOptions

# Misc
@onready var move_out_timer = $GUI/MoveOutTimer
@onready var weapon_list = WeaponData.weapon_list
@onready var upgradable_weapon_list = PlayerData.player_weapon_list
@onready var item_card = preload("res://UI/margin_item_card.tscn")
@onready var upgrade_card = preload("res://UI/margin_upgrade_card.tscn")
@onready var equipped_weapons = null


func _ready():
	pass


func _physics_process(_delta):
	#Character
	equipped_weapons = player.getEquippedWeapons()
	hp_label_label.text = "HP: " + str(PlayerData.player_hp)
	equipped_label.text = "Equipped:"
	augments_label.text = str(PlayerData.player_augment_list)
	gold_label.text = "Gold: " + str(PlayerData.player_gold)
	time_label.text = "Time: " + str(PhaseManager.battle_time)
	for weapon_index in PlayerData.player_weapon_list.size():
		weapon_icons.get_child(weapon_index).texture = PlayerData.player_weapon_list[weapon_index].sprite.texture


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

func free_childern(parent) -> void:
	var children = parent.get_children()
	for i in children:
		i.queue_free()

func _on_move_out_timer_timeout():
	# Would be useful when animation is applied
	pass # Replace with function body.
