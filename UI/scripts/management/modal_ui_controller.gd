extends RefCounted
class_name ModalUiController

const BRANCH_SELECT_PANEL_PATH := "res://UI/scenes/branch_select_panel.tscn"
const MODULE_EQUIP_SELECTION_PANEL_PATH := "res://UI/scenes/module_equip_selection_panel.tscn"
const ROUTE_SELECTION_PANEL_PATH := "res://UI/scenes/route_selection_panel.tscn"
const REWARD_SELECTION_PANEL_PATH := "res://UI/scenes/reward_selection_panel.tscn"
const WEAPON_REPLACEMENT_PANEL_PATH := "res://UI/scenes/weapon_replacement_panel.tscn"
const WEAPON_WAREHOUSE_PANEL_PATH := "res://UI/scenes/weapon_warehouse_panel.tscn"

var owner_ui: UI
var gui_root: Control
var branch_select_panel: BranchSelectPanel
var module_equip_selection_panel: ModuleEquipSelectionPanel
var route_selection_panel: RouteSelectionPanel
var reward_selection_panel: RewardSelectionPanel
var weapon_replacement_panel: WeaponReplacementPanel
var weapon_warehouse_panel: WeaponWarehousePanel

func bind(ui: UI, root: Control) -> void:
	owner_ui = ui
	gui_root = root
	sync_state_from_owner()

func ensure_branch_select_panel() -> bool:
	if branch_select_panel != null and is_instance_valid(branch_select_panel):
		return true
	var panel_scene := load(BRANCH_SELECT_PANEL_PATH) as PackedScene
	branch_select_panel = panel_scene.instantiate() as BranchSelectPanel if panel_scene else null
	if branch_select_panel == null:
		push_warning("Failed to create BranchSelectPanel.")
		return false
	gui_root.add_child(branch_select_panel)
	branch_select_panel.visible = false
	var callback := Callable(owner_ui, "_on_branch_selected")
	if not branch_select_panel.is_connected("branch_selected", callback):
		branch_select_panel.connect("branch_selected", callback)
	_sync_public_fields_to_owner()
	return true

func ensure_module_equip_selection_panel() -> bool:
	if module_equip_selection_panel != null and is_instance_valid(module_equip_selection_panel):
		return true
	var panel_scene := load(MODULE_EQUIP_SELECTION_PANEL_PATH) as PackedScene
	module_equip_selection_panel = panel_scene.instantiate() as ModuleEquipSelectionPanel if panel_scene else null
	if module_equip_selection_panel == null:
		push_warning("Failed to create ModuleEquipSelectionPanel.")
		return false
	gui_root.add_child(module_equip_selection_panel)
	module_equip_selection_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_route_selection_panel() -> bool:
	if route_selection_panel != null and is_instance_valid(route_selection_panel):
		return true
	var panel_scene := load(ROUTE_SELECTION_PANEL_PATH) as PackedScene
	route_selection_panel = panel_scene.instantiate() as RouteSelectionPanel if panel_scene else null
	if route_selection_panel == null:
		push_warning("Failed to create RouteSelectionPanel.")
		return false
	gui_root.add_child(route_selection_panel)
	route_selection_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_reward_selection_panel() -> bool:
	if reward_selection_panel != null and is_instance_valid(reward_selection_panel):
		return true
	var panel_scene := load(REWARD_SELECTION_PANEL_PATH) as PackedScene
	reward_selection_panel = panel_scene.instantiate() as RewardSelectionPanel if panel_scene else null
	if reward_selection_panel == null:
		push_warning("Failed to create RewardSelectionPanel.")
		return false
	gui_root.add_child(reward_selection_panel)
	reward_selection_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_weapon_replacement_panel() -> bool:
	if weapon_replacement_panel != null and is_instance_valid(weapon_replacement_panel):
		return true
	var panel_scene := load(WEAPON_REPLACEMENT_PANEL_PATH) as PackedScene
	weapon_replacement_panel = panel_scene.instantiate() as WeaponReplacementPanel if panel_scene else null
	if weapon_replacement_panel == null:
		push_warning("Failed to create WeaponReplacementPanel.")
		return false
	gui_root.add_child(weapon_replacement_panel)
	weapon_replacement_panel.visible = false
	_sync_public_fields_to_owner()
	return true

func ensure_weapon_warehouse_panel() -> bool:
	if weapon_warehouse_panel != null and is_instance_valid(weapon_warehouse_panel):
		return true
	var panel_scene := load(WEAPON_WAREHOUSE_PANEL_PATH) as PackedScene
	weapon_warehouse_panel = panel_scene.instantiate() as WeaponWarehousePanel if panel_scene else null
	if weapon_warehouse_panel == null:
		push_warning("Failed to create WeaponWarehousePanel.")
		return false
	gui_root.add_child(weapon_warehouse_panel)
	_sync_public_fields_to_owner()
	return true

func sync_state_from_owner() -> void:
	if owner_ui == null:
		return
	branch_select_panel = owner_ui.branch_select_panel
	module_equip_selection_panel = owner_ui.module_equip_selection_panel
	route_selection_panel = owner_ui.route_selection_panel
	reward_selection_panel = owner_ui.reward_selection_panel
	weapon_replacement_panel = owner_ui.weapon_replacement_panel
	weapon_warehouse_panel = owner_ui.weapon_warehouse_panel

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui.branch_select_panel = branch_select_panel
	owner_ui.module_equip_selection_panel = module_equip_selection_panel
	owner_ui.route_selection_panel = route_selection_panel
	owner_ui.reward_selection_panel = reward_selection_panel
	owner_ui.weapon_replacement_panel = weapon_replacement_panel
	owner_ui.weapon_warehouse_panel = weapon_warehouse_panel
