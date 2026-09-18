extends RefCounted
class_name RewardDetailController

# Owns branch-detail hover timers and the open-card state.
const DETAIL_HOVER_OPEN_SECONDS := 0.25
const DETAIL_HOVER_CLOSE_SECONDS := 0.15

var _panel: Control
var open_index := -1
var pending_index := -1
var mouse_index := -1
var options_box: GridContainer:
	get:
		return _panel.get("options_box") as GridContainer
var _detail_open_timer: Timer:
	get:
		return _panel.get("_detail_open_timer") as Timer
var _detail_close_timer: Timer:
	get:
		return _panel.get("_detail_close_timer") as Timer

func _init(panel: Control) -> void:
	_panel = panel

func reset() -> void:
	open_index = -1
	pending_index = -1
	mouse_index = -1
	if _detail_open_timer != null:
		_detail_open_timer.stop()
	if _detail_close_timer != null:
		_detail_close_timer.stop()

func _on_weapon_hotspot_mouse_entered(index: int) -> void:
	# Gallery/showcase cards can be built from a detached presenter without the
	# complete reward panel scene. They keep their static preview, but must not
	# enter the modal interaction state machine.
	if options_box == null or not is_instance_valid(options_box):
		return
	mouse_index = index
	pending_index = index
	if _detail_close_timer != null:
		_detail_close_timer.stop()
	if open_index == index:
		return
	if _detail_open_timer == null:
		_open_weapon_detail(index)
		return
	_detail_open_timer.start(DETAIL_HOVER_OPEN_SECONDS)

func _on_weapon_hotspot_mouse_exited(index: int) -> void:
	if mouse_index == index:
		mouse_index = -1
	if _detail_open_timer != null:
		_detail_open_timer.stop()
	_start_detail_close_timer(index)

func _on_detail_overlay_mouse_entered(index: int) -> void:
	mouse_index = index
	if _detail_close_timer != null:
		_detail_close_timer.stop()

func _on_detail_overlay_mouse_exited(index: int) -> void:
	if mouse_index == index:
		mouse_index = -1
	_start_detail_close_timer(index)

func _start_detail_close_timer(index: int) -> void:
	if open_index != index:
		return
	if _detail_close_timer == null:
		_close_weapon_detail()
		return
	_detail_close_timer.start(DETAIL_HOVER_CLOSE_SECONDS)

func _on_detail_open_timeout() -> void:
	if pending_index >= 0 and mouse_index == pending_index:
		_open_weapon_detail(pending_index)

func _on_detail_close_timeout() -> void:
	if mouse_index < 0:
		_close_weapon_detail()

func _toggle_focused_weapon_detail() -> void:
	if open_index >= 0:
		_close_weapon_detail()
		return
	var index := int(_panel.get("_focus_index"))
	if index < 0:
		index = int(_panel.get("_pinned_index")) if bool(_panel.get("_summary_mode")) else int(_panel.get("_selected_index"))
	_open_weapon_detail(index)

func _open_weapon_detail(index: int) -> void:
	if options_box == null or not is_instance_valid(options_box):
		return
	if index < 0 or index >= options_box.get_child_count():
		return
	var button := options_box.get_child(index) as Button
	if button == null or not bool(button.get_meta(&"is_weapon_reward", false)):
		return
	if open_index >= 0 and open_index != index:
		_close_weapon_detail()
	var overlay := button.find_child("WeaponBranchDetailOverlay", true, false) as Control
	var content := button.find_child("CardContentMargin", true, false) as Control
	if overlay == null or content == null:
		return
	_panel.call("_cancel_quick_select_hold")
	open_index = index
	pending_index = -1
	overlay.visible = true
	content.modulate.a = 0.25
	button.z_index = 25
	_panel.call("_confirm_button_state")

func _close_weapon_detail() -> void:
	if _detail_open_timer != null:
		_detail_open_timer.stop()
	if _detail_close_timer != null:
		_detail_close_timer.stop()
	if options_box != null and is_instance_valid(options_box) \
			and open_index >= 0 and open_index < options_box.get_child_count():
		var button := options_box.get_child(open_index) as Button
		if button != null:
			var overlay := button.find_child("WeaponBranchDetailOverlay", true, false) as Control
			var content := button.find_child("CardContentMargin", true, false) as Control
			if overlay != null:
				overlay.visible = false
			if content != null:
				content.modulate.a = 1.0
			button.z_index = 1 if button.button_pressed else 0
	open_index = -1
	pending_index = -1
	_panel.call("_confirm_button_state")
