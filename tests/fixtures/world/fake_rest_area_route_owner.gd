extends Node

const RestAreaRouteFlow = preload("res://World/rest_area_route_flow.gd")

var route_flow: RefCounted
var reset_button_calls := 0

func _ready() -> void:
	route_flow = RestAreaRouteFlow.new()
	route_flow.setup(self)

func _get_rest_area_board():
	return null

func _clear_zone4_hold_move_boost() -> void:
	pass

func _reset_zone4_hold() -> void:
	pass

func _reset_start_battle_button() -> void:
	reset_button_calls += 1

func _continue_start_battle() -> void:
	route_flow.continue_start_battle()

func _discard_unassigned_task_modules_and_continue_start_battle() -> void:
	route_flow.discard_unassigned_task_modules_and_continue_start_battle()

func _on_battle_start_cancelled() -> void:
	route_flow.on_battle_start_cancelled()

