extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PLAYER_STATUS_HUD := preload("res://UI/scripts/components/player_status_hud.gd")
const HEAVY_ASSAULT_SKILL := preload("res://Player/Skills/heavy_assault_heat_lock.gd")

var _failed := false
var _hud: Control

func _ready() -> void:
	_hud = PLAYER_STATUS_HUD.new()
	add_child(_hud)
	await get_tree().process_frame
	_test_no_active_skill_hides_skill_rail()
	_hud.set_skill_available(true)
	_test_cooldown_has_independent_duration()
	_test_ready_and_full_indicators()
	_test_energy_shortage_is_not_cooldown()
	_test_ratio_compatibility()
	_test_heavy_assault_cooldown_ticks()
	_test_energy_and_cooldown_geometry_do_not_overlap()
	print("FAIL skill energy status" if _failed else "PASS skill energy status")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_no_active_skill_hides_skill_rail() -> void:
	_hud.set_skill_available(false)
	_hud.set_energy(100.0, 125.0)
	_hud.set_skill_cost(50.0)
	_expect(
		not _hud.is_skill_rail_visible(),
		"weapons with no active skill, including passive-only weapons, must hide the active skill rail"
	)
	_expect(_hud.get_skill_state() == &"inactive", "missing active skill must remain inactive")
	_expect(
		_hud.get_full_energy_bean_count() == 0,
		"hidden active skill rail must not report visible energy segments"
	)

func _test_cooldown_has_independent_duration() -> void:
	_hud.set_energy(100.0, 125.0)
	_hud.set_skill_cost(50.0)
	_hud.set_cooldown(4.25, 8.0)
	_expect(_hud.get_skill_state() == &"cooldown", "active cooldown must have its own state")
	_expect(not _hud.is_skill_ready(), "energy must not make a cooling skill ready")
	_expect(is_equal_approx(_hud.get_cooldown_remaining(), 4.25), "remaining cooldown seconds must be retained")
	_expect(
		is_equal_approx(_hud.get_cooldown_progress(), 1.0 - 4.25 / 8.0),
		"cooldown progress must grow from zero toward ready"
	)
	var label := _hud.get_node_or_null("SkillState") as Label
	_expect(label != null and label.text == "4.3s", "cooldown must display remaining seconds")
	_expect(_hud.get_full_energy_bean_count() == 2, "cooldown must not change filled energy beans")

func _test_ready_and_full_indicators() -> void:
	_hud.set_cooldown(0.0, 8.0)
	_expect(_hud.get_skill_state() == &"ready", "enough energy after cooldown must be READY")
	_expect(_hud.is_skill_ready(), "ready state must be exposed independently")
	_expect(is_equal_approx(_hud.get_cooldown_progress(), 1.0), "ready cooldown bar must be full")
	var label := _hud.get_node_or_null("SkillState") as Label
	_expect(label != null and not label.text.is_empty(), "ready state must have a visible label")
	_hud.set_energy(125.0, 125.0)
	_expect(_hud.get_full_energy_bean_count() == 3, "the final half-capacity bean must report full")

func _test_energy_shortage_is_not_cooldown() -> void:
	_hud.set_energy(49.0, 125.0)
	_expect(_hud.get_skill_state() == &"charging", "energy shortage must remain an energy state")
	_expect(_hud.get_full_energy_bean_count() == 0, "partial bean must not count as full")
	var label := _hud.get_node_or_null("SkillState") as Label
	_expect(label != null and label.text.is_empty(), "energy shortage must not display cooldown text")

func _test_ratio_compatibility() -> void:
	_hud.set_energy(50.0, 125.0)
	_hud.set_cooldown_ratio(0.5)
	_expect(_hud.get_skill_state() == &"cooldown", "legacy ratio updates must still show cooldown")
	_expect(is_equal_approx(_hud.get_cooldown_progress(), 0.5), "legacy remaining ratio must render as completion progress")
	var label := _hud.get_node_or_null("SkillState") as Label
	_expect(label != null and label.text == "CD", "ratio-only cooldown must not invent seconds")

func _test_heavy_assault_cooldown_ticks() -> void:
	var skill = HEAVY_ASSAULT_SKILL.new()
	skill.set("_cooldown_remaining", 1.0)
	skill.call("_physics_process", 0.25)
	_expect(
		is_equal_approx(float(skill.call("get_cooldown_remaining")), 0.75),
		"heavy assault physics override must advance the base skill cooldown"
	)
	skill.free()

func _test_energy_and_cooldown_geometry_do_not_overlap() -> void:
	_hud.set_energy(125.0, 125.0)
	var energy_segments: Rect2 = _hud.get_energy_segments_rect()
	var plate: Rect2 = _hud.get_energy_plate_rect()
	var cooldown_track: Rect2 = _hud.get_cooldown_track_rect()
	_expect(
		not energy_segments.intersects(cooldown_track),
		"skill energy segments must not overlap the integrated cooldown baseline"
	)
	_expect(
		cooldown_track.position.y - energy_segments.end.y >= 3.0,
		"skill energy segments and cooldown baseline need a three-pixel internal gap"
	)
	_expect(
		plate.encloses(cooldown_track),
		"cooldown baseline must be contained by the unified skill rail"
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
