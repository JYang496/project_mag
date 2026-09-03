extends Control

const OPEN_DURATION := 0.34
const CARD_REVEAL_DURATION := 0.18
const CARD_REVEAL_INTERVAL := 0.07
const SHADE_OPACITY := 0.76
const STABLE_PANEL_HEIGHT := 688.0
const PREFERRED_PANEL_WIDTH := 1232.0
const PANEL_HORIZONTAL_SAFE_MARGIN := 24.0
const PANEL_VERTICAL_SAFE_MARGIN := 16.0
const CARD_SCENE := preload("res://UI/scenes/battle_contract_card.tscn")
const INPUT_PROMPT_TEXTURE_FACTORY := preload("res://UI/scripts/components/input_prompt_texture_factory.gd")
const REWARD_ENEMY_SCENE_PATH := "res://Npc/enemy/scenes/reward_enemy.tscn"
const MAX_ENEMY_PREVIEW_ENTRIES := 5
const ENEMY_PREVIEW_ICON_SIZE := Vector2(38, 38)

var _confirmed := Callable()
var _locked := false
var _transition_tween: Tween
var _detail_definition: Resource

@onready var cards: Array[Button] = [$Shade/Panel/Margin/Content/MainCards/CardLeft, $Shade/Panel/Margin/Content/MainCards/CardMiddle, $Shade/Panel/Margin/Content/MainCards/CardRight]
@onready var shade: ColorRect = $Shade
@onready var panel: PanelContainer = $Shade/Panel
@onready var confirm_button: Button = $Shade/Panel/Margin/Content/Actions/Confirm
@onready var title_label: Label = $Shade/Panel/Margin/Content/Title
@onready var subtitle: HBoxContainer = $Shade/Panel/Margin/Content/Subtitle
@onready var select_range_label: Label = $Shade/Panel/Margin/Content/Subtitle/SelectRange
@onready var current_selection_label: Label = $Shade/Panel/Margin/Content/Actions/CurrentSelection
@onready var terminal_status: Label = $Shade/Panel/Margin/Content/TerminalStatus
@onready var actions: HBoxContainer = $Shade/Panel/Margin/Content/Actions
@onready var detail_name: Label = $Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Header/Name
@onready var detail_objective: Label = $Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Details/Objective
@onready var enemy_preview: VBoxContainer = $Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Details/EnemyPreview
@onready var enemy_preview_header: Label = $Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Details/EnemyPreview/Header
@onready var enemy_preview_entries: HBoxContainer = $Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Details/EnemyPreview/Entries

func _ready() -> void:
	visible = false
	confirm_button.icon = INPUT_PROMPT_TEXTURE_FACTORY.space_prompt_texture()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	for card in cards:
		card.pressed.connect(_on_card_pressed.bind(card))
		card.enhanced_mode_changed.connect(_on_card_enhanced_mode_changed.bind(card))
	confirm_button.pressed.connect(_on_confirm_pressed)

func open(options: Array, confirmed: Callable) -> void:
	if visible or options.size() < 2 or options.size() > 3:
		return
	_confirmed = confirmed
	_locked = true
	confirm_button.disabled = true
	title_label.text = LocalizationManager.tr_key("battle_contract.ui.title", "Choose Next Protocol")
	select_range_label.text = LocalizationManager.tr_key(
		"battle_contract.ui.subtitle.select",
		"1–{count} Select ·"
	).replace("{count}", str(options.size()))
	confirm_button.text = LocalizationManager.tr_key("battle_contract.ui.confirm", "Begin Contract")
	_set_current_selection(null)
	_apply_panel_size(options.size() == 3)
	for index in cards.size():
		if index < options.size():
			cards[index].visible = true
			cards[index].call("setup", options[index])
			_configure_enhanced_offer(cards[index], options[index])
			cards[index].call("set_compact_layout", options.size() == 3)
			cards[index].call("set_quick_select_index", index + 1)
		else:
			cards[index].visible = false
	_update_detail_preview(options[0])
	_play_open_transition()

func _apply_panel_size(has_extra_contract: bool, has_enhanced_contract: bool = false) -> void:
	var resolved_size := calculate_panel_size(get_viewport_rect().size, has_extra_contract, has_enhanced_contract)
	var resolved_width := resolved_size.x
	var resolved_height := resolved_size.y
	panel.offset_left = -resolved_width * 0.5
	panel.offset_right = resolved_width * 0.5
	panel.offset_top = -resolved_height * 0.5
	panel.offset_bottom = resolved_height * 0.5

