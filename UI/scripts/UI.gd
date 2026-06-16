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
const HUD_PRESENTER_SCRIPT := preload("res://UI/scripts/components/hud_presenter.gd")
const WEAPON_PASSIVE_PRESENTER_SCRIPT := preload("res://UI/scripts/components/weapon_passive_presenter.gd")
const GLOBAL_UI_THEME := preload("res://UI/themes/global_ui_theme.tres")
const SPREAD_CURSOR_OVERLAY_SCRIPT := preload("res://UI/scripts/spread_cursor_overlay.gd")
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const SPREAD_CURSOR_FALLBACK_RADIUS_PX := 10.0
const BATTLE_HARDWARE_CURSOR_SIZE := 32
const BATTLE_HARDWARE_CURSOR_COLOR := Color(0.9, 0.98, 1.0, 1.0)
const BATTLE_HARDWARE_CURSOR_RING_COLOR := Color(0.33, 0.66, 1.0, 0.38)
const BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR := Color(0.12, 0.2, 0.28, 0.9)

# Roots
@onready var gui_root: Control = $GUI
@onready var character_root : Control = $GUI/CharacterRoot
@onready var shopping_rootv_2: Control = $GUI/ShoppingRootv2
@onready var upgrade_rootv_2: Control = $GUI/UpgradeRootv2
@onready var smith_root: Control = $GUI/SmithRoot
@onready var merchant_root: Control = $GUI/MerchantRoot
@onready var module_menu_root: Control = $GUI/ModuleMenuRoot
@onready var boss_root : Control = $GUI/BossRoot
@onready var pause_menu_root : Control = $GUI/PauseMenuRoot
@onready var module_root: Control = $GUI/ModuleRoot
@onready var shopping_panel: Panel = $GUI/ShoppingRootv2/Panel
@onready var upgrade_panel: Panel = $GUI/UpgradeRootv2/Panel
@onready var module_panel: Panel = $GUI/ModuleRoot/Panel
@onready var pause_menu_panel: Panel = $GUI/PauseMenuRoot/PauseMenuPanel
@onready var merchant_primary_panel: Panel = $GUI/MerchantRoot/Panel
@onready var smith_primary_panel: Panel = $GUI/SmithRoot/Panel
@onready var module_primary_panel: Panel = $GUI/ModuleMenuRoot/Panel
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
var weapon_passive_panel: PanelContainer
var weapon_passive_list: VBoxContainer


# Shopping
@onready var shop: VBoxContainer = $GUI/ShoppingRootv2/Panel/Shop
@onready var equipped_shop: GridContainer = $GUI/ShoppingRootv2/Panel/Equipped
@onready var shop_sell_button: Button = $GUI/ShoppingRootv2/Panel/ShopSellButton
@onready var shop_cancel_button: Button = $GUI/ShoppingRootv2/Panel/ShopCancelButton
var shop_sell_summary_panel: PanelContainer
var shop_sell_summary_title: Label
var shop_sell_summary_hint: Label
var shop_sell_summary_list: VBoxContainer
var shop_sell_summary_total: Label
var shop_sell_summary_modules: Label
var shop_sell_mode_active: bool = false
var shop_instruction_label: Label
var module_shop: VBoxContainer
var shop_mode_buttons: HBoxContainer
var shop_weapon_mode_button: Button
var shop_module_mode_button: Button
var shop_detail_panel: PanelContainer
var shop_detail_title: Label
var shop_detail_subtitle: Label
var shop_detail_body: VBoxContainer
var shop_detail_scroll: ScrollContainer
var _shop_purchase_mode: StringName = &"weapon"
var _shop_hover_item: Dictionary = {}
var _shop_selected_item: Dictionary = {}
signal reset_cost

# Upgrade
@onready var equipped_upg: GridContainer = $GUI/UpgradeRootv2/Panel/Equipped
@onready var upgrade_preview: MarginContainer = $GUI/UpgradeRootv2/Panel/UpgradePreview
var upgrade_instruction_label: Label
var upgrade_action_button: Button
var upgrade_mode_buttons: HBoxContainer
var upgrade_weapon_mode_button: Button
var upgrade_module_mode_button: Button
var upgrade_item_scroll: ScrollContainer
var upgrade_item_list: VBoxContainer
var upgrade_detail_panel: PanelContainer
var upgrade_detail_title: Label
var upgrade_detail_subtitle: Label
var upgrade_detail_body: VBoxContainer
var _upgrade_mode: StringName = &"weapon"
var _upgrade_hover_item: Dictionary = {}
var _upgrade_selected_item: Dictionary = {}
var module_upgrade_scroll: ScrollContainer
var module_upgrade_list: VBoxContainer
var module_upgrade_selection_label: Label
var module_upgrade_action_button: Button
var selected_upgrade_module: Module


@onready var equipped_m: GridContainer = $GUI/ModuleRoot/Panel/EquippedM
@onready var modules: GridContainer = $GUI/ModuleRoot/Panel/TemporaryModulesScroll/Modules
@onready var module_slot_scene: PackedScene = preload("res://UI/scenes/module_slot.tscn")
var module_instruction_label: Label
var module_selection_label: Label
var module_equip_button: Button
var module_sell_button: Button
var selected_temporary_module: Module
var weapon_warehouse_button: Button
var smith_module_upgrade_button: Button

# Pause menu
@onready var resume_button = $GUI/PauseMenuRoot/PauseMenuPanel/ResumeButton

# Misc
@onready var move_out_timer = $GUI/MoveOutTimer
@onready var weapon_list = GlobalVariables.weapon_list
@onready var upgradable_weapon_list = PlayerData.player_weapon_list
@onready var item_card = preload("res://UI/scenes/margin_item_card.tscn")
@onready var upgrade_card = preload("res://UI/scenes/margin_upgrade_card.tscn")
@onready var empty_weapon_pic = preload("res://asset/images/test/empty_wp.png")
@onready var equipped_weapons = null
const BRANCH_SELECT_PANEL_PATH := "res://UI/scenes/branch_select_panel.tscn"
const MODULE_EQUIP_SELECTION_PANEL_PATH := "res://UI/scenes/module_equip_selection_panel.tscn"
const ROUTE_SELECTION_PANEL_PATH := "res://UI/scenes/route_selection_panel.tscn"
const REWARD_SELECTION_PANEL_PATH := "res://UI/scenes/reward_selection_panel.tscn"
const WEAPON_REPLACEMENT_PANEL_PATH := "res://UI/scenes/weapon_replacement_panel.tscn"
const WEAPON_WAREHOUSE_PANEL_PATH := "res://UI/scenes/weapon_warehouse_panel.tscn"
const SHOP_MODULE_SLOT_SCENE := preload("res://UI/scenes/shop_module_slot.tscn")
var branch_select_panel: BranchSelectPanel
var module_equip_selection_panel: ModuleEquipSelectionPanel
var route_selection_panel: RouteSelectionPanel
var reward_selection_panel: RewardSelectionPanel
var weapon_replacement_panel: WeaponReplacementPanel
var weapon_warehouse_panel: WeaponWarehousePanel
var _branch_selection_queue: Array[Dictionary] = []
var _rest_area_merchant_active := false
var _rest_area_primary_menu_id: StringName = &""
var game_over_title_label: Label
var game_over_new_game_button: Button
var pause_language_label: Label
var pause_language_option: OptionButton
var temporary_module_confirm_toggle: CheckButton
var module_action_dialog: ConfirmationDialog
var temporary_module_settlement_dialog: ConfirmationDialog
var temporary_module_settlement_message: Label
var temporary_module_settlement_checkbox: CheckBox
var _pending_module_action := Callable()
var _pending_battle_start := Callable()
var _pending_battle_start_cancel := Callable()
const MODULE_SETTINGS_PATH := "user://module_management_settings.cfg"
var controls_hint_panel: Panel
var controls_hint_title_label: Label
var controls_hint_body_label: Label
var _primary_menu_tweens: Dictionary = {}
var spread_cursor_overlay
var _cursor_reload_total_by_weapon: Dictionary = {}
var _battle_hardware_cursor_tex: Texture2D
var _battle_hardware_cursor_applied: bool = false
var _battle_hardware_cursor_state_key: String = ""
var hud_presenter: HudPresenter
var weapon_passive_presenter
var _weapon_passive_rows: Array[Dictionary] = []


func _ready():
	GlobalVariables.ui = self
	# Reduce input-to-render latency for custom cursor overlays.
	Input.use_accumulated_input = false
	_battle_hardware_cursor_tex = _build_battle_hardware_cursor_texture()
	gui_root.theme = GLOBAL_UI_THEME
	_ensure_heat_label()
	_ensure_ammo_label()
	_ensure_resource_label_under_hp()
	_ensure_weapon_state_label()
	_init_weapon_passive_presenter()
	_ensure_weapon_passive_panel()
	_init_hud_presenter()
	_ensure_spread_cursor_overlay()
	_create_game_over_layout()
	_create_controls_hint_panel()
	_ensure_pause_language_controls()
	_init_module_action_dialogs()
	_init_shop_sell_summary()
	_init_management_ui_polish()
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
	call_deferred("_refresh_initial_prepare_shop")
	call_deferred("_restore_pending_equipment_transactions")

func _refresh_initial_prepare_shop() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	reset_shopping_refresh_cost()

func _restore_pending_equipment_transactions() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if InventoryData.pending_transactions.is_empty():
		return
	var transaction := InventoryData.pending_transactions[0] as Dictionary
	match str(transaction.get("type", "")):
		"weapon_replacement":
			var weapon := DataHandler.instantiate_weapon_from_save_payload(
				transaction.get("weapon", {}) as Dictionary
			)
			if weapon:
				request_weapon_replacement(
					weapon,
					bool(transaction.get("allow_cancel", true))
				)
			else:
				InventoryData.finish_pending_transaction(str(transaction.get("id", "")))
		"module_assignment":
			var scene_path := str(transaction.get("scene_path", ""))
			var module_instance := InventoryData.find_owned_module_by_scene_path(scene_path)
			if module_instance:
				request_module_equip_selection(module_instance, Callable(), true)
			else:
				InventoryData.finish_pending_transaction(str(transaction.get("id", "")))
		_:
			InventoryData.finish_pending_transaction(str(transaction.get("id", "")))

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
	if branch_select_panel != null and is_instance_valid(branch_select_panel):
		return
	var panel_scene := load(BRANCH_SELECT_PANEL_PATH) as PackedScene
	branch_select_panel = panel_scene.instantiate() as BranchSelectPanel if panel_scene else null
	if branch_select_panel == null:
		push_warning("Failed to create BranchSelectPanel.")
		return
	$GUI.add_child(branch_select_panel)
	branch_select_panel.visible = false
	if not branch_select_panel.is_connected("branch_selected", Callable(self, "_on_branch_selected")):
		branch_select_panel.connect("branch_selected", Callable(self, "_on_branch_selected"))

func _init_module_equip_selection_panel() -> void:
	if module_equip_selection_panel != null and is_instance_valid(module_equip_selection_panel):
		return
	var panel_scene := load(MODULE_EQUIP_SELECTION_PANEL_PATH) as PackedScene
	module_equip_selection_panel = panel_scene.instantiate() as ModuleEquipSelectionPanel if panel_scene else null
	if module_equip_selection_panel == null:
		push_warning("Failed to create ModuleEquipSelectionPanel.")
		return
	$GUI.add_child(module_equip_selection_panel)
	module_equip_selection_panel.visible = false

func _init_route_selection_panel() -> void:
	if route_selection_panel != null and is_instance_valid(route_selection_panel):
		return
	var panel_scene := load(ROUTE_SELECTION_PANEL_PATH) as PackedScene
	route_selection_panel = panel_scene.instantiate() as RouteSelectionPanel if panel_scene else null
	if route_selection_panel == null:
		push_warning("Failed to create RouteSelectionPanel.")
		return
	$GUI.add_child(route_selection_panel)
	route_selection_panel.visible = false

func _init_reward_selection_panel() -> void:
	if reward_selection_panel != null and is_instance_valid(reward_selection_panel):
		return
	var panel_scene := load(REWARD_SELECTION_PANEL_PATH) as PackedScene
	reward_selection_panel = panel_scene.instantiate() as RewardSelectionPanel if panel_scene else null
	if reward_selection_panel == null:
		push_warning("Failed to create RewardSelectionPanel.")
		return
	$GUI.add_child(reward_selection_panel)
	reward_selection_panel.visible = false

func _init_weapon_replacement_panel() -> void:
	if weapon_replacement_panel != null and is_instance_valid(weapon_replacement_panel):
		return
	var panel_scene := load(WEAPON_REPLACEMENT_PANEL_PATH) as PackedScene
	weapon_replacement_panel = panel_scene.instantiate() as WeaponReplacementPanel if panel_scene else null
	if weapon_replacement_panel == null:
		push_warning("Failed to create WeaponReplacementPanel.")
		return
	$GUI.add_child(weapon_replacement_panel)
	weapon_replacement_panel.visible = false

func _init_weapon_warehouse_panel() -> void:
	if weapon_warehouse_panel and is_instance_valid(weapon_warehouse_panel):
		return
	var panel_scene := load(WEAPON_WAREHOUSE_PANEL_PATH) as PackedScene
	weapon_warehouse_panel = panel_scene.instantiate() as WeaponWarehousePanel if panel_scene else null
	if weapon_warehouse_panel == null:
		push_warning("Failed to create WeaponWarehousePanel.")
		return
	$GUI.add_child(weapon_warehouse_panel)

func request_weapon_replacement(
	weapon: Weapon,
	allow_cancel: bool = true,
	on_complete: Callable = Callable()
) -> bool:
	_init_weapon_replacement_panel()
	if weapon_replacement_panel == null or not is_instance_valid(weapon_replacement_panel):
		return false
	return weapon_replacement_panel.open_for_weapon(weapon, allow_cancel, on_complete)

