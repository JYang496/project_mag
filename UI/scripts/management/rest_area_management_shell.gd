extends RefCounted
class_name RestAreaManagementShell

const PRIMARY_MENU_TARGET_SIZE := Vector2(312, 320)
const PANEL_MARGIN := Vector2(24, 24)
const PRIMARY_MENU_LEFT_MARGIN := 16.0
const PRIMARY_MENU_ANIM_TIME := 0.2
const PRIMARY_MENU_ANIM_TRANS := Tween.TRANS_CUBIC
const PRIMARY_MENU_ANIM_EASE := Tween.EASE_OUT

var owner_ui: Node
var active := false
var primary_menu_id: StringName = &""
var primary_menu_tweens: Dictionary = {}

func bind(owner: Node) -> void:
	owner_ui = owner

func open_primary(menu_id: StringName, root: Control, panel: Control) -> void:
	menu_id = _normalize_menu_id(menu_id)
	active = true
	primary_menu_id = menu_id
	PlayerData.is_interacting = true
	if owner_ui and owner_ui.has_method("%s_menu_in" % str(menu_id)):
		owner_ui.call("%s_menu_in" % str(menu_id))
		return
	show_primary_menu(menu_id, root, panel)

func close_primary(purchase_primary_root: Control, purchase_panel: Control, upgrade_primary_root: Control, upgrade_panel: Control, warehouse_primary_root: Control, warehouse_panel: Control) -> void:
	if not active:
		return
	match primary_menu_id:
		&"upgrade":
			hide_primary_menu(&"upgrade", upgrade_primary_root, upgrade_panel)
		&"warehouse":
			hide_primary_menu(&"warehouse", warehouse_primary_root, warehouse_panel)
		_:
			hide_primary_menu(&"purchase", purchase_primary_root, purchase_panel)
	PlayerData.is_interacting = false
	active = false
	primary_menu_id = &""

func is_menu_visible(secondary_open: bool, warehouse_panel: Control, module_equip_panel: Control) -> bool:
	if not active:
		return false
	if secondary_open:
		return true
	if warehouse_panel and is_instance_valid(warehouse_panel) and warehouse_panel.visible:
		return true
	if module_equip_panel and is_instance_valid(module_equip_panel) and module_equip_panel.visible:
		return true
	return false

func is_zone_navigation_allowed(purchase_primary_root: Control, upgrade_primary_root: Control, warehouse_primary_root: Control) -> bool:
	if TaskRewardManager.is_reward_blocking_interactions():
		return false
	if not active:
		return true
	if primary_menu_id == &"purchase" and purchase_primary_root and purchase_primary_root.visible:
		return true
	if primary_menu_id == &"upgrade" and upgrade_primary_root and upgrade_primary_root.visible:
		return true
	if primary_menu_id == &"warehouse" and warehouse_primary_root and warehouse_primary_root.visible:
		return true
	return false

func show_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	menu_id = _normalize_menu_id(menu_id)
	if owner_ui == null or root == null or panel == null:
		return
	stop_primary_menu_tween(menu_id)
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	_fit_left_panel(panel, viewport_size)
	var target_pos := panel.position
	var hidden_pos := _get_primary_menu_hidden_position(panel, target_pos)
	root.visible = true
	panel.position = hidden_pos
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", target_pos, PRIMARY_MENU_ANIM_TIME)
	tween.finished.connect(_on_primary_menu_tween_finished.bind(menu_id))
	primary_menu_tweens[menu_id] = tween

func hide_primary_menu(menu_id: StringName, root: Control, panel: Control) -> void:
	menu_id = _normalize_menu_id(menu_id)
	if owner_ui == null or root == null or panel == null:
		return
	stop_primary_menu_tween(menu_id)
	var viewport_size := owner_ui.get_viewport().get_visible_rect().size
	_fit_left_panel(panel, viewport_size)
	var target_pos := panel.position
	var hidden_pos := _get_primary_menu_hidden_position(panel, target_pos)
	if not root.visible:
		panel.position = hidden_pos
		return
	var tween := owner_ui.create_tween()
	tween.set_trans(PRIMARY_MENU_ANIM_TRANS)
	tween.set_ease(PRIMARY_MENU_ANIM_EASE)
	tween.tween_property(panel, "position", hidden_pos, PRIMARY_MENU_ANIM_TIME)
	tween.tween_callback(_on_primary_menu_hidden.bind(menu_id, root, panel, hidden_pos))
	tween.finished.connect(_on_primary_menu_tween_finished.bind(menu_id))
	primary_menu_tweens[menu_id] = tween

func stop_primary_menu_tween(menu_id: StringName) -> void:
	menu_id = _normalize_menu_id(menu_id)
	if not primary_menu_tweens.has(menu_id):
		return
	var active_tween := primary_menu_tweens[menu_id] as Tween
	if active_tween and is_instance_valid(active_tween):
		active_tween.kill()
	primary_menu_tweens.erase(menu_id)

func clear_module_state_if_active() -> void:
	if primary_menu_id == &"warehouse":
		stop_primary_menu_tween(&"warehouse")
		active = false
		primary_menu_id = &""
		PlayerData.is_interacting = false

func _on_primary_menu_hidden(menu_id: StringName, root: Control, panel: Control, hidden_pos: Vector2) -> void:
	if root:
		root.visible = false
	if panel:
		panel.position = hidden_pos
	primary_menu_tweens.erase(menu_id)

func _on_primary_menu_tween_finished(menu_id: StringName) -> void:
	primary_menu_tweens.erase(menu_id)

func _normalize_menu_id(menu_id: StringName) -> StringName:
	match menu_id:
		&"merchant":
			return &"purchase"
		&"smith":
			return &"upgrade"
		&"module":
			return &"warehouse"
		_:
			return menu_id

func _fit_left_panel(panel: Control, viewport_size: Vector2) -> void:
	if panel == null:
		return
	var available_size: Vector2 = viewport_size - PANEL_MARGIN * 2.0
	var width: float = minf(PRIMARY_MENU_TARGET_SIZE.x, available_size.x)
	var height: float = minf(PRIMARY_MENU_TARGET_SIZE.y, available_size.y)
	panel.size = Vector2(maxf(width, 0.0), maxf(height, 0.0))
	panel.position = Vector2(maxf(PRIMARY_MENU_LEFT_MARGIN, PANEL_MARGIN.x), (viewport_size.y - panel.size.y) * 0.5)

func _get_primary_menu_hidden_position(panel: Control, target_pos: Vector2) -> Vector2:
	return Vector2(-panel.size.x - PRIMARY_MENU_LEFT_MARGIN, target_pos.y)

