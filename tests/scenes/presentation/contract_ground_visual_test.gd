extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const GROUND := preload("res://World/battle_contract/beacon_ground_visual.gd")
const PROJECTED := preload("res://World/battle_contract/beacon_projected_visual.gd")
const FIRE_SPRAY := preload("res://Player/Weapons/Effects/cone_spray_vfx.tscn")
const FREEZE_SPRAY := preload("res://Player/Weapons/Effects/glacier_spray_vfx.tscn")

var _failed := false

func _ready() -> void:
	_test_shared_combat_palette_semantics()
	_test_spray_scene_palette_semantics()
	_test_ground_state_semantics()
	_test_projected_palette_semantics()
	print("FAIL: contract ground visual" if _failed else "PASS: contract ground visual")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_shared_combat_palette_semantics() -> void:
	_expect(PALETTE.FREEZE.is_equal_approx(Color("#83A9FF")), "freeze must use the blue-violet semantic color")
	_expect(PALETTE.FREEZE_CORE.is_equal_approx(Color("#E6EDFF")), "freeze must expose a readable core color")
	_expect(PALETTE.FREEZE_DARK.is_equal_approx(Color("#3D4F8F")), "freeze must expose a dark structure color")
	_expect(PALETTE.FIRE.is_equal_approx(Color("#FF3B4A")), "fire must use the red semantic color")
	_expect(PALETTE.FIRE_CORE.is_equal_approx(Color("#FFD0A3")), "fire must expose a readable core color")
	_expect(PALETTE.FIRE_DARK.is_equal_approx(Color("#6B1622")), "fire must expose a dark structure color")
	_expect(PALETTE.WARNING.is_equal_approx(Color("#FF762E")), "warning must use the shared orange-red semantic color")
	_expect(PALETTE.REWARD.is_equal_approx(Color("#F4C542")), "reward must retain the reserved gold color")
	_expect(PALETTE.SPEED.is_equal_approx(Color("#A8E85C")), "speed must move out of the reward-gold range")
	_expect(PALETTE.FIELD_TASK.is_equal_approx(Color("#B888FF")), "field tasks must move out of the reward-gold range")
	var fire_warning_gap := _hue_distance_degrees(PALETTE.FIRE, PALETTE.WARNING)
	var warning_reward_gap := _hue_distance_degrees(PALETTE.WARNING, PALETTE.REWARD)
	_expect(fire_warning_gap >= 20.0 and fire_warning_gap <= 30.0, "fire and warning hues must remain 20-30 degrees apart")
	_expect(warning_reward_gap >= 20.0 and warning_reward_gap <= 30.0, "warning and reward hues must remain 20-30 degrees apart")

func _hue_distance_degrees(first: Color, second: Color) -> float:
	var distance := absf(first.h - second.h) * 360.0
	return minf(distance, 360.0 - distance)

func _test_spray_scene_palette_semantics() -> void:
	var fire_spray := FIRE_SPRAY.instantiate()
	_expect(Color(fire_spray.range_cue_color, 1.0).is_equal_approx(PALETTE.FIRE), "flame spray range cue must use the shared red fire hue")
	_expect(Color(fire_spray.core_highlight_color, 1.0).is_equal_approx(PALETTE.FIRE_CORE), "flame spray core must use the shared fire core")
	_expect(Color(fire_spray.trail_modulate, 1.0).is_equal_approx(PALETTE.FIRE), "flame spray trail must remain fire-red")
	fire_spray.free()
	var freeze_spray := FREEZE_SPRAY.instantiate()
	_expect(Color(freeze_spray.range_cue_color, 1.0).is_equal_approx(PALETTE.FREEZE), "glacier spray range cue must use the shared blue-violet freeze hue")
	_expect(Color(freeze_spray.core_highlight_color, 1.0).is_equal_approx(PALETTE.FREEZE_CORE), "glacier spray core must use the shared freeze core")
	_expect(Color(freeze_spray.trail_modulate, 1.0).is_equal_approx(PALETTE.FREEZE), "glacier spray trail must remain blue-violet")
	freeze_spray.free()

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
	_expect(Color(contest_detail, 1.0).is_equal_approx(Color(PALETTE.WARNING, 1.0)), "enemy contest ground must use the shared warning hue")
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
	_expect(Color(contested, 1.0).is_equal_approx(Color(PALETTE.WARNING, 1.0)), "contested projected marker must use the shared warning hue")
	visual.set_progress(1.0)
	var complete := visual.get_state_palette_snapshot().primary as Color
	_expect(absf(complete.r - complete.g) < 0.05, "projected completion must begin white before resolving cyan")
	visual.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
