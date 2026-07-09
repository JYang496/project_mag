extends Control
class_name ModuleUpgradeView

@onready var module_upgrade_scroll: ScrollContainer = $ModuleUpgradeScroll
@onready var module_upgrade_list: VBoxContainer = $ModuleUpgradeScroll/ModuleUpgradeList
@onready var module_upgrade_selection_label: Label = $ModuleUpgradeSelectionLabel
@onready var module_upgrade_action_button: Button = $ModuleUpgradeActionButton

var owner_ui: Node
var selected_module: Module

func bind(owner_ui: Node) -> void:
	if owner_ui == null:
		return
	self.owner_ui = owner_ui
	var action_pressed := Callable(owner_ui, "_on_module_upgrade_action_pressed")
	if not module_upgrade_action_button.pressed.is_connected(action_pressed):
		module_upgrade_action_button.pressed.connect(action_pressed)
	owner_ui.call("_style_management_button", module_upgrade_action_button, true)

func set_selected_module(module_instance: Module) -> void:
	selected_module = module_instance

func get_selected_module() -> Module:
	return selected_module

func refresh_list() -> void:
	if module_upgrade_list == null:
		return
	_clear_container(module_upgrade_list)
	var has_rows := false
	for module_ref in InventoryData.get_all_owned_modules():
		var module_instance := module_ref as Module
		if module_instance == null or not is_instance_valid(module_instance):
			continue
		if int(module_instance.module_level) >= Module.MAX_LEVEL:
			continue
		has_rows = true
		var button := Button.new()
		button.text = build_row_text(module_instance)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select_module.bind(module_instance))
		module_upgrade_list.add_child(button)
		if owner_ui:
			owner_ui.call("_style_management_button", button, module_instance == selected_module)
	if not has_rows:
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key("ui.upgrade.module.empty", "No modules can be upgraded.")
		module_upgrade_list.add_child(empty)
	if selected_module != null and (not is_instance_valid(selected_module) or int(selected_module.module_level) >= Module.MAX_LEVEL):
		selected_module = null
	refresh_action()

func select_module(module_instance: Module) -> void:
	selected_module = module_instance
	refresh_list()
	refresh_action()

func trigger_action() -> bool:
	if selected_module == null or not is_instance_valid(selected_module):
		return false
	var result := InventoryData.upgrade_module_with_gold(selected_module)
	if not result.get("ok", false):
		if owner_ui and owner_ui.has_method("show_item_message"):
			owner_ui.call("show_item_message", str(result.get("reason", "")), 1.6)
		return false
	if owner_ui and owner_ui.has_method("update_upg"):
		owner_ui.call("update_upg")
	return true

func refresh_action() -> void:
	if module_upgrade_action_button == null or module_upgrade_selection_label == null:
		return
	var ready := selected_module != null and is_instance_valid(selected_module) \
		and int(selected_module.module_level) < Module.MAX_LEVEL
	var price := get_upgrade_price(selected_module) if ready else 0
	module_upgrade_action_button.disabled = not ready or PlayerData.player_gold < price
	module_upgrade_action_button.text = LocalizationManager.tr_format(
		"ui.upgrade.module.action",
		{"value": price},
		"Upgrade Module: %s" % price
	) if ready else LocalizationManager.tr_key("ui.upgrade.module.action_empty", "Upgrade Module")
	if ready:
		module_upgrade_selection_label.text = LocalizationManager.tr_format(
			"ui.upgrade.module.selected",
			{"module": LocalizationManager.get_module_name(selected_module), "level": selected_module.module_level},
			"%s Lv.%d" % [LocalizationManager.get_module_name(selected_module), selected_module.module_level]
		)
	else:
		module_upgrade_selection_label.text = LocalizationManager.tr_key("ui.upgrade.module.select_prompt", "Select a module to upgrade.")

func build_row_text(module_instance: Module) -> String:
	var price := get_upgrade_price(module_instance)
	return "%s Lv.%d -> Lv.%d    %s" % [
		LocalizationManager.get_module_name(module_instance),
		int(module_instance.module_level),
		int(module_instance.module_level) + 1,
		LocalizationManager.tr_format("ui.upgrade.cost", {"value": price}, "Cost: %s" % price),
	]

func get_upgrade_price(module_instance: Module) -> int:
	if module_instance == null or not is_instance_valid(module_instance):
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_module_upgrade_gold(
			int(module_instance.cost),
			int(module_instance.module_level)
		)
	return EconomyConfig.new().get_module_upgrade_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
