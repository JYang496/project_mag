extends Node2D
class_name ContractMortarStrike

const WARNING_SCENE := preload("res://Npc/enemy/scenes/target_warning.tscn")
const DESCENT_VFX_SCENE := preload("res://Npc/enemy/scenes/mortar_shell_descent_vfx.tscn")
const AREA_EFFECT_SCENE := preload("res://Combat/area_effect/area_effect.tscn")
const IMPACT_VISUAL_FRAMES := preload("res://asset/images/effects/mortar_impact/mortar_impact_frames.tres")

var warning_duration_sec := 1.5
var blast_radius := 62.0
var damage := 1
var _remaining := 1.5
var _warning: Node2D
var _descent: Node2D

func _ready() -> void:
	_remaining = maxf(warning_duration_sec, 0.1)
	_warning = WARNING_SCENE.instantiate() as Node2D
	if _warning != null:
		_warning.set("duration", _remaining)
		_warning.set("radius", blast_radius)
		_warning.set("show_countdown", false)
		add_child(_warning)
	_descent = DESCENT_VFX_SCENE.instantiate() as Node2D
	if _descent != null:
		add_child(_descent)

func _process(delta: float) -> void:
	_remaining -= delta
	if _descent != null and is_instance_valid(_descent) and _descent.has_method("set_descent_progress"):
		_descent.call("set_descent_progress", 1.0 - clampf(_remaining / maxf(warning_duration_sec, 0.1), 0.0, 1.0))
	if _remaining > 0.0:
		return
	_impact()
	queue_free()

func _impact() -> void:
	var area := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	if area == null or get_parent() == null:
		return
	area.global_position = global_position
	area.duration = 0.22
	area.radius = maxf(blast_radius, 8.0)
	area.target_group = AreaEffect.TargetGroup.ALLIES
	area.one_shot_damage = maxi(damage, 1)
	area.tick_damage = 0
	area.visual_enabled = true
	area.use_animated_visual = true
	area.visual_frames = IMPACT_VISUAL_FRAMES
	area.visual_animation = &"impact"
	area.visual_duration = 0.25
	area.draw_enabled = false
	area.apply_once_per_target = true
	area.source_node = self
	get_parent().add_child(area)

