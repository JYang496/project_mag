extends RefCounted
class_name WeaponSwitchController

var _tween: Tween

func build_fixed_order(list_size: int, slot_count: int) -> Array[int]:
	var order: Array[int] = []
	order.resize(slot_count)
	order.fill(-1)
	if list_size <= 0:
		return order
	for slot_index in range(mini(list_size, slot_count)):
		order[slot_index] = slot_index
	return order

func build_slot_rects(
	slot_count: int,
	main_index: int,
	offhand_size: Vector2,
	mainhand_size: Vector2,
	gap: float
) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var next_x := 0.0
	for slot_index in range(slot_count):
		var slot_size := mainhand_size if slot_index == main_index else offhand_size
		rects.append(Rect2(Vector2(next_x, 0.0), slot_size))
		next_x += slot_size.x + gap
	return rects

func play(
	owner: Control,
	slots: Array[Control],
	target_rects: Array[Rect2],
	duration: float,
	transition: Tween.TransitionType,
	ease: Tween.EaseType,
	finished: Callable
) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = owner.create_tween()
	_tween.set_trans(transition)
	_tween.set_ease(ease)
	_tween.set_parallel(true)
	for slot_index in range(slots.size()):
		var slot := slots[slot_index]
		if slot_index >= target_rects.size():
			continue
		var target_rect := target_rects[slot_index]
		slot.modulate.a = 0.72
		_tween.tween_property(slot, "position", target_rect.position, duration)
		_tween.tween_property(slot, "size", target_rect.size, duration)
		_tween.tween_property(slot, "modulate:a", 1.0, duration)
	_tween.finished.connect(func() -> void:
		for slot_index in range(slots.size()):
			var slot := slots[slot_index]
			if slot_index < target_rects.size():
				slot.position = target_rects[slot_index].position
				slot.size = target_rects[slot_index].size
			slot.modulate = Color.WHITE
		finished.call()
	)

func stop() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
