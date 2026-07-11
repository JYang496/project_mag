extends RefCounted
class_name BuildTagDisplay

const STATUS_EFFECT: StringName = &"effect"
const STATUS_FIT: StringName = &"fit"
const STATUS_FIT_BLOCKED: StringName = &"fit_blocked"
const STATUS_FIT_UNKNOWN: StringName = &"fit_unknown"
const STATUS_FALLBACK: StringName = &"fallback"

const DEFAULT_COLOR: Color = Color(0.54, 0.64, 0.72, 1.0)
const FIT_COLOR: Color = Color(0.38, 0.86, 0.58, 1.0)
const BLOCKED_COLOR: Color = Color(1.0, 0.34, 0.28, 1.0)
const UNKNOWN_COLOR: Color = Color(0.62, 0.68, 0.74, 1.0)
const CHIP_HORIZONTAL_PADDING: float = 18.0
const CHIP_MIN_WIDTH: float = 42.0
const CHIP_MAX_WIDTH: float = 118.0
const CHIP_ASCII_CHAR_WIDTH: float = 6.5
const CHIP_WIDE_CHAR_WIDTH: float = 12.0

const TAG_SPECS := {
	"heat": {"label": "Heat", "color": Color(1.0, 0.42, 0.18, 1.0), "icon_key": "heat", "sort_weight": 10},
	"mark": {"label": "Mark", "color": Color(0.95, 0.72, 0.22, 1.0), "icon_key": "mark", "sort_weight": 20},
	"freeze": {"label": "Freeze", "color": Color(0.36, 0.78, 1.0, 1.0), "icon_key": "freeze", "sort_weight": 30},
	"reload": {"label": "Reload", "color": Color(0.70, 0.74, 1.0, 1.0), "icon_key": "reload", "sort_weight": 40},
	"area": {"label": "Area", "color": Color(0.76, 0.56, 1.0, 1.0), "icon_key": "area", "sort_weight": 50},
	"on_hit": {"label": "On Hit", "color": Color(0.56, 0.86, 0.76, 1.0), "icon_key": "on_hit", "sort_weight": 60},
	"execute": {"label": "Execute", "color": Color(1.0, 0.56, 0.50, 1.0), "icon_key": "execute", "sort_weight": 70},
	"economy": {"label": "Economy", "color": Color(0.96, 0.82, 0.28, 1.0), "icon_key": "economy", "sort_weight": 80},
	"projectile": {"label": "Projectile", "color": Color(0.48, 0.82, 1.0, 1.0), "icon_key": "projectile", "sort_weight": 90},
	"beam": {"label": "Beam", "color": Color(0.96, 0.48, 1.0, 1.0), "icon_key": "beam", "sort_weight": 100},
	"defense": {"label": "Defense", "color": Color(0.38, 0.84, 0.68, 1.0), "icon_key": "defense", "sort_weight": 110},
	"ammo": {"label": "Ammo", "color": Color(0.58, 0.78, 1.0, 1.0), "icon_key": "ammo", "sort_weight": 120},
	"crit": {"label": "Crit", "color": Color(1.0, 0.66, 0.26, 1.0), "icon_key": "crit", "sort_weight": 130},
	"close": {"label": "Close", "color": Color(0.92, 0.58, 0.42, 1.0), "icon_key": "close", "sort_weight": 140},
	"buff": {"label": "Buff", "color": Color(0.50, 0.88, 0.54, 1.0), "icon_key": "buff", "sort_weight": 150},
	"weapon": {"label": "Weapon", "color": Color(0.72, 0.82, 0.96, 1.0), "icon_key": "weapon", "sort_weight": 180},
	"module": {"label": "Module", "color": Color(0.72, 0.74, 1.0, 1.0), "icon_key": "module", "sort_weight": 190},
	"terrain": {"label": "Terrain", "color": Color(0.54, 0.82, 0.58, 1.0), "icon_key": "terrain", "sort_weight": 200},
	"task": {"label": "Task", "color": Color(0.74, 0.62, 1.0, 1.0), "icon_key": "task", "sort_weight": 210},
}

static func build_tag_chip(source_value: Variant, label_override: String = "") -> Dictionary:
	var source_key := _normalize_source_key(source_value)
	var spec: Dictionary = TAG_SPECS.get(source_key, {})
	var label := label_override.strip_edges()
	if label == "":
		var fallback_label := str(spec.get("label", _label_from_key(source_key))).strip_edges()
		label = _localized_tag_label(source_key, fallback_label)
	if label == "":
		label = LocalizationManager.tr_key("ui.common.tag", "Tag")
	var known := not spec.is_empty()
	return {
		"label": label,
		"icon_key": str(spec.get("icon_key", "generic")),
		"color": spec.get("color", DEFAULT_COLOR),
		"sort_weight": int(spec.get("sort_weight", 900)),
		"status": STATUS_EFFECT if known else STATUS_FALLBACK,
		"source_key": source_key,
	}

