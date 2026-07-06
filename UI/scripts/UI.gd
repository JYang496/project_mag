extends CanvasLayer
class_name UI

# Top-level UI coordinator. Keep legacy fields and methods stable while moving
# subsystem behavior into controllers, presenters, and views.

const HP_BAR_ANIM_TIME := 0.2
const HP_BAR_TRANS := Tween.TRANS_SINE
const HP_BAR_EASE := Tween.EASE_OUT
const HUD_PRESENTER_SCRIPT := preload("res://UI/scripts/components/hud_presenter.gd")
const HUD_REFRESH_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/hud_refresh_controller.gd")
const TASK_OBJECTIVE_HUD_PRESENTER_SCRIPT := preload("res://UI/scripts/components/task_objective_hud_presenter.gd")
const UI_DIRTY_SIGNAL_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/ui_dirty_signal_controller.gd")
const WEAPON_PASSIVE_PRESENTER_SCRIPT := preload("res://UI/scripts/components/weapon_passive_presenter.gd")
const WEAPON_PASSIVE_PANEL_VIEW_SCRIPT := preload("res://UI/scripts/components/weapon_passive_panel_view.gd")
const EQUIPMENT_PICKUP_FLOW_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/equipment_pickup_flow_controller.gd")
const WEAPON_BRANCH_SELECTION_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/weapon_branch_selection_controller.gd")
const MODULE_TRANSACTION_DIALOG_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/module_transaction_dialog_controller.gd")
const MODAL_DIALOG_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/modal_dialog_controller.gd")
const TASK_MODULE_DIALOG_CONTROLLER_SCRIPT := preload("res://UI/scripts/components/task_module_dialog_controller.gd")
const REST_AREA_MANAGEMENT_SHELL_SCRIPT := preload("res://UI/scripts/management/rest_area_management_shell.gd")
const REST_AREA_UI_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/rest_area_ui_controller.gd")
const PURCHASE_MANAGEMENT_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/purchase_management_controller.gd")
const UPGRADE_MANAGEMENT_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/upgrade_management_controller.gd")
const MODULE_WAREHOUSE_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/module_warehouse_controller.gd")
const MANAGEMENT_UI_STYLE_HELPER_SCRIPT := preload("res://UI/scripts/management/management_ui_style_helper.gd")
const MANAGEMENT_UI_BOOTSTRAP_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/management_ui_bootstrap_controller.gd")
const MODAL_UI_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/modal_ui_controller.gd")
const UI_LAYOUT_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/ui_layout_controller.gd")
const PAUSE_UI_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/pause_ui_controller.gd")
const LOCALIZATION_REFRESH_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/localization_refresh_controller.gd")
const UI_BOOTSTRAP_CONTROLLER_SCRIPT := preload("res://UI/scripts/management/ui_bootstrap_controller.gd")
const HINT_PRESENTER_SCRIPT := preload("res://UI/scripts/components/hint_presenter.gd")
const BATTLE_CURSOR_PRESENTER_SCRIPT := preload("res://UI/scripts/components/battle_cursor_presenter.gd")
const GLOBAL_UI_THEME := preload("res://UI/themes/global_ui_theme.tres")
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const SPREAD_CURSOR_OVERLAY_SCRIPT_PATH := "res://UI/scripts/spread_cursor_overlay.gd"

# Roots
@onready var gui_root: Control = $GUI
@onready var character_root : Control = $GUI/CharacterRoot
@onready var purchase_management_root: Control = $GUI/PurchaseRoot/ShoppingRootv2
@onready var upgrade_management_root: Control = $GUI/UpgradeRoot/UpgradeRootv2
@onready var upgrade_primary_root: Control = $GUI/UpgradeRoot/PrimaryMenuRoot
@onready var purchase_primary_root: Control = $GUI/PurchaseRoot/PrimaryMenuRoot
@onready var warehouse_primary_root: Control = $GUI/WarehouseRoot/PrimaryMenuRoot
@onready var board_edit_primary_root: Control = $GUI/BoardEditRoot/PrimaryMenuRoot
@onready var battle_start_primary_root: Control = $GUI/BattleStartRoot/PrimaryMenuRoot
@onready var pause_menu_root : Control = $GUI/PauseMenuRoot
@onready var warehouse_management_root: Control = $GUI/WarehouseRoot/ModuleManagementRoot
@onready var purchase_panel: Panel = $GUI/PurchaseRoot/ShoppingRootv2/Panel
@onready var upgrade_panel: Panel = $GUI/UpgradeRoot/UpgradeRootv2/Panel
@onready var module_panel: Panel = $GUI/WarehouseRoot/ModuleManagementRoot/Panel
@onready var pause_menu_panel: Panel = $GUI/PauseMenuRoot/PauseMenuPanel
@onready var purchase_primary_panel: Panel = $GUI/PurchaseRoot/PrimaryMenuRoot/Panel
@onready var upgrade_primary_panel: Panel = $GUI/UpgradeRoot/PrimaryMenuRoot/Panel
@onready var warehouse_primary_panel: Panel = $GUI/WarehouseRoot/PrimaryMenuRoot/Panel
@onready var board_edit_primary_panel: Panel = $GUI/BoardEditRoot/PrimaryMenuRoot/Panel
@onready var battle_start_primary_panel: Panel = $GUI/BattleStartRoot/PrimaryMenuRoot/Panel
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
var shop: VBoxContainer
var shop_refresh_button: Button
var shop_purchase_button: Button
var shop_back_button: Button
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
@warning_ignore("unused_private_class_variable")
var _shop_purchase_mode: StringName = &"weapon"
@warning_ignore("unused_private_class_variable")
var _shop_hover_item: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _shop_selected_item: Dictionary = {}
@warning_ignore("unused_signal")
signal reset_cost

# Upgrade
var upgrade_instruction_label: Label
var upgrade_action_button: Button
var upgrade_mode_buttons: HBoxContainer
var upgrade_weapon_mode_button: Button
var upgrade_module_mode_button: Button
var upgrade_item_scroll: ScrollContainer
var upgrade_item_list: BoxContainer
var upgrade_detail_panel: PanelContainer
var upgrade_detail_title: Label
var upgrade_detail_subtitle: Label
var upgrade_detail_body: VBoxContainer
@warning_ignore("unused_private_class_variable")
var _upgrade_mode: StringName = &"weapon"
@warning_ignore("unused_private_class_variable")
var _upgrade_hover_item: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _upgrade_selected_item: Dictionary = {}
var selected_upgrade_module: Module


var equipped_m: GridContainer
var modules: GridContainer
var module_instruction_label: Label
var module_selection_label: Label
var module_equip_button: Button
var module_sell_button: Button
var selected_temporary_module: Module
var weapon_warehouse_button: Button
var upgrade_module_button: Button

# Pause menu
@onready var resume_button = $GUI/PauseMenuRoot/PauseMenuPanel/ResumeButton

