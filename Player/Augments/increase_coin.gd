extends Augment

var probability = 0.5
var increased_coin = 1
var COIN_PER_LEVEL = 1


func _ready() -> void:
	PlayerData.player_augment_list.append(self)
	update_aug_status.emit()


func _on_update_aug_status() -> void:
	if not PlayerData.player.is_connected("coin_collected",Callable(self,"increase_random_coin")):
		PlayerData.player.connect("coin_collected",Callable(self,"increase_random_coin"))
	increased_coin = level * COIN_PER_LEVEL

func increase_random_coin() -> void:
	if randf() < probability:
		PlayerData.player_gold += increased_coin

func remove_augment() -> void:
	if PlayerData.player.is_connected("coin_collected",Callable(self,"increase_random_coin")):
		PlayerData.player.disconnect("coin_collected",Callable(self,"increase_random_coin"))
	queue_free()
