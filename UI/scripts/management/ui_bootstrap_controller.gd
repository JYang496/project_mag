extends RefCounted
class_name UiBootstrapController

var owner_ui: UI

func bind(ui: UI) -> void:
	owner_ui = ui

func bootstrap() -> void:
	if owner_ui == null:
		return
	owner_ui._ensure_hud_presenter_instance()
	owner_ui.heat_label = owner_ui.hud_presenter.ensure_heat_label(owner_ui.character_root)
	owner_ui.ammo_label = owner_ui.hud_presenter.ensure_ammo_label(owner_ui.hp_label_label)
	owner_ui.resource_label = owner_ui.hud_presenter.ensure_resource_label_under_hp(owner_ui.resource_label, owner_ui.hp_label_label)
	owner_ui.weapon_state_label = owner_ui.hud_presenter.ensure_weapon_state_label(owner_ui.character_root)
	owner_ui._init_weapon_passive_presenter()
	owner_ui._init_equipment_pickup_flow_controller()
	owner_ui._init_weapon_branch_selection_controller()
	owner_ui._init_rest_area_management_shell()
	owner_ui._init_rest_area_ui_controller()
	owner_ui._init_purchase_management_controller()
	owner_ui._init_upgrade_management_controller()
	owner_ui._init_module_warehouse_controller()
	owner_ui._init_management_ui_bootstrap_controller()
	owner_ui._init_modal_ui_controller()
	owner_ui._init_ui_layout_controller()
	owner_ui._init_pause_ui_controller()
	owner_ui._init_localization_refresh_controller()
	owner_ui._init_hint_presenter()
	owner_ui._ensure_weapon_passive_panel()
	owner_ui._init_hud_presenter()
	owner_ui._init_ui_dirty_signal_controller()
	owner_ui._ensure_spread_cursor_overlay()
	owner_ui._init_battle_cursor_presenter()
	owner_ui._create_game_over_layout()
	owner_ui._create_controls_hint_panel()
	owner_ui._ensure_pause_language_controls()
	owner_ui._init_module_action_dialogs()
	owner_ui._init_management_ui_polish()
	owner_ui._refresh_localized_static_text()
	owner_ui._create_quest_hint()
	owner_ui._ensure_rest_area_hover_hint()
	owner_ui._connect_ui_dirty_signals()
	owner_ui._connect_viewport_signals()
	owner_ui._apply_responsive_layout()
	owner_ui._init_item_message_timer()
	owner_ui._update_controls_guide_for_phase(PhaseManager.current_state())
	owner_ui._update_cursor_presentation()
	owner_ui._bind_weapon_selector()
	owner_ui.refresh_border()
