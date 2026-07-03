extends Node

func _ready() -> void:
	var ok := _run()
	get_tree().quit(0 if ok else 1)

func _run() -> bool:
	var scene := load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene
	if scene == null:
		push_error("MachineGunSpreadProbe: failed to load machine_gun.tscn")
		return false
	var weapon := scene.instantiate()
	if weapon == null:
		push_error("MachineGunSpreadProbe: failed to instantiate machine gun")
		return false
	add_child(weapon)
	weapon.global_position = Vector2.ZERO
	if not bool(weapon.get("spread_enabled")):
		push_error("MachineGunSpreadProbe: spread_enabled is false.")
		return false
	var close_preview: Dictionary = weapon.call("get_spread_preview_info_for_target", Vector2(120.0, 0.0))
	if float(close_preview.get("miss_chance", 1.0)) != 0.0 or float(close_preview.get("max_radius", 1.0)) != 0.0:
		push_error("MachineGunSpreadProbe: close range no-spread zone is not active.")
		return false
	var far_preview: Dictionary = weapon.call("get_spread_preview_info_for_target", Vector2(900.0, 0.0))
	if float(far_preview.get("max_radius", 0.0)) <= 0.0:
		push_error("MachineGunSpreadProbe: spread radius is not active.")
		return false
	print("MachineGunSpreadProbe: close miss=%.2f radius=%.2f | far miss=%.2f radius=%.2f" % [
		float(close_preview.get("miss_chance", 0.0)),
		float(close_preview.get("max_radius", 0.0)),
		float(far_preview.get("miss_chance", 0.0)),
		float(far_preview.get("max_radius", 0.0)),
	])
	return true
