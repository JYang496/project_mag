extends Control
class_name SkillEnergyMeter

const ENERGY_PER_CORE := 50.0
const CORE_SIZE := Vector2(28.0, 12.0)
const CORE_GAP := 5.0
const UNDERLINE_HEIGHT := 3.0
const MIN_CORE_COUNT := 2

const EMPTY_FILL := Color(0.04, 0.08, 0.10, 0.78)
const EMPTY_BORDER := Color(0.20, 0.32, 0.36, 0.95)
const FILLED_FILL := Color(0.18, 0.78, 0.95, 0.95)
const FILLED_EDGE := Color(0.68, 0.96, 1.0, 1.0)
const COST_EDGE := Color(0.96, 0.94, 0.55, 1.0)
const SHORTAGE_EDGE := Color(1.0, 0.18, 0.16, 1.0)
const SHORTAGE_FILL := Color(0.45, 0.04, 0.05, 0.86)
const COOLDOWN_WASH := Color(0.02, 0.03, 0.04, 0.52)

var _current_energy: float = 0.0
var _max_energy: float = 100.0
var _skill_cost: float = 50.0
var _cooldown_ratio: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_minimum_size()

func set_energy(current: float, max_value: float) -> void:
	var next_max := maxf(max_value, ENERGY_PER_CORE)
	var next_current := clampf(current, 0.0, next_max)
	if is_equal_approx(_current_energy, next_current) and is_equal_approx(_max_energy, next_max):
		return
	var core_count_changed := _get_core_count_for(_max_energy) != _get_core_count_for(next_max)
	_current_energy = next_current
	_max_energy = next_max
	if core_count_changed:
		_sync_minimum_size()
	queue_redraw()

func set_skill_cost(cost: float) -> void:
	var next_cost := maxf(cost, 0.0)
	if is_equal_approx(_skill_cost, next_cost):
		return
	_skill_cost = next_cost
	queue_redraw()

func set_cooldown_ratio(ratio: float) -> void:
	var next_ratio := clampf(ratio, 0.0, 1.0)
	if is_equal_approx(_cooldown_ratio, next_ratio):
		return
	_cooldown_ratio = next_ratio
	queue_redraw()

func _draw() -> void:
	var core_count := _get_core_count()
	var core_area_height := CORE_SIZE.y + UNDERLINE_HEIGHT + 2.0
	var origin_y := maxf(0.0, (size.y - core_area_height) * 0.5)
	for index in range(core_count):
		_draw_core(index, origin_y)

func _draw_core(index: int, origin_y: float) -> void:
	var x := float(index) * (CORE_SIZE.x + CORE_GAP)
	var rect := Rect2(Vector2(x, origin_y), CORE_SIZE)
	var core_start := float(index) * ENERGY_PER_CORE
	var fill_ratio := clampf((_current_energy - core_start) / ENERGY_PER_CORE, 0.0, 1.0)
	var required_ratio := clampf((_skill_cost - core_start) / ENERGY_PER_CORE, 0.0, 1.0)
	var missing_required := required_ratio > fill_ratio and required_ratio > 0.0

	draw_rect(rect, EMPTY_FILL, true)
	if fill_ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * fill_ratio, rect.size.y))
		draw_rect(fill_rect, FILLED_FILL, true)
	if missing_required:
		var missing_start := rect.position.x + rect.size.x * fill_ratio
		var missing_width := rect.size.x * (required_ratio - fill_ratio)
		draw_rect(Rect2(Vector2(missing_start, rect.position.y), Vector2(missing_width, rect.size.y)), SHORTAGE_FILL, true)

	var border_color := EMPTY_BORDER
	if required_ratio > 0.0:
		border_color = COST_EDGE
	if missing_required:
		border_color = SHORTAGE_EDGE
	elif fill_ratio > 0.0:
		border_color = FILLED_EDGE
	draw_rect(rect, border_color, false, 1.5)

	if required_ratio > 0.0:
		var underline_y := rect.position.y + rect.size.y + 2.0
		var underline_width := maxf(2.0, rect.size.x * required_ratio)
		var underline_color := SHORTAGE_EDGE if missing_required else COST_EDGE
		draw_rect(Rect2(Vector2(rect.position.x, underline_y), Vector2(underline_width, UNDERLINE_HEIGHT)), underline_color, true)

	if _cooldown_ratio > 0.0:
		var wash_height := rect.size.y * clampf(_cooldown_ratio, 0.0, 1.0)
		draw_rect(Rect2(Vector2(rect.position.x, rect.position.y + rect.size.y - wash_height), Vector2(rect.size.x, wash_height)), COOLDOWN_WASH, true)

func _get_required_core_count() -> int:
	if _skill_cost <= 0.0:
		return 0
	return int(ceil(_skill_cost / ENERGY_PER_CORE))

func _has_energy_shortage() -> bool:
	return _skill_cost > _current_energy

func _sync_minimum_size() -> void:
	custom_minimum_size = _calculate_minimum_size(_get_core_count())

func _calculate_minimum_size(core_count: int) -> Vector2:
	var safe_count := maxi(MIN_CORE_COUNT, core_count)
	return Vector2(
		float(safe_count) * CORE_SIZE.x + float(safe_count - 1) * CORE_GAP,
		CORE_SIZE.y + UNDERLINE_HEIGHT + 2.0
	)

func _get_core_count() -> int:
	return _get_core_count_for(_max_energy)

func _get_core_count_for(max_value: float) -> int:
	return maxi(MIN_CORE_COUNT, int(ceil(maxf(max_value, ENERGY_PER_CORE) / ENERGY_PER_CORE)))
