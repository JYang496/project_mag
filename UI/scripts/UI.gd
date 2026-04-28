extends CanvasLayer
class_name UI

const PANEL_TARGET_SIZE := Vector2(1000, 600)
const PANEL_MARGIN := Vector2(24, 24)
const PAUSE_PANEL_TARGET_SIZE := Vector2(400, 600)
const PRIMARY_MENU_TARGET_SIZE := Vector2(312, 320)
const PRIMARY_MENU_LEFT_MARGIN := 16.0
const PRIMARY_MENU_ANIM_TIME := 0.2
const PRIMARY_MENU_ANIM_TRANS := Tween.TRANS_CUBIC
const PRIMARY_MENU_ANIM_EASE := Tween.EASE_OUT
const HUD_MARGIN := 16.0
const REST_HINT_SIZE := Vector2(460, 108)
const REST_HINT_OFFSET := Vector2(12, 212)
const REST_ZONE_HINT_SIZE := Vector2(240, 30)
const CONTROLS_HINT_PANEL_SIZE := Vector2(360, 156)
const CONTROLS_HINT_PANEL_MARGIN := Vector2(16, 16)
const HP_BAR_ANIM_TIME := 0.2
const HP_BAR_TRANS := Tween.TRANS_SINE
const HP_BAR_EASE := Tween.EASE_OUT
const GLOBAL_UI_THEME := preload("res://UI/themes/global_ui_theme.tres")
const SPREAD_CURSOR_OVERLAY_SCRIPT := preload("res://UI/scripts/spread_cursor_overlay.gd")
const SPREAD_CURSOR_FALLBACK_RADIUS_PX := 10.0
const BATTLE_HARDWARE_CURSOR_SIZE := 24
const BATTLE_HARDWARE_CURSOR_COLOR := Color(0.9, 0.98, 1.0, 1.0)

# Roots
@onready var gui_root: Control = $GUI
@onready var character_root : Control = $GUI/CharacterRoot
@onready var shopping_rootv_2: Control = $GUI/ShoppingRootv2
@onready var upgrade_rootv_2: Control = $GUI/UpgradeRootv2
@onready var smith_root: Control = $GUI/SmithRoot
@onready var merchant_root: Control = $GUI/MerchantRoot
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
@onready var merchant_primary_panel: Panel = $GUI/MerchantRoot/Panel
@onready var smith_primary_panel: Panel = $GUI/SmithRoot/Panel
var game_over_root: Control
var game_over_total_damage_label: Label
var game_over_completed_levels_label: Label
var game_over_enemy_kills_label: Label
var game_over_elite_kills_label: Label
var game_over_gold_earned_label: Label
var quest_hint_label: Label
var rest_area_hover_hint_label: Label
var _rest_area_hover_hint_anchor_world := Vector2.ZERO
var _rest_area_hover_hint_use_world_anchor := false
var _rest_area_zone_hint_labels: Array[Label] = []
var _rest_area_zone_hint_anchors: Array[Vector2] = []
var item_message_timer: Timer


# Character
@onready var equipped_label = $GUI/CharacterRoot/Equipped
@onready var weapon_selector: WeaponSelector = $GUI/CharacterRoot/WeaponSelector
@onready var augments_label = $GUI/CharacterRoot/Augments
@onready var hp_label_label = $GUI/CharacterRoot/HpLabel
@onready var hp_label_text = $GUI/CharacterRoot/HpLabel/Hp
@onready var hp_bar: ProgressBar = $GUI/CharacterRoot/HpLabel/HpBar
@onready var gold_label = $GUI/CharacterRoot/Gold
@onready var resource_label = $GUI/CharacterRoot/Resource
@onready var time_label = $GUI/CharacterRoot/Time
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
var _rest_area_merchant_active := false
var _rest_area_primary_menu_id: StringName = &""
var game_over_title_label: Label
var game_over_new_game_button: Button
var pause_language_label: Label
var pause_language_option: OptionButton
var controls_hint_panel: Panel
var controls_hint_title_label: Label
var controls_hint_body_label: Label
var _primary_menu_tweens: Dictionary = {}
var spread_cursor_overlay
var _cursor_reload_total_by_weapon: Dictionary = {}
var _battle_hardware_cursor_tex: Texture2D
var _battle_hardware_cursor_applied: bool = false
var _last_heat_label_text: String = ""
var _last_ammo_label_text: String = ""
var _last_weapon_state_text: String = ""


func _ready():
	GlobalVariables.ui = self
	# Reduce input-to-render latency for custom cursor overlays.
	Input.use_accumulated_input = false
	_battle_hardware_cursor_tex = _build_battle_hardware_cursor_texture()
	gui_root.theme = GLOBAL_UI_THEME
	_init_hp_bar()
	_refresh_hp_hud()
	_ensure_heat_label()
	_ensure_ammo_label()
	_ensure_resource_label_under_hp()
	_ensure_weapon_state_label()
	_ensure_spread_cursor_overlay()
	_init_branch_select_panel()
	_init_module_equip_selection_panel()
	_init_route_selection_panel()
	_init_reward_selection_panel()
	_create_game_over_layout()
	_create_controls_hint_panel()
	_ensure_pause_language_controls()
	_refresh_localized_static_text()
	_create_quest_hint()
	_ensure_rest_area_hover_hint()
	_connect_viewport_signals()
	_apply_responsive_layout()
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.connect("language_changed", Callable(self, "_on_language_changed"))
	_init_item_message_timer()
	_update_controls_guide_for_phase(PhaseManager.current_state())
	_update_cursor_presentation()
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
	var is_already_owned := PlayerData.player_weapon_list.has(weapon) or InventoryData.inventory_slots.has(weapon)
	if not is_already_owned:
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
	_refresh_hud_text_values()
	_refresh_controls_hint_visibility()
	_update_rest_area_hover_hint_position()

func _process(_delta: float) -> void:
	# Cursor-follow visuals should run on render frames to minimize perceived mouse lag.
	drag_item_icon.set_position(get_viewport().get_mouse_position())
	_update_spread_cursor_overlay()
func _input(_event) -> void:
	if _event is InputEventMouseMotion:
		var motion := _event as InputEventMouseMotion
		drag_item_icon.set_position(motion.position)
		_update_spread_cursor_overlay(motion.position)

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
		_update_cursor_presentation()
	
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
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.refresh_slots()

func shopping_panel_in() -> void:
	if shopping_rootv_2 == null:
		return
	move_out_timer.stop()
	shop_cancel_button._on_button_up()
	update_shop()
	if merchant_root:
		merchant_root.visible = false
	shopping_rootv_2.visible = true

func shopping_panel_out() -> void:
	shopping_rootv_2.visible = false
	InventoryData.clear_on_select()
	refresh_border()
	move_out_timer.start()

func merchant_menu_in() -> void:
	shopping_panel_out()
	_show_primary_menu(&"merchant", merchant_root, merchant_primary_panel)