static func calculate_panel_size(viewport_size: Vector2, has_extra_contract: bool, has_enhanced_contract: bool = false) -> Vector2:
	var available_width := maxf(0.0, viewport_size.x - PANEL_HORIZONTAL_SAFE_MARGIN * 2.0)
	var available_height := maxf(0.0, viewport_size.y - PANEL_VERTICAL_SAFE_MARGIN * 2.0)
	# Protocol state changes must not resize this centered panel. A height change
	# moves every child on screen even though only one card changed its contents.
	var requested_height := STABLE_PANEL_HEIGHT
	return Vector2(
		minf(PREFERRED_PANEL_WIDTH, available_width),
		minf(requested_height, available_height)
	)

func _on_viewport_size_changed() -> void:
	_apply_panel_size(cards[2].visible, _has_active_enhanced_mode())

func dismiss() -> void:
	_kill_transition()
	visible = false
	_locked = false
	_clear_callbacks()

func detach_selected_card(target_parent: Control) -> Button:
	if target_parent == null:
		return null
	for card_index in cards.size():
		var card := cards[card_index]
		if card.definition != BattleContractManager.selected_contract:
			continue
		var screen_rect := card.get_global_rect()
		var old_parent := card.get_parent()
		var old_index := card.get_index()
		card.reparent(target_parent, false)
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.position = screen_rect.position
		card.size = screen_rect.size
		card.custom_minimum_size = screen_rect.size
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		card.disabled = true
		card.call("set_selected", false, false)
		var replacement := CARD_SCENE.instantiate() as Button
		old_parent.add_child(replacement)
		old_parent.move_child(replacement, old_index)
		replacement.pressed.connect(_on_card_pressed.bind(replacement))
		replacement.enhanced_mode_changed.connect(_on_card_enhanced_mode_changed.bind(replacement))
		cards[card_index] = replacement
		return card
	return null

func _input(event: InputEvent) -> void:
	if not visible or _locked or not _is_space_key_pressed(event):
		return
	_on_confirm_pressed()
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _locked:
		return
	if event is InputEventKey and not event.echo:
		var quick_index := _quick_select_index_for_key(event.keycode)
		if quick_index >= 0 and event.pressed:
			_select_card_by_index(quick_index)
			get_viewport().set_input_as_handled()
			return

