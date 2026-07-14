extends RefCounted
class_name NpcDamageFeedbackController

const HIT_LABEL_SCENE := preload("res://UI/labels/hit_label.tscn")
const ENEMY_HP_BAR_SCENE := preload("res://UI/scenes/components/enemy_hp_bar.tscn")
const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")

var npc
var _pending_hit_label_damage: int = 0
var _hit_label_batch_id: int = 0
var _pending_hit_label_damage_by_type: Dictionary = {}
var _enemy_hp_bar: EnemyHpBar
var _hit_flash_tween: Tween
var _hit_flash_overlay: Sprite2D
var _warning_flash_tween: Tween
var _warning_flash_overlay: Sprite2D

func setup(source_npc) -> void:
	npc = source_npc

func queue_hit_label_damage(damage_value: int, damage_type: StringName) -> void:
	if damage_value <= 0 or npc == null:
		return
	sync_enemy_hp_bar()
	show_enemy_hp_bar_on_damage()
	var normalized_type := Attack.normalize_damage_type(damage_type)
	_pending_hit_label_damage += damage_value
	_pending_hit_label_damage_by_type[normalized_type] = int(_pending_hit_label_damage_by_type.get(normalized_type, 0)) + damage_value
	if npc.is_dead:
		flush_pending_hit_label()
		return
	_hit_label_batch_id += 1
	_flush_hit_label_after_delay(_hit_label_batch_id)

func _flush_hit_label_after_delay(batch_id: int) -> void:
	var tree: SceneTree = npc.get_tree()
	if tree == null:
		return
	await tree.create_timer(maxf(npc.hit_label_merge_window_sec, 0.0)).timeout
	if npc == null or not npc.is_inside_tree() or batch_id != _hit_label_batch_id:
		return
	flush_pending_hit_label()

func flush_pending_hit_label() -> void:
	if _pending_hit_label_damage <= 0 or npc == null:
		return
	var tree: SceneTree = npc.get_tree()
	if tree == null or tree.root == null:
		return
	var hit_label_ins = HIT_LABEL_SCENE.instantiate()
	var ui_parent := _get_hit_label_parent(tree)
	var label_color := _resolve_hit_label_color()
	var target_id: int = int(npc.get_instance_id())
	for item in tree.get_nodes_in_group(&"active_hit_labels"):
		if is_instance_valid(item) and item.has_method("get_target_instance_id") and int(item.call("get_target_instance_id")) == target_id:
			item.call("merge_damage", _pending_hit_label_damage, label_color)
			_pending_hit_label_damage = 0
			_pending_hit_label_damage_by_type.clear()
			return
	var label_position: Vector2 = npc.global_position
	label_position = ProjectedUi.project_to_screen(tree, npc.global_position, label_position)
	hit_label_ins.position = label_position
	hit_label_ins.set_target_instance_id(target_id)
	hit_label_ins.setNumber(_pending_hit_label_damage)
	hit_label_ins.setColor(label_color)
	_pending_hit_label_damage = 0
	_pending_hit_label_damage_by_type.clear()
	ui_parent.call_deferred("add_child", hit_label_ins)

func _get_hit_label_parent(tree: SceneTree) -> Node:
	return ProjectedUi.ensure_layer(tree)

func _resolve_hit_label_color() -> Color:
	if _pending_hit_label_damage <= 0:
		return Color.WHITE
	var dominant_type: StringName = Attack.TYPE_PHYSICAL
	var dominant_damage: int = 0
	for type_key in _pending_hit_label_damage_by_type.keys():
		var type_damage := int(_pending_hit_label_damage_by_type[type_key])
		if type_damage > dominant_damage:
			dominant_damage = type_damage
			dominant_type = Attack.normalize_damage_type(type_key)
	if float(dominant_damage) <= float(_pending_hit_label_damage) * 0.5:
		return Color(0.65, 0.65, 0.65, 1.0)
	match dominant_type:
		Attack.TYPE_ENERGY:
			return Color(0.72, 0.45, 1.0, 1.0)
		Attack.TYPE_FIRE:
			return Color(1.0, 0.3, 0.25, 1.0)
		Attack.TYPE_FREEZE:
			return Color(0.35, 0.95, 1.0, 1.0)
		_:
			return Color.WHITE

func play_hit_flash() -> void:
	if npc == null or not npc.hit_flash_enabled:
		return
	var sprite_body := npc.sprite_body as Sprite2D
	if sprite_body == null or not is_instance_valid(sprite_body):
		return
	var overlay := _ensure_flash_overlay(sprite_body, "HitFlashOverlay", _hit_flash_overlay)
	if overlay == null:
		return
	_hit_flash_overlay = overlay
	if _hit_flash_tween != null and is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
	var flash_in := maxf(npc.hit_flash_in_duration_sec, 0.0)
	var flash_out := maxf(npc.hit_flash_out_duration_sec, 0.0)
	var peak_alpha := clampf(npc.hit_flash_peak_alpha, 0.0, 1.0)
	_sync_flash_overlay(overlay, sprite_body)
	overlay.visible = true
	overlay.modulate = Color(npc.hit_flash_peak_color.r, npc.hit_flash_peak_color.g, npc.hit_flash_peak_color.b, 0.0)
	_hit_flash_tween = npc.create_tween()
	if flash_in > 0.0:
		_hit_flash_tween.tween_property(overlay, "modulate:a", peak_alpha, flash_in)
	else:
		overlay.modulate.a = peak_alpha
	if flash_out > 0.0:
		_hit_flash_tween.tween_property(overlay, "modulate:a", 0.0, flash_out)
	else:
		overlay.modulate.a = 0.0
	_hit_flash_tween.finished.connect(func() -> void:
		if overlay != null and is_instance_valid(overlay):
			overlay.visible = false
		_hit_flash_tween = null
	)

