extends CanvasLayer
class_name UI

const PANEL_TARGET_SIZE := Vector2(1000, 600)
const PANEL_MARGIN := Vector2(24, 24)
const PAUSE_PANEL_TARGET_SIZE := Vector2(400, 600)
const HUD_MARGIN := 16.0
const HP_BAR_ANIM_TIME := 0.2
const HP_BAR_TRANS := Tween.TRANS_SINE
const HP_BAR_EASE := Tween.EASE_OUT

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
var quest_hint_label: Label
var item_message_timer: Timer


# Character
@onready var equipped_label = $GUI/CharacterRoot/Equipped
@onready var weapon_icons = $GUI/CharacterRoot/WeaponIcons
@onready var weapon_selector: WeaponSelector = $GUI/CharacterRoot/WeaponSelector
@onready var augments_label = $GUI/CharacterRoot/Augments
@onready var hp_label_label = $GUI/CharacterRoot/HpLabel
@onready var hp_label_text = $GUI/CharacterRoot/HpLabel/Hp
@onready var hp_bar: ProgressBar = $GUI/CharacterRoot/HpLabel/HpBar
@onready var gold_label = $GUI/CharacterRoot/Gold
@onready var resource_label = $GUI/CharacterRoot/Resource
@onready var time_label = $GUI/CharacterRoot/Time
@onready var phase_label = $GUI/CharacterRoot/Phase
var heat_label: Label
var ammo_label: Label
var weapon_state_label: Label
var _hp_bar_display_value: float = 0.0
var _hp_bar_tween: Tween


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
@onready var branch_select_panel_scene = preload("res://UI/scenes/branch_select_panel.tscn")
@onready var module_equip_selection_panel_scene = preload("res://UI/scenes/module_equip_selection_panel.tscn")
@onready var route_selection_panel_scene = preload("res://UI/scenes/route_selection_panel.tscn")
@onready var reward_selection_panel_scene = preload("res://UI/scenes/reward_selection_panel.tscn")
var branch_select_panel: BranchSelectPanel
var module_equip_selection_panel: ModuleEquipSelectionPanel
var route_selection_panel: RouteSelectionPanel
var reward_selection_panel: RewardSelectionPanel


func _ready():
	GlobalVariables.ui = self
	_init_hp_bar()
	_refresh_hp_hud()
	_ensure_heat_label()
	_ensure_ammo_label()
	_ensure_weapon_state_label()
	_init_branch_select_panel()
	_init_module_equip_selection_panel()
	_init_route_selection_panel()
	_init_reward_selection_panel()
	_create_game_over_layout()
	_create_quest_hint()
	_connect_viewport_signals()
	_apply_responsive_layout()
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	_init_item_message_timer()
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.bind_player_data()
		weapon_selector.refresh_slots()
	refresh_border()

func _init_item_message_timer() -> void:
	if item_message_timer and is_instance_valid(item_message_timer):
		return
	item_message_timer = Timer.new()
	item_message_timer.one_shot = true
	item_message_timer.wait_time = 1.8
	add_child(item_message_timer)
	if not item_message_timer.is_connected("timeout", Callable(self, "_on_item_message_timeout")):
		item_message_timer.timeout.connect(Callable(self, "_on_item_message_timeout"))

func _init_branch_select_panel() -> void:
	branch_select_panel = branch_select_panel_scene.instantiate() as BranchSelectPanel
	if branch_select_panel == null:
		push_warning("Failed to create BranchSelectPanel.")
		return
	$GUI.add_child(branch_select_panel)
	branch_select_panel.visible = false
	if not branch_select_panel.is_connected("branch_selected", Callable(self, "_on_branch_selected")):
		branch_select_panel.connect("branch_selected", Callable(self, "_on_branch_selected"))

func _init_module_equip_selection_panel() -> void:
	module_equip_selection_panel = module_equip_selection_panel_scene.instantiate() as ModuleEquipSelectionPanel
	if module_equip_selection_panel == null:
		push_warning("Failed to create ModuleEquipSelectionPanel.")
		return
	$GUI.add_child(module_equip_selection_panel)
	module_equip_selection_panel.visible = false

func _init_route_selection_panel() -> void:
	route_selection_panel = route_selection_panel_scene.instantiate() as RouteSelectionPanel
	if route_selection_panel == null:
		push_warning("Failed to create RouteSelectionPanel.")
		return
	$GUI.add_child(route_selection_panel)
	route_selection_panel.visible = false

func _init_reward_selection_panel() -> void:
	reward_selection_panel = reward_selection_panel_scene.instantiate() as RewardSelectionPanel
	if reward_selection_panel == null:
		push_warning("Failed to create RewardSelectionPanel.")
		return
	$GUI.add_child(reward_selection_panel)
	reward_selection_panel.visible = false

