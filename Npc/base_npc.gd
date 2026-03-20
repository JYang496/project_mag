extends CharacterBody2D
class_name BaseNPC

@onready var sprite_body = $Body
@onready var hurt_box = $HurtBox
@onready var hit_label = preload("res://UI/labels/hit_label.tscn")

# Export
@export var movement_speed = 20.0
@export var hp = 10
@export var knockback_recover = 3.5
@export var hit_label_merge_window_sec: float = 0.03
var damage_taken_multiplier: float = 1.0

var knockback = {
	"amount": 0,
	"angle": Vector2.ZERO
}

@onready var status_timer: Timer = $StatusTimer
var status_effects: Array[StatusEffect] = []
var overlapping : bool = false
var is_dead: bool = false
var _pending_hit_label_damage: int = 0
var _hit_label_batch_id: int = 0
var _pending_hit_label_damage_by_type: Dictionary = {}

var _quest_lock_active := false
var _quest_lock_speed := 0.0
var _quest_lock_damage_mul := 1.0
var _quest_freeze_movement := false
@onready var _base_movement_speed: float = movement_speed
var _quest_outline_enabled := false
var _quest_outline_original_material: Material
var _quest_outline_material: ShaderMaterial

const QUEST_OUTLINE_SHADER: Shader = preload("res://Shaders/quest_outline.gdshader") as Shader


func damaged(attack:Attack):
	var effective_damage := attack.damage
	if effective_damage > 0:
		effective_damage = int(round(effective_damage * damage_taken_multiplier))
		effective_damage = max(1, effective_damage)
	_queue_hit_label_damage(
		effective_damage,
		Attack.normalize_damage_type(attack.damage_type)
	)
	
	# Status
	if status_timer.is_stopped():
		status_timer.start()
	
	# Knock back
	knockback.amount = attack.knock_back.amount
	knockback.angle = attack.knock_back.angle
	
	if is_dead:
		return  # Prevents further damage processing if already dead
	hp -= effective_damage
	if hp <= 0 and not is_dead:
		is_dead = true
		_flush_pending_hit_label()
		death(attack)	


func _queue_hit_label_damage(damage_value: int, damage_type: StringName) -> void:
	if damage_value <= 0:
		return
	var normalized_type := Attack.normalize_damage_type(damage_type)
	_pending_hit_label_damage += damage_value
	var current_type_damage: int = int(_pending_hit_label_damage_by_type.get(normalized_type, 0))
	_pending_hit_label_damage_by_type[normalized_type] = current_type_damage + damage_value
	_hit_label_batch_id += 1
	var queued_batch_id := _hit_label_batch_id
	_schedule_hit_label_flush(queued_batch_id)


func _schedule_hit_label_flush(batch_id: int) -> void:
	_flush_hit_label_after_delay(batch_id)


func _flush_hit_label_after_delay(batch_id: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(maxf(hit_label_merge_window_sec, 0.0)).timeout
	if not is_inside_tree():
		return
	if batch_id != _hit_label_batch_id:
		return
	_flush_pending_hit_label()


func _flush_pending_hit_label() -> void:
	if _pending_hit_label_damage <= 0:
		return
	var combined_damage := _pending_hit_label_damage
	var label_color := _resolve_hit_label_color()
	_pending_hit_label_damage = 0
	var hit_label_ins = hit_label.instantiate()
	hit_label_ins.global_position = global_position
	hit_label_ins.setNumber(combined_damage)
	hit_label_ins.setColor(label_color)
	get_tree().root.call_deferred("add_child", hit_label_ins)
	_pending_hit_label_damage_by_type.clear()

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
		return Color(0.65, 0.65, 0.65, 1.0) # Gray (chaos)
	match dominant_type:
		Attack.TYPE_ENERGY:
			return Color(0.72, 0.45, 1.0, 1.0) # Purple
		Attack.TYPE_FIRE:
			return Color(1.0, 0.3, 0.25, 1.0) # Red
		Attack.TYPE_FREEZE:
			return Color(0.35, 0.95, 1.0, 1.0) # Cyan
		_:
			return Color.WHITE

func death(_killing_attack: Attack = null):
		queue_free()

func _on_status_timer_timeout() -> void:
	if status_effects.is_empty():
		status_timer.stop()
		return
	for i in range(status_effects.size() - 1, -1, -1):
		var effect := status_effects[i]
		if effect == null:
			status_effects.remove_at(i)
			continue
		effect.apply_tick(self)
		if effect.step():
			status_effects.remove_at(i)


func apply_status_effect(effect: StatusEffect) -> void:
	if effect == null:
		return
	for existing in status_effects:
		if existing.effect_id == effect.effect_id:
			existing.merge_from(effect)
			if status_timer.is_stopped():
				status_timer.start()
			return
	status_effects.append(effect)
	if status_timer.is_stopped():
		status_timer.start()


func apply_status_payload(status_name: StringName, status_data: Variant) -> void:
	match status_name:
		&"erosion":
			apply_status_effect(ErosionStatusEffect.from_payload(status_data))

func set_quest_lock(active: bool, damage_mul: float = 0.5, freeze_movement: bool = true) -> void:
	if active:
		if _quest_lock_active:
			return
		_quest_lock_active = true
		_quest_lock_speed = movement_speed if movement_speed > 0.0 else _base_movement_speed
		_quest_lock_damage_mul = damage_taken_multiplier
		_quest_freeze_movement = freeze_movement
		damage_taken_multiplier = minf(damage_taken_multiplier, maxf(damage_mul, 0.05))
		return
	if not _quest_lock_active:
		return
	_quest_lock_active = false
	_quest_freeze_movement = false
	damage_taken_multiplier = _quest_lock_damage_mul

func is_quest_movement_locked() -> bool:
	return _quest_lock_active and _quest_freeze_movement

func set_outline_highlight(enabled: bool, color: Color = Color.WHITE, width: float = 1.0) -> void:
	if sprite_body == null:
		return
	if enabled:
		if not _quest_outline_enabled:
			_quest_outline_original_material = sprite_body.material
			_quest_outline_material = _build_quest_outline_material(color, width)
			_quest_outline_enabled = true
		if _quest_outline_material:
			_quest_outline_material.set_shader_parameter("outline_color", color)
			_quest_outline_material.set_shader_parameter("outline_width", width)
			sprite_body.material = _quest_outline_material
		return
	if not _quest_outline_enabled:
		return
	_quest_outline_enabled = false
	sprite_body.material = _quest_outline_original_material

func _build_quest_outline_material(color: Color, width: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = QUEST_OUTLINE_SHADER
	material.set_shader_parameter("outline_color", color)
	material.set_shader_parameter("outline_width", width)
	return material
