extends Node2D
class_name TestEnemy

var status_payloads: Array[Dictionary] = []
var status_effects: Array = []
var received_attacks: Array[int] = []

func damaged(attack: Attack) -> void:
	received_attacks.append(int(attack.damage))

func apply_status_payload(status_id: StringName, payload: Dictionary) -> void:
	status_payloads.append({
		"id": status_id,
		"payload": payload.duplicate(true),
	})

func apply_status_effect(effect: Variant) -> void:
	status_effects.append(effect)