func _init_shop_sell_summary() -> void:
	if shop_sell_summary_panel and is_instance_valid(shop_sell_summary_panel):
		return
	shop_sell_summary_panel = PanelContainer.new()
	shop_sell_summary_panel.name = "ShopSellSummary"
	shop_sell_summary_panel.position = Vector2(25.0, 50.0)
	shop_sell_summary_panel.size = Vector2(500.0, 500.0)
	shop_sell_summary_panel.custom_minimum_size = Vector2(500.0, 500.0)
	shop_sell_summary_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.09, 0.96)
	style.border_color = Color(0.78, 0.24, 0.18, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	shop_sell_summary_panel.add_theme_stylebox_override("panel", style)
	shopping_panel.add_child(shop_sell_summary_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	shop_sell_summary_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	shop_sell_summary_title = Label.new()
	shop_sell_summary_title.add_theme_font_size_override("font_size", 26)
	shop_sell_summary_title.add_theme_color_override("font_color", Color(1.0, 0.48, 0.36))
	content.add_child(shop_sell_summary_title)
	shop_sell_summary_hint = Label.new()
	shop_sell_summary_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_sell_summary_hint.modulate = Color(0.82, 0.86, 0.9)
	content.add_child(shop_sell_summary_hint)
	var separator := HSeparator.new()
	content.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	shop_sell_summary_list = VBoxContainer.new()
	shop_sell_summary_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_sell_summary_list.add_theme_constant_override("separation", 8)
	scroll.add_child(shop_sell_summary_list)
	shop_sell_summary_modules = Label.new()
	shop_sell_summary_modules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(shop_sell_summary_modules)
	shop_sell_summary_total = Label.new()
	shop_sell_summary_total.add_theme_font_size_override("font_size", 22)
	shop_sell_summary_total.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	content.add_child(shop_sell_summary_total)
	refresh_shop_sell_summary()

func set_shop_sell_mode(enabled: bool) -> void:
	shop_sell_mode_active = enabled
	InventoryData.clear_on_select()
	for slot: EquipmentSlotShop in equipped_shop.get_children():
		slot.sell_mode = enabled
		slot.reset_sell_status()
	shop_sell_button.visible = not enabled
	var shop_confirm := shopping_panel.get_node_or_null("ShopConfirmButton") as Button
	if shop_confirm:
		shop_confirm.visible = enabled
	shop_cancel_button.visible = enabled
	var shop_back := shopping_panel.get_node_or_null("BackToMerchantMenu") as Button
	if shop_back:
		shop_back.visible = not enabled
	var shop_refresh := shopping_panel.get_node_or_null("ShopRefreshButton") as Button
	if shop_refresh:
		shop_refresh.visible = not enabled
	shop.visible = not enabled
	if module_shop:
		var module_scroll := module_shop.get_parent() as Control
		if module_scroll:
			module_scroll.visible = not enabled
	if shop_mode_buttons:
		shop_mode_buttons.visible = not enabled
	if shop_detail_panel:
		shop_detail_panel.visible = not enabled
	if shop_sell_summary_panel:
		shop_sell_summary_panel.visible = enabled
	_refresh_shop_mode_title()
	refresh_shop_sell_summary()
	if not enabled:
		_apply_shop_purchase_mode(_shop_purchase_mode)

func _refresh_shop_mode_title() -> void:
	var shop_title := shopping_panel.get_node_or_null("Title") as Label
	if shop_title:
		shop_title.text = LocalizationManager.tr_key(
			"ui.shop.sell.panel_title" if shop_sell_mode_active else "ui.panel.purchase",
			"Sell Weapons" if shop_sell_mode_active else "Purchase"
		)

func refresh_shop_sell_summary() -> void:
	if shop_sell_summary_list == null:
		return
	for child in shop_sell_summary_list.get_children():
		shop_sell_summary_list.remove_child(child)
		child.queue_free()
	var total_gold := 0
	var module_count := 0
	var valid_count := 0
	for weapon_ref in InventoryData.ready_to_sell_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		valid_count += 1
		var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
		var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		var base_price := int(weapon_def.price) if weapon_def else 0
		var gold := GlobalVariables.economy_data.get_duplicate_weapon_gold(base_price) \
			if GlobalVariables.economy_data else EconomyConfig.new().get_duplicate_weapon_gold(base_price)
		var weapon_modules := weapon.get_module_count()
		total_gold += gold
		module_count += weapon_modules
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = LocalizationManager.tr_format(
			"ui.shop.sell.row",
			{
				"name": LocalizationManager.get_weapon_name_from_node(weapon),
				"level": int(weapon.level),
				"fuse": int(weapon.fuse),
				"gold": gold,
				"modules": weapon_modules,
			},
			"%s  Lv.%d  Fuse %d  |  +%d Gold  |  %d modules" % [
				LocalizationManager.get_weapon_name_from_node(weapon),
				int(weapon.level),
				int(weapon.fuse),
				gold,
				weapon_modules,
			]
		)
		shop_sell_summary_list.add_child(row)
	if valid_count == 0:
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key(
			"ui.shop.sell.empty",
			"Click a weapon on the right to mark it for sale."
		)
		empty.modulate = Color(0.68, 0.72, 0.76)
		shop_sell_summary_list.add_child(empty)
	shop_sell_summary_modules.text = LocalizationManager.tr_format(
		"ui.shop.sell.modules",
		{"count": module_count},
		"Equipped modules moved to temporary storage: %d" % module_count
	)
	shop_sell_summary_total.text = LocalizationManager.tr_format(
		"ui.shop.sell.total",
		{"count": valid_count, "gold": total_gold},
		"Selected: %d    Total refund: +%d Gold" % [valid_count, total_gold]
	)
	var shop_confirm := shopping_panel.get_node_or_null("ShopConfirmButton") as Button
	if shop_confirm:
		shop_confirm.disabled = valid_count == 0

func _init_module_action_dialogs() -> void:
	module_action_dialog = ConfirmationDialog.new()
	module_action_dialog.name = "ModuleActionDialog"
	$GUI.add_child(module_action_dialog)
	module_action_dialog.confirmed.connect(_on_module_action_confirmed)
	_connect_right_cancel_window(module_action_dialog)
	temporary_module_settlement_dialog = ConfirmationDialog.new()
	temporary_module_settlement_dialog.name = "TemporaryModuleSettlementDialog"
	temporary_module_settlement_dialog.dialog_text = ""
	temporary_module_settlement_dialog.wrap_controls = false
	$GUI.add_child(temporary_module_settlement_dialog)
	_connect_right_cancel_window(temporary_module_settlement_dialog)
	var content := VBoxContainer.new()
	content.name = "SettlementContent"
	content.custom_minimum_size = Vector2(480.0, 0.0)
	temporary_module_settlement_message = Label.new()
	temporary_module_settlement_message.name = "Message"
	temporary_module_settlement_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(temporary_module_settlement_message)
	temporary_module_settlement_checkbox = CheckBox.new()
	temporary_module_settlement_checkbox.text = LocalizationManager.tr_key(
		"ui.module.settlement.dont_show",
		"Do not show this confirmation again"
	)
	content.add_child(temporary_module_settlement_checkbox)
	temporary_module_settlement_dialog.add_child(content)
	temporary_module_settlement_dialog.confirmed.connect(_on_temporary_module_settlement_confirmed)
	temporary_module_settlement_dialog.canceled.connect(_on_temporary_module_settlement_cancelled)

func _connect_right_cancel_window(dialog: Window) -> void:
	if dialog == null or not dialog.has_signal("window_input"):
		return
	var callback := Callable(self, "_on_cancel_window_input")
	if not dialog.is_connected("window_input", callback):
		dialog.connect("window_input", callback)

func _on_cancel_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("CANCEL") \
			and PhaseManager.current_state() != PhaseManager.BATTLE \
			and handle_non_battle_right_cancel():
		get_viewport().set_input_as_handled()

func request_module_unequip_confirmation(module_instance: Module, weapon: Weapon) -> bool:
	if module_instance == null or weapon == null:
		return false
	module_action_dialog.title = LocalizationManager.tr_key("ui.module.unequip.title", "Unequip Module")
	module_action_dialog.dialog_text = LocalizationManager.tr_format(
		"ui.module.unequip.confirm",
		{
			"module": LocalizationManager.get_module_name(module_instance),
			"weapon": LocalizationManager.get_weapon_name_from_node(weapon),
		},
		"Move %s from %s to the temporary area? Unsold modules are sold when battle starts." % [
			LocalizationManager.get_module_name(module_instance),
			LocalizationManager.get_weapon_name_from_node(weapon),
		]
	)
	_pending_module_action = Callable(self, "_confirm_module_unequip").bind(module_instance, weapon)
	module_action_dialog.popup_centered()
	return true

func _confirm_module_unequip(module_instance: Module, weapon: Weapon) -> void:
	var result := InventoryData.unequip_module_from_weapon(module_instance, weapon)
	if not result.get("ok", false):
		show_item_message(LocalizationManager.localize_module_reason(str(result.get("reason", ""))), 1.8)

func request_temporary_module_sell_confirmation(module_instance: Module) -> bool:
	if module_instance == null or not InventoryData.temporary_modules.has(module_instance):
		return false
	var gold := GlobalVariables.economy_data.get_duplicate_module_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	) if GlobalVariables.economy_data else 0
	module_action_dialog.title = LocalizationManager.tr_key("ui.module.sell.title", "Sell Module")
	module_action_dialog.dialog_text = LocalizationManager.tr_format(
		"ui.module.sell.confirm",
		{
			"module": LocalizationManager.get_module_name(module_instance),
			"level": module_instance.module_level,
			"gold": gold,
		},
		"Sell %s Lv.%d for %d Gold? This cannot be undone." % [
			LocalizationManager.get_module_name(module_instance),
			module_instance.module_level,
			gold,
		]
	)
	_pending_module_action = Callable(self, "_confirm_temporary_module_sell").bind(module_instance)
	module_action_dialog.popup_centered()
	return true

func _confirm_temporary_module_sell(module_instance: Module) -> void:
	InventoryData.sell_temporary_module(module_instance)
	if selected_temporary_module == module_instance:
		selected_temporary_module = null
	update_modules()

func _on_module_action_confirmed() -> void:
	if _pending_module_action.is_valid():
		_pending_module_action.call()
	_pending_module_action = Callable()

func request_temporary_module_settlement(
	on_complete: Callable,
	on_cancel: Callable = Callable()
) -> bool:
	if has_pending_blocking_transaction():
		show_item_message(LocalizationManager.tr_key(
			"ui.transaction.pending",
			"Finish or cancel the current equipment transaction first."
		), 1.8)
		if on_cancel.is_valid():
			on_cancel.call_deferred()
		return false
	if InventoryData.temporary_modules.is_empty():
		on_complete.call_deferred()
		return true
	_pending_battle_start = on_complete
	_pending_battle_start_cancel = on_cancel
	if not _is_temporary_module_confirmation_enabled():
		InventoryData.sell_all_temporary_modules()
		on_complete.call_deferred()
		_pending_battle_start = Callable()
		_pending_battle_start_cancel = Callable()
		return true
	var total_gold := 0
	for module_instance in InventoryData.temporary_modules:
		total_gold += GlobalVariables.economy_data.get_duplicate_module_gold(
			int(module_instance.cost),
			int(module_instance.module_level)
		) if GlobalVariables.economy_data else 0
	if temporary_module_settlement_message:
		temporary_module_settlement_message.text = LocalizationManager.tr_format(
			"ui.module.settlement.confirm",
			{"count": InventoryData.temporary_modules.size(), "gold": total_gold},
			"Sell %d temporary modules for %d Gold and start battle?" % [
				InventoryData.temporary_modules.size(),
				total_gold,
			]
		)
	temporary_module_settlement_checkbox.button_pressed = false
	temporary_module_settlement_dialog.title = LocalizationManager.tr_key(
		"ui.module.settlement.title",
		"Temporary Module Settlement"
	)
	temporary_module_settlement_dialog.popup_centered_clamped(Vector2i(560, 260), 0.8)
	return true

func _on_temporary_module_settlement_confirmed() -> void:
	if temporary_module_settlement_checkbox.button_pressed:
		_set_temporary_module_confirmation_enabled(false)
	InventoryData.sell_all_temporary_modules()
	if _pending_battle_start.is_valid():
		_pending_battle_start.call_deferred()
	_pending_battle_start = Callable()
	_pending_battle_start_cancel = Callable()

func _on_temporary_module_settlement_cancelled() -> void:
	if _pending_battle_start_cancel.is_valid():
		_pending_battle_start_cancel.call_deferred()
	_pending_battle_start = Callable()
	_pending_battle_start_cancel = Callable()

func has_pending_blocking_transaction() -> bool:
	if has_pending_branch_selection():
		return true
	if weapon_replacement_panel and weapon_replacement_panel.visible:
		return true
	if module_equip_selection_panel and module_equip_selection_panel.visible:
		return true
	return false

func _is_temporary_module_confirmation_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(MODULE_SETTINGS_PATH) != OK:
		return true
	return bool(cfg.get_value("module_management", "confirm_temporary_sale", true))

func _set_temporary_module_confirmation_enabled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(MODULE_SETTINGS_PATH)
	cfg.set_value("module_management", "confirm_temporary_sale", enabled)
	cfg.save(MODULE_SETTINGS_PATH)
	if temporary_module_confirm_toggle:
		temporary_module_confirm_toggle.button_pressed = enabled

func request_weapon_branch_selection(weapon: Weapon, target_fuse: int = 0) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	_init_branch_select_panel()
	if branch_select_panel == null or not is_instance_valid(branch_select_panel):
		return false
	var resolved_target_fuse := target_fuse if target_fuse > 0 else int(weapon.fuse)
	_branch_selection_queue.append({
		"weapon": weakref(weapon),
		"weapon_id": DataHandler.get_weapon_id_from_instance(weapon),
		"target_fuse": resolved_target_fuse,
	})
	_request_next_queued_weapon_branch_selection()
	return true

func has_pending_branch_selection() -> bool:
	return not _branch_selection_queue.is_empty() or (branch_select_panel != null and is_instance_valid(branch_select_panel) and branch_select_panel.visible)

func is_branch_selection_blocking_interactions() -> bool:
	return has_pending_branch_selection()

func _is_branch_selection_safe_state() -> bool:
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		return false
	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		return false
	return true

func _warn_skipped_branch_selection(weapon_id: String, target_fuse: int, reason: String) -> void:
	push_warning("Skipped branch selection for weapon id=%s fuse=%d: %s" % [weapon_id, target_fuse, reason])
	var message := ""
	if reason == "no_options":
		message = LocalizationManager.tr_key("ui.branch.no_options", "No evolution branch is configured for this weapon.")
	elif reason == "missing_weapon":
		message = LocalizationManager.tr_key("ui.branch.missing_weapon", "Evolution choice skipped because the weapon is no longer available.")
	if message != "":
		show_item_message(message, 2.0)

func _open_branch_panel_for_queue_entry(entry: Dictionary) -> bool:
	var weapon_ref: WeakRef = entry.get("weapon", null)
	var queued_weapon := weapon_ref.get_ref() as Weapon if weapon_ref else null
	var weapon_id := str(entry.get("weapon_id", ""))
	var target_fuse := int(entry.get("target_fuse", 0))
	if queued_weapon == null or not is_instance_valid(queued_weapon):
		_warn_skipped_branch_selection(weapon_id, target_fuse, "missing_weapon")
		return false
	var branch_options := queued_weapon.branch_runtime.get_branch_options()
	if branch_options.is_empty():
		_warn_skipped_branch_selection(weapon_id, target_fuse, "no_options")
		return false
	branch_select_panel.open_for_weapon(queued_weapon, branch_options)
	return true

func _request_next_queued_weapon_branch_selection() -> void:
	if branch_select_panel == null or not is_instance_valid(branch_select_panel):
		_branch_selection_queue.clear()
		return
	if branch_select_panel.visible:
		return
	if TaskRewardManager.is_reward_blocking_interactions():
		return
	if not _is_branch_selection_safe_state():
		return
	while not _branch_selection_queue.is_empty():
		var entry: Dictionary = _branch_selection_queue.pop_front()
		if _open_branch_panel_for_queue_entry(entry):
			return

func request_module_equip_selection(
	module_instance: Module,
	on_complete: Callable = Callable(),
	allow_reward_transaction: bool = false
) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	if not allow_reward_transaction and not is_rest_area_module_management_available():
		show_item_message(LocalizationManager.tr_key(
			"ui.module.reason.rest_area_only",
			"Modules can only be managed in the Rest Area."
		), 1.8)
		return false
	_init_module_equip_selection_panel()
	if module_equip_selection_panel == null or not is_instance_valid(module_equip_selection_panel):
		return false
	var transaction_id := "module:%s" % str(module_instance.scene_file_path)
	InventoryData.begin_pending_transaction({
		"id": transaction_id,
		"type": "module_assignment",
		"scene_path": str(module_instance.scene_file_path),
	})
	var wrapped_complete := Callable(self, "_on_module_assignment_completed").bind(
		transaction_id,
		on_complete
	)
	return module_equip_selection_panel.open_for_module(
		module_instance,
		wrapped_complete,
		allow_reward_transaction
	)

func _on_module_assignment_completed(
	assigned: bool,
	transaction_id: String,
	on_complete: Callable
) -> void:
	InventoryData.finish_pending_transaction(transaction_id)
	if on_complete.is_valid():
		on_complete.call_deferred(assigned)

func request_route_selection(
	route_defs: Array[RunRouteDefinition],
	default_route_id: String,
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable()
) -> bool:
	if TaskRewardManager.is_reward_blocking_interactions():
		return false
	if is_branch_selection_blocking_interactions():
		show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return false
	_init_route_selection_panel()
	if route_selection_panel == null or not is_instance_valid(route_selection_panel):
		return false
	return route_selection_panel.open_for_routes(route_defs, default_route_id, on_confirm, on_cancel)

func request_reward_selection(
	route_display_name: String,
	reward_options: Array[RewardInfo],
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable(),
	allow_cancel: bool = true
) -> bool:
	if is_branch_selection_blocking_interactions():
		show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return false
	_init_reward_selection_panel()
	if reward_selection_panel == null or not is_instance_valid(reward_selection_panel):
		return false
	return reward_selection_panel.open_for_rewards(route_display_name, reward_options, on_confirm, on_cancel, allow_cancel)

func request_task_reward_selection(
	reward_options: Array[RewardInfo],
	on_confirm: Callable
) -> bool:
	_init_reward_selection_panel()
	if reward_selection_panel == null or not is_instance_valid(reward_selection_panel):
		return false
	return reward_selection_panel.open_for_rewards(
		LocalizationManager.tr_key("ui.task_reward.source", "Completed Objective"),
		reward_options,
		on_confirm,
		Callable(),
		false,
		LocalizationManager.tr_key("ui.task_reward.title", "Objective Reward"),
		LocalizationManager.tr_key(
			"ui.task_reward.subtitle",
			"Choose one reward for completing an objective this battle."
		)
	)

func resume_pending_weapon_branch_selection() -> void:
	_request_next_queued_weapon_branch_selection()

func _on_branch_selected(weapon: Weapon, branch_id: String) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.branch_runtime.set_branch(branch_id):
		push_warning("Failed to apply branch '%s' for weapon '%s'." % [branch_id, weapon.name])
	call_deferred("_finalize_branch_selected_weapon", weapon)

func _finalize_branch_selected_weapon(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var is_already_owned := PlayerData.player_weapon_list.has(weapon)
	if not is_already_owned:
		PlayerData.player.create_weapon(weapon)
	update_upg()
	refresh_border()
	_request_next_queued_weapon_branch_selection()


func _physics_process(_delta):
	#Character
	hud_presenter.refresh_dynamic_texts()
	_refresh_weapon_passive_panel()
	_refresh_controls_hint_visibility()
	_update_rest_area_hover_hint_position()
	_refresh_shop_purchase_action()

func _init_hud_presenter() -> void:
	if hud_presenter and is_instance_valid(hud_presenter):
		return
	hud_presenter = HUD_PRESENTER_SCRIPT.new() as HudPresenter
	if hud_presenter == null:
		return
	hud_presenter.bind_nodes(
		hp_bar,
		hp_label_text,
		heat_label,
		ammo_label,
		weapon_state_label,
		gold_label,
		resource_label,
		time_label,
		equipped_label,
		augments_label
	)
	hud_presenter.configure_hp_bar_anim(HP_BAR_ANIM_TIME, HP_BAR_TRANS, HP_BAR_EASE)
	hud_presenter.init_hp_bar()
	hud_presenter.refresh_static_texts()

func _init_weapon_passive_presenter() -> void:
	if weapon_passive_presenter != null:
		return
	weapon_passive_presenter = WEAPON_PASSIVE_PRESENTER_SCRIPT.new()

func _process(_delta: float) -> void:
	# Cursor-follow visuals should run on render frames to minimize perceived mouse lag.
	_update_spread_cursor_overlay()
func _input(_event) -> void:
	if _event is InputEventMouseMotion:
		var motion := _event as InputEventMouseMotion
		_update_spread_cursor_overlay(motion.position)

	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		return
	if _event.is_action_pressed("CANCEL") \
			and PhaseManager.current_state() != PhaseManager.BATTLE \
			and handle_non_battle_right_cancel():
		get_viewport().set_input_as_handled()
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
	if is_branch_selection_blocking_interactions():
		show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	move_out_timer.stop()
	set_shop_sell_mode(false)
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
	if weapon_warehouse_panel:
		weapon_warehouse_panel.close_panel()
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
	_apply_shop_purchase_mode(&"weapon")

func merchant_open_module_buy_panel() -> void:
	var should_wait := merchant_root != null and merchant_root.visible
	_hide_primary_menu(&"merchant", merchant_root, merchant_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	shopping_panel_in()
	_apply_shop_purchase_mode(&"module")

func merchant_open_sell_panel() -> void:
	var should_wait := merchant_root != null and merchant_root.visible
	_hide_primary_menu(&"merchant", merchant_root, merchant_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	_init_weapon_warehouse_panel()
	if weapon_warehouse_panel:
		weapon_warehouse_panel.open_panel()

func warehouse_back_to_merchant() -> void:
	if weapon_warehouse_panel:
		weapon_warehouse_panel.close_panel()
	shopping_panel_out()
	if _rest_area_primary_menu_id == &"module":
		_show_primary_menu(&"module", module_menu_root, module_primary_panel)
	else:
		_show_primary_menu(&"merchant", merchant_root, merchant_primary_panel)

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

func is_rest_area_menu_visible() -> bool:
	if not _rest_area_merchant_active:
		return false
	if _is_primary_menu_open() or _is_secondary_menu_open():
		return true
	if weapon_warehouse_panel and is_instance_valid(weapon_warehouse_panel) and weapon_warehouse_panel.visible:
		return true
	if module_equip_selection_panel and is_instance_valid(module_equip_selection_panel) and module_equip_selection_panel.visible:
		return true
	return false

func is_rest_area_zone_navigation_allowed() -> bool:
	if TaskRewardManager.is_reward_blocking_interactions():
		return false
	if not _rest_area_merchant_active:
		return true
	if _rest_area_primary_menu_id == &"merchant" and merchant_root and merchant_root.visible:
		return true
	if _rest_area_primary_menu_id == &"smith" and smith_root and smith_root.visible:
		return true
	if _rest_area_primary_menu_id == &"module" and module_menu_root and module_menu_root.visible:
		return true
	return false

func handle_rest_area_right_cancel() -> bool:
	if _cancel_top_level_non_battle_ui():
		return true
	if not _rest_area_merchant_active:
		return false
	# Secondary menu should step back to primary menu first.
	if _rest_area_primary_menu_id == &"merchant":
		if weapon_warehouse_panel and weapon_warehouse_panel.visible:
			weapon_warehouse_panel.close_panel()
			_show_primary_menu(&"merchant", merchant_root, merchant_primary_panel)
			return true
		if shopping_rootv_2 and shopping_rootv_2.visible:
			merchant_back_to_primary_menu()
			return true
	elif _rest_area_primary_menu_id == &"smith":
		if upgrade_rootv_2 and upgrade_rootv_2.visible:
			smith_back_to_primary_menu()
			return true
	elif _rest_area_primary_menu_id == &"module":
		if weapon_warehouse_panel and weapon_warehouse_panel.visible:
			weapon_warehouse_panel.close_panel()
			_show_primary_menu(&"module", module_menu_root, module_primary_panel)
			return true
		if module_equip_selection_panel and module_equip_selection_panel.visible:
			module_equip_selection_panel.close_without_assignment()
			return true
		if module_root and module_root.visible:
			module_back_to_primary_menu()
			return true
	return false

func handle_non_battle_right_cancel() -> bool:
	return _cancel_top_level_non_battle_ui()

func _cancel_top_level_non_battle_ui() -> bool:
	if temporary_module_settlement_dialog and temporary_module_settlement_dialog.visible:
		temporary_module_settlement_dialog.hide()
		_on_temporary_module_settlement_cancelled()
		return true
	if module_action_dialog and module_action_dialog.visible:
		module_action_dialog.hide()
		_pending_module_action = Callable()
		return true
	if weapon_replacement_panel and weapon_replacement_panel.visible:
		weapon_replacement_panel.call("_on_cancel_pressed")
		return not weapon_replacement_panel.visible
	if route_selection_panel and route_selection_panel.visible:
		route_selection_panel.call("_on_cancel_pressed")
		return not route_selection_panel.visible
	if reward_selection_panel and reward_selection_panel.visible:
		reward_selection_panel.call("_on_cancel_pressed")
		return not reward_selection_panel.visible
	if module_equip_selection_panel and module_equip_selection_panel.visible:
		module_equip_selection_panel.close_without_assignment()
		return true
	if _rest_area_merchant_active:
		return _cancel_rest_area_menu_level()
	return false

func _cancel_rest_area_menu_level() -> bool:
	if _rest_area_primary_menu_id == &"merchant":
		if weapon_warehouse_panel and weapon_warehouse_panel.visible:
			weapon_warehouse_panel.close_panel()
			_show_primary_menu(&"merchant", merchant_root, merchant_primary_panel)
			return true
		if shopping_rootv_2 and shopping_rootv_2.visible:
			if shop_sell_mode_active:
				set_shop_sell_mode(false)
				return true
			merchant_back_to_primary_menu()
			return true
		if merchant_root and merchant_root.visible:
			close_rest_area_primary_menu()
			return true
	elif _rest_area_primary_menu_id == &"smith":
		if upgrade_rootv_2 and upgrade_rootv_2.visible:
			smith_back_to_primary_menu()
			return true
		if smith_root and smith_root.visible:
			close_rest_area_primary_menu()
			return true
	elif _rest_area_primary_menu_id == &"module":
		if weapon_warehouse_panel and weapon_warehouse_panel.visible:
			weapon_warehouse_panel.close_panel()
			_show_primary_menu(&"module", module_menu_root, module_primary_panel)
			return true
		if module_root and module_root.visible:
			module_back_to_primary_menu()
			return true
		if module_menu_root and module_menu_root.visible:
			close_rest_area_primary_menu()
			return true
	return false

func open_rest_area_smith_menu() -> void:
	_rest_area_merchant_active = true
	_rest_area_primary_menu_id = &"smith"
	PlayerData.is_interacting = true
	smith_menu_in()

func open_rest_area_module_menu() -> void:
	_rest_area_merchant_active = true
	_rest_area_primary_menu_id = &"module"
	PlayerData.is_interacting = true
	module_menu_in()

func close_rest_area_primary_menu() -> void:
	if not _rest_area_merchant_active:
		return
	if _rest_area_primary_menu_id == &"smith":
		smith_menu_out()
	elif _rest_area_primary_menu_id == &"module":
		module_menu_out()
	else:
		merchant_menu_out()
	PlayerData.is_interacting = false
	_rest_area_merchant_active = false
	_rest_area_primary_menu_id = &""

func reset_shopping_refresh_cost() -> void:
	reset_cost.emit()
	refresh_shop_items_for_prepare()

func refresh_shop_items_for_prepare() -> void:
	var shop_refresh := shopping_panel.get_node_or_null("ShopRefreshButton")
	if shop_refresh != null and shop_refresh.has_method("refresh_shop_items"):
		shop_refresh.call("refresh_shop_items")
		return
	for slot in shop.get_children():
		var shop_slot := slot as ShopWeaponSlot
		if shop_slot == null:
			continue
		shop_slot.new_item()
		shop_slot.update()
	if module_shop:
		for slot in module_shop.get_children():
			if slot.has_method("new_item"):
				slot.call("new_item")
			if slot.has_method("update"):
				slot.call("update")

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
	if is_branch_selection_blocking_interactions():
		show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return
	_apply_upgrade_mode(_upgrade_mode)
	update_upg()
	if smith_root:
		smith_root.visible = false
	upgrade_rootv_2.visible = true
	equipped_upg.visible = false

func upg_panel_out() -> void:
	upgrade_rootv_2.visible = false
	InventoryData.clear_on_select()
	_upgrade_hover_item = {}
	_upgrade_selected_item = {}
	refresh_border()

func smith_menu_in() -> void:
	upg_panel_out()
	_show_primary_menu(&"smith", smith_root, smith_primary_panel)

func smith_menu_out() -> void:
	_hide_primary_menu(&"smith", smith_root, smith_primary_panel)
	upg_panel_out()

func smith_open_upgrade_panel(mode: StringName = &"weapon") -> void:
	var should_wait := smith_root != null and smith_root.visible
	_hide_primary_menu(&"smith", smith_root, smith_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	_apply_upgrade_mode(mode)
	upg_panel_in()

func smith_open_weapon_upgrade_panel() -> void:
	smith_open_upgrade_panel(&"weapon")

func smith_open_module_upgrade_panel() -> void:
	smith_open_upgrade_panel(&"module")

func smith_back_to_primary_menu() -> void:
	upg_panel_out()
	_show_primary_menu(&"smith", smith_root, smith_primary_panel)

func module_menu_in() -> void:
	module_panel_out()
	_show_primary_menu(&"module", module_menu_root, module_primary_panel)

func module_menu_out() -> void:
	_hide_primary_menu(&"module", module_menu_root, module_primary_panel)
	module_panel_out()
	if module_equip_selection_panel and module_equip_selection_panel.visible:
		module_equip_selection_panel.close_without_assignment()
	InventoryData.clear_on_select()

func module_open_management_panel() -> void:
	if not is_rest_area_module_management_available():
		_show_module_rest_area_only_message()
		return
	var should_wait := module_menu_root != null and module_menu_root.visible
	_hide_primary_menu(&"module", module_menu_root, module_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	module_panel_in()

func module_open_weapon_warehouse_panel() -> void:
	var should_wait := module_menu_root != null and module_menu_root.visible
	_hide_primary_menu(&"module", module_menu_root, module_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	_init_weapon_warehouse_panel()
	if weapon_warehouse_panel:
		weapon_warehouse_panel.open_panel()

func module_back_to_primary_menu() -> void:
	if module_equip_selection_panel and module_equip_selection_panel.visible:
		module_equip_selection_panel.close_without_assignment()
	module_panel_out()
	_show_primary_menu(&"module", module_menu_root, module_primary_panel)

func module_panel_in() -> void:
	if not is_rest_area_module_management_available():
		_show_module_rest_area_only_message()
		return
	update_modules()
	module_root.visible = true

func module_panel_out() -> void:
	module_root.visible = false

func is_rest_area_module_management_available() -> bool:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return false
	for node in get_tree().get_nodes_in_group("rest_area"):
		if node and is_instance_valid(node) and node.has_method("is_module_management_available"):
			if bool(node.call("is_module_management_available")):
				return true
	return false

func _show_module_rest_area_only_message() -> void:
	show_item_message(LocalizationManager.tr_key(
		"ui.module.reason.rest_area_only",
		"Modules can only be managed in the Rest Area."
	), 1.8)

func _close_module_management_ui() -> void:
	if module_equip_selection_panel and module_equip_selection_panel.visible:
		module_equip_selection_panel.close_without_assignment()
	if module_root:
		module_root.visible = false
	if module_menu_root:
		module_menu_root.visible = false
	InventoryData.clear_on_select()
	if _rest_area_primary_menu_id == &"module":
		_stop_primary_menu_tween(&"module")
		_rest_area_merchant_active = false
		_rest_area_primary_menu_id = &""
		PlayerData.is_interacting = false

func update_shop() -> void:
	for eq in equipped_shop.get_children():
		eq.update()
	for sh in shop.get_children():
		sh.update()
	if module_shop:
		for module_slot in module_shop.get_children():
			if module_slot.has_method("update"):
				module_slot.call("update")

func update_upg() -> void:
	for eq in equipped_upg.get_children():
		eq.update()
	upgrade_preview.update()
	_refresh_module_upgrade_list()
	_refresh_upgrade_action()
	_refresh_upgrade_template()
func update_modules() -> void:
	for eq in equipped_m.get_children():
		eq.update()
	for child in modules.get_children():
		child.queue_free()
	var slot_count := maxi(InventoryData.temporary_modules.size(), 1)
	for index in range(slot_count):
		var slot := module_slot_scene.instantiate() as ModuleSlot
		slot.module_index = index
		modules.add_child(slot)
		slot.module_selected.connect(_on_temporary_module_selected)
		slot.update()
		slot.set_selected(slot.module == selected_temporary_module)
	if selected_temporary_module != null and not InventoryData.temporary_modules.has(selected_temporary_module):
		selected_temporary_module = null
	_refresh_module_action()

func _init_management_ui_polish() -> void:
	_style_management_panel(shopping_panel)
	_style_management_panel(upgrade_panel)
	_style_management_panel(module_panel)

	shop_instruction_label = _create_management_instruction(
		shopping_panel,
		"ShopInstruction",
		Vector2(25, 40),
		Vector2(1, 1)
	)
	shop_instruction_label.visible = false
	upgrade_instruction_label = _create_management_instruction(
		upgrade_panel,
		"UpgradeInstruction",
		Vector2(25, 42),
		Vector2(480, 30)
	)
	module_instruction_label = _create_management_instruction(
		module_panel,
		"ModuleInstruction",
		Vector2(25, 42),
		Vector2(500, 30)
	)
	_ensure_purchase_module_shop()
	_ensure_purchase_mode_controls()
	_ensure_shop_detail_panel()
	_ensure_module_upgrade_panel()
	_ensure_upgrade_template_panel()
	_ensure_management_menu_buttons()

	for button_name in ["ShopRefreshButton", "ShopSellButton", "ShopCancelButton", "ShopConfirmButton", "BackToMerchantMenu"]:
		_style_management_button(shopping_panel.get_node_or_null(button_name) as Button)
	_style_management_button(shopping_panel.get_node_or_null("ShopConfirmButton") as Button, true)
	_position_management_button(shopping_panel.get_node_or_null("ShopRefreshButton") as Button, Vector2(325, 532), Vector2(200, 52))
	_position_management_button(shopping_panel.get_node_or_null("ShopSellButton") as Button, Vector2(540, 532), Vector2(200, 52))
	_position_management_button(shopping_panel.get_node_or_null("ShopCancelButton") as Button, Vector2(540, 532), Vector2(200, 52))
	_position_management_button(shopping_panel.get_node_or_null("BackToMerchantMenu") as Button, Vector2(760, 532), Vector2(200, 52))
	_position_management_button(shopping_panel.get_node_or_null("ShopConfirmButton") as Button, Vector2(760, 532), Vector2(200, 52))
	_style_management_button(upgrade_panel.get_node_or_null("BackToSmithMenu") as Button)
	_style_management_button(module_panel.get_node_or_null("BackToModuleMenu") as Button)
	_position_management_button(upgrade_panel.get_node_or_null("BackToSmithMenu") as Button, Vector2(760, 532), Vector2(200, 52))
	_position_management_button(module_panel.get_node_or_null("BackToModuleMenu") as Button, Vector2(760, 532), Vector2(200, 52))

	upgrade_action_button = Button.new()
	upgrade_action_button.name = "UpgradeActionButton"
	upgrade_action_button.position = Vector2(540, 532)
	upgrade_action_button.size = Vector2(200, 52)
	upgrade_action_button.pressed.connect(_on_upgrade_action_pressed)
	upgrade_panel.add_child(upgrade_action_button)
	_style_management_button(upgrade_action_button, true)

	var module_scroll := module_panel.get_node_or_null("TemporaryModulesScroll") as ScrollContainer
	if module_scroll:
		module_scroll.position = Vector2(25, 78)
		module_scroll.size = Vector2(500, 392)
		module_scroll.custom_minimum_size = Vector2(500, 392)
	module_selection_label = Label.new()
	module_selection_label.name = "ModuleSelectionLabel"
	module_selection_label.position = Vector2(25, 480)
	module_selection_label.size = Vector2(500, 35)
	module_selection_label.clip_text = true
	module_panel.add_child(module_selection_label)
	module_equip_button = Button.new()
	module_equip_button.name = "ModuleEquipButton"
	module_equip_button.position = Vector2(25, 522)
	module_equip_button.size = Vector2(238, 52)
	module_equip_button.pressed.connect(_on_module_equip_pressed)
	module_panel.add_child(module_equip_button)
	_style_management_button(module_equip_button, true)
	module_sell_button = Button.new()
	module_sell_button.name = "ModuleSellButton"
	module_sell_button.position = Vector2(287, 522)
	module_sell_button.size = Vector2(238, 52)
	module_sell_button.pressed.connect(_on_module_sell_pressed)
	module_panel.add_child(module_sell_button)
	_style_management_button(module_sell_button)

	for title_panel in [shopping_panel, upgrade_panel, module_panel]:
		var title := title_panel.get_node_or_null("Title") as Label
		if title:
			title.add_theme_font_size_override("font_size", 26)
			title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	_refresh_upgrade_action()
	_refresh_module_action()
	_apply_shop_purchase_mode(_shop_purchase_mode)

func _ensure_purchase_module_shop() -> void:
	if module_shop != null:
		return
	equipped_shop.visible = false
	shop.custom_minimum_size = Vector2(500, 405)
	shop.position = Vector2(25, 104)
	shop.size = Vector2(500, 419)
	shop.add_theme_constant_override("separation", 8)
	var module_scroll := ScrollContainer.new()
	module_scroll.name = "ModuleShopScroll"
	module_scroll.position = Vector2(25, 104)
	module_scroll.size = Vector2(500, 419)
	module_scroll.custom_minimum_size = Vector2(500, 419)
	shopping_panel.add_child(module_scroll)
	module_shop = VBoxContainer.new()
	module_shop.name = "ModuleShop"
	module_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module_shop.add_theme_constant_override("separation", 8)
	module_scroll.add_child(module_shop)
	for index in range(4):
		var slot := SHOP_MODULE_SLOT_SCENE.instantiate()
		slot.name = "ModuleShopSlot%d" % (index + 1)
		module_shop.add_child(slot)

func _ensure_purchase_mode_controls() -> void:
	if shop_mode_buttons != null and is_instance_valid(shop_mode_buttons):
		return
	shop_mode_buttons = HBoxContainer.new()
	shop_mode_buttons.name = "ShopModeButtons"
	shop_mode_buttons.position = Vector2(25, 54)
	shop_mode_buttons.size = Vector2(500, 38)
	shop_mode_buttons.add_theme_constant_override("separation", 8)
	shopping_panel.add_child(shop_mode_buttons)
	shop_weapon_mode_button = Button.new()
	shop_weapon_mode_button.name = "BuyWeaponModeButton"
	shop_weapon_mode_button.toggle_mode = true
	shop_weapon_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_weapon_mode_button.pressed.connect(_on_shop_weapon_mode_pressed)
	shop_mode_buttons.add_child(shop_weapon_mode_button)
	_style_management_button(shop_weapon_mode_button, true)
	shop_module_mode_button = Button.new()
	shop_module_mode_button.name = "BuyModuleModeButton"
	shop_module_mode_button.toggle_mode = true
	shop_module_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_module_mode_button.pressed.connect(_on_shop_module_mode_pressed)
	shop_mode_buttons.add_child(shop_module_mode_button)
	_style_management_button(shop_module_mode_button)

func _ensure_shop_detail_panel() -> void:
	if shop_detail_panel != null and is_instance_valid(shop_detail_panel):
		return
	shop_detail_panel = PanelContainer.new()
	shop_detail_panel.name = "ShopDetailPanel"
	shop_detail_panel.position = Vector2(540, 104)
	shop_detail_panel.size = Vector2(440, 419)
	shop_detail_panel.custom_minimum_size = Vector2(440, 419)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.071, 0.086, 0.94)
	style.border_color = Color(0.24, 0.38, 0.46, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	shop_detail_panel.add_theme_stylebox_override("panel", style)
	shopping_panel.add_child(shop_detail_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	shop_detail_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	shop_detail_title = Label.new()
	shop_detail_title.add_theme_font_size_override("font_size", 22)
	shop_detail_title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	shop_detail_title.clip_text = true
	root.add_child(shop_detail_title)
	shop_detail_subtitle = Label.new()
	shop_detail_subtitle.add_theme_font_size_override("font_size", 13)
	shop_detail_subtitle.modulate = Color(0.72, 0.81, 0.86)
	shop_detail_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(shop_detail_subtitle)
	var separator := HSeparator.new()
	root.add_child(separator)
	shop_detail_scroll = ScrollContainer.new()
	shop_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(shop_detail_scroll)
	shop_detail_body = VBoxContainer.new()
	shop_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_detail_body.add_theme_constant_override("separation", 8)
	shop_detail_scroll.add_child(shop_detail_body)
	_clear_shop_detail()

func _on_shop_weapon_mode_pressed() -> void:
	_apply_shop_purchase_mode(&"weapon")

func _on_shop_module_mode_pressed() -> void:
	_apply_shop_purchase_mode(&"module")

func _apply_shop_purchase_mode(mode: StringName) -> void:
	_shop_purchase_mode = &"module" if mode == &"module" else &"weapon"
	var show_purchase := not shop_sell_mode_active
	if shop:
		shop.visible = show_purchase and _shop_purchase_mode == &"weapon"
	if module_shop:
		var module_scroll := module_shop.get_parent() as Control
		if module_scroll:
			module_scroll.visible = show_purchase and _shop_purchase_mode == &"module"
	if shop_detail_panel:
		shop_detail_panel.visible = show_purchase
	if shop_weapon_mode_button:
		shop_weapon_mode_button.button_pressed = _shop_purchase_mode == &"weapon"
	if shop_module_mode_button:
		shop_module_mode_button.button_pressed = _shop_purchase_mode == &"module"
	_shop_hover_item = {}
	_shop_selected_item = {}
	_clear_shop_slot_selection()
	_refresh_shop_detail()
	_refresh_shop_purchase_action()

func set_shop_hover_item(item_data: Dictionary) -> void:
	_shop_hover_item = item_data.duplicate(true)
	_refresh_shop_detail()

func clear_shop_hover_item(item_data: Dictionary = {}) -> void:
	if item_data.is_empty():
		_shop_hover_item = {}
	elif _shop_items_match(_shop_hover_item, item_data):
		_shop_hover_item = {}
	_refresh_shop_detail()

func set_shop_selected_item(item_data: Dictionary) -> void:
	_shop_selected_item = item_data.duplicate(true)
	_apply_shop_selection_highlight(_shop_selected_item)
	_refresh_shop_detail()
	_refresh_shop_purchase_action()

func clear_shop_selected_item(item_data: Dictionary = {}) -> void:
	if item_data.is_empty():
		_shop_selected_item = {}
		_clear_shop_slot_selection()
	elif _shop_items_match(_shop_selected_item, item_data):
		_shop_selected_item = {}
		_clear_shop_slot_selection()
	_refresh_shop_detail()
	_refresh_shop_purchase_action()

func purchase_selected_shop_item() -> bool:
	if _shop_selected_item.is_empty():
		show_item_message(LocalizationManager.tr_key("ui.shop.select_first", "Select an item first."), 1.3)
		return false
	var slot := _shop_selected_item.get("slot", null) as Node
	if slot == null or not is_instance_valid(slot):
		_shop_selected_item = {}
		_clear_shop_slot_selection()
		_refresh_shop_detail()
		_refresh_shop_purchase_action()
		return false
	if not slot.has_method("try_purchase"):
		return false
	var purchased := bool(slot.call("try_purchase"))
	if purchased:
		_shop_selected_item = {}
		_shop_hover_item = {}
		_clear_shop_slot_selection()
		_refresh_shop_detail()
	_refresh_shop_purchase_action()
	return purchased

func _apply_shop_selection_highlight(item_data: Dictionary) -> void:
	_clear_shop_slot_selection()
	var slot := item_data.get("slot", null) as Node
	if slot != null and is_instance_valid(slot) and slot.has_method("set_selected"):
		slot.call("set_selected", true)

func _clear_shop_slot_selection() -> void:
	if shop:
		for child in shop.get_children():
			if child.has_method("set_selected"):
				child.call("set_selected", false)
	if module_shop:
		for child in module_shop.get_children():
			if child.has_method("set_selected"):
				child.call("set_selected", false)

func _refresh_shop_purchase_action() -> void:
	if shop_sell_button == null or not is_instance_valid(shop_sell_button):
		return
	if shop_sell_mode_active:
		return
	var selected_slot := _shop_selected_item.get("slot", null) as Node
	var has_selection := selected_slot != null and is_instance_valid(selected_slot)
	var can_buy := false
	if has_selection and selected_slot.has_method("can_purchase"):
		can_buy = bool(selected_slot.call("can_purchase"))
	shop_sell_button.disabled = not can_buy
	var selected_name := str(_shop_selected_item.get("name", ""))
	if selected_name == "":
		shop_sell_button.text = LocalizationManager.tr_key("ui.shop.buy.select", "购买")
	else:
		shop_sell_button.text = LocalizationManager.tr_format("ui.shop.buy.item", {"name": selected_name}, "购买")

func _shop_items_match(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return str(a.get("type", "")) == str(b.get("type", "")) and str(a.get("id", "")) == str(b.get("id", ""))

func _refresh_shop_detail() -> void:
	if shop_detail_title == null or shop_detail_body == null:
		return
	var active := _shop_hover_item if not _shop_hover_item.is_empty() else _shop_selected_item
	if active.is_empty():
		_clear_shop_detail()
		return
	shop_detail_title.text = str(active.get("name", ""))
	shop_detail_title.add_theme_color_override("font_color", active.get("rarity_color", Color(0.86, 0.94, 1.0)))
	shop_detail_subtitle.text = str(active.get("description", ""))
	_clear_container(shop_detail_body)
	match str(active.get("type", "")):
		"weapon":
			_fill_weapon_shop_detail(active)
		"module":
			_fill_module_shop_detail(active)
		_:
			_clear_shop_detail()

func _clear_shop_detail() -> void:
	if shop_detail_title:
		shop_detail_title.text = ""
	if shop_detail_subtitle:
		shop_detail_subtitle.text = ""
	if shop_detail_body:
		_clear_container(shop_detail_body)

func _fill_weapon_shop_detail(item_data: Dictionary) -> void:
	var weapon_def := item_data.get("definition", null) as WeaponDefinition
	if weapon_def == null:
		return
	_add_shop_detail_section("武器类型", _format_weapon_definition_types(weapon_def))
	_add_shop_detail_section("购买价格", str(int(item_data.get("price", 0))))
	var level_rows := _build_weapon_level_rows(weapon_def)
	if not level_rows.is_empty():
		_add_shop_detail_header("等级参数 / 升级价格")
		for row in level_rows:
			_add_shop_detail_text(row)
	var branches := DataHandler.read_weapon_branch_options(str(weapon_def.scene_path), 999)
	if not branches.is_empty():
		_add_shop_detail_header("分支选择")
		for branch_def in branches:
			var branch_name := LocalizationManager.get_branch_display_name(branch_def)
			var branch_desc := LocalizationManager.get_branch_description(branch_def)
			var unlock_text := "Fuse %d" % int(branch_def.unlock_fuse)
			_add_shop_detail_text("%s  [%s]\n%s" % [branch_name, unlock_text, branch_desc])

func _fill_module_shop_detail(item_data: Dictionary) -> void:
	var module_instance := item_data.get("module", null) as Module
	if module_instance == null or not is_instance_valid(module_instance):
		return
	_add_shop_detail_section("可安装武器类型", _format_module_install_targets(module_instance))
	_add_shop_detail_section("购买价格", str(int(item_data.get("price", 0))))
	_add_shop_detail_header("等级参数 / 升级价格")
	var original_level := int(module_instance.module_level)
	for level in range(1, Module.MAX_LEVEL + 1):
		module_instance.set_module_level(level)
		var effects := module_instance.get_effect_descriptions()
		var upgrade_price := "-" if level >= Module.MAX_LEVEL else str(_get_module_shop_upgrade_cost(module_instance))
		_add_shop_detail_text("Lv.%d  升级: %s\n%s" % [level, upgrade_price, "\n".join(effects)])
	module_instance.set_module_level(original_level)

func _build_weapon_level_rows(weapon_def: WeaponDefinition) -> PackedStringArray:
	var rows := PackedStringArray()
	if weapon_def.scene == null:
		return rows
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		return rows
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if not (weapon_data_variant is Dictionary):
		weapon.queue_free()
		return rows
	var weapon_data := weapon_data_variant as Dictionary
	var keys: Array = weapon_data.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in keys:
		var level_data := weapon.get_weapon_level_data(key, weapon_data)
		if level_data.is_empty():
			continue
		var upgrade_price := "-" if int(key) >= keys.size() else str(_get_weapon_shop_upgrade_cost(weapon_def))
		rows.append("Lv.%s  升级: %s\n%s" % [str(key), upgrade_price, _format_stat_dictionary(level_data)])
	weapon.queue_free()
	return rows

func _format_stat_dictionary(data: Dictionary) -> String:
	var parts := PackedStringArray()
	for key_variant in data.keys():
		var key := str(key_variant)
		parts.append("%s: %s" % [_format_shop_stat_label(key), str(data[key_variant])])
	return " / ".join(parts)

func _format_shop_stat_label(key: String) -> String:
	match key:
		"damage":
			return "伤害"
		"speed":
			return "速度"
		"projectile_hits":
			return "命中"
		"fire_interval_sec":
			return "间隔"
		"ammo":
			return "弹药"
		"bullet_count":
			return "弹数"
		"duration":
			return "持续"
		"hit_cd":
			return "命中间隔"
		"explosion_scale":
			return "爆炸"
		_:
			return key.replace("_", " ").capitalize()

func _format_weapon_definition_types(weapon_def: WeaponDefinition) -> String:
	if weapon_def == null or weapon_def.scene == null:
		return "未知"
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		return "未知"
	var parts := PackedStringArray()
	for value in weapon.get_explicit_weapon_traits():
		parts.append(_format_type_name(str(value)))
	for value in weapon.get_explicit_delivery_types():
		parts.append(_format_type_name(str(value)))
	for value in weapon.get_explicit_weapon_capabilities():
		parts.append(_format_type_name(str(value)))
	weapon.queue_free()
	return " / ".join(parts) if not parts.is_empty() else "通用"

func _format_module_install_targets(module_instance: Module) -> String:
	var parts := PackedStringArray()
	for value in module_instance.get_normalized_required_weapon_traits():
		parts.append(_format_type_name(str(value)))
	for value in module_instance.get_normalized_required_delivery_types():
		parts.append(_format_type_name(str(value)))
	for value in module_instance.get_normalized_required_weapon_capabilities():
		parts.append(_format_type_name(str(value)))
	return " / ".join(parts) if not parts.is_empty() else "任意武器"

func _format_type_name(value: String) -> String:
	match value:
		"physical":
			return "物理"
		"energy":
			return "能量"
		"fire":
			return "火焰"
		"freeze":
			return "冻结"
		"heat":
			return "热量"
		"charge":
			return "蓄能"
		"projectile":
			return "弹体"
		"melee_contact":
			return "近战"
		"beam":
			return "光束"
		"area":
			return "范围"
		"summon":
			return "召唤"
		"trap":
			return "陷阱"
		"support":
			return "支援"
		"movement":
			return "位移"
		_:
			return value.capitalize()

func _get_weapon_shop_upgrade_cost(weapon_def: WeaponDefinition) -> int:
	if weapon_def == null:
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_weapon_upgrade_gold(int(weapon_def.price))
	return maxi(1, int(round(float(weapon_def.price) * 0.5)))

func _get_module_shop_upgrade_cost(module_instance: Module) -> int:
	if module_instance == null:
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_module_upgrade_gold(int(module_instance.cost))
	return EconomyConfig.new().get_module_upgrade_gold(int(module_instance.cost))

func _add_shop_detail_section(title: String, value: String) -> void:
	_add_shop_detail_header(title)
	_add_shop_detail_text(value)

func _add_shop_detail_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.63, 0.86, 0.95))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_detail_body.add_child(label)

func _add_shop_detail_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.92))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_detail_body.add_child(label)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _ensure_module_upgrade_panel() -> void:
	if module_upgrade_list != null:
		return
	equipped_upg.custom_minimum_size = Vector2(440, 205)
	equipped_upg.position = Vector2(540, 80)
	equipped_upg.size = Vector2(440, 205)
	module_upgrade_scroll = ScrollContainer.new()
	module_upgrade_scroll.name = "ModuleUpgradeScroll"
	module_upgrade_scroll.position = Vector2(540, 300)
	module_upgrade_scroll.size = Vector2(440, 205)
	module_upgrade_scroll.custom_minimum_size = Vector2(440, 205)
	upgrade_panel.add_child(module_upgrade_scroll)
	module_upgrade_list = VBoxContainer.new()
	module_upgrade_list.name = "ModuleUpgradeList"
	module_upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module_upgrade_list.add_theme_constant_override("separation", 8)
	module_upgrade_scroll.add_child(module_upgrade_list)
	module_upgrade_selection_label = Label.new()
	module_upgrade_selection_label.name = "ModuleUpgradeSelectionLabel"
	module_upgrade_selection_label.position = Vector2(540, 510)
	module_upgrade_selection_label.size = Vector2(200, 48)
	module_upgrade_selection_label.clip_text = true
	upgrade_panel.add_child(module_upgrade_selection_label)
	module_upgrade_action_button = Button.new()
	module_upgrade_action_button.name = "ModuleUpgradeActionButton"
	module_upgrade_action_button.position = Vector2(540, 548)
	module_upgrade_action_button.size = Vector2(200, 44)
	module_upgrade_action_button.pressed.connect(_on_module_upgrade_action_pressed)
	upgrade_panel.add_child(module_upgrade_action_button)
	_style_management_button(module_upgrade_action_button, true)

func _ensure_upgrade_template_panel() -> void:
	if upgrade_item_list != null:
		return
	equipped_upg.visible = false
	upgrade_preview.visible = false
	if module_upgrade_scroll:
		module_upgrade_scroll.visible = false
	if module_upgrade_selection_label:
		module_upgrade_selection_label.visible = false
	if module_upgrade_action_button:
		module_upgrade_action_button.visible = false
	if upgrade_instruction_label:
		upgrade_instruction_label.visible = false

	upgrade_mode_buttons = HBoxContainer.new()
	upgrade_mode_buttons.name = "UpgradeModeButtons"
	upgrade_mode_buttons.position = Vector2(25, 54)
	upgrade_mode_buttons.size = Vector2(500, 38)
	upgrade_mode_buttons.add_theme_constant_override("separation", 8)
	upgrade_panel.add_child(upgrade_mode_buttons)

	upgrade_weapon_mode_button = Button.new()
	upgrade_weapon_mode_button.name = "UpgradeWeaponModeButton"
	upgrade_weapon_mode_button.toggle_mode = true
	upgrade_weapon_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_weapon_mode_button.pressed.connect(_on_upgrade_weapon_mode_pressed)
	upgrade_mode_buttons.add_child(upgrade_weapon_mode_button)
	_style_management_button(upgrade_weapon_mode_button, true)

	upgrade_module_mode_button = Button.new()
	upgrade_module_mode_button.name = "UpgradeModuleModeButton"
	upgrade_module_mode_button.toggle_mode = true
	upgrade_module_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_module_mode_button.pressed.connect(_on_upgrade_module_mode_pressed)
	upgrade_mode_buttons.add_child(upgrade_module_mode_button)
	_style_management_button(upgrade_module_mode_button)

	upgrade_item_scroll = ScrollContainer.new()
	upgrade_item_scroll.name = "UpgradeItemScroll"
	upgrade_item_scroll.position = Vector2(25, 104)
	upgrade_item_scroll.size = Vector2(500, 419)
	upgrade_item_scroll.custom_minimum_size = Vector2(500, 419)
	upgrade_panel.add_child(upgrade_item_scroll)

	upgrade_item_list = VBoxContainer.new()
	upgrade_item_list.name = "UpgradeItemList"
	upgrade_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_item_list.add_theme_constant_override("separation", 8)
	upgrade_item_scroll.add_child(upgrade_item_list)

	upgrade_detail_panel = PanelContainer.new()
	upgrade_detail_panel.name = "UpgradeDetailPanel"
	upgrade_detail_panel.position = Vector2(540, 104)
	upgrade_detail_panel.size = Vector2(440, 419)
	upgrade_detail_panel.custom_minimum_size = Vector2(440, 419)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.071, 0.086, 0.94)
	style.border_color = Color(0.24, 0.38, 0.46, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	upgrade_detail_panel.add_theme_stylebox_override("panel", style)
	upgrade_panel.add_child(upgrade_detail_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	upgrade_detail_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	upgrade_detail_title = Label.new()
	upgrade_detail_title.add_theme_font_size_override("font_size", 22)
	upgrade_detail_title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	upgrade_detail_title.clip_text = true
	root.add_child(upgrade_detail_title)
	upgrade_detail_subtitle = Label.new()
	upgrade_detail_subtitle.add_theme_font_size_override("font_size", 13)
	upgrade_detail_subtitle.modulate = Color(0.72, 0.81, 0.86)
	upgrade_detail_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(upgrade_detail_subtitle)
	root.add_child(HSeparator.new())
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(detail_scroll)
	upgrade_detail_body = VBoxContainer.new()
	upgrade_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_detail_body.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(upgrade_detail_body)
	_apply_upgrade_mode(_upgrade_mode)

func _on_upgrade_weapon_mode_pressed() -> void:
	_apply_upgrade_mode(&"weapon")

func _on_upgrade_module_mode_pressed() -> void:
	_apply_upgrade_mode(&"module")

func _apply_upgrade_mode(mode: StringName) -> void:
	_upgrade_mode = &"module" if mode == &"module" else &"weapon"
	if upgrade_weapon_mode_button:
		upgrade_weapon_mode_button.button_pressed = _upgrade_mode == &"weapon"
	if upgrade_module_mode_button:
		upgrade_module_mode_button.button_pressed = _upgrade_mode == &"module"
	_upgrade_hover_item = {}
	_upgrade_selected_item = {}
	if _upgrade_mode == &"weapon":
		selected_upgrade_module = null
	else:
		InventoryData.on_select_upg = null
	_refresh_upgrade_template()

func _refresh_upgrade_template() -> void:
	if upgrade_item_list == null:
		return
	_clear_container(upgrade_item_list)
	var items := _build_upgrade_items(_upgrade_mode)
	if items.is_empty():
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key("ui.upgrade.empty", "No upgradeable items.")
		empty.add_theme_color_override("font_color", Color(0.72, 0.81, 0.86))
		upgrade_item_list.add_child(empty)
	for item_data in items:
		_add_upgrade_item_row(item_data)
	_refresh_upgrade_detail()
	_refresh_upgrade_action()

func _build_upgrade_items(mode: StringName) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if mode == &"weapon":
		for weapon_ref in PlayerData.player_weapon_list:
			var weapon := weapon_ref as Weapon
			if weapon == null or not is_instance_valid(weapon):
				continue
			output.append(_build_weapon_upgrade_item_data(weapon))
	else:
		for module_ref in InventoryData.get_all_owned_modules():
			var module_instance := module_ref as Module
			if module_instance == null or not is_instance_valid(module_instance):
				continue
			output.append(_build_module_upgrade_item_data(module_instance))
	return output

func _add_upgrade_item_row(item_data: Dictionary) -> void:
	var button := Button.new()
	button.text = _format_upgrade_row_text(item_data)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(500, 96)
	button.expand_icon = true
	var icon := item_data.get("icon", null) as Texture2D
	if icon:
		button.icon = icon
	button.pressed.connect(_on_upgrade_item_selected.bind(item_data))
	button.mouse_entered.connect(_on_upgrade_item_hovered.bind(item_data))
	button.mouse_exited.connect(_on_upgrade_item_unhovered.bind(item_data))
	upgrade_item_list.add_child(button)
	item_data["button"] = button
	_style_management_button(button, _upgrade_items_match(_upgrade_selected_item, item_data))

func _on_upgrade_item_hovered(item_data: Dictionary) -> void:
	_upgrade_hover_item = item_data.duplicate(true)
	_refresh_upgrade_detail()

func _on_upgrade_item_unhovered(item_data: Dictionary) -> void:
	if _upgrade_items_match(_upgrade_hover_item, item_data):
		_upgrade_hover_item = {}
	_refresh_upgrade_detail()

func _on_upgrade_item_selected(item_data: Dictionary) -> void:
	_upgrade_selected_item = item_data.duplicate(true)
	if str(item_data.get("type", "")) == "weapon":
		InventoryData.on_select_upg = item_data.get("weapon", null) as Weapon
		selected_upgrade_module = null
	else:
		selected_upgrade_module = item_data.get("module", null) as Module
		InventoryData.on_select_upg = null
	_refresh_upgrade_template()

func _refresh_upgrade_detail() -> void:
	if upgrade_detail_title == null or upgrade_detail_body == null:
		return
	var active := _upgrade_hover_item if not _upgrade_hover_item.is_empty() else _upgrade_selected_item
	if active.is_empty():
		upgrade_detail_title.text = ""
		upgrade_detail_subtitle.text = ""
		_clear_container(upgrade_detail_body)
		return
	upgrade_detail_title.text = str(active.get("name", ""))
	upgrade_detail_title.add_theme_color_override("font_color", active.get("rarity_color", Color(0.86, 0.94, 1.0)))
	upgrade_detail_subtitle.text = str(active.get("description", ""))
	_clear_container(upgrade_detail_body)
	if str(active.get("type", "")) == "weapon":
		_fill_weapon_upgrade_detail(active)
	else:
		_fill_module_upgrade_detail(active)

func _on_upgrade_action_pressed() -> void:
	if _try_upgrade_selected_template_item():
		return
	if upgrade_preview.has_method("try_upgrade_selected_weapon"):
		upgrade_preview.call("try_upgrade_selected_weapon")

func _try_upgrade_selected_template_item() -> bool:
	if _upgrade_selected_item.is_empty():
		show_item_message(LocalizationManager.tr_key("ui.upgrade.select_first", "Select an item first."), 1.3)
		return false
	if str(_upgrade_selected_item.get("type", "")) == "weapon":
		return _try_upgrade_selected_weapon_from_template(_upgrade_selected_item)
	return _try_upgrade_selected_module_from_template(_upgrade_selected_item)

func _try_upgrade_selected_weapon_from_template(item_data: Dictionary) -> bool:
	var weapon := item_data.get("weapon", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return false
	if int(weapon.level) >= int(weapon.max_level):
		show_item_message(LocalizationManager.tr_key("ui.upgrade.fully_upgraded", "Fully upgraded."), 1.4)
		return false
	var price := _get_weapon_upgrade_price(weapon)
	if PlayerData.player_gold < price:
		show_item_message(LocalizationManager.tr_key("ui.shop.not_enough_gold", "Not enough gold."), 1.4)
		return false
	PlayerData.player_gold -= price
	weapon.set_level(int(weapon.level) + 1)
	update_upg()
	return true

func _try_upgrade_selected_module_from_template(item_data: Dictionary) -> bool:
	var module_instance := item_data.get("module", null) as Module
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	var result := InventoryData.upgrade_module_with_gold(module_instance)
	if not result.get("ok", false):
		show_item_message(str(result.get("reason", "")), 1.6)
		return false
	update_upg()
	return true

func _ensure_management_menu_buttons() -> void:
	var smith_weapon_button := smith_primary_panel.get_node_or_null("OpenUpgradeButton") as Button
	if smith_weapon_button:
		smith_weapon_button.position = Vector2(28, 108)
		smith_weapon_button.size = Vector2(220, 46)
	if smith_module_upgrade_button == null:
		smith_module_upgrade_button = Button.new()
		smith_module_upgrade_button.name = "OpenModuleUpgradeButton"
		smith_module_upgrade_button.position = Vector2(28, 166)
		smith_module_upgrade_button.size = Vector2(220, 46)
		smith_module_upgrade_button.pressed.connect(smith_open_module_upgrade_panel)
		smith_primary_panel.add_child(smith_module_upgrade_button)
		_style_management_button(smith_module_upgrade_button)

	var open_module_button := module_primary_panel.get_node_or_null("OpenModuleButton") as Button
	if open_module_button:
		open_module_button.position = Vector2(28, 166)
		open_module_button.size = Vector2(220, 46)
	if weapon_warehouse_button == null:
		weapon_warehouse_button = Button.new()
		weapon_warehouse_button.name = "OpenWeaponWarehouseButton"
		weapon_warehouse_button.position = Vector2(28, 108)
		weapon_warehouse_button.size = Vector2(220, 46)
		weapon_warehouse_button.pressed.connect(module_open_weapon_warehouse_panel)
		module_primary_panel.add_child(weapon_warehouse_button)
		_style_management_button(weapon_warehouse_button)

func _style_management_panel(panel: Panel) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.09, 0.98)
	style.border_color = Color(0.18, 0.38, 0.52, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

func _style_management_button(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	button.custom_minimum_size.y = 44.0
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.38, 0.58) if primary else Color(0.12, 0.18, 0.25)
	normal.border_color = Color(0.3, 0.68, 0.9) if primary else Color(0.28, 0.42, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)

func _position_management_button(button: Button, position: Vector2, button_size: Vector2) -> void:
	if button == null:
		return
	button.position = position
	button.size = button_size

func _create_management_instruction(panel: Panel, node_name: String, position: Vector2, label_size: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = position
	label.size = label_size
	label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.8))
	label.add_theme_font_size_override("font_size", 16)
	panel.add_child(label)
	return label

func _refresh_upgrade_action() -> void:
	if upgrade_action_button == null:
		return
	var ready := false
	var price := 0
	if not _upgrade_selected_item.is_empty():
		if str(_upgrade_selected_item.get("type", "")) == "weapon":
			var weapon := _upgrade_selected_item.get("weapon", null) as Weapon
			ready = weapon != null and is_instance_valid(weapon) and int(weapon.level) < int(weapon.max_level)
			price = _get_weapon_upgrade_price(weapon) if ready else 0
		else:
			var module_instance := _upgrade_selected_item.get("module", null) as Module
			ready = module_instance != null and is_instance_valid(module_instance) and int(module_instance.module_level) < Module.MAX_LEVEL
			price = _get_module_upgrade_price(module_instance) if ready else 0
	upgrade_action_button.disabled = not ready or PlayerData.player_gold < price
	upgrade_action_button.text = LocalizationManager.tr_format(
		"ui.upgrade.action_price",
		{"value": price},
		"升级: %s" % price
	) if ready else LocalizationManager.tr_key("ui.upgrade.action_empty", "升级")

func _build_weapon_upgrade_item_data(weapon: Weapon) -> Dictionary:
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	var rarity := weapon_def.get_rarity() if weapon_def else RARITY_UTIL.COMMON
	return {
		"type": "weapon",
		"id": str(weapon.get_instance_id()),
		"weapon": weapon,
		"name": LocalizationManager.get_weapon_name_from_node(weapon),
		"description": LocalizationManager.get_weapon_description_from_definition(weapon_def) if weapon_def else "",
		"level": int(weapon.level),
		"max_level": int(weapon.max_level),
		"price": _get_weapon_upgrade_price(weapon),
		"icon": weapon.sprite.texture if weapon.sprite else null,
		"params": _build_weapon_upgrade_param_summary(weapon),
		"rarity_color": RARITY_UTIL.get_color(rarity),
	}

func _build_module_upgrade_item_data(module_instance: Module) -> Dictionary:
	var rarity := module_instance.get_rarity()
	return {
		"type": "module",
		"id": str(module_instance.get_instance_id()),
		"module": module_instance,
		"name": LocalizationManager.get_module_name(module_instance),
		"description": "\n".join(module_instance.get_effect_descriptions()),
		"level": int(module_instance.module_level),
		"max_level": Module.MAX_LEVEL,
		"price": _get_module_upgrade_price(module_instance),
		"icon": _get_module_texture(module_instance),
		"params": _build_module_upgrade_param_summary(module_instance),
		"rarity_color": RARITY_UTIL.get_color(rarity),
	}

func _format_upgrade_row_text(item_data: Dictionary) -> String:
	var level := int(item_data.get("level", 0))
	var max_level := int(item_data.get("max_level", 0))
	var price := int(item_data.get("price", 0))
	var price_text := "-" if level >= max_level else str(price)
	return "%s\nLv.%d/%d    升级: %s\n%s" % [
		str(item_data.get("name", "")),
		level,
		max_level,
		price_text,
		str(item_data.get("params", "")),
	]

func _build_weapon_upgrade_param_summary(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if not (weapon_data_variant is Dictionary):
		return ""
	var weapon_data := weapon_data_variant as Dictionary
	var current_data := weapon.get_weapon_level_data(weapon.level, weapon_data)
	var next_data := weapon.get_weapon_level_data(int(weapon.level) + 1, weapon_data)
	var keys := ["damage", "fire_interval_sec", "ammo", "speed", "projectile_hits", "bullet_count"]
	var parts := PackedStringArray()
	for key in keys:
		if not current_data.has(key):
			continue
		var current_value := str(current_data.get(key, "-"))
		var next_value := str(next_data.get(key, "-")) if not next_data.is_empty() else "-"
		parts.append("%s %s>%s" % [_format_shop_stat_label(key), current_value, next_value])
		if parts.size() >= 3:
			break
	return " / ".join(parts)

func _build_module_upgrade_param_summary(module_instance: Module) -> String:
	if module_instance == null or not is_instance_valid(module_instance):
		return ""
	var original_level := int(module_instance.module_level)
	var current_effect := module_instance.get_effect_descriptions()
	var current_text := current_effect[0] if current_effect.size() > 0 else ""
	if original_level < Module.MAX_LEVEL:
		module_instance.set_module_level(original_level + 1)
		var next_effect := module_instance.get_effect_descriptions()
		var next_text := next_effect[0] if next_effect.size() > 0 else ""
		module_instance.set_module_level(original_level)
		if next_text != "" and next_text != current_text:
			return "%s > %s" % [current_text, next_text]
	module_instance.set_module_level(original_level)
	return current_text

func _get_module_texture(module_instance: Module) -> Texture2D:
	if module_instance == null or not is_instance_valid(module_instance):
		return null
	var sprite := module_instance.get_node_or_null("%Sprite") as Sprite2D
	return sprite.texture if sprite else null

func _upgrade_items_match(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return str(a.get("type", "")) == str(b.get("type", "")) and str(a.get("id", "")) == str(b.get("id", ""))

func _fill_weapon_upgrade_detail(item_data: Dictionary) -> void:
	var weapon := item_data.get("weapon", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return
	_add_upgrade_detail_section("当前等级", "Lv.%d/%d" % [int(weapon.level), int(weapon.max_level)])
	_add_upgrade_detail_section("升级价格", "-" if int(weapon.level) >= int(weapon.max_level) else str(_get_weapon_upgrade_price(weapon)))
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def != null:
		_add_upgrade_detail_section("武器类型", _format_weapon_definition_types(weapon_def))
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if weapon_data_variant is Dictionary:
		var weapon_data := weapon_data_variant as Dictionary
		var current_data := weapon.get_weapon_level_data(weapon.level, weapon_data)
		var next_data := weapon.get_weapon_level_data(int(weapon.level) + 1, weapon_data)
		_add_upgrade_detail_header("参数变化")
		_add_upgrade_detail_text(_format_upgrade_delta(current_data, next_data))

func _fill_module_upgrade_detail(item_data: Dictionary) -> void:
	var module_instance := item_data.get("module", null) as Module
	if module_instance == null or not is_instance_valid(module_instance):
		return
	_add_upgrade_detail_section("当前等级", "Lv.%d/%d" % [int(module_instance.module_level), Module.MAX_LEVEL])
	_add_upgrade_detail_section("升级价格", "-" if int(module_instance.module_level) >= Module.MAX_LEVEL else str(_get_module_upgrade_price(module_instance)))
	_add_upgrade_detail_section("可安装武器类型", _format_module_install_targets(module_instance))
	var original_level := int(module_instance.module_level)
	_add_upgrade_detail_header("参数变化")
	module_instance.set_module_level(original_level)
	var current_effects := module_instance.get_effect_descriptions()
	if original_level < Module.MAX_LEVEL:
		module_instance.set_module_level(original_level + 1)
		var next_effects := module_instance.get_effect_descriptions()
		_add_upgrade_detail_text("当前:\n%s\n\n下一级:\n%s" % ["\n".join(current_effects), "\n".join(next_effects)])
	else:
		_add_upgrade_detail_text("\n".join(current_effects))
	module_instance.set_module_level(original_level)

func _format_upgrade_delta(current_data: Dictionary, next_data: Dictionary) -> String:
	if next_data.is_empty():
		return _format_stat_dictionary(current_data)
	var keys := PackedStringArray()
	for key_variant in current_data.keys():
		var key := str(key_variant)
		if not keys.has(key):
			keys.append(key)
	for key_variant in next_data.keys():
		var key := str(key_variant)
		if not keys.has(key):
			keys.append(key)
	var lines := PackedStringArray()
	for key in keys:
		var from_value := str(current_data.get(key, "-"))
		var to_value := str(next_data.get(key, "-"))
		lines.append("%s: %s -> %s" % [_format_shop_stat_label(key), from_value, to_value])
	return "\n".join(lines)

func _add_upgrade_detail_section(title: String, value: String) -> void:
	_add_upgrade_detail_header(title)
	_add_upgrade_detail_text(value)

func _add_upgrade_detail_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.63, 0.86, 0.95))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_detail_body.add_child(label)

func _add_upgrade_detail_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.92))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_detail_body.add_child(label)

func _get_weapon_upgrade_price(weapon: Weapon) -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 0
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def == null:
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_weapon_upgrade_gold(int(weapon_def.price))
	return maxi(1, int(round(float(weapon_def.price) * 0.5)))

func _refresh_module_upgrade_list() -> void:
	if module_upgrade_list == null:
		return
	for child in module_upgrade_list.get_children():
		child.queue_free()
	var has_rows := false
	for module_instance in InventoryData.get_all_owned_modules():
		if module_instance == null or not is_instance_valid(module_instance):
			continue
		if int(module_instance.module_level) >= Module.MAX_LEVEL:
			continue
		has_rows = true
		var button := Button.new()
		button.text = _build_module_upgrade_row_text(module_instance)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_upgrade_module_selected.bind(module_instance))
		module_upgrade_list.add_child(button)
		_style_management_button(button, module_instance == selected_upgrade_module)
	if not has_rows:
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key("ui.upgrade.module.empty", "No modules can be upgraded.")
		module_upgrade_list.add_child(empty)
	if selected_upgrade_module != null and (not is_instance_valid(selected_upgrade_module) or int(selected_upgrade_module.module_level) >= Module.MAX_LEVEL):
		selected_upgrade_module = null
	_refresh_module_upgrade_action()

func _on_upgrade_module_selected(module_instance: Module) -> void:
	selected_upgrade_module = module_instance
	_refresh_module_upgrade_list()
	_refresh_module_upgrade_action()

func _on_module_upgrade_action_pressed() -> void:
	if selected_upgrade_module == null or not is_instance_valid(selected_upgrade_module):
		return
	var result := InventoryData.upgrade_module_with_gold(selected_upgrade_module)
	if not result.get("ok", false):
		show_item_message(str(result.get("reason", "")), 1.6)
	update_upg()

func _refresh_module_upgrade_action() -> void:
	if module_upgrade_action_button == null or module_upgrade_selection_label == null:
		return
	var ready := selected_upgrade_module != null and is_instance_valid(selected_upgrade_module) \
		and int(selected_upgrade_module.module_level) < Module.MAX_LEVEL
	var price := _get_module_upgrade_price(selected_upgrade_module) if ready else 0
	module_upgrade_action_button.disabled = not ready or PlayerData.player_gold < price
	module_upgrade_action_button.text = LocalizationManager.tr_format(
		"ui.upgrade.module.action",
		{"value": price},
		"Upgrade Module: %s" % price
	) if ready else LocalizationManager.tr_key("ui.upgrade.module.action_empty", "Upgrade Module")
	if ready:
		module_upgrade_selection_label.text = LocalizationManager.tr_format(
			"ui.upgrade.module.selected",
			{"module": LocalizationManager.get_module_name(selected_upgrade_module), "level": selected_upgrade_module.module_level},
			"%s Lv.%d" % [LocalizationManager.get_module_name(selected_upgrade_module), selected_upgrade_module.module_level]
		)
	else:
		module_upgrade_selection_label.text = LocalizationManager.tr_key("ui.upgrade.module.select_prompt", "Select a module to upgrade.")

func _build_module_upgrade_row_text(module_instance: Module) -> String:
	var price := _get_module_upgrade_price(module_instance)
	return "%s Lv.%d -> Lv.%d    %s" % [
		LocalizationManager.get_module_name(module_instance),
		int(module_instance.module_level),
		int(module_instance.module_level) + 1,
		LocalizationManager.tr_format("ui.upgrade.cost", {"value": price}, "Cost: %s" % price),
	]

func _get_module_upgrade_price(module_instance: Module) -> int:
	if module_instance == null or not is_instance_valid(module_instance):
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_module_upgrade_gold(int(module_instance.cost))
	return EconomyConfig.new().get_module_upgrade_gold(int(module_instance.cost))

func _on_temporary_module_selected(module_instance: Module) -> void:
	selected_temporary_module = module_instance
	for slot: ModuleSlot in modules.get_children():
		slot.set_selected(slot.module == selected_temporary_module)
	_refresh_module_action()

func _on_module_equip_pressed() -> void:
	if selected_temporary_module != null and is_instance_valid(selected_temporary_module):
		request_module_equip_selection(selected_temporary_module)

func _on_module_sell_pressed() -> void:
	if selected_temporary_module != null and is_instance_valid(selected_temporary_module):
		request_temporary_module_sell_confirmation(selected_temporary_module)

func _refresh_module_action() -> void:
	if module_equip_button == null or module_sell_button == null or module_selection_label == null:
		return
	var has_selection := selected_temporary_module != null and is_instance_valid(selected_temporary_module)
	module_equip_button.disabled = not has_selection
	module_sell_button.disabled = not has_selection
	module_equip_button.text = LocalizationManager.tr_key("ui.module.action.equip_selected", "Equip Selected Module")
	module_sell_button.text = LocalizationManager.tr_key("ui.module.action.sell_selected", "Sell Selected Module")
	if has_selection:
		module_selection_label.text = LocalizationManager.tr_format(
			"ui.module.selected",
			{"module": LocalizationManager.get_module_name(selected_temporary_module), "level": selected_temporary_module.module_level},
			"Selected: %s Lv.%d" % [LocalizationManager.get_module_name(selected_temporary_module), selected_temporary_module.module_level]
		)
	else:
		module_selection_label.text = LocalizationManager.tr_key("ui.module.select_prompt", "Select a temporary module to manage.")

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
	if new_phase != PhaseManager.PREPARE:
		_close_module_management_ui()
	if new_phase == PhaseManager.GAMEOVER:
		_show_game_over()
	_request_next_queued_weapon_branch_selection()
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
	if not _refresh_battle_hardware_cursor_texture(false, 1.0):
		return
	var hotspot := Vector2(BATTLE_HARDWARE_CURSOR_SIZE * 0.5, BATTLE_HARDWARE_CURSOR_SIZE * 0.5)
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_WAIT]:
		Input.set_custom_mouse_cursor(_battle_hardware_cursor_tex, shape, hotspot)
	_battle_hardware_cursor_applied = true

func _refresh_battle_hardware_cursor_texture(ammo_visible: bool, ammo_progress: float) -> bool:
	var progress_bucket := clampi(int(round(clampf(ammo_progress, 0.0, 1.0) * 100.0)), 0, 100)
	var state_key := "%s:%d" % [str(ammo_visible), progress_bucket]
	if _battle_hardware_cursor_tex != null and state_key == _battle_hardware_cursor_state_key:
		return true
	_battle_hardware_cursor_tex = _build_battle_hardware_cursor_texture(ammo_visible, float(progress_bucket) / 100.0)
	_battle_hardware_cursor_state_key = state_key
	if _battle_hardware_cursor_tex == null:
		return false
	if _battle_hardware_cursor_applied:
		var hotspot := Vector2(BATTLE_HARDWARE_CURSOR_SIZE * 0.5, BATTLE_HARDWARE_CURSOR_SIZE * 0.5)
		for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_WAIT]:
			Input.set_custom_mouse_cursor(_battle_hardware_cursor_tex, shape, hotspot)
	return true

func _clear_battle_hardware_cursor() -> void:
	if not _battle_hardware_cursor_applied:
		return
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_WAIT]:
		Input.set_custom_mouse_cursor(null, shape)
	_battle_hardware_cursor_applied = false
	_battle_hardware_cursor_state_key = ""

func _build_battle_hardware_cursor_texture(ammo_visible: bool = false, ammo_progress: float = 1.0) -> Texture2D:
	var size: int = maxi(12, BATTLE_HARDWARE_CURSOR_SIZE)
	var center := int(round(float(size) * 0.5))
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var c := BATTLE_HARDWARE_CURSOR_COLOR
	var ring_radius := clampi(int(round(SPREAD_CURSOR_FALLBACK_RADIUS_PX)), 4, maxi(4, center - 3))
	var center_v := Vector2(center, center)
	var diamond := [
		center_v + Vector2(0.0, -ring_radius),
		center_v + Vector2(ring_radius, 0.0),
		center_v + Vector2(0.0, ring_radius),
		center_v + Vector2(-ring_radius, 0.0),
	]
	_draw_image_polyline(image, diamond, BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR, 3)
	_draw_image_polyline(image, diamond, BATTLE_HARDWARE_CURSOR_RING_COLOR, 1)
	if ammo_visible:
		_draw_image_diamond_progress(image, diamond, clampf(ammo_progress, 0.0, 1.0), c, 2)
	_draw_image_line(image, Vector2(center - 4, center), Vector2(center + 4, center), BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR, 3)
	_draw_image_line(image, Vector2(center, center - 4), Vector2(center, center + 4), BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR, 3)
	_draw_image_line(image, Vector2(center - 4, center), Vector2(center + 4, center), c, 1)
	_draw_image_line(image, Vector2(center, center - 4), Vector2(center, center + 4), c, 1)
	return ImageTexture.create_from_image(image)

func _draw_image_diamond_progress(image: Image, points: Array, progress: float, color: Color, width: int = 1) -> void:
	if points.size() < 2 or progress <= 0.0:
		return
	var ordered := [points[0], points[3], points[2], points[1], points[0]]
	var total_len := 0.0
	for index in range(ordered.size() - 1):
		total_len += (ordered[index] as Vector2).distance_to(ordered[index + 1] as Vector2)
	var remaining := total_len * clampf(progress, 0.0, 1.0)
	for index in range(ordered.size() - 1):
		if remaining <= 0.0:
			return
		var from_point := ordered[index] as Vector2
		var to_point := ordered[index + 1] as Vector2
		var segment_len := from_point.distance_to(to_point)
		if remaining >= segment_len:
			_draw_image_line(image, from_point, to_point, color, width)
			remaining -= segment_len
			continue
		var partial_to := from_point.lerp(to_point, remaining / maxf(segment_len, 0.0001))
		_draw_image_line(image, from_point, partial_to, color, width)
		return

func _draw_image_polyline(image: Image, points: Array, color: Color, width: int = 1) -> void:
	if points.size() < 2:
		return
	for index in range(points.size()):
		var from_point := points[index] as Vector2
		var to_point := points[(index + 1) % points.size()] as Vector2
		_draw_image_line(image, from_point, to_point, color, width)

func _draw_image_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width: int = 1) -> void:
	var steps := maxi(int(ceil(from_point.distance_to(to_point))), 1)
	var radius := maxi(int(floor(float(width) * 0.5)), 0)
	for step in range(steps + 1):
		var point := from_point.lerp(to_point, float(step) / float(steps))
		_draw_image_point(image, point, color, radius)

