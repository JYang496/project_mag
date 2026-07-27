extends CanvasLayer
class_name GameOverView

@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var total_damage_label: Label = %TotalDamageLabel
@onready var total_damage_value: Label = %TotalDamageValue
@onready var completed_levels_label: Label = %CompletedLevelsLabel
@onready var completed_levels_value: Label = %CompletedLevelsValue
@onready var enemy_kills_label: Label = %EnemyKillsLabel
@onready var enemy_kills_value: Label = %EnemyKillsValue
@onready var elite_kills_label: Label = %EliteKillsLabel
@onready var elite_kills_value: Label = %EliteKillsValue
@onready var gold_earned_label: Label = %GoldEarnedLabel
@onready var gold_earned_value: Label = %GoldEarnedValue
@onready var new_game_button: Button = %NewGameButton

var owner_ui: Node


func bind(owner: Node) -> void:
	owner_ui = owner
	var pressed_callable := Callable(owner, "_on_game_over_new_game_pressed")
	if not new_game_button.pressed.is_connected(pressed_callable):
		new_game_button.pressed.connect(pressed_callable)
	refresh_static_texts()


func show_game_over() -> void:
	total_damage_value.text = _format_integer(PlayerData.run_total_damage_dealt)
	completed_levels_value.text = _format_integer(PlayerData.run_completed_levels)
	enemy_kills_value.text = _format_integer(PlayerData.run_enemy_kills)
	elite_kills_value.text = _format_integer(PlayerData.run_elite_kills)
	gold_earned_value.text = _format_integer(PlayerData.run_gold_earned)
	visible = true
	_play_reveal()
	new_game_button.grab_focus.call_deferred()


func refresh_static_texts() -> void:
	if title_label and is_instance_valid(title_label):
		title_label.text = LocalizationManager.tr_key("ui.gameover.title", "Mission Failed")
	if subtitle_label and is_instance_valid(subtitle_label):
		subtitle_label.text = LocalizationManager.tr_key("ui.gameover.subtitle", "Run Summary")
	_set_label_text(total_damage_label, "ui.gameover.stat.total_damage", "Total Damage")
	_set_label_text(completed_levels_label, "ui.gameover.stat.completed_levels", "Completed Levels")
	_set_label_text(enemy_kills_label, "ui.gameover.stat.enemy_kills", "Enemy Kills")
	_set_label_text(elite_kills_label, "ui.gameover.stat.elite_kills", "Elite Kills")
	_set_label_text(gold_earned_label, "ui.gameover.stat.gold_earned", "Gold Earned")
	if new_game_button and is_instance_valid(new_game_button):
		new_game_button.text = LocalizationManager.tr_key(
			"ui.gameover.return_to_menu",
			"Return to Main Menu"
		)


func debug_get_stat_texts() -> PackedStringArray:
	return PackedStringArray([
		"%s: %s" % [total_damage_label.text, total_damage_value.text],
		"%s: %s" % [completed_levels_label.text, completed_levels_value.text],
		"%s: %s" % [enemy_kills_label.text, enemy_kills_value.text],
		"%s: %s" % [elite_kills_label.text, elite_kills_value.text],
		"%s: %s" % [gold_earned_label.text, gold_earned_value.text],
	])


func _set_label_text(label: Label, key: String, fallback: String) -> void:
	if label and is_instance_valid(label):
		label.text = LocalizationManager.tr_key(key, fallback)


func _format_integer(value: int) -> String:
	var source := str(maxi(value, 0))
	var formatted := ""
	while source.length() > 3:
		formatted = "," + source.right(3) + formatted
		source = source.left(source.length() - 3)
	return source + formatted


func _play_reveal() -> void:
	var root := $GameOverRoot as Control
	root.modulate.a = 0.0
	game_over_panel.scale = Vector2(0.97, 0.97)
	game_over_panel.pivot_offset = game_over_panel.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.18)
	tween.tween_property(game_over_panel, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
