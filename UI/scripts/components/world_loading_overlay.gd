extends Control
## Presentation only: phase progress is never presented as a byte percentage.
const STAGES := ["sync_run", "load_world", "deploy_world", "link_battle", "ready"]
const CYAN := Color("64d9e8")
var loading_progress := 0.0
var _stage := 0
var _elapsed := 0.0
var _stage_age := 0.16
var _mecha_id := ""
var _emblem: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func begin_loading(mecha_id: String) -> void:
	loading_progress = 0.0
	_stage = 0
	_elapsed = 0.0
	_stage_age = 0.0
	_mecha_id = mecha_id
	_emblem = null
	set_process(true)
	queue_redraw()

func set_emblem(texture: Texture2D) -> void:
	_emblem = texture
	queue_redraw()

func stop() -> void:
	set_process(false)
	_emblem = null

func set_loading_progress(value: float) -> void:
	loading_progress = maxf(loading_progress, clampf(value, 0.0, 1.0))
	var stage := 0 if loading_progress < 0.24 else (1 if loading_progress < 0.84 else (2 if loading_progress < 0.94 else 3))
	_set_stage(maxi(_stage, stage))
	queue_redraw()

func complete_loading() -> void:
	loading_progress = 1.0
	_set_stage(4)
	queue_redraw()

func _set_stage(stage: int) -> void:
	if stage != _stage:
		_stage = stage
		_stage_age = 0.0

func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, 14.4)
	_stage_age = minf(_stage_age + delta, 0.16)
	queue_redraw()

func _text(key: String, baseline: float, font_size: int, color: Color) -> void:
	var text := str(TranslationServer.translate(key))
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(roundf((size.x - width) / 2.0), baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("040a0f"))
	draw_rect(Rect2(Vector2(24, 24), size - Vector2(48, 48)), Color(CYAN, 0.30), false, 1)
	var center := (size / 2.0).floor()
	var badge_center := center + Vector2(0, -104)
	var ring_phase := fposmod(_elapsed, 1.6) / 1.6
	draw_arc(badge_center, roundf(52 + 20 * ring_phase), 0, TAU, 64, Color(CYAN, 0.22 * (1 - ring_phase)), 1)
	if _emblem != null:
		var dimensions := _emblem.get_size()
		var fitted := (dimensions * (96.0 / maxf(dimensions.x, dimensions.y))).floor()
		draw_texture_rect(_emblem, Rect2((badge_center - fitted / 2).floor(), fitted), false)
	else:
		# Neutral mech insignia until the caller supplies a selected-mech portrait.
		draw_rect(Rect2(badge_center - Vector2(48, 48), Vector2(96, 96)), Color(CYAN, 0.08))
		draw_rect(Rect2(badge_center - Vector2(24, 30), Vector2(48, 44)), Color(CYAN, 0.65), false, 2)
		draw_rect(Rect2(badge_center + Vector2(-16, -14), Vector2(32, 6)), CYAN)
		draw_polyline(PackedVector2Array([badge_center + Vector2(-34, 30), badge_center + Vector2(-34, 8), badge_center + Vector2(0, 26), badge_center + Vector2(34, 8), badge_center + Vector2(34, 30)]), CYAN, 2)
	var appearance := clampf(_stage_age / 0.16, 0.0, 1.0)
	var offset := roundf(4 * (1 - appearance))
	_text("ui.loading." + STAGES[_stage], center.y + 12 + offset, 24, Color(Color("e1f6fa"), appearance))
	_text("ui.loading." + STAGES[_stage] + ".system", center.y + 38 + offset, 12, Color(CYAN, 0.75 * appearance))
	# 9 * 40 + 8 * 10 = 440. Explicit readiness alone completes the last block.
	var completed := 9 if _stage == 4 else mini(8, floori(loading_progress * 9))
	var origin := center + Vector2(-220, 66)
	for index in range(9):
		var rect := Rect2(origin + Vector2(index * 50, 0), Vector2(40, 12))
		if index < completed:
			draw_rect(rect, CYAN)
		elif index == completed:
			draw_rect(rect, Color(CYAN, 0.22 + 0.10 * sin(_elapsed * TAU / 0.9)))
			draw_rect(rect, CYAN, false, 1)
		else:
			draw_rect(rect, Color("10222d"))
			draw_rect(rect, Color(CYAN, 0.18), false, 1)
	var footer := str(TranslationServer.translate("ui.loading.mecha")).replace("{id}", _mecha_id)
	var font := get_theme_default_font()
	var width := font.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(roundf(center.x - width / 2), size.y - 48), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CYAN, 0.65))