func _draw_image_point(image: Image, point: Vector2, color: Color, radius: int) -> void:
	var px := int(round(point.x))
	var py := int(round(point.y))
	for y in range(py - radius, py + radius + 1):
		for x in range(px - radius, px + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			image.set_pixel(x, y, color)


func _show_game_over() -> void:
	if game_over_root == null:
		return
	pause_menu_root.visible = false
	shopping_rootv_2.visible = false
	upgrade_rootv_2.visible = false
	module_root.visible = false
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
		smith_root,
		module_menu_root
	]
	for root in roots:
		if root and is_instance_valid(root) and root.visible:
			return true
	return false

func _is_secondary_menu_open() -> bool:
	var roots := [
		shopping_rootv_2,
		upgrade_rootv_2,
		module_root,
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
	_fit_center_panel(module_panel, viewport_size, PANEL_TARGET_SIZE)
	_fit_left_panel(merchant_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	_fit_left_panel(smith_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
	_fit_left_panel(module_primary_panel, viewport_size, PRIMARY_MENU_TARGET_SIZE, PRIMARY_MENU_LEFT_MARGIN)
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
		weapon_selector.set_layout_origin(Vector2(HUD_MARGIN + 12.0, HUD_MARGIN - 2.0))
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
	var mouse_screen := viewport.get_mouse_position()
	if mouse_screen_override is Vector2:
		mouse_screen = mouse_screen_override as Vector2
	spread_cursor_overlay.set_cursor_screen_position(mouse_screen)
	var main_weapon := _get_main_weapon_node()
	if main_weapon == null or not is_instance_valid(main_weapon):
		_clear_spread_cursor_ammo_progress()
		_refresh_battle_hardware_cursor_texture(false, 1.0)
		spread_cursor_overlay.set_fallback_screen_radius(SPREAD_CURSOR_FALLBACK_RADIUS_PX)
		spread_cursor_overlay.visible = false
		return
	_update_battle_hardware_cursor_ammo_progress(main_weapon)
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
		spread_cursor_overlay.visible = true
		return
	spread_cursor_overlay.set_fallback_screen_radius(SPREAD_CURSOR_FALLBACK_RADIUS_PX)
	spread_cursor_overlay.visible = false

func _update_battle_hardware_cursor_ammo_progress(main_weapon: Node) -> void:
	if main_weapon == null or not is_instance_valid(main_weapon):
		_refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	if not main_weapon.has_method("get_ammo_status"):
		_refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	var status_variant: Variant = main_weapon.call("get_ammo_status")
	if not (status_variant is Dictionary):
		_refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	var status: Dictionary = status_variant as Dictionary
	if not bool(status.get("enabled", false)):
		_refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	var max_ammo: int = max(1, int(status.get("max", 0)))
	var current_ammo: int = clampi(int(status.get("current", 0)), 0, max_ammo)
	var is_reloading: bool = bool(status.get("is_reloading", false))
	var reload_left: float = maxf(float(status.get("reload_left", 0.0)), 0.0)
	var weapon_id: int = main_weapon.get_instance_id()
	var progress: float = 1.0
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
	else:
		_cursor_reload_total_by_weapon.erase(weapon_id)
		progress = clampf(float(current_ammo) / float(max_ammo), 0.0, 1.0)
	_refresh_battle_hardware_cursor_texture(true, progress)

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

func _ensure_weapon_passive_panel() -> void:
	if weapon_passive_panel != null and is_instance_valid(weapon_passive_panel):
		return
	weapon_passive_panel = PanelContainer.new()
	weapon_passive_panel.name = "WeaponPassivePanel"
	weapon_passive_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_passive_panel.position = Vector2(224.0, 8.0)
	weapon_passive_panel.custom_minimum_size = Vector2(300.0, 0.0)
	character_root.add_child(weapon_passive_panel)
	weapon_passive_list = VBoxContainer.new()
	weapon_passive_list.name = "WeaponPassiveList"
	weapon_passive_list.add_theme_constant_override("separation", 4)
	weapon_passive_panel.add_child(weapon_passive_list)

func _refresh_weapon_passive_panel() -> void:
	if weapon_passive_presenter == null:
		return
	_ensure_weapon_passive_panel()
	if weapon_passive_panel == null or weapon_passive_list == null:
		return
	var statuses: Array = weapon_passive_presenter.get_equipped_weapon_passive_statuses()
	weapon_passive_panel.visible = not statuses.is_empty()
	_ensure_weapon_passive_row_count(statuses.size())
	for idx in range(_weapon_passive_rows.size()):
		var row := _weapon_passive_rows[idx]
		var root := row.get("root", null) as Control
		if root == null:
			continue
		if idx >= statuses.size():
			root.visible = false
			continue
		root.visible = true
		_apply_weapon_passive_row(row, statuses[idx])

func _ensure_weapon_passive_row_count(count: int) -> void:
	if weapon_passive_list == null:
		return
	while _weapon_passive_rows.size() < count:
		_weapon_passive_rows.append(_create_weapon_passive_row())

func _create_weapon_passive_row() -> Dictionary:
	var row_root := VBoxContainer.new()
	row_root.name = "WeaponPassiveRow"
	row_root.custom_minimum_size = Vector2(288.0, 0.0)
	row_root.add_theme_constant_override("separation", 1)
	weapon_passive_list.add_child(row_root)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 6)
	row_root.add_child(header)

	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(18.0, 18.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon_rect)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	header.add_child(name_label)

	var state_label := Label.new()
	state_label.name = "State"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.custom_minimum_size = Vector2(98.0, 0.0)
	header.add_child(state_label)

	var progress_bar := ProgressBar.new()
	progress_bar.name = "Progress"
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.step = 0.001
	progress_bar.custom_minimum_size = Vector2(0.0, 8.0)
	progress_bar.show_percentage = false
	row_root.add_child(progress_bar)

	var detail_label := Label.new()
	detail_label.name = "Detail"
	detail_label.clip_text = true
	detail_label.add_theme_font_size_override("font_size", 11)
	row_root.add_child(detail_label)

	return {
		"root": row_root,
		"icon": icon_rect,
		"name": name_label,
		"state": state_label,
		"progress": progress_bar,
		"detail": detail_label,
	}

func _apply_weapon_passive_row(row: Dictionary, status: Dictionary) -> void:
	var root := row.get("root", null) as Control
	var icon_rect := row.get("icon", null) as TextureRect
	var name_label := row.get("name", null) as Label
	var state_label := row.get("state", null) as Label
	var progress_bar := row.get("progress", null) as ProgressBar
	var detail_label := row.get("detail", null) as Label
	if root == null or name_label == null or state_label == null or progress_bar == null or detail_label == null:
		return
	var is_main := bool(status.get("is_main_weapon", false))
	var state := str(status.get("state", "inactive"))
	var ready := bool(status.get("ready", false))
	var weapon_prefix := "* " if is_main else "  "
	var passive_name := str(status.get("passive_name", ""))
	var name_text := str(status.get("weapon_name", "Weapon"))
	if passive_name != "":
		name_text = "%s - %s" % [name_text, passive_name]
	name_label.text = weapon_prefix + name_text
	if icon_rect != null:
		var icon_variant: Variant = status.get("icon", null)
		icon_rect.texture = icon_variant as Texture2D
		icon_rect.visible = icon_rect.texture != null
	state_label.text = _format_weapon_passive_state(state, ready)
	var progress := float(status.get("progress", -1.0))
	progress_bar.visible = progress >= 0.0
	if progress_bar.visible:
		progress_bar.value = clampf(progress, 0.0, 1.0)
	detail_label.text = _format_weapon_passive_detail(status)
	if is_main:
		root.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif str(status.get("inactive_reason", "")) == "not_main_weapon":
		root.modulate = Color(0.65, 0.65, 0.65, 0.82)
	else:
		root.modulate = Color(0.8, 0.8, 0.8, 0.9)

func _format_weapon_passive_state(state: String, ready: bool) -> String:
	if ready:
		return "Ready"
	match state:
		"charging":
			return "Charging"
		"ready_pending_action":
			return "Primed"
		"waiting_refresh":
			return "Refresh"
		"cooldown":
			return "Cooldown"
		"inactive":
			return "Inactive"
		_:
			return state.capitalize()

func _format_weapon_passive_detail(status: Dictionary) -> String:
	var parts: Array[String] = []
	var current: Variant = status.get("current", null)
	var required: Variant = status.get("required", null)
	if current != null and required != null:
		parts.append("%s/%s" % [_format_passive_number(current), _format_passive_number(required)])
	var radial_projectile_count := int(status.get("radial_projectile_count", 0))
	if radial_projectile_count > 0:
		parts.append(LocalizationManager.tr_format(
			"ui.passive.next_radial_volley",
			{"count": radial_projectile_count},
			"Next volley: {count}"
		))
	var trigger_hint := str(status.get("trigger_hint", ""))
	if trigger_hint != "":
		parts.append(trigger_hint)
	var refresh_hint := str(status.get("refresh_hint", ""))
	if refresh_hint != "":
		parts.append("refresh: %s" % refresh_hint)
	var condition_type := str(status.get("condition_type", ""))
	if condition_type != "" and trigger_hint == "":
		parts.append(condition_type)
	var refresh_type := str(status.get("refresh_type", ""))
	if refresh_type != "" and refresh_hint == "":
		parts.append("refresh: %s" % refresh_type)
	var inactive_reason := str(status.get("inactive_reason", ""))
	if inactive_reason != "":
		parts.append(inactive_reason)
	return " | ".join(parts)

func _format_passive_number(value: Variant) -> String:
	var number := float(value)
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))
	return "%.1f" % number

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
	temporary_module_confirm_toggle = pause_menu_panel.get_node_or_null("TemporaryModuleConfirmToggle") as CheckButton
	if temporary_module_confirm_toggle == null:
		temporary_module_confirm_toggle = CheckButton.new()
		temporary_module_confirm_toggle.name = "TemporaryModuleConfirmToggle"
		pause_menu_panel.add_child(temporary_module_confirm_toggle)
	if not temporary_module_confirm_toggle.toggled.is_connected(_on_temporary_module_confirm_toggled):
		temporary_module_confirm_toggle.toggled.connect(_on_temporary_module_confirm_toggled)
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
	if temporary_module_confirm_toggle:
		temporary_module_confirm_toggle.position = Vector2(72.0, 366.0)
		temporary_module_confirm_toggle.size = Vector2(310.0, 30.0)
		temporary_module_confirm_toggle.text = LocalizationManager.tr_key(
			"ui.settings.confirm_temporary_module_sale",
			"Confirm temporary module sale before battle"
		)
		temporary_module_confirm_toggle.button_pressed = _is_temporary_module_confirmation_enabled()

