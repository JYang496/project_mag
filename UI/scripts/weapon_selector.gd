extends Control
class_name WeaponSelector

@export var debug_mode := true

const SLOT_COUNT := 4
const SWITCH_ANIM_TIME := 0.35
const SWITCH_ANIM_TRANS := Tween.TRANS_SINE
const SWITCH_ANIM_EASE := Tween.EASE_OUT
# Perimeter cycle to keep motion on square edges (avoid hourglass crossing).
const SLOT_CYCLE: Array[int] = [0, 3, 1, 2]

@onready var _slot_nodes: Array[Control] = [$Slot0, $Slot1, $Slot2, $Slot3]

var slot_nodes: Array[Control] = []
var logical_order: Array[int] = []

var _slot_base_positions: Array[Vector2] = []
var _queued_step := 0
var _is_animating := false
var _needs_full_refresh := false
var _switch_tween: Tween

var _empty_weapon_pic: Texture2D = preload("res://Textures/test/empty_wp.png")
var _mainhand_slot_bg: Texture2D = preload("res://asset/images/ui/mainhand.png")
var _offhand_slot_bg: Texture2D = preload("res://asset/images/ui/offhand.png")

func _ready() -> void:
	slot_nodes = _slot_nodes.duplicate()
	_slot_base_positions.clear()
	for slot_node in _slot_nodes:
		_slot_base_positions.append(slot_node.position)
	_ensure_debug_labels()
	refresh_slots()
	_debug_log_state("ready")

func set_layout_origin(origin: Vector2) -> void:
	position = origin

func bind_player_data() -> void:
	if not PlayerData.is_connected("weapon_list_changed", Callable(self, "_on_weapon_list_changed")):
		PlayerData.weapon_list_changed.connect(Callable(self, "_on_weapon_list_changed"))
	if not PlayerData.is_connected("main_weapon_index_changed", Callable(self, "_on_main_weapon_index_changed")):
		PlayerData.main_weapon_index_changed.connect(Callable(self, "_on_main_weapon_index_changed"))

func refresh_slots() -> void:
	if _is_animating:
		_needs_full_refresh = true
		return
	var valid_weapons := _sanitize_weapon_list()
	var list_size := valid_weapons.size()
	var main_idx := PlayerData.main_weapon_index
	if list_size <= 0:
		main_idx = -1
	else:
		main_idx = clampi(main_idx, 0, list_size - 1)
	logical_order = _build_logical_order(list_size, main_idx)
	_apply_visuals_from_logical_order(valid_weapons)
	_update_debug_labels()
	_debug_log_state("refresh_slots")

func animate_main_switch(step: int) -> void:
	var sign_step := signi(step)
	if sign_step == 0:
		refresh_slots()
		return
	if _is_animating:
		if _queued_step == 0:
			_queued_step = sign_step
			_debug_log_state("queued_step_%d" % sign_step)
		return
	if _slot_nodes.size() != SLOT_COUNT or _slot_base_positions.size() != SLOT_COUNT:
		refresh_slots()
		return

	_sanitize_weapon_list()
	var occupied_slots := _get_occupied_slots_in_cycle()
	if occupied_slots.size() < 2:
		refresh_slots()
		return
	_rotate_logical_order(sign_step)
	_set_all_slot_backgrounds_offhand()
	_update_debug_labels()
	_debug_log_state("pre_anim_slot_bg_update_step_%d" % sign_step)

	_is_animating = true
	if _switch_tween and is_instance_valid(_switch_tween):
		_switch_tween.kill()
	_switch_tween = create_tween()
	_switch_tween.set_trans(SWITCH_ANIM_TRANS)
	_switch_tween.set_ease(SWITCH_ANIM_EASE)
	_switch_tween.set_parallel(true)

	for slot_idx in occupied_slots:
		var target_idx := _get_occupied_target_slot(slot_idx, sign_step, occupied_slots)
		var target_pos := _slot_base_positions[target_idx]
		_switch_tween.tween_property(_slot_nodes[slot_idx], "position", target_pos, SWITCH_ANIM_TIME)

	_switch_tween.finished.connect(Callable(self, "_on_switch_anim_finished").bind(sign_step))
	_debug_log_state("animate_start_step_%d" % sign_step)

