extends Control

const PANEL_SCENE := preload("res://UI/scenes/battle_contract_selection_panel.tscn")
const PANEL_SCRIPT := preload("res://UI/scripts/battle_contract_selection_panel.gd")
const ELIMINATION := preload("res://data/battle_contracts/elimination.tres")
const SURVIVAL := preload("res://data/battle_contracts/survival.tres")
const REWARD := preload("res://data/battle_contracts/reward.tres")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _panel: Control


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	LocalizationManager.set_locale("zh_CN", false)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.015, 0.025, 0.035, 1.0)
	add_child(background)
	_panel = PANEL_SCENE.instantiate() as Control
	add_child(_panel)
	if "--capture-contract-selection-showcase" in OS.get_cmdline_user_args():
		await _capture_layouts()
		return
	_open_options([ELIMINATION, SURVIVAL, REWARD])
	await get_tree().process_frame
	var panel_rect := (_panel.get_node("Shade/Panel") as Control).get_global_rect()
	var cards: Array = _panel.get("cards") as Array
	var valid := panel_rect.position.x >= 23.5 and panel_rect.position.y >= 15.5
	valid = valid and panel_rect.end.x <= size.x - 23.5 and panel_rect.end.y <= size.y - 15.5
	for card: Button in cards:
		if card.visible:
			valid = valid and card.get_node("Margin/Content").get_global_rect().end.y <= card.get_global_rect().end.y + 0.5
	print("PASS: expanded contract selection showcase" if valid else "FAIL: expanded contract selection showcase")
	await TEST_TEARDOWN.finish(self, 0 if valid else 1, _reset)


func _capture_layouts() -> void:
	_open_options([ELIMINATION, SURVIVAL])
	await _save_capture("contract_selection_two_cards.png")
	var first_card := (_panel.get("cards") as Array)[0] as Button
	first_card.call("set_enhanced_offer", [
		LocalizationManager.tr_key("battle_contract.enhanced.demo.elimination.risk.1", "Enemies gain +20% movement speed"),
		LocalizationManager.tr_key("battle_contract.enhanced.demo.elimination.risk.2", "Final batch adds 1 elite"),
	], [
		LocalizationManager.tr_key("battle_contract.enhanced.demo.elimination.reward.1", "Gold +40%"),
		LocalizationManager.tr_key("battle_contract.enhanced.demo.elimination.reward.2", "Higher reward-choice quality"),
	])
	first_card.call("set_enhanced_mode", true)
	_panel.call("_on_card_enhanced_mode_changed", true, first_card)
	await _save_capture("contract_selection_enhanced_card.png")
	_panel.call("dismiss")
	_panel.queue_free()
	await get_tree().process_frame
	_panel = PANEL_SCENE.instantiate() as Control
	add_child(_panel)
	await get_tree().process_frame
	_open_options([ELIMINATION, SURVIVAL, REWARD])
	await _save_capture("contract_selection_three_cards.png")
	get_tree().quit()


func _open_options(options: Array) -> void:
	_panel.call("open", options, Callable(), Callable())
	_panel.call("_kill_transition")
	var panel_container := _panel.get_node("Shade/Panel") as PanelContainer
	var shade := _panel.get_node("Shade") as ColorRect
	panel_container.scale = Vector2.ONE
	panel_container.modulate = Color.WHITE
	shade.color.a = PANEL_SCRIPT.SHADE_OPACITY
	_panel.get_node("Shade/Panel/Margin/Content/Title").modulate.a = 1.0
	_panel.get_node("Shade/Panel/Margin/Content/Subtitle").modulate.a = 1.0
	_panel.get_node("Shade/Panel/Margin/Content/Actions").modulate.a = 1.0
	for card: Button in _panel.get("cards") as Array:
		if card.visible:
			card.modulate.a = 1.0
	_panel.call("_finish_open_transition")
	var visible_cards: Array = (_panel.get("cards") as Array).filter(func(card: Button): return card.visible)
	if not visible_cards.is_empty():
		(visible_cards[0] as Button).call("set_selected", true, false)
		_panel.call("_set_current_selection", (visible_cards[0] as Button).definition)
		(_panel.get_node("Shade/Panel/Margin/Content/Actions/Confirm") as Button).disabled = false


func _save_capture(file_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://output/showcases/ui")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join(file_name)
	var error := get_viewport().get_texture().get_image().save_png(output_path)
	if error == OK:
		print("CAPTURED: %s" % output_path)
	else:
		push_error("BattleContractSelectionExpandedShowcase: capture failed (%d)" % error)


func _reset() -> void:
	LocalizationManager.set_locale("en", false)
	_panel = null