func _on_pause_language_option_item_selected(index: int) -> void:
	if pause_language_option == null:
		return
	var locale := str(pause_language_option.get_item_metadata(index))
	if locale != "":
		LocalizationManager.set_locale(locale)

func _on_temporary_module_confirm_toggled(enabled: bool) -> void:
	_set_temporary_module_confirmation_enabled(enabled)

func _on_language_changed(_new_locale: String) -> void:
	_refresh_localized_static_text()
	_refresh_controls_guide_texts()
	_refresh_heat_fallback_text()
	hud_presenter.refresh_static_texts()
	hud_presenter.refresh_dynamic_texts()
	if route_selection_panel and is_instance_valid(route_selection_panel) and route_selection_panel.visible:
		route_selection_panel._on_language_changed(LocalizationManager.get_locale())
	if reward_selection_panel and is_instance_valid(reward_selection_panel) and reward_selection_panel.visible:
		reward_selection_panel._on_language_changed(LocalizationManager.get_locale())
	if branch_select_panel and is_instance_valid(branch_select_panel) and branch_select_panel.visible:
		branch_select_panel._on_language_changed(LocalizationManager.get_locale())
	if module_equip_selection_panel and is_instance_valid(module_equip_selection_panel) and module_equip_selection_panel.visible:
		module_equip_selection_panel._on_language_changed(LocalizationManager.get_locale())