# Misc
var branch_select_panel: BranchSelectPanel
var module_equip_selection_panel: ModuleEquipSelectionPanel
var route_selection_panel: RouteSelectionPanel
var reward_selection_panel: RewardSelectionPanel
var weapon_replacement_panel: WeaponReplacementPanel
var weapon_warehouse_panel: WeaponWarehousePanel
var purchase_management_view
var module_shop_list_view
var upgrade_management_view
var module_management_view
@warning_ignore("unused_private_class_variable")
var _branch_selection_queue: Array[Dictionary] = []
@warning_ignore("unused_private_class_variable")
var _equipment_pickup_queue: Array[Dictionary] = []
@warning_ignore("unused_private_class_variable")
var _equipment_pickup_processing := false
@warning_ignore("unused_private_class_variable")
var _equipment_pickup_dispatch_scheduled := false
# Compatibility mirrors written by RestAreaUiController for tests/external probes.
@warning_ignore("unused_private_class_variable")
var _rest_area_menu_active := false
@warning_ignore("unused_private_class_variable")
var _rest_area_primary_menu_id: StringName = &""
var game_over_view
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
var controls_hint_view
var right_hud_stack: VBoxContainer
var board_edit_panel: Control
var cell_management_panel: Control
@warning_ignore("unused_private_class_variable")
var _primary_menu_tweens: Dictionary = {}
var spread_cursor_overlay
var hud_presenter: HudPresenter
var hud_refresh_controller
var task_objective_hud_presenter
var ui_dirty_signal_controller
var weapon_passive_presenter
var weapon_passive_panel_view
var equipment_pickup_flow_controller
var weapon_branch_selection_controller
var module_transaction_dialog_controller
var modal_dialog_controller
var task_module_dialog_controller
var rest_area_management_shell
var rest_area_ui_controller
var purchase_management_controller
var upgrade_management_controller
var module_warehouse_controller
var management_ui_style_helper = MANAGEMENT_UI_STYLE_HELPER_SCRIPT.new()
var management_ui_bootstrap_controller
var modal_ui_controller
var ui_layout_controller
var pause_ui_controller
var localization_refresh_controller
var ui_bootstrap_controller
var hint_presenter
var battle_cursor_presenter
var _weapon_passive_rows: Array[Dictionary] = []
var _weapon_passive_panel_dirty := true
var _weapon_passive_panel_refresh_timer := 0.0
const WEAPON_PASSIVE_PANEL_REFRESH_INTERVAL := 1.0
var _shop_purchase_action_dirty := true
var _management_action_refresh_scheduled := false
@warning_ignore("unused_private_class_variable")
var _passive_status_signal_weapons: Array[Node] = []
var _upgrade_action_dirty := true
var _warehouse_action_dirty := true


# Lifecycle and bootstrap

func _ready():
	GlobalVariables.ui = self
	# Reduce input-to-render latency for custom cursor overlays.
	Input.use_accumulated_input = false
	gui_root.theme = GLOBAL_UI_THEME
	_init_ui_bootstrap_controller()
	ui_bootstrap_controller.bootstrap()
	_init_task_objective_hud_presenter()
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.connect("language_changed", Callable(self, "_on_language_changed"))
	call_deferred("_refresh_initial_prepare_shop")
	call_deferred("_restore_pending_equipment_transactions")

func _exit_tree() -> void:
	_disconnect_ui_dirty_signals()
	_disconnect_weapon_passive_status_signals()
	if modal_ui_controller != null:
		modal_ui_controller.clear_modal_registry()
	if task_module_dialog_controller != null:
		task_module_dialog_controller.dispose()
	if GlobalVariables.ui == self:
		GlobalVariables.ui = null

func _init_ui_bootstrap_controller() -> void:
	if ui_bootstrap_controller != null:
		return
	ui_bootstrap_controller = UI_BOOTSTRAP_CONTROLLER_SCRIPT.new()
	ui_bootstrap_controller.bind(self)

func _bind_weapon_selector() -> void:
	if weapon_selector and is_instance_valid(weapon_selector):
		weapon_selector.bind_player_data()
		weapon_selector.refresh_slots()

func _refresh_initial_prepare_shop() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	_init_rest_area_ui_controller()
	rest_area_ui_controller.reset_purchase_refresh_cost()

func _restore_pending_equipment_transactions() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if InventoryData.pending_transactions.is_empty():
		return
	var transaction := InventoryData.pending_transactions[0] as Dictionary
	match str(transaction.get("type", "")):
		"weapon_replacement":
			var weapon_payload := transaction.get("weapon", {}) as Dictionary
			var weapon := DataHandler.instantiate_weapon_from_save_payload(weapon_payload)
			if weapon:
				add_child(weapon)
				DataHandler.restore_weapon_runtime_from_save_payload(weapon, weapon_payload)
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

func _init_modal_ui_controller() -> void:
	if modal_ui_controller != null:
		return
	modal_ui_controller = MODAL_UI_CONTROLLER_SCRIPT.new()
	modal_ui_controller.bind(self, gui_root)

func _init_ui_layout_controller() -> void:
	if ui_layout_controller != null:
		return
	_init_rest_area_management_shell()
	ui_layout_controller = UI_LAYOUT_CONTROLLER_SCRIPT.new()
	ui_layout_controller.bind(self, rest_area_management_shell)
	if rest_area_ui_controller != null:
		rest_area_ui_controller.set_layout_controller(ui_layout_controller)

func _init_pause_ui_controller() -> void:
	if pause_ui_controller != null:
		return
	pause_ui_controller = PAUSE_UI_CONTROLLER_SCRIPT.new()
	pause_ui_controller.bind(self, pause_menu_panel, resume_button)

func _init_localization_refresh_controller() -> void:
	if localization_refresh_controller != null:
		return
	localization_refresh_controller = LOCALIZATION_REFRESH_CONTROLLER_SCRIPT.new()
	localization_refresh_controller.bind(self)

func _init_branch_select_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_branch_select_panel()

func _init_module_equip_selection_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_module_equip_selection_panel()

func _init_route_selection_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_route_selection_panel()

func _init_reward_selection_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_reward_selection_panel()

func _init_board_edit_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_board_edit_panel()

func _init_cell_management_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_cell_management_panel()

func open_cell_management_panel(mode: StringName = &"task") -> bool:
	_init_modal_ui_controller()
	return modal_ui_controller.open_cell_management_panel(mode)

func request_close_cell_management_panel() -> bool:
	_init_modal_ui_controller()
	return modal_ui_controller.request_close_cell_management_panel()

func _on_cell_management_board_requested() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.open_cell_board_management()

func open_board_edit_panel() -> bool:
	_init_modal_ui_controller()
	return modal_ui_controller.open_board_edit_panel()

func request_close_board_edit_panel(_confirm_pending: bool = true) -> bool:
	_init_modal_ui_controller()
	return modal_ui_controller.request_close_board_edit_panel()

func _on_board_edit_panel_close_requested() -> void:
	request_close_board_edit_panel(true)

