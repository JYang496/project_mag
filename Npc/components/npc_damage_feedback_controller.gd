extends RefCounted
class_name NpcDamageFeedbackController

const HIT_LABEL_SCENE := preload("res://UI/labels/hit_label.tscn")
const ENEMY_HP_BAR_SCENE := preload("res://UI/scenes/components/enemy_hp_bar.tscn")
const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")
const DamageFeedbackEventType := preload("res://Combat/damage/damage_feedback_event.gd")
const CombatHitVfxProfileType := preload("res://Combat/Vfx/combat_hit_vfx_profile.gd")
const CombatHitVfxServiceType := preload("res://Combat/Vfx/combat_hit_vfx_service.gd")

var npc
var _pending_hit_label_batches: Dictionary = {}
var _scheduled_hit_label_batches: Dictionary = {}
var _enemy_hp_bar: EnemyHpBar
var _hit_flash_tween: Tween
var _hit_flash_overlay: Sprite2D
var _warning_flash_tween: Tween
var _warning_flash_overlay: Sprite2D

func setup(source_npc) -> void:
	npc = source_npc

func queue_hit_label_damage(
	damage_value: int,
	damage_type: StringName,
	attack_batch_id: int = 0,
	is_critical: bool = false,
	is_periodic: bool = false,
	is_killing_blow: bool = false
) -> void:
	var event = DamageFeedbackEventType.new(damage_value, damage_type)
	event.feedback_batch_id = attack_batch_id
	event.is_critical = is_critical
	event.is_periodic = is_periodic
	event.is_killing_blow = is_killing_blow
	queue_hit_label_event(event)

func queue_hit_label_event(event) -> void:
	if event == null or event.final_damage <= 0 or npc == null:
		return
	sync_enemy_hp_bar()
	show_enemy_hp_bar_on_damage()
	# Presentation batches are target-local: fast direct hits share one short
	# window while periodic ticks use a slower lane. Gameplay attack batch ids
	# remain on the event for diagnostics and do not control visual spam.
	var batch_id: StringName = &"periodic" if event.is_periodic else &"direct"
	var batch = _pending_hit_label_batches.get(batch_id)
	if batch == null:
		batch = event.duplicate_event()
	else:
		batch.merge(event)
	_pending_hit_label_batches[batch_id] = batch
	if npc.is_dead:
		flush_pending_hit_label()
		return
	if not _scheduled_hit_label_batches.has(batch_id):
		_scheduled_hit_label_batches[batch_id] = true
		_flush_hit_label_after_delay(batch_id, _merge_window_for(event.is_periodic))

func _merge_window_for(is_periodic: bool) -> float:
	if is_periodic and npc.get("hit_label_periodic_merge_window_sec") != null:
		return maxf(float(npc.hit_label_periodic_merge_window_sec), 0.0)
	return maxf(float(npc.hit_label_merge_window_sec), 0.0)

func _flush_hit_label_after_delay(batch_id: StringName, delay_sec: float) -> void:
	var tree: SceneTree = npc.get_tree()
	if tree == null:
		return
	await tree.create_timer(delay_sec).timeout
	if npc == null or not npc.is_inside_tree():
		return
	_flush_hit_label_batch(batch_id)

func flush_pending_hit_label() -> void:
	if npc == null:
		return
	for batch_id in _pending_hit_label_batches.keys().duplicate():
		_flush_hit_label_batch(StringName(batch_id))

func _flush_hit_label_batch(batch_id: StringName) -> void:
	_scheduled_hit_label_batches.erase(batch_id)
	if not _pending_hit_label_batches.has(batch_id) or npc == null:
		return
	var batch = _pending_hit_label_batches[batch_id]
	_pending_hit_label_batches.erase(batch_id)
	if batch == null or batch.final_damage <= 0:
		return
	var tree: SceneTree = npc.get_tree()
	if tree == null or tree.root == null:
		return
	var hit_label_ins = HIT_LABEL_SCENE.instantiate()
	var ui_parent := _get_hit_label_parent(tree)
	var target_id: int = int(npc.get_instance_id())
	var label_position: Vector2 = npc.global_position
	label_position = ProjectedUi.project_to_screen(tree, npc.global_position, label_position)
	hit_label_ins.position = label_position
	hit_label_ins.set_target_instance_id(target_id)
	batch.target_instance_id = target_id
	batch.target_max_hp = max(1, npc.get_incoming_damage_max_hp())
	hit_label_ins.configure(batch)
	ui_parent.call_deferred("add_child", hit_label_ins)