func _is_space_key_pressed(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.pressed \
		and not key_event.echo \
		and (key_event.keycode == KEY_SPACE \
			or key_event.physical_keycode == KEY_SPACE \
			or key_event.unicode == KEY_SPACE)

func _quick_select_index_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1, KEY_KP_1: return 0
		KEY_2, KEY_KP_2: return 1
		KEY_3, KEY_KP_3: return 2
	return -1

func _select_card_by_index(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	var card := cards[index]
	if not card.visible or card.disabled:
		return
	card.grab_focus()
	_on_card_pressed(card)

func _on_card_pressed(card: Button) -> void:
	if _locked:
		return
	_update_detail_preview(card.definition)
	if not BattleContractManager.select_contract(card.definition):
		for candidate in cards:
			candidate.call("set_selected", candidate.definition == BattleContractManager.selected_contract)
		return
	for candidate in cards:
		candidate.call("set_selected", candidate == card)
		if candidate != card:
			candidate.call("set_enhanced_mode", false)
	if bool(card.call("is_enhanced_mode")):
		BattleContractManager.set_selected_contract_enhanced(true)
	_set_current_selection(card.definition)
	_refresh_confirm_action(card)
	confirm_button.disabled = false

func _update_detail_preview(definition: Resource) -> void:
	if definition == null:
		return
	_detail_definition = definition
	var id := str(definition.contract_id)
	detail_name.text = LocalizationManager.tr_key("battle_contract.ui.briefing", "Protocol Briefing")
	var structure := LocalizationManager.tr_key(
		"battle_contract.card.%s.trait" % id,
		LocalizationManager.tr_key("battle_contract.card.%s.summary" % id, "Standard encounter")
	).replace("\n", " · ")
	var briefing := "%s\n%s\n%s\n%s" % [
		LocalizationManager.tr_key("battle_contract.detail.structure", "BATTLE STRUCTURE"),
		structure,
		LocalizationManager.tr_key("battle_contract.detail.completion", "COMPLETION"),
		LocalizationManager.tr_key(definition.description_key, "Complete the contract objective."),
	]
	var card := _card_for_definition(definition)
	if card != null and bool(card.call("is_enhanced_mode")):
		briefing += "\n%s  ◆ %s\n%s  ◆ %s" % [
			LocalizationManager.tr_key("battle_contract.card.enhanced_risk", "ENHANCED RISK"),
			" · ".join(card.call("get_enhanced_risk_lines") as Array[String]),
			LocalizationManager.tr_key("battle_contract.card.enhanced_reward", "EXTRA REWARD"),
			" · ".join(card.call("get_enhanced_reward_lines") as Array[String]),
		]
	detail_objective.text = briefing
	_update_enemy_preview(id)

func _set_current_selection(definition: Resource) -> void:
	var selection_name := "—"
	if definition != null:
		var id := str(definition.contract_id)
		selection_name = LocalizationManager.tr_key(definition.name_key, id.capitalize())
		var selected_card := _card_for_definition(definition)
		if selected_card != null and bool(selected_card.call("is_enhanced_mode")):
			selection_name += LocalizationManager.tr_key("battle_contract.ui.enhanced_suffix", " · Enhanced")
	current_selection_label.text = LocalizationManager.tr_key(
		"battle_contract.ui.current_selection",
		"Current Selection: {name}"
	).replace("{name}", selection_name)

func _on_card_enhanced_mode_changed(enabled: bool, card: Button) -> void:
	if card == null:
		return
	if BattleContractManager.current_options.has(card.definition):
		if BattleContractManager.selected_contract != card.definition:
			_on_card_pressed(card)
		BattleContractManager.set_selected_contract_enhanced(enabled)
		if enabled:
			card.call("set_enhanced_offer", card.call("get_enhanced_risk_lines"), [BattleContractManager.get_selected_enhanced_reward_line()])
	_apply_panel_size(cards[2].visible, _has_active_enhanced_mode())
	if card.definition == _detail_definition:
		_update_detail_preview(card.definition)
	if card.definition == BattleContractManager.selected_contract or card.button_pressed:
		_set_current_selection(card.definition)
		_refresh_confirm_action(card)

func _refresh_confirm_action(card: Button) -> void:
	confirm_button.text = LocalizationManager.tr_key(
		"battle_contract.ui.confirm_enhanced" if card != null and bool(card.call("is_enhanced_mode")) else "battle_contract.ui.confirm",
		"Begin Enhanced Protocol" if card != null and bool(card.call("is_enhanced_mode")) else "Begin Contract"
	)

func _card_for_definition(definition: Resource) -> Button:
	for card in cards:
		if card.visible and card.definition == definition:
			return card
	return null

func is_selected_contract_enhanced() -> bool:
	var selected_card := _card_for_definition(BattleContractManager.selected_contract)
	return selected_card != null and bool(selected_card.call("is_enhanced_mode"))

func _has_active_enhanced_mode() -> bool:
	for card in cards:
		if card.visible and bool(card.call("is_enhanced_mode")):
			return true
	return false

func _configure_enhanced_offer(card: Button, definition: Resource) -> void:
	var enhanced: Resource = BattleContractManager.get_enhanced_definition(definition.contract_id)
	if enhanced == null:
		return
	var risk_lines: Array[String] = []
	for index in enhanced.risk_text_keys.size():
		var fallback: String = enhanced.risk_fallback_lines[index] if index < enhanced.risk_fallback_lines.size() else "Enhanced objective"
		risk_lines.append(LocalizationManager.tr_key(enhanced.risk_text_keys[index], fallback))
	card.call("set_enhanced_offer", risk_lines, [LocalizationManager.tr_key("battle_contract.enhanced.reward.random", "Random bonus reward")])

func _update_enemy_preview(contract_id: String) -> void:
	_clear_enemy_preview()
	var preview := build_enemy_preview_snapshot(contract_id, PhaseManager.current_level)
	var entries: Array = preview.get("entries", [])
	enemy_preview.visible = bool(preview.get("available", false))
	if not enemy_preview.visible:
		return
	if entries.is_empty():
		enemy_preview_header.text = LocalizationManager.tr_key("battle_contract.ui.enemy_preview.none", "NO ENEMIES")
		return
	enemy_preview_header.text = LocalizationManager.tr_key(
		"battle_contract.ui.enemy_preview.possible" if bool(preview.get("uncertain", true)) else "battle_contract.ui.enemy_preview.confirmed",
		"MAY APPEAR" if bool(preview.get("uncertain", true)) else "ENEMIES THIS BATTLE"
	)
	var visible_count := mini(entries.size(), MAX_ENEMY_PREVIEW_ENTRIES)
	for index in visible_count:
		enemy_preview_entries.add_child(_make_enemy_preview_entry(entries[index] as Dictionary))
	if entries.size() > visible_count:
		var overflow := Label.new()
		overflow.text = "+%d" % (entries.size() - visible_count)
		overflow.custom_minimum_size = Vector2(28, ENEMY_PREVIEW_ICON_SIZE.y)
		overflow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		overflow.add_theme_font_size_override("font_size", 13)
		overflow.add_theme_color_override("font_color", Color(0.62, 0.76, 0.79))
		enemy_preview_entries.add_child(overflow)

func _clear_enemy_preview() -> void:
	for child in enemy_preview_entries.get_children():
		enemy_preview_entries.remove_child(child)
		child.queue_free()

func _make_enemy_preview_entry(data: Dictionary) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.custom_minimum_size = Vector2(66, 0)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 1)
	var portrait := TextureRect.new()
	portrait.texture = data.get("texture") as Texture2D
	portrait.custom_minimum_size = ENEMY_PREVIEW_ICON_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(portrait)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 3)
	var name_label := Label.new()
	name_label.text = str(data.get("name", "Enemy"))
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.90))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = name_label.text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	if bool(data.get("elite", false)):
		var elite_badge := Label.new()
		elite_badge.text = LocalizationManager.tr_key("battle_contract.ui.enemy_preview.elite", "ELITE")
		elite_badge.add_theme_font_size_override("font_size", 10)
		elite_badge.add_theme_color_override("font_color", Color(1.0, 0.72, 0.24))
		elite_badge.tooltip_text = elite_badge.text
		name_row.add_child(elite_badge)
	item.add_child(name_row)
	return item

