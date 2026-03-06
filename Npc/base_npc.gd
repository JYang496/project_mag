extends CharacterBody2D
class_name BaseNPC

@onready var sprite_body = $Body
@onready var hurt_box = $HurtBox
@onready var hit_label = preload("res://UI/labels/hit_label.tscn")

# Export
@export var movement_speed = 20.0
@export var hp = 10
@export var knockback_recover = 3.5
var damage_taken_multiplier: float = 1.0

var knockback = {
	"amount": 0,
	"angle": Vector2.ZERO
}

@onready var status_timer: Timer = $StatusTimer
var status_effects: Array[StatusEffect] = []
var overlapping : bool = false
var is_dead: bool = false


func damaged(attack:Attack):
	
	# Hit label
	var hit_label_ins = hit_label.instantiate()
	hit_label_ins.global_position = global_position
	var effective_damage := attack.damage
	if effective_damage > 0:
		effective_damage = int(round(effective_damage * damage_taken_multiplier))
		effective_damage = max(1, effective_damage)
	hit_label_ins.setNumber(effective_damage)
	get_tree().root.call_deferred("add_child",hit_label_ins)
	
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
		death()	

func death():
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
