extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")

var _failed := false
var _view: GameOverView
var _ui: UI
var _original_locale := ""
var _original_stats := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_snapshot_runtime_state()
	LocalizationManager.set_locale("zh_CN")
	PlayerData.run_total_damage_dealt = 1234567
	PlayerData.run_completed_levels = 4
	PlayerData.run_enemy_kills = 85
	PlayerData.run_elite_kills = 2
	PlayerData.run_gold_earned = 32

	_ui = UI_SCENE.instantiate() as UI
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_ui.battle_hud.visible, "进入结算前战斗 HUD 应可见。")

	_ui._show_game_over()
	await get_tree().process_frame
	_view = _ui.game_over_view as GameOverView

	_expect(_view.visible, "结算视图应在 show_game_over 后显示。")
	_expect(get_tree().paused, "进入结算后应暂停战斗树。")
	_expect(not _ui.battle_hud.visible, "进入结算后应隐藏战斗 HUD。")
	_expect(not _ui.right_hud_stack.visible, "进入结算后应隐藏右侧运行时 HUD。")
	_expect(not _ui.left_contract_hud_stack.visible, "进入结算后应隐藏契约 HUD。")
	_expect(_view.get_node("GameOverRoot").mouse_filter == Control.MOUSE_FILTER_STOP,
		"结算根节点必须阻止输入穿透。")
	_expect(_view.total_damage_value.text == "1,234,567", "大数值应使用千位分隔符。")
	_expect(_view.enemy_kills_value.text == "85", "敌人击杀数未正确呈现。")
	_expect(_view.new_game_button.has_focus(), "结算显示后应默认聚焦主操作按钮。")
	_expect(not _view.endless_button.visible, "失败结算不应显示超载模式入口。")

	get_tree().paused = false
	_view.visible = false
	_ui._show_run_complete()
	await get_tree().process_frame
	_expect(_view.visible and _view.endless_button.visible, "通关结算必须显示可选超载模式入口。")
	_expect(_view.title_label.text == LocalizationManager.tr_key("ui.run_complete.title", "MISSION COMPLETE"), "通关结算必须使用任务完成语义。")

	print("FAIL game-over flow" if _failed else "PASS game-over flow")
	await TEST_TEARDOWN.finish(
		self,
		1 if _failed else 0,
		_restore_runtime_state,
		[_ui]
	)
	_view = null
	_ui = null


func _snapshot_runtime_state() -> void:
	_original_locale = LocalizationManager.get_locale()
	_original_stats = {
		"damage": PlayerData.run_total_damage_dealt,
		"levels": PlayerData.run_completed_levels,
		"enemies": PlayerData.run_enemy_kills,
		"elites": PlayerData.run_elite_kills,
		"gold": PlayerData.run_gold_earned,
	}


func _restore_runtime_state() -> void:
	get_tree().paused = false
	LocalizationManager.set_locale(_original_locale)
	PlayerData.run_total_damage_dealt = int(_original_stats.get("damage", 0))
	PlayerData.run_completed_levels = int(_original_stats.get("levels", 0))
	PlayerData.run_enemy_kills = int(_original_stats.get("enemies", 0))
	PlayerData.run_elite_kills = int(_original_stats.get("elites", 0))
	PlayerData.run_gold_earned = int(_original_stats.get("gold", 0))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