func merchant_menu_out() -> void:
	_hide_primary_menu(&"merchant", merchant_root, merchant_primary_panel)
	shopping_panel_out()
	_rest_area_merchant_active = false
	if _rest_area_primary_menu_id == &"merchant":
		_rest_area_primary_menu_id = &""

func merchant_open_buy_panel() -> void:
	var should_wait := merchant_root != null and merchant_root.visible
	_hide_primary_menu(&"merchant", merchant_root, merchant_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	shopping_panel_in()

func merchant_open_sell_panel() -> void:
	var should_wait := merchant_root != null and merchant_root.visible
	_hide_primary_menu(&"merchant", merchant_root, merchant_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	shopping_panel_in()
	if shop_sell_button and is_instance_valid(shop_sell_button):
		shop_sell_button._on_button_up()

func merchant_back_to_primary_menu() -> void:
	shopping_panel_out()
	_show_primary_menu(&"merchant", merchant_root, merchant_primary_panel)

func open_rest_area_merchant_menu() -> void:
	_rest_area_merchant_active = true
	_rest_area_primary_menu_id = &"merchant"
	PlayerData.is_interacting = true
	merchant_menu_in()

func close_rest_area_merchant_menu() -> void:
	if not _rest_area_merchant_active:
		return
	merchant_menu_out()
	PlayerData.is_interacting = false

func is_rest_area_merchant_active() -> bool:
	return _rest_area_merchant_active

func is_rest_area_zone_navigation_allowed() -> bool:
	if not _rest_area_merchant_active:
		return true
	if _rest_area_primary_menu_id == &"merchant" and merchant_root and merchant_root.visible:
		return true
	if _rest_area_primary_menu_id == &"smith" and smith_root and smith_root.visible:
		return true
	return false

func handle_rest_area_right_cancel() -> bool:
	if not _rest_area_merchant_active:
		return false
	# Secondary menu should step back to primary menu first.
	if _rest_area_primary_menu_id == &"merchant":
		if shopping_rootv_2 and shopping_rootv_2.visible:
			merchant_back_to_primary_menu()
			return true
	elif _rest_area_primary_menu_id == &"smith":
		if (upgrade_rootv_2 and upgrade_rootv_2.visible) or (gear_fuse_root and gear_fuse_root.visible):
			smith_back_to_primary_menu()
			return true
	return false

func open_rest_area_smith_menu() -> void:
	_rest_area_merchant_active = true
	_rest_area_primary_menu_id = &"smith"
	PlayerData.is_interacting = true
	smith_menu_in()

func close_rest_area_primary_menu() -> void:
	if not _rest_area_merchant_active:
		return
	if _rest_area_primary_menu_id == &"smith":
		smith_menu_out()
	else:
		merchant_menu_out()
	PlayerData.is_interacting = false
	_rest_area_merchant_active = false
	_rest_area_primary_menu_id = &""

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
	if smith_root:
		smith_root.visible = false
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
	if smith_root:
		smith_root.visible = false
	gear_fuse_root.visible = true
	inventory_gf.visible = false
	equipped_gf.visible = true

func gf_panel_out() -> void:
	InventoryData.ready_to_fuse_list.clear()
	if branch_select_panel and is_instance_valid(branch_select_panel):
		branch_select_panel.close_panel(true)
	gear_fuse_root.visible = false

func smith_menu_in() -> void:
	upg_panel_out()
	gf_panel_out()
	_show_primary_menu(&"smith", smith_root, smith_primary_panel)

func smith_menu_out() -> void:
	_hide_primary_menu(&"smith", smith_root, smith_primary_panel)
	upg_panel_out()
	gf_panel_out()

func smith_open_upgrade_panel() -> void:
	var should_wait := smith_root != null and smith_root.visible
	_hide_primary_menu(&"smith", smith_root, smith_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	upg_panel_in()

func smith_open_fuse_panel() -> void:
	var should_wait := smith_root != null and smith_root.visible
	_hide_primary_menu(&"smith", smith_root, smith_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	gf_panel_in()

func smith_back_to_primary_menu() -> void:
	upg_panel_out()
	gf_panel_out()
	_show_primary_menu(&"smith", smith_root, smith_primary_panel)

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
	_update_cursor_presentation()


func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.GAMEOVER:
		_show_game_over()
	_update_controls_guide_for_phase(new_phase)
	_update_cursor_presentation()

func _should_use_battle_ring_cursor() -> bool:
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		return false
	if get_tree().paused:
		return false
	if pause_menu_root and is_instance_valid(pause_menu_root) and pause_menu_root.visible:
		return false
	if game_over_root and is_instance_valid(game_over_root) and game_over_root.visible:
		return false
	if _is_primary_menu_open() or _is_secondary_menu_open():
		return false
	if branch_select_panel and is_instance_valid(branch_select_panel) and branch_select_panel.visible:
		return false
	if module_equip_selection_panel and is_instance_valid(module_equip_selection_panel) and module_equip_selection_panel.visible:
		return false
	if route_selection_panel and is_instance_valid(route_selection_panel) and route_selection_panel.visible:
		return false
	if reward_selection_panel and is_instance_valid(reward_selection_panel) and reward_selection_panel.visible:
		return false
	return true

func _update_cursor_presentation() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _should_use_battle_ring_cursor():
		_apply_battle_hardware_cursor()
	else:
		_clear_battle_hardware_cursor()

func _apply_battle_hardware_cursor() -> void:
	if _battle_hardware_cursor_applied:
		return
	if _battle_hardware_cursor_tex == null:
		_battle_hardware_cursor_tex = _build_battle_hardware_cursor_texture()
	if _battle_hardware_cursor_tex == null:
		return
	var hotspot := Vector2(BATTLE_HARDWARE_CURSOR_SIZE * 0.5, BATTLE_HARDWARE_CURSOR_SIZE * 0.5)
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_WAIT]:
		Input.set_custom_mouse_cursor(_battle_hardware_cursor_tex, shape, hotspot)
	_battle_hardware_cursor_applied = true

func _clear_battle_hardware_cursor() -> void:
	if not _battle_hardware_cursor_applied:
		return
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_WAIT]:
		Input.set_custom_mouse_cursor(null, shape)
	_battle_hardware_cursor_applied = false

func _build_battle_hardware_cursor_texture() -> Texture2D:
	var size: int = maxi(12, BATTLE_HARDWARE_CURSOR_SIZE)
	var center := int(size / 2)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var c := BATTLE_HARDWARE_CURSOR_COLOR
	for x in range(size):
		image.set_pixel(x, center, c)
	for y in range(size):
		image.set_pixel(center, y, c)
	for i in range(-3, 4):
		image.set_pixel(center + i, center, c)
		image.set_pixel(center, center + i, c)
	var outline := Color(0.12, 0.2, 0.28, 0.9)
	for x in range(size):
		if center - 1 >= 0:
			image.set_pixel(x, center - 1, outline)
		if center + 1 < size:
			image.set_pixel(x, center + 1, outline)
	for y in range(size):
		if center - 1 >= 0:
			image.set_pixel(center - 1, y, outline)
		if center + 1 < size:
			image.set_pixel(center + 1, y, outline)
	return ImageTexture.create_from_image(image)


func _show_game_over() -> void:
	if game_over_root == null:
		return
	pause_menu_root.visible = false
	shopping_rootv_2.visible = false
	upgrade_rootv_2.visible = false
	inventory_root.visible = false
	module_root.visible = false
	gear_fuse_root.visible = false
	game_over_total_damage_label.text = LocalizationManager.tr_format(
		"ui.gameover.total_damage",
		{"value": PlayerData.run_total_damage_dealt},
		"Total Damage: %s" % str(PlayerData.run_total_damage_dealt)
	)
	game_over_completed_levels_label.text = LocalizationManager.tr_format(
		"ui.gameover.completed_levels",
		{"value": PlayerData.run_completed_levels},
		"Completed Levels: %s" % str(PlayerData.run_completed_levels)
	)
	game_over_enemy_kills_label.text = LocalizationManager.tr_format(
		"ui.gameover.enemy_kills",
		{"value": PlayerData.run_enemy_kills},
		"Enemy Kills: %s" % str(PlayerData.run_enemy_kills)
	)
	game_over_elite_kills_label.text = LocalizationManager.tr_format(
		"ui.gameover.elite_kills",
		{"value": PlayerData.run_elite_kills},
		"Elite Kills: %s" % str(PlayerData.run_elite_kills)
	)
	game_over_gold_earned_label.text = LocalizationManager.tr_format(
		"ui.gameover.gold_earned",
		{"value": PlayerData.run_gold_earned},
		"Gold Earned: %s" % str(PlayerData.run_gold_earned)
	)
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
	panel.custom_minimum_size = Vector2(560, 380)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_top = -190
	panel.offset_right = 280
	panel.offset_bottom = 190
	game_over_root.add_child(panel)

	game_over_title_label = Label.new()
	game_over_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title_label.offset_left = 0
	game_over_title_label.offset_top = 24
	game_over_title_label.offset_right = 560
	game_over_title_label.offset_bottom = 56
	panel.add_child(game_over_title_label)

	game_over_total_damage_label = _create_game_over_stat_label(panel, 92)
	game_over_completed_levels_label = _create_game_over_stat_label(panel, 132)
	game_over_enemy_kills_label = _create_game_over_stat_label(panel, 172)
	game_over_elite_kills_label = _create_game_over_stat_label(panel, 212)
	game_over_gold_earned_label = _create_game_over_stat_label(panel, 252)

	game_over_new_game_button = Button.new()
	game_over_new_game_button.offset_left = 210
	game_over_new_game_button.offset_top = 316
	game_over_new_game_button.offset_right = 350
	game_over_new_game_button.offset_bottom = 352
	game_over_new_game_button.pressed.connect(_on_game_over_new_game_pressed)
	panel.add_child(game_over_new_game_button)
	_refresh_game_over_static_text()

func _create_game_over_stat_label(parent: Control, top_offset: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_left = 20
	label.offset_top = top_offset
	label.offset_right = 540
	label.offset_bottom = top_offset + 32
	parent.add_child(label)
	return label


func _on_game_over_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://World/Start.tscn")

func _create_controls_hint_panel() -> void:
	if controls_hint_panel != null and is_instance_valid(controls_hint_panel):
		return
	controls_hint_panel = Panel.new()
	controls_hint_panel.name = "ControlsHintPanel"
	controls_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_hint_panel.z_index = 35
	$GUI.add_child(controls_hint_panel)

	controls_hint_title_label = Label.new()
	controls_hint_title_label.name = "Title"
	controls_hint_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	controls_hint_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls_hint_title_label.add_theme_font_size_override("font_size", 18)
	controls_hint_panel.add_child(controls_hint_title_label)

	controls_hint_body_label = Label.new()
	controls_hint_body_label.name = "Body"
	controls_hint_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	controls_hint_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	controls_hint_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_hint_body_label.add_theme_font_size_override("font_size", 16)
	controls_hint_panel.add_child(controls_hint_body_label)

func _layout_controls_hint_panel(viewport_size: Vector2) -> void:
	if controls_hint_panel == null or not is_instance_valid(controls_hint_panel):
		return
	var width := minf(CONTROLS_HINT_PANEL_SIZE.x, viewport_size.x - 2.0 * CONTROLS_HINT_PANEL_MARGIN.x)
	var height := CONTROLS_HINT_PANEL_SIZE.y
	controls_hint_panel.size = Vector2(maxf(width, 260.0), height)
	controls_hint_panel.position = Vector2(
		viewport_size.x - controls_hint_panel.size.x - CONTROLS_HINT_PANEL_MARGIN.x,
		CONTROLS_HINT_PANEL_MARGIN.y
	)
	controls_hint_title_label.position = Vector2(14.0, 10.0)
	controls_hint_title_label.size = Vector2(controls_hint_panel.size.x - 28.0, 28.0)
	controls_hint_body_label.position = Vector2(14.0, 40.0)
	controls_hint_body_label.size = Vector2(controls_hint_panel.size.x - 28.0, controls_hint_panel.size.y - 50.0)

func _update_controls_guide_for_phase(phase: String) -> void:
	if controls_hint_panel == null or not is_instance_valid(controls_hint_panel):
		return
	if phase == PhaseManager.GAMEOVER:
		controls_hint_panel.visible = false
		return
	_refresh_controls_hint_visibility()
	if not controls_hint_panel.visible:
		return
	if _is_primary_menu_open():
		controls_hint_title_label.text = LocalizationManager.tr_key("ui.tutorial.state.primary_menu", "Current: Primary Menu")
		var primary_menu_lines := PackedStringArray([
			LocalizationManager.tr_key("ui.tutorial.panel.primary_menu.line1", "[LMB] Click buttons"),
			LocalizationManager.tr_key("ui.tutorial.panel.primary_menu.line2", "[RMB] Exit current menu")
		])
		controls_hint_body_label.text = "\n".join(primary_menu_lines)
		return
	if phase == PhaseManager.BATTLE:
		controls_hint_title_label.text = LocalizationManager.tr_key("ui.tutorial.state.battle", "Current: Battle")
		var battle_lines := PackedStringArray([
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line1", "[W][A][S][D] Move"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line2", "[LMB] Attack"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line3", "[Space] Skill"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line4", "[R] Weapon Skill"),
			LocalizationManager.tr_key("ui.tutorial.panel.battle.line5", "[Q/E] Switch Weapon  [Esc] Pause")
		])
		controls_hint_body_label.text = "\n".join(battle_lines)
		return
	controls_hint_title_label.text = LocalizationManager.tr_key("ui.tutorial.state.rest", "Current: Rest Area")
	var rest_lines := PackedStringArray([
		LocalizationManager.tr_key("ui.tutorial.panel.rest.line1", "[LMB] Click menu and zones"),
		LocalizationManager.tr_key("ui.tutorial.panel.rest.line2", "[LMB Hold Center] Start battle"),
		LocalizationManager.tr_key("ui.tutorial.panel.rest.line3", "[Esc] Pause")
	])
	controls_hint_body_label.text = "\n".join(rest_lines)

func _refresh_controls_hint_visibility() -> void:
	if controls_hint_panel == null or not is_instance_valid(controls_hint_panel):
		return
	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		controls_hint_panel.visible = false
		return
	controls_hint_panel.visible = not _is_secondary_menu_open()

func _is_primary_menu_open() -> bool:
	var roots := [
		merchant_root,
		smith_root
	]
	for root in roots:
		if root and is_instance_valid(root) and root.visible:
			return true
	return false

func _is_secondary_menu_open() -> bool:
	var roots := [
		shopping_rootv_2,
		upgrade_rootv_2,
		gear_fuse_root,
		module_root,
		inventory_root
	]
	for root in roots:
		if root and is_instance_valid(root) and root.visible:
			return true
	return false

func _refresh_controls_guide_texts() -> void:
	_update_controls_guide_for_phase(PhaseManager.current_state())


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
	_fit_left_panel(merchant_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	_fit_left_panel(smith_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	_fit_pause_layout(viewport_size)
	_layout_hud(viewport_size)
	_layout_rest_area_hover_hint(viewport_size)
	_layout_quest_hint(viewport_size)
	_layout_controls_hint_panel(viewport_size)

func _show_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	if root == null or panel == null:
		return
	_stop_primary_menu_tween(menu_id)
	var viewport_size := get_viewport().get_visible_rect().size
	_fit_left_panel(panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	var target_pos := panel.position
	var hidden_pos := _get_primary_menu_hidden_position(panel, target_pos)
	root.visible = true
	panel.position = hidden_pos
	var tween := create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", target_pos, PRIMARY_MENU_ANIM_TIME)
	tween.finished.connect(Callable(self, "_on_primary_menu_tween_finished").bind(menu_id))
	_primary_menu_tweens[menu_id] = tween

func _hide_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	if root == null or panel == null:
		return
	_stop_primary_menu_tween(menu_id)
	var viewport_size := get_viewport().get_visible_rect().size
	_fit_left_panel(panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	var target_pos := panel.position
	var hidden_pos := _get_primary_menu_hidden_position(panel, target_pos)
	if not root.visible:
		panel.position = hidden_pos
		return
	var tween := create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", hidden_pos, PRIMARY_MENU_ANIM_TIME)
	tween.tween_callback(Callable(self, "_on_primary_menu_hidden").bind(menu_id, root, panel, hidden_pos))
	tween.finished.connect(Callable(self, "_on_primary_menu_tween_finished").bind(menu_id))
	_primary_menu_tweens[menu_id] = tween

func _get_primary_menu_hidden_position(panel: Control, target_pos: Vector2) -> Vector2:
	return Vector2(-panel.size.x - PRIMARY_MENU_LEFT_MARGIN, target_pos.y)

func _stop_primary_menu_tween(menu_id: StringName) -> void:
	if not _primary_menu_tweens.has(menu_id):
		return
	var active_tween := _primary_menu_tweens[menu_id] as Tween
	if active_tween and is_instance_valid(active_tween):
		active_tween.kill()
	_primary_menu_tweens.erase(menu_id)

func _on_primary_menu_hidden(menu_id: StringName, root: Control, panel: Control, hidden_pos: Vector2) -> void:
	if root:
		root.visible = false
	if panel:
		panel.position = hidden_pos
	_primary_menu_tweens.erase(menu_id)

func _on_primary_menu_tween_finished(menu_id: StringName) -> void:
	_primary_menu_tweens.erase(menu_id)

func _fit_center_panel(panel: Control, viewport_size: Vector2, target_size: Vector2) -> void:
	if panel == null:
		return
	var available_size: Vector2 = viewport_size - PANEL_MARGIN * 2.0
	var width: float = minf(target_size.x, available_size.x)
	var height: float = minf(target_size.y, available_size.y)
	panel.size = Vector2(maxf(width, 0.0), maxf(height, 0.0))
	panel.position = (viewport_size - panel.size) * 0.5

func _fit_left_panel(panel: Control, viewport_size: Vector2, target_size: Vector2, left_margin: float) -> void:
	if panel == null:
		return
	var available_size: Vector2 = viewport_size - PANEL_MARGIN * 2.0
	var width: float = minf(target_size.x, available_size.x)
	var height: float = minf(target_size.y, available_size.y)
	panel.size = Vector2(maxf(width, 0.0), maxf(height, 0.0))
	panel.position = Vector2(maxf(left_margin, PANEL_MARGIN.x), (viewport_size.y - panel.size.y) * 0.5)

func _fit_pause_layout(viewport_size: Vector2) -> void:
	pause_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu_root.offset_left = 0
	pause_menu_root.offset_top = 0
	pause_menu_root.offset_right = 0
	pause_menu_root.offset_bottom = 0
	_fit_center_panel(pause_menu_panel, viewport_size, PAUSE_PANEL_TARGET_SIZE)

func _layout_hud(viewport_size: Vector2) -> void:
	equipped_label.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.set_layout_origin(Vector2(HUD_MARGIN + 12.0, HUD_MARGIN + 6.0))
	hp_label_label.position = Vector2(HUD_MARGIN, viewport_size.y - 120.0)
	if heat_label:
		var heat_spacing := 8.0
		var heat_height := maxf(heat_label.get_combined_minimum_size().y, 20.0)
		heat_label.position = Vector2(HUD_MARGIN, hp_label_label.position.y - heat_height - heat_spacing)
	if ammo_label:
		ammo_label.position = Vector2(64.0, 64.0)
	if weapon_state_label:
		weapon_state_label.position = Vector2(HUD_MARGIN, viewport_size.y - 300.0)
	gold_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN)
	time_label.position = Vector2(viewport_size.x * 0.4, HUD_MARGIN + 56.0)
	resource_label.position = Vector2(64.0, 88.0)

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

func _ensure_rest_area_hover_hint() -> void:
	if rest_area_hover_hint_label != null:
		return
	rest_area_hover_hint_label = Label.new()
	rest_area_hover_hint_label.name = "RestAreaHoverHint"
	rest_area_hover_hint_label.visible = false
	rest_area_hover_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rest_area_hover_hint_label.z_index = 50
	rest_area_hover_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rest_area_hover_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	rest_area_hover_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_area_hover_hint_label.add_theme_font_size_override("font_size", 15)
	rest_area_hover_hint_label.size = REST_HINT_SIZE
	$GUI.add_child(rest_area_hover_hint_label)

func _create_rest_area_zone_hint_label() -> Label:
	var label := Label.new()
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", 15)
	label.size = REST_ZONE_HINT_SIZE
	$GUI.add_child(label)
	return label

func _ensure_rest_area_zone_hint_capacity(count: int) -> void:
	while _rest_area_zone_hint_labels.size() < count:
		_rest_area_zone_hint_labels.append(_create_rest_area_zone_hint_label())
	while _rest_area_zone_hint_anchors.size() < count:
		_rest_area_zone_hint_anchors.append(Vector2.ZERO)

func _hide_rest_area_zone_hint_labels() -> void:
	for label in _rest_area_zone_hint_labels:
		if label:
			label.visible = false
	_rest_area_zone_hint_anchors.clear()

func set_rest_area_zone_hints_at_world(hints: Array) -> void:
	_ensure_rest_area_hover_hint()
	rest_area_hover_hint_label.visible = false
	_rest_area_hover_hint_use_world_anchor = false
	var count := hints.size()
	_ensure_rest_area_zone_hint_capacity(count)
	for idx in range(_rest_area_zone_hint_labels.size()):
		var label := _rest_area_zone_hint_labels[idx]
		if label == null:
			continue
		if idx >= count:
			label.visible = false
			continue
		var entry: Variant = hints[idx]
		if not (entry is Dictionary):
			label.visible = false
			continue
		var hint_dict := entry as Dictionary
		var text := str(hint_dict.get("text", ""))
		var world_pos_variant: Variant = hint_dict.get("world_pos", Vector2.ZERO)
		if not (world_pos_variant is Vector2) or text.strip_edges() == "":
			label.visible = false
			continue
		var world_pos: Vector2 = world_pos_variant as Vector2
		_rest_area_zone_hint_anchors[idx] = world_pos
		label.text = text
		label.visible = true
	_update_rest_area_hover_hint_position()

func set_rest_area_hover_hint(text: String) -> void:
	_ensure_rest_area_hover_hint()
	_hide_rest_area_zone_hint_labels()
	if rest_area_hover_hint_label == null:
		return
	rest_area_hover_hint_label.text = text
	rest_area_hover_hint_label.visible = text.strip_edges() != ""
	_rest_area_hover_hint_use_world_anchor = false
	var viewport := get_viewport()
	if viewport:
		_layout_rest_area_hover_hint(viewport.get_visible_rect().size)

func set_rest_area_hover_hint_at_world(text: String, world_pos: Vector2) -> void:
	_ensure_rest_area_hover_hint()
	_hide_rest_area_zone_hint_labels()
	if rest_area_hover_hint_label == null:
		return
	rest_area_hover_hint_label.text = text
	rest_area_hover_hint_label.visible = text.strip_edges() != ""
	_rest_area_hover_hint_anchor_world = world_pos
	_rest_area_hover_hint_use_world_anchor = rest_area_hover_hint_label.visible
	_update_rest_area_hover_hint_position()

func clear_rest_area_hover_hint() -> void:
	_hide_rest_area_zone_hint_labels()
	if rest_area_hover_hint_label == null:
		return
	rest_area_hover_hint_label.text = ""
	rest_area_hover_hint_label.visible = false
	_rest_area_hover_hint_use_world_anchor = false

func _layout_rest_area_hover_hint(viewport_size: Vector2) -> void:
	if rest_area_hover_hint_label == null:
		return
	rest_area_hover_hint_label.size = REST_HINT_SIZE
	var target := Vector2(HUD_MARGIN, HUD_MARGIN) + REST_HINT_OFFSET
	var max_x := maxf(0.0, viewport_size.x - rest_area_hover_hint_label.size.x - 8.0)
	var max_y := maxf(0.0, viewport_size.y - rest_area_hover_hint_label.size.y - 8.0)
	rest_area_hover_hint_label.position = Vector2(
		clampf(target.x, 8.0, max_x),
		clampf(target.y, 8.0, max_y)
	)

func _update_rest_area_hover_hint_position() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if rest_area_hover_hint_label and rest_area_hover_hint_label.visible and _rest_area_hover_hint_use_world_anchor:
		var screen_pos := viewport.get_canvas_transform() * _rest_area_hover_hint_anchor_world
		var target := Vector2(
			screen_pos.x - rest_area_hover_hint_label.size.x * 0.5,
			screen_pos.y - rest_area_hover_hint_label.size.y - 10.0
		)
		var max_x := maxf(0.0, viewport_size.x - rest_area_hover_hint_label.size.x - 8.0)
		var max_y := maxf(0.0, viewport_size.y - rest_area_hover_hint_label.size.y - 8.0)
		rest_area_hover_hint_label.position = Vector2(
			clampf(target.x, 8.0, max_x),
			clampf(target.y, 8.0, max_y)
		)
	for idx in range(_rest_area_zone_hint_labels.size()):
		var label := _rest_area_zone_hint_labels[idx]
		if label == null or not label.visible:
			continue
		if idx >= _rest_area_zone_hint_anchors.size():
			continue
		var anchor := _rest_area_zone_hint_anchors[idx]
		var zone_screen_pos := viewport.get_canvas_transform() * anchor
		var zone_target := Vector2(
			zone_screen_pos.x - label.size.x * 0.5,
			zone_screen_pos.y - label.size.y * 0.5
		)
		var zone_max_x := maxf(0.0, viewport_size.x - label.size.x - 8.0)
		var zone_max_y := maxf(0.0, viewport_size.y - label.size.y - 8.0)
		label.position = Vector2(
			clampf(zone_target.x, 8.0, zone_max_x),
			clampf(zone_target.y, 8.0, zone_max_y)
		)

func _ensure_spread_cursor_overlay() -> void:
	if spread_cursor_overlay != null and is_instance_valid(spread_cursor_overlay):
		return
	var overlay := Control.new()
	overlay.name = "SpreadCursorOverlay"
	overlay.set_script(SPREAD_CURSOR_OVERLAY_SCRIPT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 300
	gui_root.add_child(overlay)
	gui_root.move_child(overlay, gui_root.get_child_count() - 1)
	spread_cursor_overlay = overlay

func _update_spread_cursor_overlay(mouse_screen_override: Variant = null) -> void:
	if spread_cursor_overlay == null or not is_instance_valid(spread_cursor_overlay):
		return
	_update_cursor_presentation()
	var viewport := get_viewport()
	if viewport == null:
		_clear_spread_cursor_ammo_progress()
		spread_cursor_overlay.visible = false
		return
	if not _should_use_battle_ring_cursor():
		_clear_spread_cursor_ammo_progress()
		spread_cursor_overlay.visible = false
		return
	spread_cursor_overlay.visible = true
	var mouse_screen := viewport.get_mouse_position()
	if mouse_screen_override is Vector2:
		mouse_screen = mouse_screen_override as Vector2
	spread_cursor_overlay.set_cursor_screen_position(mouse_screen)
	var main_weapon := _get_main_weapon_node()
	if main_weapon == null or not is_instance_valid(main_weapon):
		_clear_spread_cursor_ammo_progress()
		spread_cursor_overlay.set_fallback_screen_radius(SPREAD_CURSOR_FALLBACK_RADIUS_PX)
		return
	_update_spread_cursor_ammo_progress(main_weapon)
	var canvas_inv := viewport.get_canvas_transform().affine_inverse()
	var mouse_world := canvas_inv * mouse_screen
	var spread_enabled := false
	var spread_radius_world := 0.0
	if main_weapon.has_method("get_spread_preview_info_for_target"):
		var info_variant: Variant = main_weapon.call("get_spread_preview_info_for_target", mouse_world)
		if info_variant is Dictionary:
			var info := info_variant as Dictionary
			spread_enabled = bool(info.get("enabled", false))
			spread_radius_world = maxf(float(info.get("max_radius", 0.0)), 0.0)
	elif main_weapon.has_method("get_spread_preview_radius_for_target"):
		spread_radius_world = maxf(float(main_weapon.call("get_spread_preview_radius_for_target", mouse_world)), 0.0)
		spread_enabled = spread_radius_world > 0.0
	if spread_enabled and spread_radius_world > 0.0:
		spread_cursor_overlay.set_world_anchor_and_radius(mouse_world, spread_radius_world)
		return
	spread_cursor_overlay.set_fallback_screen_radius(SPREAD_CURSOR_FALLBACK_RADIUS_PX)

func _update_spread_cursor_ammo_progress(main_weapon: Node) -> void:
	if spread_cursor_overlay == null or not is_instance_valid(spread_cursor_overlay):
		return
	if main_weapon == null or not is_instance_valid(main_weapon):
		_clear_spread_cursor_ammo_progress()
		return
	if not main_weapon.has_method("get_ammo_status"):
		_clear_spread_cursor_ammo_progress()
		return
	var status_variant: Variant = main_weapon.call("get_ammo_status")
	if not (status_variant is Dictionary):
		_clear_spread_cursor_ammo_progress()
		return
	var status: Dictionary = status_variant as Dictionary
	if not bool(status.get("enabled", false)):
		_clear_spread_cursor_ammo_progress()
		return
	var max_ammo: int = max(1, int(status.get("max", 0)))
	var current_ammo: int = clampi(int(status.get("current", 0)), 0, max_ammo)
	var is_reloading: bool = bool(status.get("is_reloading", false))
	var reload_left: float = maxf(float(status.get("reload_left", 0.0)), 0.0)
	var weapon_id: int = main_weapon.get_instance_id()
	var progress: float = 1.0
	var clockwise: bool = false
	if is_reloading:
		var tracked_total := float(_cursor_reload_total_by_weapon.get(weapon_id, 0.0))
		if tracked_total <= 0.0:
			tracked_total = reload_left
		tracked_total = maxf(tracked_total, reload_left)
		_cursor_reload_total_by_weapon[weapon_id] = tracked_total
		if tracked_total <= 0.0:
			progress = 0.0
		else:
			progress = clampf(1.0 - (reload_left / tracked_total), 0.0, 1.0)
		clockwise = false
	else:
		_cursor_reload_total_by_weapon.erase(weapon_id)
		progress = clampf(float(current_ammo) / float(max_ammo), 0.0, 1.0)
		clockwise = false
	spread_cursor_overlay.set_ammo_progress(progress, clockwise, true)

func _clear_spread_cursor_ammo_progress() -> void:
	if spread_cursor_overlay != null and is_instance_valid(spread_cursor_overlay):
		spread_cursor_overlay.clear_ammo_progress()

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
	hp_label_text.text = LocalizationManager.tr_format("ui.hud.hp", {"current": current_hp, "max": max_hp}, "HP: %d/%d" % [current_hp, max_hp])
	_set_hp_bar_max(max_hp)
	_animate_hp_bar_to(current_hp)

func _ensure_heat_label() -> void:
	if heat_label != null and is_instance_valid(heat_label):
		return
	heat_label = Label.new()
	heat_label.name = "Heat"
	heat_label.text = LocalizationManager.tr_key("ui.hud.heat_empty", "Heat: --")
	heat_label.visible = false
	character_root.add_child(heat_label)

func _ensure_ammo_label() -> void:
	if ammo_label != null and is_instance_valid(ammo_label):
		return
	ammo_label = Label.new()
	ammo_label.name = "Ammo"
	ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
	ammo_label.visible = true
	# Keep ammo in the same HUD container as HP, as a sibling under HpLabel.
	hp_label_label.add_child(ammo_label)

func _ensure_resource_label_under_hp() -> void:
	if resource_label == null or not is_instance_valid(resource_label):
		return
	if hp_label_label == null or not is_instance_valid(hp_label_label):
		return
	if resource_label.get_parent() == hp_label_label:
		return
	var previous_parent := resource_label.get_parent()
	if previous_parent:
		previous_parent.remove_child(resource_label)
	hp_label_label.add_child(resource_label)

func _ensure_weapon_state_label() -> void:
	if weapon_state_label != null and is_instance_valid(weapon_state_label):
		return
	weapon_state_label = Label.new()
	weapon_state_label.name = "WeaponState"
	weapon_state_label.text = LocalizationManager.tr_key("ui.hud.weapon_state_none", "Main: -- | WS: -- | PS: --")
	weapon_state_label.visible = false
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
	var overheat_text := LocalizationManager.tr_key("ui.hud.heat_overheat", " (OVERHEAT)") if overheated else ""
	var next_text := LocalizationManager.tr_format(
		"ui.hud.heat",
		{
			"value": int(round(heat_value)),
			"max": int(round(heat_max)),
			"percent": percent,
			"overheat": overheat_text
		},
		"Heat: %d/%d (%d%%)%s" % [int(round(heat_value)), int(round(heat_max)), percent, overheat_text]
	)
	if _last_heat_label_text != next_text:
		_last_heat_label_text = next_text
		heat_label.text = next_text
	heat_label.visible = true

func _update_ammo_label_text() -> void:
	if ammo_label == null or not is_instance_valid(ammo_label):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	if not PlayerData.player.has_method("get_main_weapon"):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var main_weapon_variant: Variant = PlayerData.player.call("get_main_weapon")
	if not (main_weapon_variant is Node):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var main_weapon := main_weapon_variant as Node
	if main_weapon == null or not is_instance_valid(main_weapon):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	if not main_weapon.has_method("get_ammo_status"):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var status_variant: Variant = main_weapon.call("get_ammo_status")
	if not (status_variant is Dictionary):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var status := status_variant as Dictionary
	if not bool(status.get("enabled", false)):
		ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")
		return
	var current := int(status.get("current", 0))
	var max_ammo := int(status.get("max", 0))
	var is_reloading := bool(status.get("is_reloading", false))
	var reload_left := maxf(float(status.get("reload_left", 0.0)), 0.0)
	var reload_text := ""
	if is_reloading:
		reload_text = LocalizationManager.tr_format("ui.hud.ammo_reloading", {"sec": snappedf(reload_left, 0.1)}, " (Reloading %.1fs)" % reload_left)
	var next_ammo_text := LocalizationManager.tr_format(
		"ui.hud.ammo",
		{"current": current, "max": max_ammo, "reload": reload_text},
		"Ammo: %d/%d%s" % [current, max_ammo, reload_text]
	)
	if _last_ammo_label_text != next_ammo_text:
		_last_ammo_label_text = next_ammo_text
		ammo_label.text = next_ammo_text

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

func _get_main_weapon_node() -> Node:
	if PlayerData.player_weapon_list.is_empty():
		return null
	PlayerData.sanitize_main_weapon_index()
	var idx := PlayerData.main_weapon_index
	if idx < 0 or idx >= PlayerData.player_weapon_list.size():
		return null
	var weapon_variant: Variant = PlayerData.player_weapon_list[idx]
	var weapon_node := weapon_variant as Node
	if weapon_node == null or not is_instance_valid(weapon_node):
		return null
	return weapon_node

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
		weapon_state_label.text = LocalizationManager.tr_key("ui.hud.weapon_state_none", "Main: -- | WS: -- | PS: --")
		return
	var weapon_count := PlayerData.player_weapon_list.size()
	var main_text := LocalizationManager.tr_key("ui.hud.weapon.main.none", "None")
	if weapon_count == 1:
		main_text = LocalizationManager.tr_key("ui.hud.weapon.main.locked", "W1 (locked)")
	elif PlayerData.main_weapon_index >= 0:
		main_text = LocalizationManager.tr_format("ui.hud.weapon.main.slot", {"index": PlayerData.main_weapon_index + 1}, "W%s" % str(PlayerData.main_weapon_index + 1))
	var ws_cd: float = PlayerData.player.get_weapon_active_cd_remaining() if PlayerData.player.has_method("get_weapon_active_cd_remaining") else 0.0
	var ps_cd := 0.0
	var active_skill_node: Node = null
	if PlayerData.player.active_skill_holder and PlayerData.player.active_skill_holder.get_child_count() > 0:
		active_skill_node = PlayerData.player.active_skill_holder.get_child(0)
	if active_skill_node != null and active_skill_node.has_method("get_cooldown_remaining"):
		ps_cd = float(active_skill_node.call("get_cooldown_remaining"))
	var fail_reason := ""
	if PlayerData.player.has_method("get_last_weapon_skill_fail_reason"):
		fail_reason = str(PlayerData.player.get_last_weapon_skill_fail_reason())
	var lock_text := LocalizationManager.tr_key("ui.hud.weapon.swap.on", "on") if weapon_count > 1 else LocalizationManager.tr_key("ui.hud.weapon.swap.off", "off")
	var ps_text := "%.1fs" % ps_cd if ps_cd > 0.0 else LocalizationManager.tr_key("ui.hud.weapon.ready", "Ready")
	var fail_text := ""
	if fail_reason != "":
		fail_text = LocalizationManager.tr_format("ui.hud.weapon.fail", {"reason": fail_reason}, " Fail:%s" % fail_reason)
	var next_state_text := LocalizationManager.tr_format(
		"ui.hud.weapon_state",
		{
			"main": main_text,
			"offhand": maxi(0, weapon_count - 1),
			"swap": lock_text,
			"ws": "%.1fs" % ws_cd,
			"ps": ps_text,
			"fail": fail_text
		},
		"Main:%s Offhand:%d Swap:%s WS:%.1fs PS:%s%s" % [main_text, maxi(0, weapon_count - 1), lock_text, ws_cd, ps_text, fail_text]
	)
	if _last_weapon_state_text != next_state_text:
		_last_weapon_state_text = next_state_text
		weapon_state_label.text = next_state_text

func _ensure_pause_language_controls() -> void:
	var pause_label := pause_menu_panel.get_node_or_null("Paused") as Label
	if pause_label:
		pause_label.text = LocalizationManager.tr_key("ui.panel.pause", "Paused")
	resume_button.text = LocalizationManager.tr_key("ui.panel.resume", "Resume")
	var existing_label := pause_menu_panel.get_node_or_null("LanguageLabel")
	if existing_label is Label:
		pause_language_label = existing_label as Label
	else:
		pause_language_label = Label.new()
		pause_language_label.name = "LanguageLabel"
		pause_menu_panel.add_child(pause_language_label)
	var existing_option := pause_menu_panel.get_node_or_null("LanguageOption")
	if existing_option is OptionButton:
		pause_language_option = existing_option as OptionButton
	else:
		pause_language_option = OptionButton.new()
		pause_language_option.name = "LanguageOption"
		pause_menu_panel.add_child(pause_language_option)
	if not pause_language_option.is_connected("item_selected", Callable(self, "_on_pause_language_option_item_selected")):
		pause_language_option.connect("item_selected", Callable(self, "_on_pause_language_option_item_selected"))
	_refresh_pause_language_options()

func _refresh_pause_language_options() -> void:
	if pause_language_label:
		pause_language_label.text = LocalizationManager.tr_key("ui.settings.language", "Language")
		pause_language_label.position = Vector2(72.0, 324.0)
		pause_language_label.size = Vector2(110.0, 28.0)
	if pause_language_option == null:
		return
	pause_language_option.position = Vector2(184.0, 320.0)
	pause_language_option.size = Vector2(148.0, 30.0)
	pause_language_option.clear()
	var locales := LocalizationManager.available_locales()
	var selected_idx := -1
	var current_locale := LocalizationManager.get_locale()
	for i in range(locales.size()):
		var locale := str(locales[i])
		pause_language_option.add_item(LocalizationManager.locale_display_name(locale))
		pause_language_option.set_item_metadata(i, locale)
		if locale == current_locale:
			selected_idx = i
	if selected_idx >= 0:
		pause_language_option.select(selected_idx)

func _on_pause_language_option_item_selected(index: int) -> void:
	if pause_language_option == null:
		return
	var locale := str(pause_language_option.get_item_metadata(index))
	if locale != "":
		LocalizationManager.set_locale(locale)

func _on_language_changed(_new_locale: String) -> void:
	_refresh_localized_static_text()
	_refresh_controls_guide_texts()
	_refresh_heat_fallback_text()
	_refresh_hud_text_values()
	_refresh_hp_hud()
	_update_heat_label_text()
	_update_ammo_label_text()
	_update_weapon_state_label_text()
	if route_selection_panel and is_instance_valid(route_selection_panel) and route_selection_panel.visible:
		route_selection_panel._on_language_changed(LocalizationManager.get_locale())
	if reward_selection_panel and is_instance_valid(reward_selection_panel) and reward_selection_panel.visible:
		reward_selection_panel._on_language_changed(LocalizationManager.get_locale())
	if branch_select_panel and is_instance_valid(branch_select_panel) and branch_select_panel.visible:
		branch_select_panel._on_language_changed(LocalizationManager.get_locale())
	if module_equip_selection_panel and is_instance_valid(module_equip_selection_panel) and module_equip_selection_panel.visible:
		module_equip_selection_panel._on_language_changed(LocalizationManager.get_locale())

func _refresh_localized_static_text() -> void:
	var shop_title := shopping_panel.get_node_or_null("Title") as Label
	if shop_title:
		shop_title.text = LocalizationManager.tr_key("ui.panel.shop", "Shop")
	var upgrade_title := upgrade_panel.get_node_or_null("Title") as Label
	if upgrade_title:
		upgrade_title.text = LocalizationManager.tr_key("ui.panel.upgrade", "Upgrade")
	var gear_fuse_title := gear_fuse_panel.get_node_or_null("Title") as Label
	if gear_fuse_title:
		gear_fuse_title.text = LocalizationManager.tr_key("ui.panel.gear_fuse", "Gear Fuse")
	var module_title := module_panel.get_node_or_null("Title") as Label
	if module_title:
		module_title.text = LocalizationManager.tr_key("ui.panel.module", "Module")
	var inventory_title := inventory_panel.get_node_or_null("Title") as Label
	if inventory_title:
		inventory_title.text = LocalizationManager.tr_key("ui.panel.inventory", "Inventory")
	shop_sell_button.text = LocalizationManager.tr_key("ui.panel.sell", "Sell")
	shop_cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	var shop_confirm := shopping_panel.get_node_or_null("ShopConfirmButton") as Button
	if shop_confirm:
		shop_confirm.text = LocalizationManager.tr_key("ui.panel.confirm", "Confirm")
	var shop_refresh := shopping_panel.get_node_or_null("ShopRefreshButton") as Button
	if shop_refresh:
		shop_refresh.text = LocalizationManager.tr_key("ui.panel.refresh", "Refresh")
	var to_gf := upgrade_panel.get_node_or_null("ToGF") as Button
	if to_gf:
		to_gf.text = LocalizationManager.tr_key("ui.panel.to_gear_fuse", "To Gear Fuse")
	var upg_switch := upgrade_panel.get_node_or_null("SwtichBtn") as Button
	if upg_switch:
		upg_switch.text = LocalizationManager.tr_key("ui.panel.inventory_bag", "Inventory / Bag")
	var to_upgrade := gear_fuse_panel.get_node_or_null("ToUpgrade") as Button
	if to_upgrade:
		to_upgrade.text = LocalizationManager.tr_key("ui.panel.to_upgrade", "To Upgrade")
	var gf_switch := gear_fuse_panel.get_node_or_null("SwtichBtn") as Button
	if gf_switch:
		gf_switch.text = LocalizationManager.tr_key("ui.panel.inventory_bag", "Inventory / Bag")
	var gf_confirm := gear_fuse_panel.get_node_or_null("MarginContainer/VBoxContainer/ConfirmBtn") as Button
	if gf_confirm:
		gf_confirm.text = LocalizationManager.tr_key("ui.panel.fuse", "Fuse")
	var to_inv := module_panel.get_node_or_null("ToInv") as Button
	if to_inv:
		to_inv.text = LocalizationManager.tr_key("ui.panel.to_inventory", "Inventory")
	var to_module := inventory_panel.get_node_or_null("ToModel") as Button
	if to_module:
		to_module.text = LocalizationManager.tr_key("ui.panel.to_module", "Module")
	var pause_label := pause_menu_panel.get_node_or_null("Paused") as Label
	if pause_label:
		pause_label.text = LocalizationManager.tr_key("ui.panel.pause", "Paused")
	resume_button.text = LocalizationManager.tr_key("ui.panel.resume", "Resume")
	_refresh_controls_guide_texts()
	_refresh_pause_language_options()
	_refresh_game_over_static_text()

func _refresh_game_over_static_text() -> void:
	if game_over_title_label and is_instance_valid(game_over_title_label):
		game_over_title_label.text = LocalizationManager.tr_key("ui.gameover.title", "Game Over")
	if game_over_new_game_button and is_instance_valid(game_over_new_game_button):
		game_over_new_game_button.text = LocalizationManager.tr_key("ui.gameover.new_game", "New Game")

func debug_get_game_over_stat_texts() -> PackedStringArray:
	var output := PackedStringArray()
	if game_over_total_damage_label and is_instance_valid(game_over_total_damage_label):
		output.append(game_over_total_damage_label.text)
	if game_over_completed_levels_label and is_instance_valid(game_over_completed_levels_label):
		output.append(game_over_completed_levels_label.text)
	if game_over_enemy_kills_label and is_instance_valid(game_over_enemy_kills_label):
		output.append(game_over_enemy_kills_label.text)
	if game_over_elite_kills_label and is_instance_valid(game_over_elite_kills_label):
		output.append(game_over_elite_kills_label.text)
	if game_over_gold_earned_label and is_instance_valid(game_over_gold_earned_label):
		output.append(game_over_gold_earned_label.text)
	return output

func _refresh_heat_fallback_text() -> void:
	if heat_label and is_instance_valid(heat_label) and not heat_label.visible:
		heat_label.text = LocalizationManager.tr_key("ui.hud.heat_empty", "Heat: --")
	if ammo_label and is_instance_valid(ammo_label):
		if PlayerData.player == null or not is_instance_valid(PlayerData.player):
			ammo_label.text = LocalizationManager.tr_key("ui.hud.ammo_empty", "Ammo: --")

func _refresh_hud_text_values() -> void:
	equipped_label.text = LocalizationManager.tr_key("ui.hud.equipped", "Equipped:")
	augments_label.text = str(PlayerData.player_augment_list)
	gold_label.text = LocalizationManager.tr_format("ui.hud.gold", {"value": PlayerData.player_gold}, "Gold: %s" % str(PlayerData.player_gold))
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("get_current_energy"):
		resource_label.text = LocalizationManager.tr_format(
			"ui.hud.energy",
			{"value": int(round(PlayerData.player.get_current_energy()))},
			"Energy: %d" % int(round(PlayerData.player.get_current_energy()))
		)
	else:
		resource_label.text = LocalizationManager.tr_key("ui.hud.energy_none", "Energy: --")
	time_label.text = LocalizationManager.tr_format("ui.hud.time", {"value": PhaseManager.battle_time}, "Time: %s" % str(PhaseManager.battle_time))
