extends Node2D
class_name BossVisualRuntime

signal attack_confirmed

const WARNING_COLOR := Color(1.0, 0.18, 0.12, 0.92)
const PHASE_COLORS := [Color(1.0, 0.38, 0.12, 0.86), Color(0.80, 0.28, 1.0, 0.88), Color(1.0, 0.12, 0.28, 0.94)]

var boss: BaseEnemy
var phase_index := 0
var phase_count := 1
var telegraph_active := false
var telegraph_elapsed := 0.0
var telegraph_duration := 0.9
var damage_confirmed := false
var _hp_bar: ProgressBar
var _hp_label: Label
var _environment_overlay: ColorRect
var _environment_tween: Tween


func setup(source: BaseEnemy) -> void:
	boss = source


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hybrid_enemy_aura_source")
	_create_boss_hud()
	_play_boss_entrance()
	call_deferred("_register_ground_visual")


func _process(delta: float) -> void:
	_sync_hud()
	if not telegraph_active:
		return
	telegraph_elapsed += maxf(delta, 0.0)
	if not damage_confirmed and telegraph_elapsed >= telegraph_duration * 0.78:
		damage_confirmed = true
		attack_confirmed.emit()
	if telegraph_elapsed >= telegraph_duration:
		telegraph_active = false
	queue_redraw()


func begin_attack_telegraph(duration_sec: float = 0.9) -> void:
	telegraph_active = true
	telegraph_elapsed = 0.0
	telegraph_duration = clampf(duration_sec, 0.7, 1.2)
	damage_confirmed = false


func set_phase(next_phase: int, total_phases: int) -> void:
	phase_count = maxi(total_phases, 1)
	phase_index = clampi(next_phase, 0, phase_count - 1)
	if boss != null and boss.sprite_body != null:
		boss.sprite_body.modulate = Color.WHITE.lerp(_phase_color().lightened(0.18), 0.16)
	_play_environment_transition()


func is_damage_confirmed() -> bool:
	return telegraph_active and damage_confirmed


func get_hybrid_aura_visual() -> Dictionary:
	var radius := 72.0
	if boss != null and boss.has_method("_resolve_hurtbox_or_visible_sprite_extent"):
		var extent := boss.call("_resolve_hurtbox_or_visible_sprite_extent") as Vector2
		radius = clampf(maxf(extent.x, extent.y) * 0.78, 56.0, 120.0)
	var color := WARNING_COLOR if telegraph_active else _phase_color()
	var progress := clampf(telegraph_elapsed / maxf(telegraph_duration, 0.01), 0.0, 1.0)
	if telegraph_active and damage_confirmed:
		color = Color.WHITE.lerp(WARNING_COLOR, 0.35)
	return {
		"visible": boss != null and is_instance_valid(boss),
		"radius": radius * (1.0 + progress * 0.08 if telegraph_active else 1.0),
		"line_width": 5.0 if telegraph_active else 3.0,
		"line_color": color,
		"fill_color": Color(color.r, color.g, color.b, 0.10 if telegraph_active else 0.035),
		"detail_color": Color(color.r, color.g, color.b, color.a * 0.55),
		"detail_width": 1.5,
		"relationship_kind": &"boss_attack_confirm" if damage_confirmed else (&"boss_attack_warning" if telegraph_active else &"boss_footprint"),
	}


func _phase_color() -> Color:
	return PHASE_COLORS[mini(phase_index, PHASE_COLORS.size() - 1)]


func _create_boss_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BossHudLayer"
	layer.layer = 80
	add_child(layer)
	_environment_overlay = ColorRect.new()
	_environment_overlay.name = "BossEnvironmentOverlay"
	_environment_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_environment_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_environment_overlay.color = Color(0.06, 0.02, 0.10, 0.0)
	layer.add_child(_environment_overlay)
	var panel := PanelContainer.new()
	panel.name = "BossHpHud"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-260.0, 22.0)
	panel.size = Vector2(520.0, 54.0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.text = "BOSS"
	box.add_child(_hp_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(500.0, 18.0)
	_hp_bar.show_percentage = false
	box.add_child(_hp_bar)


func _play_environment_transition() -> void:
	if _environment_overlay == null:
		return
	if _environment_tween != null and _environment_tween.is_valid():
		_environment_tween.kill()
	_environment_overlay.color = Color(0.06, 0.02, 0.10, 0.14)
	_environment_tween = create_tween()
	_environment_tween.tween_property(_environment_overlay, "color:a", 0.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_boss_entrance() -> void:
	set_meta(&"boss_entrance_visual_active", true)
	_play_environment_transition()
	var player := PlayerData.player as Node
	if player != null and is_instance_valid(player) and player.has_method("request_camera_shake") and boss != null:
		player.call("request_camera_shake", 0.12, boss.global_position, 1100.0)


func _sync_hud() -> void:
	if boss == null or not is_instance_valid(boss) or _hp_bar == null:
		return
	var max_hp := maxi(maxi(int(boss.get("_incoming_damage_max_hp")), int(boss.hp)), 1)
	_hp_bar.max_value = max_hp
	_hp_bar.value = maxi(int(boss.hp), 0)
	_hp_label.text = "BOSS  ·  PHASE %d/%d" % [phase_index + 1, phase_count]


func _register_ground_visual() -> void:
	HybridGroundRegistration.register(self, &"register_enemy_support_visual")


func _exit_tree() -> void:
	if _environment_tween != null and _environment_tween.is_valid():
		_environment_tween.kill()
	HybridGroundRegistration.unregister(self)