func start_warning_flash(color: Color = Color(1.0, 0.05, 0.03, 1.0), peak_alpha: float = 0.9, pulse_duration_sec: float = 0.12) -> void:
	if npc == null:
		return
	var sprite_body := npc.sprite_body as Sprite2D
	if sprite_body == null or not is_instance_valid(sprite_body):
		return
	var overlay := _ensure_flash_overlay(sprite_body, "WarningFlashOverlay", _warning_flash_overlay)
	if overlay == null:
		return
	_warning_flash_overlay = overlay
	if _warning_flash_tween != null and is_instance_valid(_warning_flash_tween):
		_warning_flash_tween.kill()
	var safe_duration := maxf(pulse_duration_sec, 0.03)
	_sync_flash_overlay(overlay, sprite_body)
	overlay.visible = true
	overlay.modulate = Color(color.r, color.g, color.b, 0.0)
	_warning_flash_tween = npc.create_tween()
	_warning_flash_tween.set_loops()
	_warning_flash_tween.tween_property(overlay, "modulate:a", clampf(peak_alpha, 0.0, 1.0), safe_duration)
	_warning_flash_tween.tween_property(overlay, "modulate:a", 0.0, safe_duration)

func stop_warning_flash() -> void:
	if _warning_flash_tween != null and is_instance_valid(_warning_flash_tween):
		_warning_flash_tween.kill()
	_warning_flash_tween = null
	if _warning_flash_overlay != null and is_instance_valid(_warning_flash_overlay):
		_warning_flash_overlay.visible = false
		_warning_flash_overlay.modulate.a = 0.0

func _ensure_flash_overlay(sprite_body: Sprite2D, overlay_name: String, existing_overlay: Sprite2D) -> Sprite2D:
	if existing_overlay != null and is_instance_valid(existing_overlay):
		return existing_overlay
	var overlay := Sprite2D.new()
	overlay.name = overlay_name
	overlay.centered = sprite_body.centered
	overlay.offset = sprite_body.offset
	overlay.texture_filter = sprite_body.texture_filter
	overlay.z_index = 1
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	overlay.material = add_mat
	overlay.visible = false
	overlay.modulate = Color(npc.hit_flash_peak_color.r, npc.hit_flash_peak_color.g, npc.hit_flash_peak_color.b, 0.0)
	sprite_body.add_child(overlay)
	return overlay

func _sync_flash_overlay(overlay: Sprite2D, sprite_body: Sprite2D) -> void:
	overlay.texture = sprite_body.texture
	overlay.position = Vector2.ZERO
	overlay.scale = Vector2.ONE
	overlay.rotation = 0.0
	overlay.flip_h = sprite_body.flip_h
	overlay.flip_v = sprite_body.flip_v
	overlay.offset = sprite_body.offset
	overlay.centered = sprite_body.centered

func sync_enemy_hp_bar() -> void:
	var hp_bar := _ensure_enemy_hp_bar()
	if hp_bar == null:
		return
	hp_bar.set_vertical_offset(npc.hp_bar_vertical_offset)
	hp_bar.set_max_hp(max(1, npc.get_incoming_damage_max_hp()))
	hp_bar.set_hp(max(0, int(npc.hp)))

func show_enemy_hp_bar_on_damage() -> void:
	var hp_bar := _ensure_enemy_hp_bar()
	if hp_bar == null:
		return
	if npc.is_dead:
		hp_bar.hide_immediately()
		return
	hp_bar.show_for(npc.hp_bar_show_duration_sec)

func hide_enemy_hp_bar() -> void:
	if _enemy_hp_bar != null and is_instance_valid(_enemy_hp_bar):
		_enemy_hp_bar.hide_immediately()

func _ensure_enemy_hp_bar() -> EnemyHpBar:
	if npc == null or not npc.is_in_group("enemies"):
		return null
	if _enemy_hp_bar != null and is_instance_valid(_enemy_hp_bar):
		return _enemy_hp_bar
	var instance := ENEMY_HP_BAR_SCENE.instantiate() as EnemyHpBar
	if instance == null:
		return null
	instance.offset_y = npc.hp_bar_vertical_offset
	npc.add_child(instance)
	_enemy_hp_bar = instance
	_enemy_hp_bar.hide_immediately()
	return _enemy_hp_bar
