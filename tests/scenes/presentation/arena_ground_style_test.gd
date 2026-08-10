extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const ARENA_GROUND_STYLE := preload("res://Visual/Oblique/arena_ground_style.gd")
const GROUND_SHADER := preload("res://Shaders/battlefield_deployment_ground.gdshader")

var _failed := false


func _ready() -> void:
	_test_stable_six_variant_policy()
	_test_twelve_decal_catalog()
	_test_restrained_detail_budget()
	print("FAIL: arena ground style" if _failed else "PASS: arena ground style")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _test_stable_six_variant_policy() -> void:
	var variants := {}
	for cell_id in range(-12, 13):
		var first := ARENA_GROUND_STYLE.build_style(cell_id)
		var second := ARENA_GROUND_STYLE.build_style(cell_id)
		_expect(first == second, "cell style must be stable for id %d" % cell_id)
		var variant := int(first.get("variant", -1))
		_expect(variant >= 0 and variant < ARENA_GROUND_STYLE.VARIANT_COUNT, "variant must remain within the six-style catalog")
		variants[variant] = true
	_expect(variants.size() == ARENA_GROUND_STYLE.VARIANT_COUNT, "a normal board id range must expose all six reusable floor variants")


func _test_restrained_detail_budget() -> void:
	for cell_id in range(-12, 13):
		var style := ARENA_GROUND_STYLE.build_style(cell_id)
		var strength := float(style.get("detail_strength", 1.0))
		_expect(strength >= ARENA_GROUND_STYLE.DETAIL_STRENGTH_MIN, "floor detail must remain visible")
		_expect(strength <= ARENA_GROUND_STYLE.DETAIL_STRENGTH_MAX, "floor detail must remain lower contrast than combat cues")
		var seed := float(style.get("seed", -1.0))
		_expect(seed >= 0.0 and seed <= 1.0, "shader detail seed must remain normalized")
		var decal_strength := float(style.get("decal_strength", 1.0))
		_expect(decal_strength > 0.0, "arena decal must remain visible")
		_expect(decal_strength <= ARENA_GROUND_STYLE.DECAL_STRENGTH_MAX, "arena decal must remain subordinate to combat cues")
		var ambient_phase := float(style.get("ambient_phase", -1.0))
		_expect(ambient_phase >= 0.0 and ambient_phase < 1.0, "ambient circuit animation phase must remain normalized and deterministic")


func _test_twelve_decal_catalog() -> void:
	var decals := {}
	for cell_id in range(-256, 257):
		var style := ARENA_GROUND_STYLE.build_style(cell_id)
		var decal_id := int(style.get("decal_id", -1))
		_expect(decal_id >= 0 and decal_id < ARENA_GROUND_STYLE.DECAL_COUNT, "decal id must stay within the reusable catalog")
		_expect(int(style.get("decal_rotation", -1)) in range(4), "decal rotation must remain quarter-turn aligned")
		decals[decal_id] = true
	_expect(decals.size() == ARENA_GROUND_STYLE.DECAL_COUNT, "normal board ids must expose all twelve reusable decals")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
