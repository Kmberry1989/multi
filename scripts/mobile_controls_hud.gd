extends CanvasLayer
class_name MobileControlsHUD

const JOYSTICK_RADIUS := 72.0
const KNOB_RADIUS := 30.0
const CAMERA_DRAG_SENSITIVITY := 1.0

var _player: PlayerCharacter
var _level_scene: Node
var _joystick_touch_id := -1
var _camera_touch_id := -1
var _camera_last_position := Vector2.ZERO

var _joystick_base: Panel
var _joystick_knob: Panel
var _camera_area: Control

func _ready() -> void:
	layer = 20
	_build_ui()
	call_deferred("_reset_joystick")

func bind_context(level_scene: Node, player: PlayerCharacter) -> void:
	_level_scene = level_scene
	_player = player
	if _player:
		_player.set_touch_move_input(Vector2.ZERO)
		for action_name in [
			"shift",
			"jump",
			"light_punch",
			"light_kick",
			"special_attack",
			"block",
			"target_cycle",
		]:
			_player.set_touch_action_pressed(action_name, false)

func _build_ui() -> void:
	var root := Control.new()
	root.name = "MobileControlsRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_camera_area = Control.new()
	_camera_area.anchor_left = 0.42
	_camera_area.anchor_top = 0.0
	_camera_area.anchor_right = 1.0
	_camera_area.anchor_bottom = 0.74
	_camera_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_camera_area)

	_joystick_base = Panel.new()
	_joystick_base.anchor_left = 0.02
	_joystick_base.anchor_top = 0.74
	_joystick_base.anchor_right = 0.2
	_joystick_base.anchor_bottom = 0.98
	_joystick_base.custom_minimum_size = Vector2(160.0, 160.0)
	_joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_base.self_modulate = Color(1.0, 1.0, 1.0, 0.28)
	_joystick_base.resized.connect(_reset_joystick)
	root.add_child(_joystick_base)

	_joystick_knob = Panel.new()
	_joystick_knob.size = Vector2(KNOB_RADIUS * 2.0, KNOB_RADIUS * 2.0)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_knob.self_modulate = Color(1.0, 1.0, 1.0, 0.55)
	_joystick_base.add_child(_joystick_knob)
	_reset_joystick()

	var action_stack := VBoxContainer.new()
	action_stack.anchor_left = 0.72
	action_stack.anchor_top = 0.54
	action_stack.anchor_right = 0.98
	action_stack.anchor_bottom = 0.98
	action_stack.alignment = BoxContainer.ALIGNMENT_END
	action_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_stack.add_theme_constant_override("separation", 12)
	root.add_child(action_stack)

	action_stack.add_child(_build_button_row([
		{"label": "Chat", "mode": "tap", "action": "chat"},
		{"label": "Bag", "mode": "tap", "action": "inventory"},
		{"label": "Run", "mode": "hold", "action": "shift"},
	]))
	action_stack.add_child(_build_button_row([
		{"label": "Use", "mode": "tap", "action": "light_punch"},
		{"label": "Edit", "mode": "tap", "action": "light_kick"},
		{"label": "Jump", "mode": "tap", "action": "jump"},
	]))
	action_stack.add_child(_build_button_row([
		{"label": "Garden", "mode": "tap", "action": "special_attack"},
		{"label": "Emote", "mode": "tap", "action": "block"},
		{"label": "Rotate", "mode": "tap", "action": "target_cycle"},
	]))
	action_stack.add_child(_build_tip_label())

func _build_button_row(button_specs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	for spec in button_specs:
		row.add_child(_build_action_button(spec))
	return row

func _build_action_button(spec: Dictionary) -> Button:
	var button := Button.new()
	button.text = str(spec.get("label", "Action"))
	button.custom_minimum_size = Vector2(92.0, 70.0)
	button.focus_mode = Control.FOCUS_NONE
	button.self_modulate = Color(1.0, 1.0, 1.0, 0.9)
	var mode := str(spec.get("mode", "tap"))
	var action := str(spec.get("action", ""))
	if mode == "hold":
		button.button_down.connect(
			func() -> void:
				_set_touch_action(action, true)
		)
		button.button_up.connect(
			func() -> void:
				_set_touch_action(action, false)
		)
	else:
		button.pressed.connect(
			func() -> void:
				_tap_action(action)
		)
	return button

func _build_tip_label() -> Label:
	var label := Label.new()
	label.text = "Left thumb moves. Drag upper-right to look."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _joystick_touch_id == -1 and _point_in_control(_joystick_base, event.position):
			_joystick_touch_id = event.index
			_update_joystick(event.position)
			return
		if _camera_touch_id == -1 and _point_in_control(_camera_area, event.position):
			_camera_touch_id = event.index
			_camera_last_position = event.position
			return
	else:
		if event.index == _joystick_touch_id:
			_joystick_touch_id = -1
			_reset_joystick()
			if _player:
				_player.set_touch_move_input(Vector2.ZERO)
		if event.index == _camera_touch_id:
			_camera_touch_id = -1

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_id:
		_update_joystick(event.position)
	elif event.index == _camera_touch_id:
		if _player:
			var drag_delta := event.position - _camera_last_position
			_player.apply_touch_look_delta(drag_delta * CAMERA_DRAG_SENSITIVITY)
		_camera_last_position = event.position

func _update_joystick(screen_position: Vector2) -> void:
	var base_center := _joystick_base.global_position + (_joystick_base.size * 0.5)
	var offset := screen_position - base_center
	var clamped := offset.limit_length(JOYSTICK_RADIUS)
	_joystick_knob.position = (_joystick_base.size * 0.5) + clamped - (_joystick_knob.size * 0.5)
	if _player:
		var input_vector := Vector2(clamped.x / JOYSTICK_RADIUS, clamped.y / JOYSTICK_RADIUS)
		_player.set_touch_move_input(Vector2(input_vector.x, -input_vector.y))

func _reset_joystick() -> void:
	if _joystick_knob == null or _joystick_base == null:
		return
	_joystick_knob.position = (_joystick_base.size * 0.5) - (_joystick_knob.size * 0.5)

func _tap_action(action: String) -> void:
	match action:
		"inventory":
			if _level_scene and _level_scene.has_method("toggle_inventory"):
				_level_scene.toggle_inventory()
		"chat":
			if _level_scene and _level_scene.has_method("toggle_chat"):
				_level_scene.toggle_chat()
		_:
			_set_touch_action(action, true)
			_set_touch_action(action, false)

func _set_touch_action(action: String, pressed: bool) -> void:
	if _player == null:
		return
	_player.set_touch_action_pressed(action, pressed)

func _point_in_control(control: Control, point: Vector2) -> bool:
	if control == null:
		return false
	return Rect2(control.global_position, control.size).has_point(point)
