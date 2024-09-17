extends Control

var example_dict = {}

func _ready():
	pass
	
func import_csv_data(path:String):
	if path == null or path == "":
		printerr("Error: path cannot be null or empty")
	var file = FileAccess.open(path, FileAccess.READ)

	while !file.eof_reached():
		var data_set = Array(file.get_csv_line())
		if data_set[0] == "": # Quit when id does not exist
			break
		example_dict[example_dict.size()] = data_set
	file.close()
	print (example_dict)