func _close_board_edit_panel_without_confirmation() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.close_board_edit_panel_without_confirmation()

func _find_board() -> BoardCellGenerator:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Board") as BoardCellGenerator

func request_cell_effect_commit_confirmation(on_confirm: Callable, on_cancel: Callable = Callable()) -> bool:
	if not CellEffectRuntime.has_pending_edits():
		if on_confirm.is_valid():
			on_confirm.call_deferred()
		return true
	var lines := CellEffectRuntime.build_pending_commit_lines()
	var text := LocalizationManager.tr_key("ui.board_edit.commit_prompt", "Leave the board edit panel with these pending edits?") + "\n\n"
	text += "\n".join(lines)
	text += "\n\n" + LocalizationManager.tr_key("ui.board_edit.commit_warning", "These edits stay pending after you leave. Cell effect items are consumed only when battle starts.")
	return request_confirmation(
		&"cell_effect_commit",
		LocalizationManager.tr_key("ui.board_edit.commit_title", "Pending Board Edits"),
		text,
		LocalizationManager.tr_key("ui.board_edit.leave_panel", "Leave Panel"),
		LocalizationManager.tr_key("ui.common.cancel", "Cancel"),
		on_confirm,
		on_cancel,
		false,
		Vector2i(560, 360)
	)

func _init_weapon_replacement_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_weapon_replacement_panel()

func _init_weapon_warehouse_panel() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_weapon_warehouse_panel()

func _init_purchase_management_controller() -> void:
	if purchase_management_controller != null:
		return
	purchase_management_controller = PURCHASE_MANAGEMENT_CONTROLLER_SCRIPT.new()
	purchase_management_controller.bind(self, purchase_panel)

func _init_upgrade_management_controller() -> void:
	if upgrade_management_controller != null:
		return
	upgrade_management_controller = UPGRADE_MANAGEMENT_CONTROLLER_SCRIPT.new()
	upgrade_management_controller.bind(self, upgrade_panel, upgrade_instruction_label)

func _init_module_warehouse_controller() -> void:
	if module_warehouse_controller != null:
		return
	module_warehouse_controller = MODULE_WAREHOUSE_CONTROLLER_SCRIPT.new()
	module_warehouse_controller.bind(self, module_panel)

func _init_management_ui_bootstrap_controller() -> void:
	if management_ui_bootstrap_controller != null:
		return
	management_ui_bootstrap_controller = MANAGEMENT_UI_BOOTSTRAP_CONTROLLER_SCRIPT.new()
	management_ui_bootstrap_controller.bind(self)


# Modal requests and blocking selection flows

func request_weapon_replacement(
	weapon: Weapon,
	allow_cancel: bool = true,
	on_complete: Callable = Callable()
) -> bool:
	_init_weapon_replacement_panel()
	if weapon_replacement_panel == null or not is_instance_valid(weapon_replacement_panel):
		return false
	return weapon_replacement_panel.open_for_weapon(weapon, allow_cancel, on_complete)

func request_weapon_pickup_selection(weapon: Weapon) -> bool:
	_init_equipment_pickup_flow_controller()
	return equipment_pickup_flow_controller.request_weapon_pickup_selection(weapon)

func request_module_pickup_selection(
	module_instance: Module,
	on_complete: Callable = Callable()
) -> bool:
	_init_equipment_pickup_flow_controller()
	return equipment_pickup_flow_controller.request_module_pickup_selection(module_instance, on_complete)

func _schedule_equipment_pickup_queue() -> void:
	_init_equipment_pickup_flow_controller()
	equipment_pickup_flow_controller.call("_schedule")

func _is_equipment_pickup_modal_open() -> bool:
	_init_equipment_pickup_flow_controller()
	return equipment_pickup_flow_controller.call("_is_modal_open")

func _find_next_equipment_pickup_index() -> int:
	_init_equipment_pickup_flow_controller()
	return int(equipment_pickup_flow_controller.call("_find_next_index"))

func _request_next_queued_equipment_pickup() -> void:
	_init_equipment_pickup_flow_controller()
	equipment_pickup_flow_controller.request_next_queued_pickup()

func _open_queued_equipment_pickup(entry: Dictionary) -> bool:
	_init_equipment_pickup_flow_controller()
	return bool(equipment_pickup_flow_controller.call("_open_entry", entry))

func _on_queued_weapon_pickup_completed(_accepted: bool = false, _result: Dictionary = {}) -> void:
	_init_equipment_pickup_flow_controller()
	equipment_pickup_flow_controller.on_weapon_pickup_completed(_accepted, _result)

func _complete_queued_module_pickup(assigned: bool, on_complete: Callable = Callable()) -> void:
	_init_equipment_pickup_flow_controller()
	equipment_pickup_flow_controller.complete_module_pickup(assigned, on_complete)

func _init_module_action_dialogs() -> void:
	_init_modal_dialog_controller()
	_init_task_module_dialog_controller()
	if module_transaction_dialog_controller == null:
		module_transaction_dialog_controller = MODULE_TRANSACTION_DIALOG_CONTROLLER_SCRIPT.new()
		module_transaction_dialog_controller.bind(self, gui_root, modal_dialog_controller)
	else:
		module_transaction_dialog_controller.set_modal_dialog_controller(modal_dialog_controller)
	module_transaction_dialog_controller.ensure_dialogs()
	_sync_module_transaction_dialog_refs()

func _init_modal_dialog_controller() -> void:
	if modal_dialog_controller != null:
		return
	modal_dialog_controller = MODAL_DIALOG_CONTROLLER_SCRIPT.new()
	modal_dialog_controller.bind(self, gui_root)

func _init_task_module_dialog_controller() -> void:
	_init_modal_dialog_controller()
	if task_module_dialog_controller != null:
		return
	task_module_dialog_controller = TASK_MODULE_DIALOG_CONTROLLER_SCRIPT.new()
	task_module_dialog_controller.bind(modal_dialog_controller)

func confirm(spec: Dictionary) -> bool:
	_init_modal_dialog_controller()
	return modal_dialog_controller.confirm(spec)

func request_confirmation(
	id: StringName,
	title: String,
	body: String,
	confirm_text: String = "OK",
	cancel_text: String = "Cancel",
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable(),
	destructive: bool = false,
	size = null,
	checkbox_text: String = "",
	checkbox_callback: Callable = Callable()
) -> bool:
	_init_modal_dialog_controller()
	return modal_dialog_controller.request_confirmation(
		id,
		title,
		body,
		confirm_text,
		cancel_text,
		on_confirm,
		on_cancel,
		destructive,
		size,
		checkbox_text,
		checkbox_callback
	)

func is_dialog_visible() -> bool:
	return modal_dialog_controller != null and modal_dialog_controller.is_dialog_visible()

func is_world_interaction_blocked() -> bool:
	if is_dialog_visible():
		return true
	if _has_pending_module_transaction_dialog():
		return true
	if _is_modal_selection_world_interaction_blocked():
		return true
	if _is_rest_area_world_interaction_blocked():
		return true
	return false

