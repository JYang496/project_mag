extends Player
class_name HeavyAssault

func custom_ready() -> void:
	create_weapon("21")
	create_weapon("1", 1, true)
	#create_weapon("9", 1, true)