func request_weapon_branch_selection(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if weapon.branch_id != "":
		return false
	var branch_options := weapon.get_branch_options()
	if branch_options.is_empty():
		return false
	if branch_select_panel == null or not is_instance_valid(branch_select_panel):
		return false
	branch_select_panel.open_for_weapon(weapon, branch_options)
	return true

func request_module_equip_selection(module_instance: Module, on_complete: Callable = Callable()) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	if module_equip_selection_panel == null or not is_instance_valid(module_equip_selection_panel):
		return false
	return module_equip_selection_panel.open_for_module(module_instance, on_complete)

func request_route_selection(
	route_defs: Array[RunRouteDefinition],
	default_route_id: String,
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable()
) -> bool:
	if route_selection_panel == null or not is_instance_valid(route_selection_panel):
		return false
	return route_selection_panel.open_for_routes(route_defs, default_route_id, on_confirm, on_cancel)

func request_reward_selection(
	route_display_name: String,
	reward_options: Array[RewardInfo],
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable()
) -> bool:
	if reward_selection_panel == null or not is_instance_valid(reward_selection_panel):
		return false
	return reward_selection_panel.open_for_rewards(route_display_name, reward_options, on_confirm, on_cancel)

func _on_branch_selected(weapon: Weapon, branch_id: String) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.set_branch(branch_id):
		push_warning("Failed to apply branch '%s' for weapon '%s'." % [branch_id, weapon.name])
	call_deferred("_finalize_branch_selected_weapon", weapon)

func _finalize_branch_selected_weapon(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	PlayerData.player.create_weapon(weapon)
	update_upg()
	update_gf()
	refresh_border()


func _physics_process(_delta):
	#Character
	_refresh_hp_hud()
	_update_heat_label_text()
	_update_ammo_label_text()
	_update_weapon_state_label_text()
	equipped_label.text = "Equipped:"
	augments_label.text = str(PlayerData.player_augment_list)
	gold_label.text = "Gold: " + str(PlayerData.player_gold)
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("get_current_energy"):
		resource_label.text = "Energy: %d" % int(round(PlayerData.player.get_current_energy()))
	else:
		resource_label.text = "Energy: --"
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
	if Input.is_action_just_pressed("SWITCH_LEFT"):
		if PlayerData.player and is_instance_valid(PlayerData.player):
			PlayerData.player.try_shift_main_weapon(-1)
	if Input.is_action_just_pressed("SWITCH_RIGHT"):
		if PlayerData.player and is_instance_valid(PlayerData.player):
			PlayerData.player.try_shift_main_weapon(1)
		
func refresh_border() -> void:
	var list_changed := false
	var valid_weapons: Array = []
	for weapon in PlayerData.player_weapon_list:
		if is_instance_valid(weapon):
			valid_weapons.append(weapon)
	if valid_weapons.size() != PlayerData.player_weapon_list.size():
		list_changed = true
	PlayerData.player_weapon_list = valid_weapons
	if list_changed:
		PlayerData.notify_weapon_list_changed()

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
		if i == PlayerData.main_weapon_index:
			icon.display = true
		else:
			icon.display = false
		icon.update()
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.refresh_slots()

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
	if branch_select_panel and is_instance_valid(branch_select_panel):
		branch_select_panel.close_panel(true)
	InventoryData.clear_on_select()
	refresh_border()

func gf_panel_in() -> void:
	update_gf()
	gear_fuse_root.visible = true
	inventory_gf.visible = false
	equipped_gf.visible = true

func gf_panel_out() -> void:
	InventoryData.ready_to_fuse_list.clear()
	if branch_select_panel and is_instance_valid(branch_select_panel):
		branch_select_panel.close_panel(true)
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
	_layout_quest_hint(viewport_size)

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
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.set_layout_origin(Vector2(HUD_MARGIN + 82.0, HUD_MARGIN + 6.0))
	hp_label_label.position = Vector2(HUD_MARGIN, viewport_size.y - 120.0)
	if heat_label:
		heat_label.position = Vector2(HUD_MARGIN, viewport_size.y - 96.0)
	if ammo_label:
		ammo_label.position = Vector2(HUD_MARGIN, viewport_size.y - 72.0)
	if weapon_state_label:
		weapon_state_label.position = Vector2(HUD_MARGIN, viewport_size.y - 300.0)
	gold_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN)
	time_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN + 56.0)
	phase_label.position = Vector2(viewport_size.x - 220.0, HUD_MARGIN)
	resource_label.position = Vector2(viewport_size.x - 110.0, viewport_size.y - 54.0)

