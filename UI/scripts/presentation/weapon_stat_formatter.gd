extends RefCounted
class_name WeaponStatFormatter

const STAT_CATALOG := preload("res://UI/scripts/presentation/weapon_stat_catalog.gd")


static func format_label(key: Variant) -> String:
	var definition := STAT_CATALOG.get_definition(key)
	var label_key := str(definition.get("label_key", ""))
	var fallback := str(definition.get("fallback", str(key)))
	return LocalizationManager.tr_key(label_key, fallback) if label_key != "" else fallback


static func format_value(key: Variant, value: Variant, signed_value: bool = false) -> String:
	if value == null:
		return LocalizationManager.tr_key("ui.common.none", "--")
	var definition := STAT_CATALOG.get_definition(key)
	var format_kind := StringName(str(definition.get("format", "auto")))
	var numeric: Variant = _to_float(value)
	if numeric == null:
		return str(value)
	var number := float(numeric)
	var prefix := "+" if signed_value and number > 0.0 else ""
	match format_kind:
		&"integer":
			return prefix + str(int(roundf(number)))
		&"seconds":
			return LocalizationManager.tr_format(
				"ui.value.seconds",
				{"value": prefix + _format_decimal(number, 2)},
				"%ss" % (prefix + _format_decimal(number, 2))
			)
		&"rounds":
			return LocalizationManager.tr_format(
				"ui.value.rounds",
				{"value": prefix + str(int(roundf(number)))},
				"%s rounds" % (prefix + str(int(roundf(number))))
			)
		&"multiplier":
			return "×%s" % _format_decimal(number, 2)
		&"decimal":
			return prefix + _format_decimal(number, 2)
		_:
			return prefix + _format_decimal(number, 2)


static func format_line(key: Variant, value: Variant, separator: String = ": ") -> String:
	return "%s%s%s" % [format_label(key), separator, format_value(key, value)]


static func format_dictionary(values: Dictionary, separator: String = " / ") -> String:
	var parts := PackedStringArray()
	for key in STAT_CATALOG.sorted_keys(values):
		parts.append(format_line(key, values.get(str(key), values.get(key))))
	return separator.join(parts)


static func format_summary(values: Dictionary, limit: int = 3, separator: String = " / ") -> String:
	var parts := PackedStringArray()
	for key in STAT_CATALOG.summary_keys(values, limit):
		parts.append("%s %s" % [format_label(key), format_value(key, values.get(str(key), values.get(key)))])
	return separator.join(parts)


static func build_deltas(current_values: Dictionary, next_values: Dictionary) -> Array[Dictionary]:
	var union := current_values.duplicate()
	for key in next_values.keys():
		if not union.has(key):
			union[key] = next_values[key]
	var output: Array[Dictionary] = []
	for key in STAT_CATALOG.sorted_keys(union):
		var current_value: Variant = current_values.get(str(key), current_values.get(key, null))
		var next_value: Variant = next_values.get(str(key), next_values.get(key, null))
		var current_number: Variant = _to_float(current_value)
		var next_number: Variant = _to_float(next_value)
		var delta: Variant = null
		var changed: bool = current_value != next_value
		if current_number != null and next_number != null:
			delta = float(next_number) - float(current_number)
			changed = not is_zero_approx(float(delta))
		var definition := STAT_CATALOG.get_definition(key)
		var direction := StringName(str(definition.get("direction", "neutral")))
		var benefit := &"neutral"
		if delta != null and changed:
			if direction == &"higher_better":
				benefit = &"positive" if float(delta) > 0.0 else &"negative"
			elif direction == &"lower_better":
				benefit = &"positive" if float(delta) < 0.0 else &"negative"
		output.append({
			"key": key,
			"label": format_label(key),
			"current": current_value,
			"next": next_value,
			"delta": delta,
			"changed": changed,
			"benefit": benefit,
		})
	return output


static func format_delta_line(delta_data: Dictionary) -> String:
	var key: Variant = delta_data.get("key", &"")
	var current_text := format_value(key, delta_data.get("current", null))
	var next_text := format_value(key, delta_data.get("next", null))
	var delta_value: Variant = delta_data.get("delta", null)
	var suffix := ""
	if delta_value != null and not is_zero_approx(float(delta_value)):
		suffix = "  (%s)" % format_value(key, delta_value, true)
	return "%s  %s → %s%s" % [format_label(key), current_text, next_text, suffix]


static func _to_float(value: Variant) -> Variant:
	if value is int or value is float:
		return float(value)
	var text := str(value).strip_edges()
	if text.is_valid_float():
		return text.to_float()
	return null


static func _format_decimal(value: float, decimals: int) -> String:
	var text := "%.2f" % value
	if decimals <= 0:
		return str(int(roundf(value)))
	if decimals == 1:
		text = "%.1f" % value
	while text.contains(".") and text.ends_with("0"):
		text = text.left(-1)
	if text.ends_with("."):
		text = text.left(-1)
	return text
