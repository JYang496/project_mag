extends Augment
class_name Ricochet

var ricochet_times : int = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not PlayerData.player_augment_list.has(self):
		PlayerData.player_augment_list.append(self)
	emit_signal("update_aug_status")

func _on_update_aug_status() -> void:
	for weapon in PlayerData.player_weapon_list:
		weapon.features.append("ricochet")

func remove_augment() -> void:
	if PlayerData.player_augment_list.has(self):
		PlayerData.player_augment_list.erase(self)
	queue_free()
