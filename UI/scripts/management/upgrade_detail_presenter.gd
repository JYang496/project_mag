extends RefCounted
class_name UpgradeDetailPresenter

const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")
const DETAIL_TEXT_SCENE := preload("res://UI/components/DetailText/DetailText.tscn")
const DETAIL_FACT_SCENE := preload("res://UI/components/DetailFactCard/DetailFactCard.tscn")
const DETAIL_FACT_GRID_SCENE := preload("res://UI/components/DetailFactGrid/DetailFactGrid.tscn")
const UPGRADE_SUMMARY_SCENE := preload("res://UI/components/UpgradeSummaryPanel/UpgradeSummaryPanel.tscn")

var owner_view: Node
var detail_body: VBoxContainer

func bind(view: Node, body: VBoxContainer) -> void:
	owner_view = view
	detail_body = body

func set_detail_body(body: VBoxContainer) -> void:
	detail_body = body

func fill_weapon_detail(item_data: Dictionary) -> void:
	var weapon := item_data.get("weapon", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return
	var model = item_data.get("display_model", null)
	if model == null:
		model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon, true, str(item_data.get("location", "")))
	_add_weapon_upgrade_summary(model)
	_add_weapon_overview(item_data, weapon, model)
	_add_detail_header(LocalizationManager.tr_key("ui.weapon.detail.current_stats", "Current Base Stats"))
	_add_detail_text(WEAPON_STAT_FORMATTER.format_dictionary(model.current_stats, "\n"))

func _add_weapon_upgrade_summary(model: Variant) -> void:
	if detail_body == null:
		return
	var panel := UPGRADE_SUMMARY_SCENE.instantiate() as Control
	panel.name = "UpgradeChangePanel"
	detail_body.add_child(panel)
	panel.call("set_title", LocalizationManager.tr_key("ui.weapon.detail.upgrade_changes", "This Upgrade"))
	var content := panel.get_node("Margin/Content") as VBoxContainer

	var changed_count := 0
	for delta_data in model.upgrade_deltas:
		if not bool(delta_data.get("changed", false)):
			continue
		_add_delta_text(delta_data, content)
		changed_count += 1
	if changed_count == 0:
		_add_detail_text_to(
			content,
			LocalizationManager.tr_key("ui.weapon.detail.no_stat_changes", "No numeric stat changes.")
		)

func _add_weapon_overview(item_data: Dictionary, weapon: Weapon, model: Variant) -> void:
	if detail_body == null:
		return
	var grid := DETAIL_FACT_GRID_SCENE.instantiate() as GridContainer
	grid.name = "WeaponOverviewGrid"
	detail_body.add_child(grid)
	_add_fact_card(
		grid,
		LocalizationManager.tr_key("ui.service.detail.current_level", "Current Level"),
		"Lv.%d/%d" % [model.level, model.max_level]
	)
	_add_fact_card(
		grid,
		LocalizationManager.tr_key("ui.service.detail.upgrade_price", "Upgrade Price"),
		"-" if model.level >= model.max_level else str(_get_weapon_upgrade_price(weapon))
	)
	_add_fact_card(
		grid,
		LocalizationManager.tr_key("ui.service.detail.location", "Location"),
		str(item_data.get("location", ""))
	)
	_add_fact_card(
		grid,
		LocalizationManager.tr_key("ui.service.detail.weapon_type", "Weapon Type"),
		model.taxonomy_text()
	)

func fill_module_detail(item_data: Dictionary) -> void:
	var module_instance := item_data.get("module", null) as Module
	if module_instance == null or not is_instance_valid(module_instance):
		return
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.current_level", "Current Level"), "Lv.%d/%d" % [int(module_instance.module_level), Module.MAX_LEVEL])
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.upgrade_price", "Upgrade Price"), "-" if int(module_instance.module_level) >= Module.MAX_LEVEL else str(_get_module_upgrade_price(module_instance)))
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.location", "Location"), str(item_data.get("location", "")))
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.install_targets", "Compatible Weapons"), format_module_install_targets(module_instance))
	var original_level := int(module_instance.module_level)
	_add_detail_header(LocalizationManager.tr_key("ui.service.detail.current_stats", "Current Stats"))
	module_instance.set_module_level(original_level)
	var current_effects := module_instance.get_effect_descriptions()
	_add_detail_text("\n".join(current_effects))
	module_instance.set_module_level(original_level)

