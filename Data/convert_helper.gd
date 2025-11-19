extends Node

func _ready():
	var json = JSON.parse_string(FileAccess.get_file_as_string("res://Data/weapons.json"))
	for id in json.keys():
		var data = json[id]
		var def = WeaponDefinition.new()
		def.weapon_id = id
		def.display_name = data.name
		def.icon = load(data.img)
		def.price = int(data.price)
		def.description = data.description
		def.scene = load(data.res)
		ResourceSaver.save(def, "res://Data/weapons/%s.tres" % data.name)