func cancel_visible_dialog() -> bool:
	if modal_dialog_controller == null:
		return false
	return modal_dialog_controller.cancel_visible_dialog()

func _sync_module_transaction_dialog_refs() -> void:
	if module_transaction_dialog_controller == null:
		return
	module_action_dialog = module_transaction_dialog_controller.module_action_dialog
	temporary_module_settlement_dialog = module_transaction_dialog_controller.temporary_module_settlement_dialog
	temporary_module_settlement_message = module_transaction_dialog_controller.temporary_module_settlement_message
	temporary_module_settlement_checkbox = module_transaction_dialog_controller.temporary_module_settlement_checkbox
	_pending_module_action = module_transaction_dialog_controller.pending_module_action
	_pending_battle_start = module_transaction_dialog_controller.pending_battle_start
	_pending_battle_start_cancel = module_transaction_dialog_controller.pending_battle_start_cancel

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
	_init_module_action_dialogs()
	if module_transaction_dialog_controller != null:
		var result: bool = module_transaction_dialog_controller.request_module_unequip_confirmation(module_instance, weapon)
		_sync_module_transaction_dialog_refs()
		return result
	return false

func _confirm_module_unequip(module_instance: Module, weapon: Weapon) -> void:
	if module_transaction_dialog_controller != null:
		module_transaction_dialog_controller.call("_confirm_module_unequip", module_instance, weapon)
		_sync_module_transaction_dialog_refs()

func request_temporary_module_sell_confirmation(module_instance: Module) -> bool:
	_init_module_action_dialogs()
	if module_transaction_dialog_controller != null:
		var result: bool = module_transaction_dialog_controller.request_temporary_module_sell_confirmation(module_instance)
		_sync_module_transaction_dialog_refs()
		return result
	return false

func _confirm_temporary_module_sell(module_instance: Module) -> void:
	if module_transaction_dialog_controller != null:
		module_transaction_dialog_controller.call("_confirm_temporary_module_sell", module_instance)
		_sync_module_transaction_dialog_refs()

func _on_module_action_confirmed() -> void:
	if module_transaction_dialog_controller != null:
		module_transaction_dialog_controller.call("_on_module_action_confirmed")
		_sync_module_transaction_dialog_refs()

func request_temporary_module_settlement(
	on_complete: Callable,
	on_cancel: Callable = Callable()
) -> bool:
	_init_module_action_dialogs()
	if module_transaction_dialog_controller != null:
		var result: bool = module_transaction_dialog_controller.request_temporary_module_settlement(on_complete, on_cancel)
		_sync_module_transaction_dialog_refs()
		return result
	return false

func _on_temporary_module_settlement_confirmed() -> void:
	if module_transaction_dialog_controller != null:
		module_transaction_dialog_controller.confirm_temporary_module_settlement()
		_sync_module_transaction_dialog_refs()

func _on_temporary_module_settlement_cancelled() -> void:
	if module_transaction_dialog_controller != null:
		module_transaction_dialog_controller.cancel_temporary_module_settlement()
		_sync_module_transaction_dialog_refs()

func has_pending_blocking_transaction() -> bool:
	if has_pending_branch_selection():
		return true
	if weapon_replacement_panel and weapon_replacement_panel.visible:
		return true
	if module_equip_selection_panel and module_equip_selection_panel.visible:
		return true
	return false

func _has_pending_module_transaction_dialog() -> bool:
	if module_transaction_dialog_controller != null:
		if module_transaction_dialog_controller.active_dialog_id != &"":
			return true
		if module_transaction_dialog_controller.pending_module_action.is_valid():
			return true
		if module_transaction_dialog_controller.pending_battle_start.is_valid():
			return true
		if module_transaction_dialog_controller.pending_battle_start_cancel.is_valid():
			return true
	if _pending_module_action.is_valid():
		return true
	if _pending_battle_start.is_valid():
		return true
	if _pending_battle_start_cancel.is_valid():
		return true
	if module_action_dialog and is_instance_valid(module_action_dialog) and module_action_dialog.visible:
		return true
	if temporary_module_settlement_dialog and is_instance_valid(temporary_module_settlement_dialog) and temporary_module_settlement_dialog.visible:
		return true
	return false

func _is_modal_selection_world_interaction_blocked() -> bool:
	if modal_ui_controller != null:
		return modal_ui_controller.is_world_interaction_blocking_modal_open()
	for panel in [
		branch_select_panel,
		weapon_replacement_panel,
		route_selection_panel,
		reward_selection_panel,
		module_equip_selection_panel,
	]:
		if panel == null or not is_instance_valid(panel):
			continue
		if panel.has_method("is_modal_open") and bool(panel.call("is_modal_open")):
			return true
		if bool(panel.get("visible")):
			return true
	return false

func _is_temporary_module_confirmation_enabled() -> bool:
	if module_transaction_dialog_controller != null:
		return module_transaction_dialog_controller.is_temporary_module_confirmation_enabled()
	return true

func _set_temporary_module_confirmation_enabled(enabled: bool) -> void:
	if module_transaction_dialog_controller != null:
		module_transaction_dialog_controller.set_temporary_module_confirmation_enabled(enabled)
		if temporary_module_confirm_toggle:
			temporary_module_confirm_toggle.button_pressed = enabled
		return
	if temporary_module_confirm_toggle:
		temporary_module_confirm_toggle.button_pressed = enabled

func request_weapon_branch_selection(weapon: Weapon, target_fuse: int = 0) -> bool:
	_init_weapon_branch_selection_controller()
	return weapon_branch_selection_controller.request_weapon_branch_selection(weapon, target_fuse)

func has_pending_branch_selection() -> bool:
	_init_weapon_branch_selection_controller()
	return weapon_branch_selection_controller.has_pending_selection()

func is_branch_selection_blocking_interactions() -> bool:
	_init_weapon_branch_selection_controller()
	return weapon_branch_selection_controller.is_blocking_interactions()

func _is_branch_selection_safe_state() -> bool:
	_init_weapon_branch_selection_controller()
	return bool(weapon_branch_selection_controller.call("_is_safe_state"))

func _warn_skipped_branch_selection(weapon_id: String, target_fuse: int, reason: String) -> void:
	_init_weapon_branch_selection_controller()
	weapon_branch_selection_controller.call("_warn_skipped", weapon_id, target_fuse, reason)

func _open_branch_panel_for_queue_entry(entry: Dictionary) -> bool:
	_init_weapon_branch_selection_controller()
	return bool(weapon_branch_selection_controller.call("_open_entry", entry))

func _request_next_queued_weapon_branch_selection() -> void:
	_init_weapon_branch_selection_controller()
	weapon_branch_selection_controller.request_next()