func build_weapon_param_summary(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
	return WEAPON_STAT_FORMATTER.format_summary(model.current_stats, 3)

func build_module_param_summary(module_instance: Module) -> String:
	if module_instance == null or not is_instance_valid(module_instance):
		return ""
	var effects := module_instance.get_effect_descriptions()
	return effects[0] if effects.size() > 0 else ""

func format_stat_dictionary(data: Dictionary) -> String:
	return WEAPON_STAT_FORMATTER.format_dictionary(data)

func format_stat_label(key: String) -> String:
	return WEAPON_STAT_FORMATTER.format_label(key)

func format_weapon_definition_types(weapon_def: WeaponDefinition) -> String:
	if weapon_def == null:
		return LocalizationManager.tr_key("ui.service.value.unknown", "Unknown")
	return WEAPON_DISPLAY_BUILDER.build_from_definition(weapon_def).taxonomy_text()

func format_module_install_targets(module_instance: Module) -> String:
	var parts := PackedStringArray()
	for value in module_instance.get_normalized_required_weapon_traits():
		parts.append(format_type_name(str(value)))
	for value in module_instance.get_normalized_required_delivery_types():
		parts.append(format_type_name(str(value)))
	for value in module_instance.get_normalized_required_weapon_capabilities():
		parts.append(format_type_name(str(value)))
	return " / ".join(parts) if not parts.is_empty() else LocalizationManager.tr_key("ui.service.value.any_weapon", "Any Weapon")

func format_type_name(value: String) -> String:
	return LocalizationManager.get_module_term(StringName(value), value.replace("_", " ").capitalize())

func _add_detail_section(title: String, value: String) -> void:
	_add_detail_header(title)
	_add_detail_text(value)

func _add_detail_header(text: String) -> void:
	if detail_body == null:
		return
	var label := DETAIL_TEXT_SCENE.instantiate() as Label
	detail_body.add_child(label)
	label.call("set_data", text, Color(0.63, 0.86, 0.95), 16)

func _add_detail_text(text: String) -> void:
	_add_detail_text_to(detail_body, text)

func _add_detail_text_to(parent: Container, text: String) -> void:
	if parent == null:
		return
	var label := DETAIL_TEXT_SCENE.instantiate() as Label
	parent.add_child(label)
	label.call("set_data", text, Color(0.86, 0.9, 0.92), 13)

func _add_fact_card(parent: GridContainer, title: String, value: String) -> void:
	var card := DETAIL_FACT_SCENE.instantiate() as Control
	card.name = "DetailFact"
	parent.add_child(card)
	card.call("set_data", title, value)

func _make_upgrade_summary_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.045, 0.96)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.72, 0.48, 0.10, 0.92)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _add_delta_text(delta_data: Dictionary, parent: Container = null) -> void:
	var target := parent if parent != null else detail_body
	if target == null:
		return
	var label := DETAIL_TEXT_SCENE.instantiate() as Label
	label.name = "UpgradeDelta"
	var color := Color(0.82, 0.88, 0.9)
	match StringName(str(delta_data.get("benefit", "neutral"))):
		&"positive":
			color = Color(0.52, 0.92, 0.68)
		&"negative":
			color = Color(1.0, 0.58, 0.5)
	target.add_child(label)
	label.call("set_data", WEAPON_STAT_FORMATTER.format_delta_line(delta_data), color, 14)

func _get_weapon_upgrade_price(weapon: Weapon) -> int:
	return int(owner_view.call("_get_weapon_upgrade_price", weapon)) if owner_view != null else 0

func _get_module_upgrade_price(module_instance: Module) -> int:
	return int(owner_view.call("_get_module_upgrade_price", module_instance)) if owner_view != null else 0
