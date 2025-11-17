extends Augment

var RANGE_PER_LEVEL = 0.2
var increased_range = 0

func _ready() -> void:
	PlayerData.player_augment_list.append(self)
	update_aug_status.emit()


func _on_update_aug_status() -> void:
	increased_range = level  * RANGE_PER_LEVEL
	PlayerData.grab_radius_mutifactor = 1 + increased_range

func remove_augment() -> void:
	if PlayerData.player_augment_list.has(self):
		PlayerData.player_augment_list.erase(self)
	PlayerData.grab_radius_mutifactor = 1
	queue_free()
