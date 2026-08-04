extends RefCounted
class_name UpgradeDetailPresenter

const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")

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
	var panel := PanelContainer.new()
	panel.name = "UpgradeChangePanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_upgrade_summary_style())
	detail_body.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	var header := Label.new()
	header.name = "UpgradeChangeHeader"
	header.text = LocalizationManager.tr_key("ui.weapon.detail.upgrade_changes", "This Upgrade")
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.98, 0.75, 0.24))
	content.add_child(header)

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
	var grid := GridContainer.new()
	grid.name = "WeaponOverviewGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 7)
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
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.63, 0.86, 0.95))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.add_child(label)

func _add_detail_text(text: String) -> void:
	_add_detail_text_to(detail_body, text)

func _add_detail_text_to(parent: Container, text: String) -> void:
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.92))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _add_fact_card(parent: GridContainer, title: String, value: String) -> void:
	var card := VBoxContainer.new()
	card.name = "DetailFact"
	card.custom_minimum_size = Vector2(190, 48)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 2)
	parent.add_child(card)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.55, 0.72, 0.78))
	card.add_child(title_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.92))
	card.add_child(value_label)

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
	var label := Label.new()
	label.name = "UpgradeDelta"
	label.text = WEAPON_STAT_FORMATTER.format_delta_line(delta_data)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	match StringName(str(delta_data.get("benefit", "neutral"))):
		&"positive":
			label.add_theme_color_override("font_color", Color(0.52, 0.92, 0.68))
		&"negative":
			label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.5))
		_:
			label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.9))
	target.add_child(label)

func _get_weapon_upgrade_price(weapon: Weapon) -> int:
	return int(owner_view.call("_get_weapon_upgrade_price", weapon)) if owner_view != null else 0

func _get_module_upgrade_price(module_instance: Module) -> int:
	return int(owner_view.call("_get_module_upgrade_price", module_instance)) if owner_view != null else 0
