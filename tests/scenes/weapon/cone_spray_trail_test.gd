extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const FLAME_VFX_SCENE := preload("res://Player/Weapons/Effects/cone_spray_vfx.tscn")
const GLACIER_VFX_SCENE := preload("res://Player/Weapons/Effects/glacier_spray_vfx.tscn")

var _failed := false
var _created_nodes: Array[Node] = []


func _ready() -> void:
	_test_directional_snapshot_and_world_space_lifecycle()
	_test_pool_capacity_and_cleanup()
	_test_element_specific_motion_profiles()
	print("FAIL cone spray trail" if _failed else "PASS cone spray trail")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, Callable(), _created_nodes)


func _test_directional_snapshot_and_world_space_lifecycle() -> void:
	var vfx := _spawn_vfx(FLAME_VFX_SCENE)
	vfx.start_or_refresh(Vector2(100.0, 120.0), Vector2.RIGHT, 220.0, 40.0)
	vfx.call("_physics_process", 0.09)
	vfx.update_aim(Vector2(100.0, 120.0), Vector2.RIGHT.rotated(deg_to_rad(18.0)), 220.0, 40.0)
	var active := vfx.get_active_trail_afterimages()
	_expect(active.size() == 1, "turning beyond the adaptive threshold must leave one previous-direction afterimage")
	if active.is_empty():
		return
	var trail: Node = active[0]
	var snapshot_direction := trail.call("get_snapshot_direction") as Vector2
	_expect(snapshot_direction.dot(Vector2.RIGHT) > 0.999, "the trail must preserve the previous attack direction")
	var snapshot_origin := trail.call("get_snapshot_origin") as Vector2
	var trail_visual := trail.call("get_hybrid_ground_cone_visual") as Dictionary
	_expect(is_zero_approx(float(trail_visual.get("range_cue_opacity", 1.0))), "afterimages must not duplicate the authoritative range cue")
	vfx.call("_physics_process", 0.09)
	vfx.update_aim(Vector2(180.0, 150.0), Vector2.RIGHT.rotated(deg_to_rad(18.0)), 220.0, 40.0)
	_expect((trail.call("get_snapshot_origin") as Vector2) == snapshot_origin, "moving the weapon must not rewrite an existing world-space trail origin")
	_expect(vfx.get_active_trail_afterimages().size() == 2, "moving the active spray far enough must leave a world-space emission slice")
	trail.call("_physics_process", flame_lifetime(vfx) + 0.05)
	_expect(not bool(trail.call("is_active")), "each trail slice must expire independently after its configured lifetime")


func _test_pool_capacity_and_cleanup() -> void:
	var vfx := _spawn_vfx(FLAME_VFX_SCENE)
	vfx.trail_max_afterimages = 3
	vfx.start_or_refresh(Vector2.ZERO, Vector2.RIGHT, 200.0, 35.0)
	for index in range(7):
		vfx.call("_physics_process", 0.09)
		vfx.update_aim(Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(float(index + 1) * 16.0)), 200.0, 35.0)
	_expect(vfx.get_active_trail_afterimages().size() <= 3, "trail instances must stay within their configured pool capacity")
	vfx.cleanup_for_battle_end()
	_expect(vfx.get_active_trail_afterimages().is_empty(), "battle cleanup must deactivate every pooled trail")


func _test_element_specific_motion_profiles() -> void:
	var flame := _spawn_vfx(FLAME_VFX_SCENE)
	var glacier := _spawn_vfx(GLACIER_VFX_SCENE)
	_expect(not flame.trail_cold_style, "the flamethrower trail must use the rising ember profile")
	_expect(glacier.trail_cold_style, "the glacier trail must use the spreading frost profile")
	_expect(glacier.trail_lifetime_sec > flame.trail_lifetime_sec, "cold mist must linger longer than hot flame afterimages")
	_expect(glacier.trail_spread_scale > flame.trail_spread_scale, "cold mist must diffuse wider while flame contracts")
	_expect(flame.trail_end_scale < 1.0, "flame afterimages must contract during fade")


func _spawn_vfx(scene: PackedScene) -> ConeSprayVfx:
	var vfx := scene.instantiate() as ConeSprayVfx
	add_child(vfx)
	_created_nodes.append(vfx)
	return vfx


func flame_lifetime(vfx: ConeSprayVfx) -> float:
	return float(vfx.trail_lifetime_sec)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
