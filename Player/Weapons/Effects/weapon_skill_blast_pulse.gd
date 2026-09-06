extends Node2D
class_name WeaponSkillBlastPulse

const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")

var source_weapon: Weapon
var damage_ratio := 1.0
var radius := 100.0
var damage_type: StringName = Attack.TYPE_PHYSICAL
var _elapsed := 0.0
var _duration := 0.28
var fill_color := Color(1.0, 0.30, 0.08, 0.18)
var line_color := Color(1.0, 0.62, 0.18, 0.95)
var show_countdown := false

func setup(weapon: Weapon, ratio: float, radius_value: float, type: StringName) -> WeaponSkillBlastPulse:
	source_weapon = weapon
	damage_ratio = maxf(ratio, 0.0)
	radius = maxf(radius_value, 8.0)
	damage_type = Attack.normalize_damage_type(type)
	return self

func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	HYBRID_GROUND_REGISTRATION.register(self, &"register_warning_circle")
	_apply_damage()
	queue_redraw()

func _exit_tree() -> void:
	HYBRID_GROUND_REGISTRATION.unregister(self)

func get_warning_progress() -> float:
	var progress := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	return lerpf(0.25, 1.0, progress)

func get_warning_countdown_text() -> String:
	return ""

func cleanup_for_battle_end() -> void:
	queue_free()

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()

func _apply_damage() -> void:
	if source_weapon == null or not is_instance_valid(source_weapon):
		return
	var amount: int = maxi(1, int(round(float(source_weapon.get_runtime_damage()) * damage_ratio)))
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), global_position, radius):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.global_position.distance_to(global_position) > radius:
			continue
		var data := DamageManager.build_damage_data(
			source_weapon, amount, damage_type,
			{"amount": 120.0, "angle": global_position.direction_to(enemy.global_position)},
			DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.AREA
		)
		DamageManager.apply_to_target(enemy, data)

func _draw() -> void:
	if bool(get_meta(&"hybrid_ground_registered", false)):
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var draw_radius := lerpf(radius * 0.25, radius, progress)
	var color := Color(1.0, 0.48, 0.15, (1.0 - progress) * 0.85)
	draw_circle(Vector2.ZERO, draw_radius, Color(color, color.a * 0.18))
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 48, color, 4.0)
