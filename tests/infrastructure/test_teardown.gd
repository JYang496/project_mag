extends RefCounted

## Performs the common shutdown sequence for scene-backed and headless tests.
## Domain-specific state should be reset by `reset_callback`. Objects created
## outside the test scene tree must be supplied through `detached_objects`.
static func finish(
	root: Node,
	exit_code: int,
	reset_callback: Callable = Callable(),
	detached_objects: Array = []
) -> void:
	if root == null or not is_instance_valid(root):
		return
	var tree := root.get_tree()
	if tree == null:
		return

	BattleContractManager.unbind_combat_port()
	GlobalVariables.reset_runtime_state()
	ObjectPool.clear()
	_stop_transient_activity(root, tree)

	for object_value: Variant in detached_objects:
		_free_detached_object(object_value)

	for child: Node in root.get_children():
		child.queue_free()

	# Free scene nodes before resetting their domain state so _exit_tree hooks can
	# still inspect the runtime registries they were registered with.
	await tree.process_frame
	_free_orphan_nodes(root)
	if reset_callback.is_valid():
		reset_callback.call()
	ObjectPool.clear()
	GlobalVariables.clear_resource_cache()
	# Let deferred callbacks, killed tweens, and audio playback objects complete
	# their engine-side release before process shutdown. AudioServer release runs
	# on wall-clock time, so frame waits alone are nondeterministic in headless CI.
	await tree.create_timer(0.1).timeout
	for frame_index in range(4):
		await tree.process_frame
	# Quit is deferred once more so callers can unwind coroutine locals and clear
	# member refs before ObjectDB performs its final audit.
	tree.call_deferred("quit", exit_code)


static func _free_detached_object(object_value: Variant) -> void:
	if object_value == null or not is_instance_valid(object_value):
		return
	if not object_value is Node:
		return
	var node := object_value as Node
	if node.get_parent() != null:
		return
	node.free()


static func _free_orphan_nodes(root: Node) -> void:
	for instance_id: int in Node.get_orphan_node_ids():
		var object_value := instance_from_id(instance_id)
		if object_value == null or not is_instance_valid(object_value):
			continue
		if not object_value is Node or object_value == root:
			continue
		var node := object_value as Node
		if node.is_inside_tree() or node.get_parent() != null:
			continue
		node.free()


static func _stop_transient_activity(root: Node, tree: SceneTree) -> void:
	for tween: Tween in tree.get_processed_tweens():
		if tween != null and tween.is_valid():
			_disconnect_signal_connections(tween.finished)
			tween.kill()
	_stop_audio_recursive(tree.root)


static func _stop_audio_recursive(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.set("stream", null)
		if node != node.get_tree().root:
			node.queue_free()
	for child: Node in node.get_children(true):
		_stop_audio_recursive(child)


static func _disconnect_signal_connections(source_signal: Signal) -> void:
	for connection: Dictionary in source_signal.get_connections():
		var callback := connection.get("callable", Callable()) as Callable
		if source_signal.is_connected(callback):
			source_signal.disconnect(callback)
