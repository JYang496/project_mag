extends StatusEffect
class_name ErosionStatusEffect

var damage: int = 1


func setup_effect(tick_value: int, damage_value: int) -> ErosionStatusEffect:
	setup(&"erosion", tick_value)
	damage = max(1, damage_value)
	return self


func merge_from(other: StatusEffect) -> void:
	if other == null or not (other is ErosionStatusEffect):
		return
	var typed_other := other as ErosionStatusEffect
	ticks_left = max(ticks_left, typed_other.ticks_left)
	damage = max(damage, typed_other.damage)
	if self.source_player == null and typed_other.source_player != null:
		self.source_player = typed_other.source_player
	if self.source_node == null and typed_other.source_node != null:
		self.source_node = typed_other.source_node


func apply_tick(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("damaged"):
		return
	var attack := Attack.new()
	attack.damage = damage
	attack.source_player = self.source_player
	attack.source_node = self.source_node
	target.damaged(attack)


static func from_payload(data: Variant) -> ErosionStatusEffect:
	var tick_value := 0
	var damage_value := 1
	if data is Dictionary:
		tick_value = int((data as Dictionary).get("tick", 0))
		damage_value = int((data as Dictionary).get("damage", 1))
	return ErosionStatusEffect.new().setup_effect(tick_value, damage_value)