static func _localized_tag_label(source_key: String, fallback: String) -> String:
	match source_key:
		"weapon", "module", "terrain", "task", "economy":
			return LocalizationManager.tr_key("ui.reward.category.%s" % source_key, fallback)
		_:
			return LocalizationManager.get_module_term(StringName(source_key), fallback)

static func build_fit_status_badge(status: StringName, label: String) -> Dictionary:
	var clean_label := label.strip_edges()
	if clean_label == "":
		clean_label = "No current weapon"
	match status:
		&"fits":
			return _make_status_chip(clean_label, "fit", FIT_COLOR, 0, STATUS_FIT)
		&"blocked":
			return _make_status_chip(clean_label, "blocked", BLOCKED_COLOR, 1, STATUS_FIT_BLOCKED)
		_:
			return _make_status_chip(clean_label, "unknown", UNKNOWN_COLOR, 2, STATUS_FIT_UNKNOWN)

static func build_chips_from_keys(source_values: Array, limit: int = 0) -> Array:
	var chips: Array = []
	for value in source_values:
		_append_unique_chip(chips, build_tag_chip(value))
	if limit > 0 and chips.size() > limit:
		return chips.slice(0, limit)
	return chips

static func chip_labels(chips: Array, limit: int = 0) -> PackedStringArray:
	var labels := PackedStringArray()
	var max_count := chips.size()
	if limit > 0:
		max_count = mini(max_count, limit)
	for index in range(max_count):
		var chip := chips[index] as Dictionary
		var label := str(chip.get("label", "")).strip_edges()
		if label != "":
			labels.append(label)
	return labels

static func make_chip_row(chips: Array, limit: int = 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "BuildChipRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	populate_chip_row(row, chips, limit)
	return row

static func populate_chip_row(row: Container, chips: Array, limit: int = 0) -> void:
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var max_count := chips.size()
	if limit > 0:
		max_count = mini(max_count, limit)
	for index in range(max_count):
		var chip := chips[index] as Dictionary
		row.add_child(make_chip(chip))
	row.visible = max_count > 0

static func make_chip(chip_data: Dictionary) -> PanelContainer:
	var color: Color = chip_data.get("color", DEFAULT_COLOR)
	var text := str(chip_data.get("label", "Tag")).strip_edges()
	if text == "":
		text = "Tag"
	var panel := PanelContainer.new()
	panel.name = "BuildChip"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.custom_minimum_size = Vector2(_estimate_chip_width(text), 22.0)
	panel.tooltip_text = text
	panel.add_theme_stylebox_override("panel", _make_chip_style(color))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.custom_minimum_size = Vector2(maxf(0.0, panel.custom_minimum_size.x - CHIP_HORIZONTAL_PADDING), 0.0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)
	return panel

static func _make_status_chip(label: String, icon_key: String, color: Color, sort_weight: int, status: StringName) -> Dictionary:
	return {
		"label": label,
		"icon_key": icon_key,
		"color": color,
		"sort_weight": sort_weight,
		"status": status,
		"source_key": icon_key,
	}

static func _append_unique_chip(chips: Array, chip: Dictionary) -> void:
	var source_key := str(chip.get("source_key", "")).strip_edges()
	for existing in chips:
		if str(existing.get("source_key", "")) == source_key:
			return
	for index in range(chips.size()):
		if _comes_before(chip, chips[index]):
			chips.insert(index, chip)
			return
	chips.append(chip)

static func _comes_before(left: Dictionary, right: Dictionary) -> bool:
	var left_weight := int(left.get("sort_weight", 900))
	var right_weight := int(right.get("sort_weight", 900))
	if left_weight != right_weight:
		return left_weight < right_weight
	return str(left.get("label", "")) < str(right.get("label", ""))

static func _make_chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.18)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

static func _estimate_chip_width(text: String) -> float:
	var width := CHIP_HORIZONTAL_PADDING
	for index in range(text.length()):
		var code := text.unicode_at(index)
		width += CHIP_ASCII_CHAR_WIDTH if code <= 0x7f else CHIP_WIDE_CHAR_WIDTH
	return clampf(width, CHIP_MIN_WIDTH, CHIP_MAX_WIDTH)

static func _normalize_source_key(source_value: Variant) -> String:
	var text := str(source_value).strip_edges().to_lower()
	text = text.replace(" ", "_").replace("-", "_")
	if text == "onhit":
		return "on_hit"
	return text

static func _label_from_key(source_key: String) -> String:
	return source_key.replace("_", " ").capitalize()
