extends Module
class_name OnHitModule

func get_subscribed_weapon_events() -> Array[StringName]:
	var events := super.get_subscribed_weapon_events()
	if not events.has(WeaponEvent.HIT_CONFIRMED):
		events.append(WeaponEvent.HIT_CONFIRMED)
	if has_method("on_damage_dealt") and not events.has(WeaponEvent.DAMAGE_DEALT):
		events.append(WeaponEvent.DAMAGE_DEALT)
	return events
