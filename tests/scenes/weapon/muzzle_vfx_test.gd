extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const SERVICE := preload("res://Player/Weapons/Feedback/muzzle_flash_vfx_service.gd")
const RARE_SIGNATURE := preload("res://Player/Weapons/Feedback/rare_weapon_vfx_signature.gd")
const FLASH_SCENES := [
	preload("res://Player/Weapons/Feedback/muzzle_flash_light.tscn"),
	preload("res://Player/Weapons/Feedback/muzzle_flash_heavy.tscn"),
	preload("res://Player/Weapons/Feedback/muzzle_flash_energy.tscn"),
	preload("res://Player/Weapons/Feedback/muzzle_flash_plasma.tscn"),
]

var _failed := false

func _ready() -> void:
	_test_four_category_contract()
	_test_profile_signature_contract()
	_test_rare_branch_signatures()
	await _test_pool_budget_and_reuse()
	print("FAIL: muzzle vfx" if _failed else "PASS: muzzle vfx")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_four_category_contract() -> void:
	var styles := {}
	for scene_variant in FLASH_SCENES:
		var scene := scene_variant as PackedScene
		var flash: Node = scene.instantiate() if scene != null else null
		_expect(flash != null, "muzzle category scene must instantiate")
		if flash == null:
			continue
		styles[int(flash.shape_style)] = true
		_expect([32, 64].has(int(flash.source_size_px)), "muzzle source size must be 32 or 64")
		_expect(float(flash.duration_sec) <= 0.10, "muzzle feedback must remain short")
		flash.free()
	_expect(styles.has(0) and styles.has(1) and styles.has(2), "ballistic, energy, and plasma shapes must remain distinct")

func _test_pool_budget_and_reuse() -> void:
	var service := SERVICE.new()
	add_child(service)
	for index in range(SERVICE.MAX_ACTIVE_EFFECTS + 6):
		service.play(FLASH_SCENES[index % FLASH_SCENES.size()], Vector2(index, 0), Vector2.RIGHT)
	var saturated := service.get_pool_metrics()
	_expect(int(saturated.get("pooled", 0)) == SERVICE.MAX_ACTIVE_EFFECTS, "muzzle pool must cap allocation at twelve")
	_expect(int(saturated.get("active", 0)) == SERVICE.MAX_ACTIVE_EFFECTS, "overflow fire must recycle an active slot")
	await get_tree().create_timer(0.16).timeout
	_expect(int(service.get_pool_metrics().get("active", -1)) == 0, "muzzle flashes must return to the pool")
	service.play(FLASH_SCENES[0], Vector2.ZERO, Vector2.RIGHT)
	_expect(int(service.get_pool_metrics().get("pooled", 0)) == SERVICE.MAX_ACTIVE_EFFECTS, "second-use muzzle feedback must reuse the pool")
	service.queue_free()
	await get_tree().process_frame


func _test_profile_signature_contract() -> void:
	var scene := FLASH_SCENES[0] as PackedScene
	var flash := scene.instantiate() as Node2D
	add_child(flash)
	var base_length := float(flash.get("length_px"))
	var base_width := float(flash.get("width_px"))
	flash.call("apply_signature", {"scale": 1.2, "length_scale": 1.4, "width_scale": 0.7, "tint_strength": 0.4, "tint": Color.CYAN})
	_expect(is_equal_approx(float(flash.get("length_px")), base_length * 1.4), "advanced signature must control muzzle length")
	_expect(is_equal_approx(float(flash.get("width_px")), base_width * 0.7), "advanced signature must control muzzle width")
	flash.call("apply_signature", {})
	_expect(is_equal_approx(float(flash.get("length_px")), base_length), "pooled signature must reset to the scene baseline")
	_expect(is_equal_approx(float(flash.get("width_px")), base_width), "pooled width must not leak between weapons")
	flash.queue_free()


func _test_rare_branch_signatures() -> void:
	var styles := {}
	for branch_ids in [["frost_dash"], ["napalm_rocket"], ["arc_coil"], ["prism_fan"]]:
		var signature := RARE_SIGNATURE.for_branch_ids(branch_ids)
		styles[int(signature.get("signature_style", 0))] = true
		_expect(float(signature.get("tint_strength", 0.0)) <= 0.55, "rare branch tint must remain bounded")
	_expect(styles.size() == 4, "rare frost, napalm, arc, and prism branches must keep distinct muzzle signatures")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
