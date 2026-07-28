extends Node

const WHEEL_CART_SCENE := preload("res://Npc/enemy/scenes/enemy_wheel_cart.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false


func _ready() -> void:
	var enemy := WHEEL_CART_SCENE.instantiate() as BaseEnemy
	add_child(enemy)
	await get_tree().process_frame

	var hurt_box := enemy.get_node_or_null("HurtBox") as HurtBox
	_expect(enemy.damage > 0, "wheel cart must define positive contact damage")
	_expect(hurt_box != null, "wheel cart must retain its contact HurtBox")
	if hurt_box != null:
		_expect(hurt_box.get_collision_layer_value(3), "wheel cart HurtBox must remain on the enemy layer")
	_expect(not enemy.get_collision_mask_value(1), "wheel cart body must pass through the player layer")

	print(
		"FAIL wheel cart contact configuration"
		if _failed
		else "PASS wheel cart contact configuration"
	)
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
