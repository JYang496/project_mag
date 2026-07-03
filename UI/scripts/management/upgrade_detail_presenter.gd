extends RefCounted
class_name UpgradeDetailPresenter

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
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.current_level", "Current Level"), "Lv.%d/%d" % [int(weapon.level), int(weapon.max_level)])
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.upgrade_price", "Upgrade Price"), "-" if int(weapon.level) >= int(weapon.max_level) else str(_get_weapon_upgrade_price(weapon)))
	_add_detail_section(LocalizationManager.tr_key("ui.service.detail.location", "Location"), str(item_data.get("location", "")))
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if weapon_def != null:
		_add_detail_section(LocalizationManager.tr_key("ui.service.detail.weapon_type", "Weapon Type"), format_weapon_definition_types(weapon_def))
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if weapon_data_variant is Dictionary:
		var weapon_data := weapon_data_variant as Dictionary
		var current_data := weapon.get_weapon_level_data(weapon.level, weapon_data)
		_add_detail_header(LocalizationManager.tr_key("ui.service.detail.current_stats", "Current Stats"))
		_add_detail_text(format_stat_dictionary(current_data))

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
	var weapon_data_variant: Variant = weapon.get("weapon_data")
	if not (weapon_data_variant is Dictionary):
		return ""
	var current_data := weapon.get_weapon_level_data(weapon.level, weapon_data_variant as Dictionary)
	var keys := ["damage", "fire_interval_sec", "ammo", "speed", "projectile_hits", "bullet_count"]
	var parts := PackedStringArray()
	for key in keys:
		if not current_data.has(key):
			continue
		var current_value := str(current_data.get(key, "-"))
		parts.append("%s %s" % [format_stat_label(key), current_value])
		if parts.size() >= 3:
			break
	return " / ".join(parts)

func build_module_param_summary(module_instance: Module) -> String:
	if module_instance == null or not is_instance_valid(module_instance):
		return ""
	var effects := module_instance.get_effect_descriptions()
	return effects[0] if effects.size() > 0 else ""

func format_stat_dictionary(data: Dictionary) -> String:
	var parts := PackedStringArray()
	for key_variant in data.keys():
		var key := str(key_variant)
		parts.append("%s: %s" % [format_stat_label(key), str(data[key_variant])])
	return " / ".join(parts)

func format_stat_label(key: String) -> String:
	return LocalizationManager.get_module_term(
		StringName("stat.%s" % key),
		key.replace("_", " ").capitalize()
	)

func format_weapon_definition_types(weapon_def: WeaponDefinition) -> String:
	if weapon_def == null or weapon_def.scene == null:
		return LocalizationManager.tr_key("ui.service.value.unknown", "Unknown")
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		return LocalizationManager.tr_key("ui.service.value.unknown", "Unknown")
	var parts := PackedStringArray()
	for value in weapon.get_explicit_weapon_traits():
		parts.append(format_type_name(str(value)))
	for value in weapon.get_explicit_delivery_types():
		parts.append(format_type_name(str(value)))
	for value in weapon.get_explicit_weapon_capabilities():
		parts.append(format_type_name(str(value)))
	weapon.queue_free()
	return " / ".join(parts) if not parts.is_empty() else LocalizationManager.tr_key("ui.service.value.universal", "Universal")

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
	if detail_body == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.92))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.add_child(label)

func _get_weapon_upgrade_price(weapon: Weapon) -> int:
	return int(owner_view.call("_get_weapon_upgrade_price", weapon)) if owner_view != null else 0

func _get_module_upgrade_price(module_instance: Module) -> int:
	return int(owner_view.call("_get_module_upgrade_price", module_instance)) if owner_view != null else 0
