extends RefCounted
class_name UiBootstrapController

var owner_ui: UI
var _core_ready := false
var _pause_ready := false
var _rest_area_ready := false
var _management_ready := false
var _management_shell_ready := false
var _purchase_management_ready := false
var _upgrade_management_ready := false
var _warehouse_management_ready := false

func bind(ui: UI) -> void:
	owner_ui = ui

func bootstrap() -> void:
	bootstrap_core()
	bootstrap_pause()

func bootstrap_core() -> void:
	if _core_ready or owner_ui == null:
		return
	_core_ready = true
	if owner_ui == null:
		return
	LoadingPerformance.begin_segment("ui_bootstrap_hud")
	owner_ui._ensure_hud_presenter_instance()
	owner_ui.heat_label = owner_ui.hud_presenter.ensure_heat_label(owner_ui.character_root)
	owner_ui.ammo_label = owner_ui.hud_presenter.ensure_ammo_label(owner_ui.hp_label_label)
	owner_ui.resource_label = owner_ui.hud_presenter.ensure_resource_label_under_hp(owner_ui.resource_label, owner_ui.hp_label_label)
	owner_ui.weapon_state_label = owner_ui.hud_presenter.ensure_weapon_state_label(owner_ui.character_root)
	LoadingPerformance.end_segment("ui_bootstrap_hud")
	LoadingPerformance.begin_segment("ui_bootstrap_controllers")
	owner_ui._init_weapon_passive_presenter()
	owner_ui._init_equipment_pickup_flow_controller()
	owner_ui._init_weapon_branch_selection_controller()
	owner_ui._init_ui_layout_controller()
	owner_ui._init_localization_refresh_controller()
	owner_ui._init_hint_presenter()
	owner_ui._ensure_weapon_passive_panel()
	owner_ui._init_hud_presenter()
	owner_ui._init_ui_dirty_signal_controller()
	owner_ui._ensure_spread_cursor_overlay()
	owner_ui._init_battle_cursor_presenter()
	LoadingPerformance.end_segment("ui_bootstrap_controllers")
	LoadingPerformance.begin_segment("ui_bootstrap_aux_views")
	owner_ui._create_controls_hint_panel()
	LoadingPerformance.end_segment("ui_bootstrap_aux_views")
	LoadingPerformance.begin_segment("ui_bootstrap_finalize")
	owner_ui._refresh_localized_static_text()
	owner_ui._connect_ui_dirty_signals()
	owner_ui._connect_viewport_signals()
	owner_ui._apply_responsive_layout()
	owner_ui._init_item_message_timer()
	owner_ui._update_controls_guide_for_phase(PhaseManager.current_state())
	owner_ui._update_cursor_presentation()
	owner_ui._bind_weapon_selector()
	owner_ui.refresh_border()
	LoadingPerformance.end_segment("ui_bootstrap_finalize")

func bootstrap_pause() -> void:
	if _pause_ready or owner_ui == null:
		return
	bootstrap_core()
	_pause_ready = true
	owner_ui._init_pause_ui_controller()
	owner_ui._ensure_pause_language_controls()

func bootstrap_rest_area() -> void:
	if _rest_area_ready or owner_ui == null:
		return
	bootstrap_core()
	owner_ui._ensure_rest_area_view_instance()
	if owner_ui.rest_area_primary_menus == null:
		push_error("Rest-area primary menus failed to instantiate.")
		return
	# Mark before controller binding because the compatibility initializer re-enters this method.
	_rest_area_ready = true
	owner_ui._init_rest_area_management_shell()
	owner_ui._init_rest_area_ui_controller()
	owner_ui._init_management_ui_bootstrap_controller()
	owner_ui.management_ui_bootstrap_controller.ensure_management_menu_buttons()
	owner_ui._ensure_rest_area_hover_hint()
	owner_ui._apply_responsive_layout()

func bootstrap_management() -> void:
	if _management_ready or owner_ui == null:
		return
	bootstrap_purchase_management()
	bootstrap_upgrade_management()
	bootstrap_warehouse_management()
	_management_ready = true
	owner_ui._refresh_localized_static_text()

func bootstrap_purchase_management() -> void:
	if _purchase_management_ready or owner_ui == null:
		return
	if not _bootstrap_management_shell():
		return
	owner_ui._init_purchase_management_controller()
	owner_ui._init_purchase_management_ui_polish()
	_purchase_management_ready = true
	owner_ui._refresh_localized_static_text()

func bootstrap_upgrade_management() -> void:
	if _upgrade_management_ready or owner_ui == null:
		return
	if not _bootstrap_management_shell():
		return
	owner_ui._init_upgrade_management_controller()
	owner_ui._init_upgrade_management_ui_polish()
	_upgrade_management_ready = true
	owner_ui._refresh_localized_static_text()

func bootstrap_warehouse_management() -> void:
	if _warehouse_management_ready or owner_ui == null:
		return
	if not _bootstrap_management_shell():
		return
	owner_ui._init_module_warehouse_controller()
	owner_ui._init_warehouse_management_ui_polish()
	_warehouse_management_ready = true
	owner_ui._refresh_localized_static_text()

func _bootstrap_management_shell() -> bool:
	if _management_shell_ready:
		return true
	bootstrap_rest_area()
	owner_ui._ensure_management_shell_instance()
	if owner_ui.management_shell_view == null:
		push_error("Management Shell failed to instantiate.")
		return false
	owner_ui._init_management_ui_bootstrap_controller()
	owner_ui._init_modal_ui_controller()
	owner_ui._init_module_action_dialogs()
	owner_ui._init_management_ui_polish()
	_management_shell_ready = true
	return true