func request_module_equip_selection(
	module_instance: Module,
	on_complete: Callable = Callable(),
	allow_reward_transaction: bool = false
) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	_init_rest_area_ui_controller()
	if not allow_reward_transaction and not rest_area_ui_controller.is_module_management_available():
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
	allow_cancel: bool = true,
	show_draft_hint: bool = false
) -> bool:
	if is_branch_selection_blocking_interactions():
		show_item_message(LocalizationManager.tr_key("ui.branch.pending_blocks", "Choose an evolution branch first."), 1.6)
		return false
	_init_reward_selection_panel()
	if reward_selection_panel == null or not is_instance_valid(reward_selection_panel):
		return false
	return reward_selection_panel.open_for_rewards(
		route_display_name,
		reward_options,
		on_confirm,
		on_cancel,
		allow_cancel,
		"",
		"",
		0,
		0,
		show_draft_hint
	)

func request_task_reward_selection(
	reward_options: Array[RewardInfo],
	on_confirm: Callable,
	progress_index: int = 0,
	progress_total: int = 0
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
		LocalizationManager.tr_key("ui.task_reward.title", "Objective Complete"),
		LocalizationManager.tr_key("ui.task_reward.subtitle", "Choose 1 reward"),
		progress_index,
		progress_total
	)

func request_task_reward_summary(
	rewards: Array[RewardInfo],
	on_close: Callable
) -> bool:
	_init_reward_selection_panel()
	if reward_selection_panel == null or not is_instance_valid(reward_selection_panel):
		return false
	return reward_selection_panel.open_for_summary(
		rewards,
		on_close,
		LocalizationManager.tr_key("ui.task_reward.summary_title", "Objective Rewards"),
		LocalizationManager.tr_key("ui.task_reward.summary_subtitle", "Rewards added to inventory.")
	)

func resume_pending_weapon_branch_selection() -> void:
	_init_weapon_branch_selection_controller()
	weapon_branch_selection_controller.request_next()

func _on_branch_selected(weapon: Weapon, branch_id: String) -> void:
	_init_weapon_branch_selection_controller()
	weapon_branch_selection_controller.on_branch_selected(weapon, branch_id)

func _finalize_branch_selected_weapon(weapon: Weapon) -> void:
	_init_weapon_branch_selection_controller()
	weapon_branch_selection_controller.finalize_branch_selected_weapon(weapon)


# Frame updates and player input

func _physics_process(delta: float) -> void:
	_refresh_hud_if_needed(delta)
	_refresh_task_objective_hud_if_needed(delta)
	_refresh_weapon_passive_panel_if_needed(delta)
	_refresh_controls_hint_visibility()
	if controls_hint_view != null and is_instance_valid(controls_hint_view):
		controls_hint_view.tick(delta)
	_update_rest_area_hover_hint_position()

func _refresh_hud_if_needed(delta: float) -> void:
	_init_hud_refresh_controller()
	hud_refresh_controller.refresh_if_needed(delta)

func _refresh_task_objective_hud_if_needed(delta: float) -> void:
	if task_objective_hud_presenter == null:
		return
	if task_objective_hud_presenter.refresh_if_needed(delta):
		_increment_ui_refresh_debug_count("task_objective_hud")

func _refresh_task_objective_hud(force: bool = false) -> void:
	if task_objective_hud_presenter == null:
		return
	task_objective_hud_presenter.mark_dirty()
	task_objective_hud_presenter.refresh(force)

func _increment_ui_refresh_debug_count(key: String) -> void:
	_init_hud_refresh_controller()
	hud_refresh_controller.increment_debug_count(key)

func reset_ui_refresh_debug_counts() -> void:
	_init_hud_refresh_controller()
	hud_refresh_controller.reset_debug_counts()

func get_ui_refresh_debug_counts() -> Dictionary:
	_init_hud_refresh_controller()
	return hud_refresh_controller.get_debug_counts()

func _ensure_hud_presenter_instance() -> void:
	if hud_presenter and is_instance_valid(hud_presenter):
		return
	hud_presenter = HUD_PRESENTER_SCRIPT.new() as HudPresenter

func _init_hud_presenter() -> void:
	_ensure_hud_presenter_instance()
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
	_init_hud_refresh_controller()

func _init_hud_refresh_controller() -> void:
	_ensure_hud_presenter_instance()
	if hud_refresh_controller == null:
		hud_refresh_controller = HUD_REFRESH_CONTROLLER_SCRIPT.new()
	hud_refresh_controller.bind(hud_presenter)

func _init_task_objective_hud_presenter() -> void:
	if task_objective_hud_presenter != null:
		return
	task_objective_hud_presenter = TASK_OBJECTIVE_HUD_PRESENTER_SCRIPT.new()
	task_objective_hud_presenter.bind(self, _ensure_right_hud_stack())
	task_objective_hud_presenter.layout(get_viewport().get_visible_rect().size)

func _init_ui_dirty_signal_controller() -> void:
	if ui_dirty_signal_controller != null:
		return
	ui_dirty_signal_controller = UI_DIRTY_SIGNAL_CONTROLLER_SCRIPT.new()
	ui_dirty_signal_controller.bind(self)

func _init_weapon_passive_presenter() -> void:
	if weapon_passive_presenter != null:
		return
	weapon_passive_presenter = WEAPON_PASSIVE_PRESENTER_SCRIPT.new()

func _init_weapon_passive_panel_view() -> void:
	if weapon_passive_panel_view != null:
		return
	weapon_passive_panel_view = WEAPON_PASSIVE_PANEL_VIEW_SCRIPT.new()
	weapon_passive_panel_view.bind(character_root)

func _init_equipment_pickup_flow_controller() -> void:
	if equipment_pickup_flow_controller != null:
		return
	equipment_pickup_flow_controller = EQUIPMENT_PICKUP_FLOW_CONTROLLER_SCRIPT.new()
	equipment_pickup_flow_controller.bind(self)

func _init_weapon_branch_selection_controller() -> void:
	if weapon_branch_selection_controller != null:
		return
	weapon_branch_selection_controller = WEAPON_BRANCH_SELECTION_CONTROLLER_SCRIPT.new()
	weapon_branch_selection_controller.bind(self)

func _sync_weapon_passive_panel_view_refs() -> void:
	if weapon_passive_panel_view == null:
		return
	weapon_passive_panel = weapon_passive_panel_view.weapon_passive_panel
	weapon_passive_list = weapon_passive_panel_view.weapon_passive_list
	_weapon_passive_rows = weapon_passive_panel_view.weapon_passive_rows

func _init_rest_area_management_shell() -> void:
	if rest_area_management_shell != null:
		return
	rest_area_management_shell = REST_AREA_MANAGEMENT_SHELL_SCRIPT.new()
	rest_area_management_shell.bind(self)

func _init_rest_area_ui_controller() -> void:
	if rest_area_ui_controller != null:
		return
	_init_rest_area_management_shell()
	rest_area_ui_controller = REST_AREA_UI_CONTROLLER_SCRIPT.new()
	rest_area_ui_controller.bind(self, rest_area_management_shell, ui_layout_controller)

func _init_hint_presenter() -> void:
	if hint_presenter != null:
		return
	hint_presenter = HINT_PRESENTER_SCRIPT.new()
	hint_presenter.bind(self, gui_root)