static func build_enemy_preview_snapshot(contract_id: String, level_index: int) -> Dictionary:
	if contract_id == "rest":
		return {"available": true, "uncertain": false, "entries": []}
	var scene_paths: Array[String] = []
	if contract_id == "reward":
		scene_paths.append(REWARD_ENEMY_SCENE_PATH)
	else:
		SpawnData.ensure_loaded()
		var profile := SpawnData.get_spawn_combat_profile()
		if profile != null and not profile.levels.is_empty():
			var safe_level := maxi(level_index, 0)
			var spawn_entries: Array = []
			if safe_level < profile.levels.size():
				spawn_entries.assign(profile.get_level_spawns(safe_level))
			else:
				for plan in profile.levels:
					if plan != null:
						spawn_entries.append_array(plan.spawns)
			for entry in spawn_entries:
				var path := str(entry.enemy_scene_path) if entry != null else ""
				if path != "" and path not in scene_paths:
					scene_paths.append(path)
	var resolved_entries: Array[Dictionary] = []
	for scene_path in scene_paths:
		var resolved := _resolve_enemy_preview_entry(scene_path)
		if not resolved.is_empty():
			resolved_entries.append(resolved)
	return {
		"available": not resolved_entries.is_empty(),
		"uncertain": contract_id != "reward" and scene_paths.size() > 1,
		"entries": resolved_entries,
	}

static func _resolve_enemy_preview_entry(scene_path: String) -> Dictionary:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return {}
	var instance := scene.instantiate()
	if instance == null:
		return {}
	var body := instance.get_node_or_null("Body") as Sprite2D
	var texture := body.texture if body != null else null
	var tags_variant: Variant = instance.get("spawn_tags")
	var tags: Array = tags_variant if tags_variant is Array else []
	var enemy_id := scene_path.get_file().get_basename()
	var fallback_name := enemy_id.trim_prefix("enemy_").replace("_", " ").capitalize()
	var result := {
		"id": enemy_id,
		"name": LocalizationManager.tr_key("enemy.preview.%s" % enemy_id, fallback_name),
		"texture": texture,
		"elite": tags.has(&"elite"),
	}
	instance.free()
	return result

func _on_confirm_pressed() -> void:
	if _locked or confirm_button.disabled:
		return
	_locked = true
	if _confirmed.is_valid():
		_confirmed.call()

func _clear_callbacks() -> void:
	_confirmed = Callable()

func _play_open_transition() -> void:
	_kill_transition()
	visible = true
	shade.color.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.025, 1.0)
	panel.modulate = Color(0.65, 0.9, 1.0, 0.35)
	title_label.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	actions.modulate.a = 0.0
	terminal_status.text = LocalizationManager.tr_key(
		"battle_contract.ui.status.acquiring",
		"TACTICAL LINK // ACQUIRING CONTRACTS"
	)
	for card in cards:
		if not card.visible:
			continue
		card.modulate.a = 0.0

	_transition_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(shade, "color:a", SHADE_OPACITY, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "scale:x", 1.0, OPEN_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "modulate", Color.WHITE, OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(title_label, "modulate:a", 1.0, 0.16).set_delay(0.16)
	_transition_tween.tween_property(subtitle, "modulate:a", 1.0, 0.16).set_delay(0.2)
	for index in cards.size():
		var card := cards[index]
		if not card.visible:
			continue
		var reveal_delay := 0.22 + index * CARD_REVEAL_INTERVAL
		_transition_tween.tween_property(card, "modulate:a", 1.0, CARD_REVEAL_DURATION).set_delay(reveal_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(actions, "modulate:a", 1.0, 0.16).set_delay(0.36)
	_transition_tween.chain().tween_callback(_finish_open_transition).set_delay(0.02)

func _finish_open_transition() -> void:
	_transition_tween = null
	terminal_status.text = LocalizationManager.tr_key(
		"battle_contract.ui.status.ready",
		"TACTICAL LINK // CONTRACTS READY"
	)
	_locked = false
	cards[0].grab_focus()

func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
