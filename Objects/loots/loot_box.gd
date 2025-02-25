extends Node2D

@onready var coin_preload = preload("res://Objects/loots/coin.tscn")
@onready var item_preload = preload("res://Objects/loots/drop_item.tscn")
@onready var drop_preload = preload("res://Objects/loots/drop.tscn")
@onready var disapear_timer: Timer = $DisapearTimer

@export var coin_value:int = 0
var number_of_coins := 5
var remainder := 0

func _ready() -> void:
	number_of_coins = 5 + coin_value/10
	remainder = coin_value % number_of_coins
	animation()

# Animation, loot box rolls and falls, opens
func animation() -> void:
	var tween = create_tween()
	var rotate_tween = create_tween()
	tween.tween_property(self,"position",position + Vector2(0,-20),0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position",position + Vector2(0,20),0.5).set_ease(Tween.EASE_IN)
	rotate_tween.tween_property(self,"rotation_degrees", 1800, 1).set_ease(Tween.EASE_IN_OUT)
	tween.connect("finished",_on_tween_finished)

func drops() -> void:
	var item_drop = drop_preload.instantiate()
	item_drop.drop = item_preload
	item_drop.global_position = self.global_position
	self.call_deferred("add_sibling",item_drop)
	for i in range(number_of_coins):
		var bonus := 0
		if remainder >= 0 and remainder <= 10:
			bonus = remainder
			remainder = 0
		else:
			bonus = remainder / 2
			remainder = remainder % 2 + remainder / 2
		var drop = drop_preload.instantiate()
		drop.drop = coin_preload
		drop.value = coin_value / number_of_coins + bonus
		drop.global_position = self.global_position
		self.call_deferred("add_sibling",drop)

func _on_tween_finished() -> void:
	drops()
	disapear_timer.start()

func _on_disapear_timer_timeout() -> void:
	self.queue_free()