func _init_battle_cursor_presenter() -> void:
	if battle_cursor_presenter != null:
		return
	battle_cursor_presenter = BATTLE_CURSOR_PRESENTER_SCRIPT.new()
	battle_cursor_presenter.bind(self, spread_cursor_overlay)

func _process(_delta: float) -> void:
	# Cursor-follow visuals should run on render frames to minimize perceived mouse lag.
	_update_spread_cursor_overlay()
func _input(_event) -> void:
	if _event is InputEventMouseMotion:
		var motion := _event as InputEventMouseMotion
		_update_spread_cursor_overlay(motion.position)
	if controls_hint_view != null and is_instance_valid(controls_hint_view) \
			and controls_hint_view.handle_input_event(_event):
		get_viewport().set_input_as_handled()
		return

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


# Rest-area management compatibility entrypoints

func handle_non_battle_right_cancel() -> bool:
	return _cancel_top_level_non_battle_ui()

func _cancel_top_level_non_battle_ui() -> bool:
	if module_transaction_dialog_controller != null and module_transaction_dialog_controller.cancel_visible_dialog():
		_sync_module_transaction_dialog_refs()
		return true
	if cancel_visible_dialog():
		return true
	if modal_ui_controller != null and modal_ui_controller.cancel_visible_modal():
		return true
	if temporary_module_settlement_dialog and temporary_module_settlement_dialog.visible:
		temporary_module_settlement_dialog.hide()
		_on_temporary_module_settlement_cancelled()
		return true
	if module_action_dialog and module_action_dialog.visible:
		module_action_dialog.hide()
		_pending_module_action = Callable()
		return true
	if board_edit_panel and is_instance_valid(board_edit_panel) and board_edit_panel.visible:
		if board_edit_panel.has_method("clear_selection_if_any") and bool(board_edit_panel.call("clear_selection_if_any")):
			return true
		return request_close_board_edit_panel(true)
	if rest_area_ui_controller != null and rest_area_ui_controller.active:
		return rest_area_ui_controller.cancel_menu_level()
	return false

func reset_purchase_refresh_cost() -> void:
	# Compatibility entrypoint for PhaseManager prepare refresh.
	_init_rest_area_ui_controller()
	rest_area_ui_controller.reset_purchase_refresh_cost()

func _show_module_rest_area_only_message() -> void:
	show_item_message(LocalizationManager.tr_key(
		"ui.module.reason.rest_area_only",
		"Modules can only be managed in the Rest Area."
	), 1.8)

# Management view polish and controller bridges

func _init_management_ui_polish() -> void:
	_init_management_ui_bootstrap_controller()
	management_ui_bootstrap_controller.init_management_ui_polish()

func _refresh_shop_purchase_action_if_needed() -> void:
	if not _shop_purchase_action_dirty:
		return
	if purchase_management_controller == null:
		return
	if purchase_management_root == null or not purchase_management_root.visible:
		return
	purchase_management_controller.refresh_purchase_action()
	_shop_purchase_action_dirty = false
	_increment_ui_refresh_debug_count("shop_purchase_action")

func _schedule_management_action_refresh() -> void:
	if _management_action_refresh_scheduled:
		return
	_management_action_refresh_scheduled = true
	call_deferred("_refresh_management_actions_deferred")

func _refresh_management_actions_deferred() -> void:
	_management_action_refresh_scheduled = false
	_refresh_shop_purchase_action_if_needed()
	_refresh_management_actions_if_needed()

func _refresh_management_actions_if_needed() -> void:
	if _upgrade_action_dirty and upgrade_management_controller != null \
			and upgrade_management_root != null and upgrade_management_root.visible:
		upgrade_management_controller.refresh_action()
		_upgrade_action_dirty = false
		_increment_ui_refresh_debug_count("upgrade_action")
	if _warehouse_action_dirty and module_warehouse_controller != null \
			and warehouse_management_root != null and warehouse_management_root.visible:
		module_warehouse_controller.refresh_action()
		_warehouse_action_dirty = false
		_increment_ui_refresh_debug_count("warehouse_action")

func _ensure_management_menu_buttons() -> void:
	_init_management_ui_bootstrap_controller()
	management_ui_bootstrap_controller.ensure_management_menu_buttons()

func _style_primary_menu_controls() -> void:
	_init_management_ui_bootstrap_controller()
	management_ui_bootstrap_controller.style_primary_menu_controls()

func is_rest_area_zone_navigation_allowed() -> bool:
	# Compatibility entrypoint for RestArea/world-blocking tests.
	_init_rest_area_ui_controller()
	return rest_area_ui_controller.is_zone_navigation_allowed()

func is_rest_area_menu_visible() -> bool:
	# Compatibility entrypoint for RestArea menu state sync and tests.
	_init_rest_area_ui_controller()
	return rest_area_ui_controller.is_menu_visible()

func request_task_module_unassigned_confirmation(
	unassigned_count: int,
	on_confirm: Callable,
	on_cancel: Callable = Callable()
) -> bool:
	_init_task_module_dialog_controller()
	return task_module_dialog_controller.request_unassigned_confirmation(
		unassigned_count,
		on_confirm,
		on_cancel
	)

func request_task_module_replacement(new_module_id: String, on_replace: Callable) -> bool:
	_init_task_module_dialog_controller()
	return task_module_dialog_controller.request_replacement(new_module_id, on_replace)

func _on_management_panel_gui_input(event: InputEvent, panel: Panel) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		panel.accept_event()

func _style_management_button(button: Button, primary: bool = false) -> void:
	management_ui_style_helper.style_management_button(button, primary)

func _refresh_mode_button_styles(
	weapon_button: Button,
	module_button: Button,
	weapon_mode_active: bool
) -> void:
	management_ui_style_helper.refresh_mode_button_styles(weapon_button, module_button, weapon_mode_active)

func _on_resume_button_pressed() -> void:
	if get_tree().paused:
		# Unpause and hide UI
		get_tree().paused = false
		pause_menu_root.visible = false
	_update_cursor_presentation()


# Phase changes, pause state, and battle cursor

func _on_phase_changed(new_phase: String) -> void:
	if new_phase != PhaseManager.PREPARE:
		_init_rest_area_ui_controller()
		rest_area_ui_controller.close_module_management_ui()
		if board_edit_panel and is_instance_valid(board_edit_panel):
			board_edit_panel.close_panel()
	if new_phase == PhaseManager.GAMEOVER:
		_show_game_over()
	_request_next_queued_weapon_branch_selection()
	_update_controls_guide_for_phase(new_phase)
	_update_cursor_presentation()
	_refresh_task_objective_hud(true)

func _should_use_battle_ring_cursor() -> bool:
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		return false
	if get_tree().paused:
		return false
	if pause_menu_root and is_instance_valid(pause_menu_root) and pause_menu_root.visible:
		return false
	if game_over_view and is_instance_valid(game_over_view) and game_over_view.visible:
		return false
	if _is_primary_menu_open() or is_world_interaction_blocked():
		return false
	return true

