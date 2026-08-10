extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const GROUND := preload("res://World/battle_contract/beacon_ground_visual.gd")
const PROJECTED := preload("res://World/battle_contract/beacon_projected_visual.gd")

var _failed := false

func _ready() -> void:
	_test_ground_state_semantics()
	_test_projected_palette_semantics()
	print("FAIL: contract ground visual" if _failed else "PASS: contract ground visual")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_ground_state_semantics() -> void:
	var ground := GROUND.new()
	ground.configure_style(&"containment")
	add_child(ground)
	ground.set_state(0.0, false, 0, false)
	var inactive := ground.get_visual_state_snapshot()
	var inactive_base := inactive.base_color as Color
	_expect(inactive_base.b > inactive_base.g, "inactive rift ground must remain purple")
	ground.set_state(0.35, true, 0, false)
	var stabilizing := ground.get_visual_state_snapshot()
	var stabilize_detail := stabilizing.detail_color as Color
	_expect(stabilize_detail.g > stabilize_detail.r and stabilize_detail.b > stabilize_detail.r, "player stabilization must use cyan ground data")
	_expect(stabilize_detail.a >= 0.48, "entering the rift must activate a readable cyan ring before progress")
	ground.set_state(0.35, true, 2, false)
	var contested := ground.get_visual_state_snapshot()
	var contest_detail := contested.detail_color as Color
	_expect(contest_detail.r > contest_detail.g and contest_detail.g > contest_detail.b, "enemy contest must use orange ground pulse")
	ground.set_state(1.0, true, 0, true)
	var complete_start := ground.get_visual_state_snapshot()
	var complete_color := complete_start.base_color as Color
	_expect(absf(complete_color.r - complete_color.g) < 0.05, "completion must begin with a white confirmation flash")
	ground._process(0.72)
	var collapsed := ground.get_visual_state_snapshot().base_color as Color
	_expect(collapsed.a <= 0.01, "completed containment ground must collapse instead of persisting")

func _test_projected_palette_semantics() -> void:
	var visual := PROJECTED.new()
	visual.visual_kind = &"containment"
	var inactive := visual.get_state_palette_snapshot()
	var inactive_primary := inactive.primary as Color
	_expect(inactive_primary.b > inactive_primary.g, "inactive projected marker must use purple anomaly semantics")
	visual.set_presence(true, 0)
	visual.set_progress(0.4)
	var active := visual.get_state_palette_snapshot()
	var active_primary := active.primary as Color
	var active_progress := active.progress as Color
	_expect(active_primary.g > active_primary.r and active_progress.b > active_progress.r, "active projected marker and progress must use cyan stabilization")
	visual.set_presence(true, 3)
	var contested := visual.get_state_palette_snapshot().primary as Color
	_expect(contested.r > contested.g and contested.g > contested.b, "contested projected marker must use orange warning")
	visual.set_progress(1.0)
	var complete := visual.get_state_palette_snapshot().primary as Color
	_expect(absf(complete.r - complete.g) < 0.05, "projected completion must begin white before resolving cyan")
	visual.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
