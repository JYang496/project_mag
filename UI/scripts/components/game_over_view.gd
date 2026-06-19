extends Control
class_name GameOverView

@onready var game_over_panel: Panel = $GameOverPanel
@onready var title_label: Label = $GameOverPanel/Title
@onready var total_damage_label: Label = $GameOverPanel/TotalDamage
@onready var completed_levels_label: Label = $GameOverPanel/CompletedLevels
@onready var enemy_kills_label: Label = $GameOverPanel/EnemyKills
@onready var elite_kills_label: Label = $GameOverPanel/EliteKills
@onready var gold_earned_label: Label = $GameOverPanel/GoldEarned
@onready var new_game_button: Button = $GameOverPanel/NewGameButton

var owner_ui: Node

func bind(owner: Node) -> void:
	owner_ui = owner
	var pressed_callable := Callable(owner, "_on_game_over_new_game_pressed")
	if not new_game_button.pressed.is_connected(pressed_callable):
		new_game_button.pressed.connect(pressed_callable)
	refresh_static_texts()

func show_game_over() -> void:
	total_damage_label.text = LocalizationManager.tr_format(
		"ui.gameover.total_damage",
		{"value": PlayerData.run_total_damage_dealt},
		"Total Damage: %s" % str(PlayerData.run_total_damage_dealt)
	)
	completed_levels_label.text = LocalizationManager.tr_format(
		"ui.gameover.completed_levels",
		{"value": PlayerData.run_completed_levels},
		"Completed Levels: %s" % str(PlayerData.run_completed_levels)
	)
	enemy_kills_label.text = LocalizationManager.tr_format(
		"ui.gameover.enemy_kills",
		{"value": PlayerData.run_enemy_kills},
		"Enemy Kills: %s" % str(PlayerData.run_enemy_kills)
	)
	elite_kills_label.text = LocalizationManager.tr_format(
		"ui.gameover.elite_kills",
		{"value": PlayerData.run_elite_kills},
		"Elite Kills: %s" % str(PlayerData.run_elite_kills)
	)
	gold_earned_label.text = LocalizationManager.tr_format(
		"ui.gameover.gold_earned",
		{"value": PlayerData.run_gold_earned},
		"Gold Earned: %s" % str(PlayerData.run_gold_earned)
	)
	visible = true

func refresh_static_texts() -> void:
	if title_label and is_instance_valid(title_label):
		title_label.text = LocalizationManager.tr_key("ui.gameover.title", "Game Over")
	if new_game_button and is_instance_valid(new_game_button):
		new_game_button.text = LocalizationManager.tr_key("ui.gameover.new_game", "New Game")

func debug_get_stat_texts() -> PackedStringArray:
	return PackedStringArray([
		total_damage_label.text,
		completed_levels_label.text,
		enemy_kills_label.text,
		elite_kills_label.text,
		gold_earned_label.text,
	])