func _refresh_localized_static_text() -> void:
	_refresh_shop_mode_title()
	if shop_instruction_label:
		shop_instruction_label.text = ""
		shop_instruction_label.visible = false
	if shop_weapon_mode_button:
		shop_weapon_mode_button.text = LocalizationManager.tr_key("ui.purchase.weapons", "购买武器")
	if shop_module_mode_button:
		shop_module_mode_button.text = LocalizationManager.tr_key("ui.purchase.modules", "购买模组")
	var upgrade_title := upgrade_panel.get_node_or_null("Title") as Label
	if upgrade_title:
		upgrade_title.text = LocalizationManager.tr_key("ui.panel.upgrade_combined", "Upgrade Weapons and Modules")
	if upgrade_instruction_label:
		upgrade_instruction_label.text = ""
		upgrade_instruction_label.visible = false
	if upgrade_weapon_mode_button:
		upgrade_weapon_mode_button.text = LocalizationManager.tr_key("ui.upgrade.weapons", "升级武器")
	if upgrade_module_mode_button:
		upgrade_module_mode_button.text = LocalizationManager.tr_key("ui.upgrade.modules", "升级模组")
	var module_title := module_panel.get_node_or_null("Title") as Label
	if module_title:
		module_title.text = LocalizationManager.tr_key("ui.panel.module", "Module")
	if module_instruction_label:
		module_instruction_label.text = LocalizationManager.tr_key("ui.module.instruction", "Select a temporary module, then choose Equip or Sell.")
	shop_sell_button.text = LocalizationManager.tr_key("ui.shop.buy", "购买")
	shop_cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	if shop_sell_summary_title:
		shop_sell_summary_title.text = LocalizationManager.tr_key("ui.shop.sell.title", "Weapons Marked for Sale")
	if shop_sell_summary_hint:
		shop_sell_summary_hint.text = LocalizationManager.tr_key(
			"ui.shop.sell.hint",
			"Select weapons on the right. Confirming sells all marked weapons."
		)
	for slot: EquipmentSlotShop in equipped_shop.get_children():
		slot.refresh_sell_label_text()
	refresh_shop_sell_summary()
	var shop_confirm := shopping_panel.get_node_or_null("ShopConfirmButton") as Button
	if shop_confirm:
		shop_confirm.text = LocalizationManager.tr_key("ui.panel.confirm", "Confirm")
	var shop_refresh := shopping_panel.get_node_or_null("ShopRefreshButton") as Button
	if shop_refresh:
		if shop_refresh.has_method("refresh_button_label"):
			shop_refresh.call("refresh_button_label")
		else:
			shop_refresh.text = LocalizationManager.tr_key("ui.panel.refresh", "Refresh")
	var module_menu_title := module_primary_panel.get_node_or_null("Title") as Label
	if module_menu_title:
		module_menu_title.text = LocalizationManager.tr_key("ui.management.menu.title", "Warehouse Management")
	var module_menu_subtitle := module_primary_panel.get_node_or_null("SubTitle") as Label
	if module_menu_subtitle:
		module_menu_subtitle.text = LocalizationManager.tr_key("ui.management.menu.subtitle", "Open weapon or module warehouse")
	var module_menu_open := module_primary_panel.get_node_or_null("OpenModuleButton") as Button
	if module_menu_open:
		module_menu_open.text = LocalizationManager.tr_key("ui.module.warehouse.title", "Module Warehouse")
	if weapon_warehouse_button:
		weapon_warehouse_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")
	var module_back := module_panel.get_node_or_null("BackToModuleMenu") as Button
	if module_back:
		module_back.text = LocalizationManager.tr_key("ui.panel.back", "Back")
	var merchant_subtitle := merchant_primary_panel.get_node_or_null("SubTitle") as Label
	if merchant_subtitle:
		merchant_subtitle.text = LocalizationManager.tr_key(
			"ui.merchant.purchase.subtitle",
			"选择购买类别"
		)
	var merchant_title := merchant_primary_panel.get_node_or_null("Title") as Label
	if merchant_title:
		merchant_title.text = LocalizationManager.tr_key("ui.merchant.purchase.title", "购买")
	var buy_button := merchant_primary_panel.get_node_or_null("OpenBuyButton") as Button
	if buy_button:
		buy_button.text = LocalizationManager.tr_key("ui.purchase.weapons", "购买武器")
	var warehouse_button := merchant_primary_panel.get_node_or_null("OpenSellButton") as Button
	if warehouse_button:
		warehouse_button.visible = true
		warehouse_button.text = LocalizationManager.tr_key("ui.purchase.modules", "购买模组")
	var smith_title := smith_primary_panel.get_node_or_null("Title") as Label
	if smith_title:
		smith_title.text = LocalizationManager.tr_key("ui.smith.upgrade.title", "升级")
	var smith_subtitle := smith_primary_panel.get_node_or_null("SubTitle") as Label
	if smith_subtitle:
		smith_subtitle.text = LocalizationManager.tr_key("ui.smith.upgrade.subtitle", "选择升级类别")
	var smith_open := smith_primary_panel.get_node_or_null("OpenUpgradeButton") as Button
	if smith_open:
		smith_open.text = LocalizationManager.tr_key("ui.smith.upgrade.weapon", "武器")
	if smith_module_upgrade_button:
		smith_module_upgrade_button.text = LocalizationManager.tr_key("ui.smith.upgrade.module", "模组")
	_refresh_upgrade_action()
	_refresh_module_upgrade_action()
	_refresh_module_action()
	var pause_label := pause_menu_panel.get_node_or_null("Paused") as Label
	if pause_label:
		pause_label.text = LocalizationManager.tr_key("ui.panel.pause", "Paused")
	resume_button.text = LocalizationManager.tr_key("ui.panel.resume", "Resume")
	if hud_presenter and is_instance_valid(hud_presenter):
		hud_presenter.refresh_static_texts()
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
	hud_presenter.refresh_heat_fallback_text()
