extends Augment

var RANGE_PER_LEVEL = 0.2

func _ready() -> void:
	PlayerData.player_augment_list.append(self)
	emit_signal("update_aug_status")


func _on_update_aug_status() -> void:
	PlayerData.grab_radius_mutifactor = 1 + (level * RANGE_PER_LEVEL)

func remove_augment() -> void:
	if PlayerData.player_augment_list.has(self):
		PlayerData.player_augment_list.erase(self)
	PlayerData.grab_radius_mutifactor = 1
	queue_free()