func _create_quest_hint() -> void:
	if quest_hint_label != null:
		return
	quest_hint_label = Label.new()
	quest_hint_label.name = "QuestHint"
	quest_hint_label.visible = false
	quest_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_hint_label.text = ""
	$GUI.add_child(quest_hint_label)

func _layout_quest_hint(viewport_size: Vector2) -> void:
	if quest_hint_label == null:
		return
	var width := minf(520.0, viewport_size.x - 2.0 * HUD_MARGIN)
	quest_hint_label.size = Vector2(maxf(width, 0.0), 36.0)
	quest_hint_label.position = Vector2((viewport_size.x - quest_hint_label.size.x) * 0.5, HUD_MARGIN + 84.0)

func set_quest_hint(text: String) -> void:
	if quest_hint_label == null:
		return
	quest_hint_label.text = text
	quest_hint_label.visible = text.strip_edges() != ""

func show_item_message(text: String, duration: float = 1.8) -> void:
	set_quest_hint(text)
	if item_message_timer == null or not is_instance_valid(item_message_timer):
		_init_item_message_timer()
	item_message_timer.wait_time = maxf(0.1, duration)
	item_message_timer.start()

func _on_item_message_timeout() -> void:
	set_quest_hint("")

func _init_hp_bar() -> void:
	if hp_bar == null or not is_instance_valid(hp_bar):
		return
	var max_hp: int = max(1, int(PlayerData.player_max_hp))
	var current_hp: int = clampi(int(PlayerData.player_hp), 0, max_hp)
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(current_hp)
	_hp_bar_display_value = hp_bar.value

func _set_hp_bar_max(max_hp: int) -> void:
	if hp_bar == null or not is_instance_valid(hp_bar):
		return
	var safe_max: int = max(1, max_hp)
	if not is_equal_approx(hp_bar.max_value, float(safe_max)):
		hp_bar.max_value = float(safe_max)
	if hp_bar.value > hp_bar.max_value:
		hp_bar.value = hp_bar.max_value
	_hp_bar_display_value = clampf(_hp_bar_display_value, 0.0, hp_bar.max_value)

func _animate_hp_bar_to(target_hp: int) -> void:
	if hp_bar == null or not is_instance_valid(hp_bar):
		return
	var clamped_target: float = clampf(float(target_hp), 0.0, hp_bar.max_value)
	if is_equal_approx(_hp_bar_display_value, clamped_target):
		return
	if _hp_bar_tween != null and is_instance_valid(_hp_bar_tween):
		_hp_bar_tween.kill()
	_hp_bar_tween = create_tween()
	_hp_bar_tween.set_trans(HP_BAR_TRANS)
	_hp_bar_tween.set_ease(HP_BAR_EASE)
	_hp_bar_tween.tween_property(hp_bar, "value", clamped_target, HP_BAR_ANIM_TIME)
	_hp_bar_display_value = clamped_target

func _refresh_hp_hud() -> void:
	var max_hp: int = max(1, int(PlayerData.player_max_hp))
	var current_hp: int = clampi(int(PlayerData.player_hp), 0, max_hp)
	hp_label_text.text = "HP: %d/%d" % [current_hp, max_hp]
	_set_hp_bar_max(max_hp)
	_animate_hp_bar_to(current_hp)

func _ensure_heat_label() -> void:
	if heat_label != null and is_instance_valid(heat_label):
		return
	heat_label = Label.new()
	heat_label.name = "Heat"
	heat_label.text = "Heat: --"
	heat_label.visible = false
	character_root.add_child(heat_label)

func _ensure_ammo_label() -> void:
	if ammo_label != null and is_instance_valid(ammo_label):
		return
	ammo_label = Label.new()
	ammo_label.name = "Ammo"
	ammo_label.text = "Ammo: --"
	ammo_label.visible = true
	character_root.add_child(ammo_label)

func _ensure_weapon_state_label() -> void:
	if weapon_state_label != null and is_instance_valid(weapon_state_label):
		return
	weapon_state_label = Label.new()
	weapon_state_label.name = "WeaponState"
	weapon_state_label.text = "Main: -- | WS: -- | PS: --"
	weapon_state_label.visible = true
	character_root.add_child(weapon_state_label)