func _get_hit_label_parent(tree: SceneTree) -> Node:
	return ProjectedUi.ensure_layer(tree)

func _color_for_damage_type(damage_type: StringName) -> Color:
	match damage_type:
		&"mixed":
			return Color(0.82, 0.86, 0.88, 1.0)
		Attack.TYPE_ENERGY:
			return Color(0.72, 0.45, 1.0, 1.0)
		Attack.TYPE_FIRE:
			return Color(1.0, 0.3, 0.25, 1.0)
		Attack.TYPE_FREEZE:
			return Color(0.35, 0.95, 1.0, 1.0)
		_:
			return Color.WHITE

func play_hit_flash() -> void:
	_play_hit_flash_with_style(Color.WHITE, -1.0)

func play_hit_feedback(result: DamageResult, attack: Attack = null) -> void:
	if npc == null or result == null:
		return
	var profile := CombatHitVfxProfileType.from_damage_result(result, npc.get_incoming_damage_max_hp())
	var flash_duration := 0.07 if profile.hit_type == CombatHitVfxProfileType.HitType.KINETIC_LIGHT else 0.10
	_play_hit_flash_with_style(profile.impact_color, flash_duration)
	var tree := npc.get_tree() as SceneTree
	var service := CombatHitVfxServiceType.ensure(tree)
	if service != null:
		service.call("play", npc.global_position, profile, _resolve_hit_direction(attack))

func _resolve_hit_direction(attack: Attack) -> Vector2:
	if attack != null and attack.source_node is Node2D and is_instance_valid(attack.source_node):
		var source_position := (attack.source_node as Node2D).global_position
		var source_to_target: Vector2 = npc.global_position - source_position
		if source_to_target.length_squared() > 0.0001:
			return source_to_target.normalized()
	if attack != null:
		var knockback_direction: Variant = attack.knock_back.get("angle", Vector2.ZERO)
		if knockback_direction is Vector2 and knockback_direction.length_squared() > 0.0001:
			return (knockback_direction as Vector2).normalized()
	return Vector2.RIGHT

func _play_hit_flash_with_style(flash_color: Color, duration_override: float) -> void:
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
	var flash_out := maxf(duration_override if duration_override >= 0.0 else npc.hit_flash_out_duration_sec, 0.0)
	var peak_alpha := clampf(npc.hit_flash_peak_alpha, 0.0, 1.0)
	_sync_flash_overlay(overlay, sprite_body)
	overlay.visible = true
	overlay.modulate = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	_hit_flash_tween = npc.create_tween()
	if flash_in > 0.0:
		_hit_flash_tween.tween_property(overlay, "modulate:a", peak_alpha, flash_in)
	else:
		overlay.modulate.a = peak_alpha
	if flash_out > 0.0:
		_hit_flash_tween.tween_property(overlay, "modulate:a", 0.0, flash_out)
	else:
		overlay.modulate.a = 0.0
	# Connect directly to the overlay so the Tween does not retain this
	# RefCounted controller through a closure during scene shutdown.
	_hit_flash_tween.finished.connect(Callable(overlay, "hide"), CONNECT_ONE_SHOT)

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

func shutdown() -> void:
	if _hit_flash_tween != null and is_instance_valid(_hit_flash_tween):
		_disconnect_tween_finished(_hit_flash_tween)
		_hit_flash_tween.kill()
	if _warning_flash_tween != null and is_instance_valid(_warning_flash_tween):
		_disconnect_tween_finished(_warning_flash_tween)
		_warning_flash_tween.kill()
	_hit_flash_tween = null
	_warning_flash_tween = null
	_hit_flash_overlay = null
	_warning_flash_overlay = null
	_enemy_hp_bar = null
	_pending_hit_label_batches.clear()
	_scheduled_hit_label_batches.clear()
	npc = null

func _disconnect_tween_finished(tween: Tween) -> void:
	for connection: Dictionary in tween.finished.get_connections():
		var callback := connection.get("callable", Callable()) as Callable
		if tween.finished.is_connected(callback):
			tween.finished.disconnect(callback)

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
