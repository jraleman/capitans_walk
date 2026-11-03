extends Control

## Both entry scenes combine independent sources without changing the fixed-tick model.

signal restart_requested
signal pause_requested
signal layout_changed
signal gamepad_changed

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const KeySource = preload("res://games/capitans_walk/input/key_source.gd")
const PadSource = preload("res://games/capitans_walk/input/pad_source.gd")
const TouchPads = preload("res://games/capitans_walk/input/touch_pads.gd")
const COMMANDS: Array[int] = [JOY_BUTTON_Y, JOY_BUTTON_BACK, JOY_BUTTON_START]

var touch_pads := TouchPads.new()
var _keys := KeySource.new()
var _pad := PadSource.new()
var _commands_down: Dictionary[Vector2i, bool] = {}
var _enabled := false
var _focused := true
var _sampling_allowed := false


func _ready() -> void:
	# Start must still reach the existing pause overlay while the model is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_pads)
	touch_pads.visible = DisplayServer.is_touchscreen_available()
	touch_pads.restart_requested.connect(restart_requested.emit)
	touch_pads.pause_requested.connect(pause_requested.emit)
	resized.connect(_layout_touch)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_layout_touch()
	_refresh_enabled()


## Max-per-action keeps mixed sources independent; opposing motors still cancel in the model.
func sample() -> InputFrame:
	if not _can_sample():
		return InputFrame.new()
	var frame := _keys.sample()
	for source: InputFrame in [_pad.sample(), touch_pads.sample()]:
		frame.q = maxf(frame.q, source.q)
		frame.w = maxf(frame.w, source.w)
		frame.o = maxf(frame.o, source.o)
		frame.p = maxf(frame.p, source.p)
		frame.whistle = frame.whistle or source.whistle
		frame.easy_left = maxf(frame.easy_left, source.easy_left)
		frame.easy_right = maxf(frame.easy_right, source.easy_right)
	return frame


func configure_keys(
	labels: PackedStringArray, whistle_key: String,
	easy_labels: PackedStringArray, easy_enabled: bool, layout: int
) -> void:
	touch_pads.configure_keys(labels, whistle_key, easy_labels, easy_enabled, layout)
	_layout_touch()


func set_enabled(value: bool) -> void:
	_enabled = value
	clear_input()
	_refresh_enabled()


func clear_input() -> void:
	_pad.clear_input()
	touch_pads.clear_input()
	for action in Options.LEG_ACTIONS + [
		Options.WHISTLE, Options.EASY_LEFT, Options.EASY_RIGHT,
	]:
		Input.action_release(action)


func touch_height() -> float:
	return touch_pads.preferred_height() if touch_pads.visible else 0.0


func has_gamepad() -> bool:
	return _pad.device >= 0 or not Input.get_connected_joypads().is_empty()


func _process(_delta: float) -> void:
	_refresh_enabled()


func _input(event: InputEvent) -> void:
	if not _focused:
		return
	if event is InputEventJoypadButton and event.button_index in COMMANDS:
		var command := Vector2i(event.device, event.button_index)
		if not event.pressed:
			_commands_down.erase(command)
			return
		if get_tree().paused and event.button_index != JOY_BUTTON_START:
			return
		if not _commands_down.has(command):
			_commands_down[command] = true
			if event.button_index == JOY_BUTTON_START:
				clear_input()
				pause_requested.emit()
			else:
				restart_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not _can_sample():
		return
	if event is InputEventScreenTouch and event.pressed and not event.canceled \
		and not touch_pads.visible:
		touch_pads.show()
		_layout_touch()
		layout_changed.emit()
		touch_pads.handle_event(event)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var had_gamepad := has_gamepad()
		if _pad.handle_event(event):
			if not had_gamepad:
				gamepad_changed.emit()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_commands_down.clear()
		clear_input()
		_refresh_enabled()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_refresh_enabled()


func _can_sample() -> bool:
	return _enabled and _focused and is_inside_tree() and not get_tree().paused


func _refresh_enabled() -> void:
	var allowed := _can_sample()
	if allowed == _sampling_allowed:
		return
	_sampling_allowed = allowed
	clear_input()
	touch_pads.set_enabled(allowed)


func _layout_touch() -> void:
	if not is_inside_tree():
		return
	var height := touch_pads.preferred_height()
	touch_pads.position = Vector2(0.0, maxf(0.0, size.y - height))
	touch_pads.size = Vector2(size.x, height)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_pad.disconnect_device(device)
		for command in _commands_down.keys():
			if command.x == device:
				_commands_down.erase(command)
	gamepad_changed.emit()