func _update_cursor_presentation() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _should_use_battle_ring_cursor():
		_apply_battle_hardware_cursor()
	else:
		_clear_battle_hardware_cursor()

func _apply_battle_hardware_cursor() -> void:
	_init_battle_cursor_presenter()
	battle_cursor_presenter.apply_battle_hardware_cursor()

func _clear_battle_hardware_cursor() -> void:
	if battle_cursor_presenter == null:
		return
	battle_cursor_presenter.clear_battle_hardware_cursor()


# Game-over and controls hint views

func _show_game_over() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.show_game_over()


func _create_game_over_layout() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.ensure_game_over_view()


func _on_game_over_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://World/Start.tscn")

func _create_controls_hint_panel() -> void:
	_init_modal_ui_controller()
	_ensure_right_hud_stack()
	modal_ui_controller.ensure_controls_hint_view()

func _ensure_right_hud_stack() -> VBoxContainer:
	if right_hud_stack != null and is_instance_valid(right_hud_stack):
		return right_hud_stack
	right_hud_stack = VBoxContainer.new()
	right_hud_stack.name = "RightHudStack"
	right_hud_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_hud_stack.z_index = 35
	right_hud_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_hud_stack.offset_left = -376.0
	right_hud_stack.offset_top = 16.0
	right_hud_stack.offset_right = -16.0
	right_hud_stack.offset_bottom = 420.0
	right_hud_stack.add_theme_constant_override("separation", 8)
	gui_root.add_child(right_hud_stack)
	return right_hud_stack

func _layout_controls_hint_panel(viewport_size: Vector2) -> void:
	_init_modal_ui_controller()
	if right_hud_stack != null and is_instance_valid(right_hud_stack):
		var available_width := maxf(1.0, viewport_size.x - 32.0)
		var stack_width := minf(360.0, available_width)
		right_hud_stack.offset_left = -16.0 - stack_width
		right_hud_stack.offset_right = -16.0
	modal_ui_controller.layout_controls_hint_panel(viewport_size)

func _update_controls_guide_for_phase(phase: String) -> void:
	_init_modal_ui_controller()
	modal_ui_controller.update_controls_guide_for_phase(phase, _is_primary_menu_open(), _get_secondary_menu_context())

func _refresh_controls_hint_visibility() -> void:
	_init_modal_ui_controller()
	modal_ui_controller.refresh_controls_hint_visibility(_is_primary_menu_open(), _get_secondary_menu_context())

func show_controls_context_reminder(action: StringName, message: String, force: bool = false) -> bool:
	if controls_hint_view == null or not is_instance_valid(controls_hint_view):
		return false
	return bool(controls_hint_view.show_context_reminder(action, message, force))

func _is_primary_menu_open() -> bool:
	if rest_area_ui_controller:
		return rest_area_ui_controller.is_primary_menu_open()
	return false

func _is_secondary_menu_open() -> bool:
	if rest_area_ui_controller:
		return rest_area_ui_controller.is_secondary_menu_open()
	return false

func _get_secondary_menu_context() -> StringName:
	if rest_area_ui_controller:
		return rest_area_ui_controller.get_secondary_menu_context()
	return &""

func _is_rest_area_world_interaction_blocked() -> bool:
	if rest_area_ui_controller:
		return rest_area_ui_controller.is_world_interaction_blocking_panel_visible()
	if board_edit_panel and is_instance_valid(board_edit_panel) and board_edit_panel.visible:
		return true
	if cell_management_panel and is_instance_valid(cell_management_panel) and cell_management_panel.visible:
		return true
	if weapon_warehouse_panel and is_instance_valid(weapon_warehouse_panel) and weapon_warehouse_panel.visible:
		return true
	for root in [purchase_management_root, upgrade_management_root, warehouse_management_root]:
		if root and is_instance_valid(root) and root.visible:
			return true
	return false

func _refresh_controls_guide_texts() -> void:
	_update_controls_guide_for_phase(PhaseManager.current_state())


# Signals and responsive layout

func _connect_viewport_signals() -> void:
	var viewport := get_viewport()
	if viewport and not viewport.is_connected("size_changed", Callable(self, "_on_viewport_size_changed")):
		viewport.connect("size_changed", Callable(self, "_on_viewport_size_changed"))

func _connect_ui_dirty_signals() -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.connect_ui_dirty_signals()

func _disconnect_ui_dirty_signals() -> void:
	if ui_dirty_signal_controller != null:
		ui_dirty_signal_controller.disconnect_ui_dirty_signals()

func _on_player_weapon_list_changed() -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.call("_on_player_weapon_list_changed")

func _on_main_weapon_index_changed(_old_index: int, _new_index: int, _step: int) -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.call("_on_main_weapon_index_changed", _old_index, _new_index, _step)

func _mark_weapon_passive_panel_dirty() -> void:
	_weapon_passive_panel_dirty = true

func _mark_shop_purchase_action_dirty() -> void:
	_shop_purchase_action_dirty = true
	_schedule_management_action_refresh()

func _mark_upgrade_action_dirty() -> void:
	_upgrade_action_dirty = true
	_schedule_management_action_refresh()

func _mark_warehouse_action_dirty() -> void:
	_warehouse_action_dirty = true
	_schedule_management_action_refresh()

func _on_player_health_changed(_current_hp: int, _max_hp: int) -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.call("_on_player_health_changed", _current_hp, _max_hp)

func _on_player_gold_changed(_value: int) -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.call("_on_player_gold_changed", _value)

func _on_inventory_modules_changed() -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.call("_on_inventory_modules_changed")

func _on_inventory_weapon_storage_changed() -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.call("_on_inventory_weapon_storage_changed")

func _mark_hud_hp_dirty() -> void:
	_init_hud_refresh_controller()
	hud_refresh_controller.mark_hp_dirty()

func _mark_hud_inventory_dirty() -> void:
	_init_hud_refresh_controller()
	hud_refresh_controller.mark_inventory_dirty()

func _mark_hud_weapon_dirty() -> void:
	_init_hud_refresh_controller()
	hud_refresh_controller.mark_weapon_dirty()

func _mark_all_hud_dirty() -> void:
	_init_hud_refresh_controller()
	hud_refresh_controller.mark_all_dirty()

func _rebind_weapon_passive_status_signals() -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.rebind_weapon_passive_status_signals()

func _disconnect_weapon_passive_status_signals() -> void:
	if ui_dirty_signal_controller != null:
		ui_dirty_signal_controller.disconnect_weapon_passive_status_signals()

func _connect_weapon_passive_status_signal(weapon: Node, signal_name: String) -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.connect_weapon_passive_status_signal(weapon, signal_name)

func _on_weapon_passive_status_signal(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null) -> void:
	_init_ui_dirty_signal_controller()
	ui_dirty_signal_controller.call("_on_weapon_passive_status_signal", _arg1, _arg2, _arg3)

