extends StatusEffect
class_name DamageTakenMultiplierStatusEffect

const EFFECT_ID_PREFIX := "damage_taken_multiplier:"

var status_id: StringName = StringName()
var multiplier: float = 1.0
var expires_at_msec: int = 0


func setup_multiplier(id_value: StringName, multiplier_value: float, duration_sec: float) -> DamageTakenMultiplierStatusEffect:
	status_id = id_value
	effect_id = StringName("%s%s" % [EFFECT_ID_PREFIX, str(status_id)])
	multiplier = maxf(multiplier_value, 0.0)
	expires_at_msec = Time.get_ticks_msec() + int(maxf(duration_sec, 0.1) * 1000.0)
	ticks_left = 1
	return self


func merge_from(other: StatusEffect) -> void:
	if other == null or not (other is DamageTakenMultiplierStatusEffect):
		return
	var typed_other := other as DamageTakenMultiplierStatusEffect
	multiplier = maxf(multiplier, typed_other.multiplier)
	expires_at_msec = maxi(expires_at_msec, typed_other.expires_at_msec)
	if self.source_player == null and typed_other.source_player != null:
		self.source_player = typed_other.source_player
	if self.source_node == null and typed_other.source_node != null:
		self.source_node = typed_other.source_node


func is_active() -> bool:
	return expires_at_msec > Time.get_ticks_msec()


func step() -> bool:
	return not is_active()
