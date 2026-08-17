extends Node2D
class_name WeaponModuleContainer

func get_modules() -> Array[Module]:
	var result: Array[Module] = []
	for child in get_children():
		if child is Module:
			result.append(child as Module)
	return result