func _on_weapon_list_changed() -> void:
	if _is_animating:
		_needs_full_refresh = true
		return
	refresh_slots()

func _on_main_weapon_index_changed(old_index: int, new_index: int, step: int) -> void:
	if old_index == new_index:
		return
	_debug_log_state("signal_main_changed_%d_to_%d_step_%d" % [old_index, new_index, step])
	var sign_step := signi(step)
	if sign_step == 0:
		refresh_slots()
		return
	if _is_animating:
		if _queued_step == 0:
			_queued_step = sign_step
		return
	animate_main_switch(sign_step)

func _on_switch_anim_finished(step: int) -> void:
	_rotate_slot_nodes(step)
	_restore_slot_positions()
	_is_animating = false
	_update_debug_labels()
	_debug_log_state("animate_finished_step_%d" % step)

	if _needs_full_refresh:
		_needs_full_refresh = false
		_queued_step = 0
		refresh_slots()
		return

	if _queued_step != 0:
		var pending_step := _queued_step
		_queued_step = 0
		animate_main_switch(pending_step)
		return

	refresh_slots()

func _sanitize_weapon_list() -> Array:
	var valid_weapons: Array = []
	for weapon in PlayerData.player_weapon_list:
		if is_instance_valid(weapon):
			valid_weapons.append(weapon)
	PlayerData.player_weapon_list = valid_weapons
	return valid_weapons

func _build_logical_order(list_size: int, main_idx: int) -> Array[int]:
	var order: Array[int] = [-1, -1, -1, -1]
	if list_size <= 0 or main_idx < 0:
		return order
	for cycle_offset in range(SLOT_COUNT):
		var slot_index := SLOT_CYCLE[cycle_offset]
		if cycle_offset < list_size:
			order[slot_index] = (main_idx + cycle_offset) % list_size
		else:
			order[slot_index] = -1
	return order

func _apply_visuals_from_logical_order(weapons: Array) -> void:
	_apply_slot_backgrounds_from_logical_order()
	_apply_weapon_icons_from_logical_order(weapons)

func _apply_slot_backgrounds_from_logical_order() -> void:
	var current_main_index := PlayerData.main_weapon_index
	for slot_idx in range(SLOT_COUNT):
		var background := _get_slot_background(_slot_nodes[slot_idx])
		var weapon_idx := logical_order[slot_idx]
		if background != null:
			background.texture = _mainhand_slot_bg if weapon_idx >= 0 and weapon_idx == current_main_index else _offhand_slot_bg

func _set_all_slot_backgrounds_offhand() -> void:
	for slot_idx in range(SLOT_COUNT):
		var background := _get_slot_background(_slot_nodes[slot_idx])
		if background != null:
			background.texture = _offhand_slot_bg

func _apply_weapon_icons_from_logical_order(weapons: Array) -> void:
	for slot_idx in range(SLOT_COUNT):
		var icon := _get_slot_icon(_slot_nodes[slot_idx])
		var weapon_idx := logical_order[slot_idx]
		if icon == null:
			continue
		if weapon_idx < 0 or weapon_idx >= weapons.size():
			icon.texture = null
			icon.visible = false
			continue
		var weapon: Variant = weapons[weapon_idx]
		icon.visible = true
		icon.texture = _get_weapon_texture(weapon)

func _get_weapon_texture(weapon: Variant) -> Texture2D:
	if is_instance_valid(weapon) and weapon.has_node("Sprite"):
		var sprite_node: Node = weapon.get_node_or_null("Sprite")
		if sprite_node != null:
			var sprite_texture: Variant = sprite_node.get("texture")
			if sprite_texture is Texture2D:
				return sprite_texture as Texture2D
	return _empty_weapon_pic

func _target_slot_index_for_step(slot_index: int, step: int) -> int:
	var cycle_index := SLOT_CYCLE.find(slot_index)
	if cycle_index < 0:
		return slot_index
	var next_cycle_index := posmod(cycle_index - signi(step), SLOT_COUNT)
	return SLOT_CYCLE[next_cycle_index]

func _rotate_slot_nodes(step: int) -> void:
	var occupied_slots := _get_occupied_slots_in_cycle()
	if occupied_slots.size() < 2:
		return
	var next_slots: Array[Control] = _slot_nodes.duplicate()
	for slot_idx in occupied_slots:
		var target_idx := _get_occupied_target_slot(slot_idx, step, occupied_slots)
		next_slots[target_idx] = _slot_nodes[slot_idx]
	_slot_nodes = next_slots

