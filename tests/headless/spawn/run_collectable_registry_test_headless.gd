extends SceneTree

const COIN_SCENE := preload("res://Objects/loots/coin.tscn")
const CHIP_SCENE := preload("res://Objects/loots/chip.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := root.get_node_or_null("/root/CollectableRegistry")
	if registry == null:
		push_error("FAIL: missing CollectableRegistry autoload")
		quit(1)
		return
	var coin := COIN_SCENE.instantiate()
	var chip := CHIP_SCENE.instantiate()
	root.add_child(coin)
	root.add_child(chip)
	await process_frame
	var collectables: Array = registry.call("get_collectables")
	var coins: Array = registry.call("get_coins")
	if collectables.size() != 2:
		push_error("FAIL: expected 2 collectables, got %d" % collectables.size())
		quit(1)
		return
	if coins.size() != 1 or coins[0] != coin:
		push_error("FAIL: expected one registered coin")
		quit(1)
		return
	coin.queue_free()
	chip.queue_free()
	await process_frame
	collectables = registry.call("get_collectables")
	if not collectables.is_empty():
		push_error("FAIL: collectables were not unregistered")
		quit(1)
		return
	print("PASS: CollectableRegistry registration, coin query, and cleanup")
	quit(0)
