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
signal reset_cost

# Upgrade
@onready var equipped_upg: GridContainer = $GUI/UpgradeRootv2/Panel/Equipped
@onready var upgrade_preview: MarginContainer = $GUI/UpgradeRootv2/Panel/UpgradePreview
var upgrade_instruction_label: Label
var upgrade_action_button: Button


@onready var equipped_m: GridContainer = $GUI/ModuleRoot/Panel/EquippedM
@onready var modules: GridContainer = $GUI/ModuleRoot/Panel/TemporaryModulesScroll/Modules
@onready var module_slot_scene: PackedScene = preload("res://UI/scenes/module_slot.tscn")
var module_instruction_label: Label
var module_selection_label: Label
var module_equip_button: Button
var module_sell_button: Button
var selected_temporary_module: Module

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
var branch_select_panel: BranchSelectPanel
var module_equip_selection_panel: ModuleEquipSelectionPanel
var route_selection_panel: RouteSelectionPanel
var reward_selection_panel: RewardSelectionPanel
var weapon_replacement_panel: WeaponReplacementPanel
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
					bool(transaction.get("cancel_to_gold", true))
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

func request_weapon_replacement(
	weapon: Weapon,
	cancel_to_gold: bool = true,
	on_complete: Callable = Callable()
) -> bool:
	_init_weapon_replacement_panel()
	if weapon_replacement_panel == null or not is_instance_valid(weapon_replacement_panel):
		return false
	return weapon_replacement_panel.open_for_weapon(weapon, cancel_to_gold, on_complete)

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
	if shop_sell_summary_panel:
		shop_sell_summary_panel.visible = enabled
	_refresh_shop_mode_title()
	refresh_shop_sell_summary()

func _refresh_shop_mode_title() -> void:
	var shop_title := shopping_panel.get_node_or_null("Title") as Label
	if shop_title:
		shop_title.text = LocalizationManager.tr_key(
			"ui.shop.sell.panel_title" if shop_sell_mode_active else "ui.panel.shop",
			"Sell Weapons" if shop_sell_mode_active else "Shop"
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
	temporary_module_settlement_dialog = ConfirmationDialog.new()
	temporary_module_settlement_dialog.name = "TemporaryModuleSettlementDialog"
	temporary_module_settlement_dialog.dialog_text = ""
	temporary_module_settlement_dialog.wrap_controls = false
	$GUI.add_child(temporary_module_settlement_dialog)
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
	if _rest_area_primary_menu_id == &"module" and module_menu_root and module_menu_root.visible:
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
		if upgrade_rootv_2 and upgrade_rootv_2.visible:
			smith_back_to_primary_menu()
			return true
	elif _rest_area_primary_menu_id == &"module":
		if module_equip_selection_panel and module_equip_selection_panel.visible:
			module_equip_selection_panel.close_without_assignment()
			return true
		if module_root and module_root.visible:
			module_back_to_primary_menu()
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
	update_upg()
	if smith_root:
		smith_root.visible = false
	upgrade_rootv_2.visible = true
	equipped_upg.visible = true

func upg_panel_out() -> void:
	upgrade_rootv_2.visible = false
	InventoryData.clear_on_select()
	refresh_border()

func smith_menu_in() -> void:
	upg_panel_out()
	_show_primary_menu(&"smith", smith_root, smith_primary_panel)

func smith_menu_out() -> void:
	_hide_primary_menu(&"smith", smith_root, smith_primary_panel)
	upg_panel_out()

func smith_open_upgrade_panel() -> void:
	var should_wait := smith_root != null and smith_root.visible
	_hide_primary_menu(&"smith", smith_root, smith_primary_panel)
	if should_wait:
		await get_tree().create_timer(PRIMARY_MENU_ANIM_TIME).timeout
	upg_panel_in()

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

func update_upg() -> void:
	for eq in equipped_upg.get_children():
		eq.update()
	upgrade_preview.update()
	_refresh_upgrade_action()
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
		Vector2(25, 42),
		Vector2(500, 30)
	)
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

	for button_name in ["ShopRefreshButton", "ShopSellButton", "ShopCancelButton", "ShopConfirmButton", "BackToMerchantMenu"]:
		_style_management_button(shopping_panel.get_node_or_null(button_name) as Button)
	_style_management_button(shopping_panel.get_node_or_null("ShopConfirmButton") as Button, true)
	_position_management_button(shopping_panel.get_node_or_null("ShopRefreshButton") as Button, Vector2(325, 548), Vector2(200, 44))
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
	upgrade_action_button.position = Vector2(127, 522)
	upgrade_action_button.size = Vector2(300, 52)
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

func _on_upgrade_action_pressed() -> void:
	if upgrade_preview.has_method("try_upgrade_selected_weapon"):
		upgrade_preview.call("try_upgrade_selected_weapon")

func _refresh_upgrade_action() -> void:
	if upgrade_action_button == null:
		return
	var selected := InventoryData.on_select_upg as Weapon
	var ready := selected != null and is_instance_valid(selected) and bool(upgrade_preview.get("upgradable"))
	upgrade_action_button.disabled = not ready
	upgrade_action_button.text = LocalizationManager.tr_key("ui.upgrade.action", "Upgrade Selected Weapon")

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
		shop_instruction_label.text = LocalizationManager.tr_key("ui.shop.instruction", "Buy weapons on the left, or manage equipped weapons on the right.")
	var upgrade_title := upgrade_panel.get_node_or_null("Title") as Label
	if upgrade_title:
		upgrade_title.text = LocalizationManager.tr_key("ui.panel.upgrade", "Upgrade")
	if upgrade_instruction_label:
		upgrade_instruction_label.text = LocalizationManager.tr_key("ui.upgrade.instruction", "Select a weapon on the right, review changes, then upgrade.")
	var module_title := module_panel.get_node_or_null("Title") as Label
	if module_title:
		module_title.text = LocalizationManager.tr_key("ui.panel.module", "Module")
	if module_instruction_label:
		module_instruction_label.text = LocalizationManager.tr_key("ui.module.instruction", "Select a temporary module, then choose Equip or Sell.")
	shop_sell_button.text = LocalizationManager.tr_key("ui.panel.sell", "Sell")
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
		module_menu_title.text = LocalizationManager.tr_key("ui.module.menu.title", "Module Management")
	var module_menu_subtitle := module_primary_panel.get_node_or_null("SubTitle") as Label
	if module_menu_subtitle:
		module_menu_subtitle.text = LocalizationManager.tr_key("ui.module.menu.subtitle", "Install or remove weapon modules")
	var module_menu_open := module_primary_panel.get_node_or_null("OpenModuleButton") as Button
	if module_menu_open:
		module_menu_open.text = LocalizationManager.tr_key("ui.module.menu.open", "Manage Modules")
	var module_back := module_panel.get_node_or_null("BackToModuleMenu") as Button
	if module_back:
		module_back.text = LocalizationManager.tr_key("ui.panel.back", "Back")
	_refresh_upgrade_action()
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