func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	_init_ui_layout_controller()
	ui_layout_controller.apply_responsive_layout()
	if task_objective_hud_presenter != null:
		task_objective_hud_presenter.layout(get_viewport().get_visible_rect().size)

# Quest, rest-area hints, and cursor overlays

func _create_quest_hint() -> void:
	_init_hint_presenter()
	hint_presenter.ensure_quest_hint()

func _ensure_rest_area_hover_hint() -> void:
	_init_hint_presenter()
	hint_presenter.ensure_rest_area_hover_hint()

func set_rest_area_zone_hints_at_world(hints: Array) -> void:
	_init_hint_presenter()
	hint_presenter.set_rest_area_zone_hints_at_world(hints)

func set_rest_area_hover_hint(text: String) -> void:
	_init_hint_presenter()
	hint_presenter.set_rest_area_hover_hint(text)

func set_rest_area_hover_hint_at_world(text: String, world_pos: Vector2) -> void:
	_init_hint_presenter()
	hint_presenter.set_rest_area_hover_hint_at_world(text, world_pos)

func clear_rest_area_hover_hint() -> void:
	_init_hint_presenter()
	hint_presenter.clear_rest_area_hover_hint()

func _layout_rest_area_hover_hint(viewport_size: Vector2) -> void:
	_init_hint_presenter()
	hint_presenter.layout_rest_area_hover_hint(viewport_size)

func _update_rest_area_hover_hint_position() -> void:
	_init_hint_presenter()
	hint_presenter.update_rest_area_hover_hint_position()

func _ensure_spread_cursor_overlay() -> void:
	if spread_cursor_overlay != null and is_instance_valid(spread_cursor_overlay):
		return
	var overlay := Control.new()
	overlay.name = "SpreadCursorOverlay"
	var overlay_script := load(SPREAD_CURSOR_OVERLAY_SCRIPT_PATH) as Script
	if overlay_script == null:
		push_warning("Failed to load SpreadCursorOverlay script.")
		return
	overlay.set_script(overlay_script)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 300
	gui_root.add_child(overlay)
	gui_root.move_child(overlay, gui_root.get_child_count() - 1)
	spread_cursor_overlay = overlay
	if battle_cursor_presenter != null:
		battle_cursor_presenter.set_overlay(spread_cursor_overlay)

func _update_spread_cursor_overlay(mouse_screen_override: Variant = null) -> void:
	_init_battle_cursor_presenter()
	_update_cursor_presentation()
	battle_cursor_presenter.update_spread_cursor_overlay(mouse_screen_override)

func _layout_quest_hint(viewport_size: Vector2) -> void:
	_init_hint_presenter()
	hint_presenter.layout_quest_hint(viewport_size)

func set_quest_hint(text: String) -> void:
	_init_hint_presenter()
	hint_presenter.set_quest_hint(text)

func show_item_message(text: String, duration: float = 1.8) -> void:
	set_quest_hint(text)
	if item_message_timer == null or not is_instance_valid(item_message_timer):
		_init_item_message_timer()
	item_message_timer.wait_time = maxf(0.1, duration)
	item_message_timer.start()

func _on_item_message_timeout() -> void:
	set_quest_hint("")


# HUD fallback widgets and weapon passive panel

func _ensure_weapon_passive_panel() -> void:
	_init_weapon_passive_panel_view()
	weapon_passive_panel_view.ensure_panel()
	_sync_weapon_passive_panel_view_refs()

func _refresh_weapon_passive_panel() -> void:
	if weapon_passive_presenter == null:
		return
	_ensure_weapon_passive_panel()
	if weapon_passive_panel_view == null:
		return
	var statuses: Array = weapon_passive_presenter.get_equipped_weapon_passive_statuses()
	weapon_passive_panel_view.refresh(statuses)
	_sync_weapon_passive_panel_view_refs()
	_weapon_passive_panel_dirty = false
	_weapon_passive_panel_refresh_timer = 0.0
	_increment_ui_refresh_debug_count("weapon_passive_panel")

func _refresh_weapon_passive_panel_if_needed(delta: float) -> void:
	if weapon_passive_presenter == null:
		return
	_weapon_passive_panel_refresh_timer += maxf(delta, 0.0)
	var should_refresh := _weapon_passive_panel_dirty
	if not should_refresh and weapon_passive_panel != null and weapon_passive_panel.visible:
		should_refresh = _weapon_passive_panel_refresh_timer >= WEAPON_PASSIVE_PANEL_REFRESH_INTERVAL
	if not should_refresh:
		return
	_refresh_weapon_passive_panel()

# Pause menu settings and localization refresh

func _ensure_pause_language_controls() -> void:
	_init_pause_ui_controller()
	pause_ui_controller.ensure_language_controls()

func _refresh_pause_language_options() -> void:
	_init_pause_ui_controller()
	pause_ui_controller.refresh_language_options()

func _on_pause_language_option_item_selected(index: int) -> void:
	_init_pause_ui_controller()
	pause_ui_controller.on_language_option_item_selected(index)

func _on_temporary_module_confirm_toggled(enabled: bool) -> void:
	_init_pause_ui_controller()
	pause_ui_controller.on_temporary_module_confirm_toggled(enabled)

func _on_language_changed(_new_locale: String) -> void:
	_refresh_localized_static_text()
	_refresh_controls_guide_texts()
	_refresh_heat_fallback_text()
	_mark_all_hud_dirty()
	_mark_weapon_passive_panel_dirty()
	if route_selection_panel and is_instance_valid(route_selection_panel) and route_selection_panel.visible:
		route_selection_panel._on_language_changed(LocalizationManager.get_locale())
	if reward_selection_panel and is_instance_valid(reward_selection_panel) and reward_selection_panel.visible:
		reward_selection_panel._on_language_changed(LocalizationManager.get_locale())
	if branch_select_panel and is_instance_valid(branch_select_panel) and branch_select_panel.visible:
		branch_select_panel._on_language_changed(LocalizationManager.get_locale())
	if module_equip_selection_panel and is_instance_valid(module_equip_selection_panel) and module_equip_selection_panel.visible:
		module_equip_selection_panel._on_language_changed(LocalizationManager.get_locale())

func _refresh_localized_static_text() -> void:
	_init_localization_refresh_controller()
	localization_refresh_controller.refresh_texts()
	_mark_all_hud_dirty()
	if task_objective_hud_presenter != null:
		task_objective_hud_presenter.mark_dirty()
	_refresh_controls_guide_texts()
	_refresh_game_over_static_text()

func _refresh_game_over_static_text() -> void:
	if game_over_view != null and is_instance_valid(game_over_view):
		game_over_view.refresh_static_texts()

func debug_get_game_over_stat_texts() -> PackedStringArray:
	if game_over_view != null and is_instance_valid(game_over_view):
		return game_over_view.debug_get_stat_texts()
	return PackedStringArray()

func _refresh_heat_fallback_text() -> void:
	hud_presenter.refresh_heat_fallback_text()