func _rotate_logical_order(step: int) -> void:
	if logical_order.size() != SLOT_COUNT:
		return
	var occupied_slots := _get_occupied_slots_in_cycle()
	if occupied_slots.size() < 2:
		return
	var old_order: Array[int] = logical_order.duplicate()
	for i in range(occupied_slots.size()):
		var slot_idx := occupied_slots[i]
		var source_slot := occupied_slots[posmod(i + signi(step), occupied_slots.size())]
		logical_order[slot_idx] = old_order[source_slot]

func _restore_slot_positions() -> void:
	for i in range(SLOT_COUNT):
		_slot_nodes[i].position = _slot_base_positions[i]

func _get_slot_icon(slot_node: Control) -> TextureRect:
	if slot_node == null:
		return null
	return slot_node.get_node_or_null("Icon") as TextureRect

func _get_slot_background(slot_node: Control) -> TextureRect:
	if slot_node == null:
		return null
	return slot_node.get_node_or_null("Background") as TextureRect

func _get_occupied_slots_in_cycle() -> Array[int]:
	var occupied_slots: Array[int] = []
	for slot_idx in SLOT_CYCLE:
		if slot_idx < logical_order.size() and logical_order[slot_idx] >= 0:
			occupied_slots.append(slot_idx)
	return occupied_slots

func _get_occupied_target_slot(slot_idx: int, step: int, occupied_slots: Array[int]) -> int:
	var idx := occupied_slots.find(slot_idx)
	if idx < 0 or occupied_slots.is_empty():
		return slot_idx
	var target_idx := posmod(idx - signi(step), occupied_slots.size())
	return occupied_slots[target_idx]

func _ensure_debug_labels() -> void:
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		if slot_node == null:
			continue
		var label := slot_node.get_node_or_null("DebugIndex") as Label
		if label == null:
			label = Label.new()
			label.name = "DebugIndex"
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_preset(Control.PRESET_CENTER)
			label.position = Vector2(-20.0, -10.0)
			label.size = Vector2(40.0, 20.0)
			slot_node.add_child(label)
		label.visible = debug_mode

func _update_debug_labels() -> void:
	for slot_idx in range(SLOT_COUNT):
		var slot_node := _slot_nodes[slot_idx]
		if slot_node == null:
			continue
		var label := slot_node.get_node_or_null("DebugIndex") as Label
		if label == null:
			continue
		label.visible = debug_mode
		if not debug_mode:
			continue
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		label.text = str(weapon_idx) if weapon_idx >= 0 else "-"
		label.modulate = Color(1.0, 0.95, 0.2) if weapon_idx == PlayerData.main_weapon_index else Color(0.9, 0.9, 0.9)

func _debug_log_state(tag: String) -> void:
	if not debug_mode:
		return
	var weapons_desc: Array[String] = []
	for i in range(PlayerData.player_weapon_list.size()):
		var weapon: Variant = PlayerData.player_weapon_list[i]
		var item_name := "null"
		if is_instance_valid(weapon):
			var name_variant: Variant = weapon.get("ITEM_NAME")
			item_name = str(name_variant) if name_variant != null else str(weapon.name)
		weapons_desc.append("%d:%s" % [i, item_name])

	var slot_desc: Array[String] = []
	for slot_idx in range(SLOT_COUNT):
		var node_idx := _slot_nodes.find(_slot_nodes[slot_idx])
		var weapon_idx := -1
		if slot_idx < logical_order.size():
			weapon_idx = logical_order[slot_idx]
		var pos: Vector2 = _slot_nodes[slot_idx].position
		slot_desc.append("slot%d(node=%d,w=%d,pos=%.1f,%.1f)" % [slot_idx, node_idx, weapon_idx, pos.x, pos.y])

	print("[WeaponSelector][%s] main=%d queued=%d anim=%s weapons=[%s] logical=%s slots=[%s]" % [
		tag,
		PlayerData.main_weapon_index,
		_queued_step,
		str(_is_animating),
		", ".join(weapons_desc),
		str(logical_order),
		", ".join(slot_desc)
	])