func _update_heat_label_text() -> void:
	if heat_label == null or not is_instance_valid(heat_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		heat_label.visible = false
		return
	if not PlayerData.player.has_method("get_total_heat_max"):
		heat_label.visible = false
		return
	var heat_max: float = float(PlayerData.player.call("get_total_heat_max"))
	if heat_max <= 0.0:
		heat_label.visible = false
		return
	var heat_value: float = float(PlayerData.player.call("get_total_heat_value"))
	var percent: int = int(round(clampf(heat_value / heat_max, 0.0, 1.0) * 100.0))
	var overheated := _any_heat_weapon_overheated()
	heat_label.text = "Heat: %d/%d (%d%%)%s" % [
		int(round(heat_value)),
		int(round(heat_max)),
		percent,
		" (OVERHEAT)" if overheated else ""
	]
	heat_label.visible = true

func _update_ammo_label_text() -> void:
	if ammo_label == null or not is_instance_valid(ammo_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		ammo_label.text = "Ammo: --"
		return
	if not PlayerData.player.has_method("get_main_weapon"):
		ammo_label.text = "Ammo: --"
		return
	var main_weapon_variant: Variant = PlayerData.player.call("get_main_weapon")
	if not (main_weapon_variant is Node):
		ammo_label.text = "Ammo: --"
		return
	var main_weapon := main_weapon_variant as Node
	if main_weapon == null or not is_instance_valid(main_weapon):
		ammo_label.text = "Ammo: --"
		return
	if not main_weapon.has_method("get_ammo_status"):
		ammo_label.text = "Ammo: --"
		return
	var status_variant: Variant = main_weapon.call("get_ammo_status")
	if not (status_variant is Dictionary):
		ammo_label.text = "Ammo: --"
		return
	var status := status_variant as Dictionary
	if not bool(status.get("enabled", false)):
		ammo_label.text = "Ammo: --"
		return
	var current := int(status.get("current", 0))
	var max_ammo := int(status.get("max", 0))
	var is_reloading := bool(status.get("is_reloading", false))
	var reload_left := maxf(float(status.get("reload_left", 0.0)), 0.0)
	ammo_label.text = "Ammo: %d/%d%s" % [
		current,
		max_ammo,
		" (Reloading %.1fs)" % reload_left if is_reloading else ""
	]

func _get_heat_weapon() -> Node:
	if PlayerData.player_weapon_list.is_empty():
		return null
	if PlayerData.main_weapon_index >= 0 and PlayerData.main_weapon_index < PlayerData.player_weapon_list.size():
		var selected = PlayerData.player_weapon_list[PlayerData.main_weapon_index]
		if selected and is_instance_valid(selected) and selected.has_method("has_heat_system") and bool(selected.call("has_heat_system")):
			return selected
	for weapon in PlayerData.player_weapon_list:
		if weapon and is_instance_valid(weapon) and weapon.has_method("has_heat_system") and bool(weapon.call("has_heat_system")):
			return weapon
	return null

func _any_heat_weapon_overheated() -> bool:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not weapon.has_method("has_heat_system"):
			continue
		if not bool(weapon.call("has_heat_system")):
			continue
		if weapon.has_method("is_weapon_overheated") and bool(weapon.call("is_weapon_overheated")):
			return true
	return false

func _update_weapon_state_label_text() -> void:
	if weapon_state_label == null or not is_instance_valid(weapon_state_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		weapon_state_label.text = "Main: -- | WS: -- | PS: --"
		return
	var weapon_count := PlayerData.player_weapon_list.size()
	var main_text := "None"
	if weapon_count == 1:
		main_text = "W1 (locked)"
	elif PlayerData.main_weapon_index >= 0:
		main_text = "W%s" % str(PlayerData.main_weapon_index + 1)
	var ws_cd := PlayerData.player.get_weapon_active_cd_remaining() if PlayerData.player.has_method("get_weapon_active_cd_remaining") else 0.0
	var ps_cd := 0.0
	var active_skill_node: Node = null
	if PlayerData.player.active_skill_holder and PlayerData.player.active_skill_holder.get_child_count() > 0:
		active_skill_node = PlayerData.player.active_skill_holder.get_child(0)
	if active_skill_node != null and active_skill_node.has_method("get_cooldown_remaining"):
		ps_cd = float(active_skill_node.call("get_cooldown_remaining"))
	var fail_reason := ""
	if PlayerData.player.has_method("get_last_weapon_skill_fail_reason"):
		fail_reason = str(PlayerData.player.get_last_weapon_skill_fail_reason())
	var lock_text := "on" if weapon_count > 1 else "off"
	weapon_state_label.text = "Main:%s Offhand:%d Swap:%s WS:%.1fs PS:%s%s" % [
		main_text,
		maxi(0, weapon_count - 1),
		lock_text,
		ws_cd,
		"%.1fs" % ps_cd if ps_cd > 0.0 else "Ready",
		" Fail:%s" % fail_reason if fail_reason != "" else ""
	]
