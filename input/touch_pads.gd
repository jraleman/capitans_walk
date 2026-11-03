extends Control

## Each finger owns a pad; touch never presses or releases shared InputMap actions.

signal restart_requested
signal pause_requested

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const PAUSE := &"pause"
const GAP := 10.0
const PAD_HEIGHT := 88.0
const UTILITY_HEIGHT := 64.0
const ACTIONS: Array[StringName] = [
	Options.Q, Options.W, Options.O, Options.P,
	Options.EASY_LEFT, Options.EASY_RIGHT, Options.WHISTLE, Options.RESTART, PAUSE,
]
const TITLES := {
	Options.Q: "THIGHS A", Options.W: "THIGHS B",
	Options.O: "CALVES A", Options.P: "CALVES B",
	Options.EASY_LEFT: "LEFT LEG", Options.EASY_RIGHT: "RIGHT LEG",
	Options.WHISTLE: "WHISTLE", Options.RESTART: "RESTART", PAUSE: "PAUSE",
}

var buttons: Dictionary[StringName, Button] = {}
var whistle_available := true
var _touches: Dictionary[int, StringName] = {}
var _mouse_action: StringName = &""
var _enabled := false
var _easy_enabled := false
var _layout := 0
var _key_labels := PackedStringArray(["Q", "W", "O", "P"])
var _easy_labels := PackedStringArray(["A", "D"])
var _whistle_key := "Space"
var _whistle_seconds := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for action in ACTIONS:
		var button := Button.new()
		button.name = str(action)
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(_mouse_down.bind(action))
		button.button_up.connect(_mouse_up)
		add_child(button)
		buttons[action] = button
	resized.connect(_on_resized)
	_refresh_labels()
	_layout_buttons()
	set_enabled(_enabled)


## The same four motor slots become two stride choices and two manual brace pads.
func configure_keys(
	labels: PackedStringArray, whistle_key: String,
	easy_labels: PackedStringArray, easy_enabled: bool, layout: int
) -> void:
	if layout not in [0, 1, 2]:
		push_error("Capitan's Walk touch layout must be Thumbs, Left-handed or Right-handed.")
		return
	if _easy_enabled != easy_enabled or _layout != layout:
		clear_input()
	_key_labels = labels.duplicate()
	_whistle_key = whistle_key
	_easy_labels = easy_labels.duplicate()
	_easy_enabled = easy_enabled
	_layout = layout
	_refresh_labels()
	_layout_buttons()


func preferred_height() -> float:
	var scale_factor := _readability()
	_apply_font_sizes(scale_factor)
	return ceilf(_utility_height(scale_factor) + (PAD_HEIGHT * 2.0 + GAP * 2.0) * scale_factor)


func sample() -> InputFrame:
	return InputFrame.new(strength(Options.Q), strength(Options.W),
		strength(Options.O), strength(Options.P), strength(Options.WHISTLE) > 0.0,
		strength(Options.EASY_LEFT), strength(Options.EASY_RIGHT))


func strength(action: StringName) -> float:
	return float(_enabled and (
		_mouse_action == action or _touches.values().has(action)
	))


## Pauses, modal results, hidden controls and layout changes release every contact.
func clear_input() -> void:
	_touches.clear()
	_mouse_action = &""
	_sync_buttons()


func set_enabled(value: bool) -> void:
	_enabled = value
	clear_input()
	for button in buttons.values():
		button.disabled = not value


## Keep recall readiness visible when touch replaces the debug view's keycaps.
func set_whistle_cooldown(seconds: float) -> void:
	_whistle_seconds = seconds
	if buttons.is_empty():
		return
	var status := "READY" if seconds <= 0.0 else "%.1f S" % seconds
	var button := buttons[Options.WHISTLE]
	var caption := "WHISTLE\n" + status
	if button.text != caption:
		button.text = caption
		button.accessibility_name = "WHISTLE / " + status
		button.tooltip_text = "WHISTLE / %s / keyboard %s. Release before calling again." % [
			status, _whistle_key,
		]


## Also used for the first touch that reveals controls on a hybrid desktop.
func handle_event(event: InputEvent) -> void:
	if not _enabled or not is_visible_in_tree() or get_tree().paused:
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) \
		and event.device == InputEvent.DEVICE_ID_EMULATION \
		and get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and not event.pressed:
		_mouse_up()
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			var action := _action_at(event.position)
			if action == &"":
				return
			_touches[event.index] = action
			_request(action)
		elif _touches.has(event.index):
			_touches.erase(event.index)
		else:
			return
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var action := _action_at(event.position)
		# Sliding may change motors, but cannot accidentally restart or pause.
		_touches[event.index] = &"" if action in [Options.RESTART, PAUSE] else action
	else:
		return
	_sync_buttons()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	handle_event(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
		or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		clear_input()


func _action_at(point: Vector2) -> StringName:
	for action in ACTIONS:
		var button := buttons[action]
		if button.visible and button.get_global_rect().has_point(point):
			return action
	return &""


func _mouse_down(action: StringName) -> void:
	if not _enabled or get_tree().paused:
		return
	_mouse_action = action
	_request(action)
	_sync_buttons()


func _mouse_up() -> void:
	_mouse_action = &""
	_sync_buttons()


func _request(action: StringName) -> void:
	if action == Options.RESTART:
		restart_requested.emit()
	elif action == PAUSE:
		pause_requested.emit()


func _sync_buttons() -> void:
	for action in buttons:
		buttons[action].set_pressed_no_signal(strength(action) > 0.0)


func _refresh_labels() -> void:
	if buttons.is_empty():
		return
	for index in Options.LEG_ACTIONS.size():
		_set_label(Options.LEG_ACTIONS[index], _key_labels[index])
	_set_label(Options.EASY_LEFT, _easy_labels[0])
	_set_label(Options.EASY_RIGHT, _easy_labels[1])
	_set_label(Options.WHISTLE, _whistle_key)
	set_whistle_cooldown(_whistle_seconds)
	_set_label(Options.RESTART, "")
	_set_label(PAUSE, "")


func _set_label(action: StringName, key: String) -> void:
	buttons[action].text = TITLES[action] + ("\n" + key if not key.is_empty() else "")
	buttons[action].accessibility_name = TITLES[action]
	buttons[action].tooltip_text = "%s%s" % [
		TITLES[action], " / keyboard " + key if not key.is_empty() else "",
	]


func _readability() -> float:
	return 2.0 if Responsive.is_portrait(get_viewport_rect().size) else 1.2


func _on_resized() -> void:
	clear_input()
	_layout_buttons()


func _apply_font_sizes(scale_factor: float) -> void:
	var font_size := roundi(22.0 * scale_factor)
	for button in buttons.values():
		if button.get_theme_font_size("font_size") != font_size:
			button.add_theme_font_size_override("font_size", font_size)


func _utility_height(scale_factor: float) -> float:
	var height := UTILITY_HEIGHT * scale_factor
	for action in _utility_actions():
		if buttons.has(action):
			height = maxf(height, buttons[action].get_combined_minimum_size().y)
	return height


func _utility_actions() -> Array[StringName]:
	var actions: Array[StringName] = [Options.RESTART, PAUSE]
	if whistle_available:
		actions.push_front(Options.WHISTLE)
	return actions


func _layout_buttons() -> void:
	if buttons.is_empty() or size.x <= 0.0:
		return
	var scale_factor := _readability()
	var gap := GAP * scale_factor
	var pad_width := minf(200.0 * scale_factor, (size.x - gap) / 2.0)
	var left := 0.0
	var right := size.x - pad_width
	var group_width := pad_width * 2.0 + gap
	if _layout != 0:
		left = 0.0 if _layout == 1 else size.x - group_width
		right = left + pad_width + gap
	for button in buttons.values():
		button.hide()
	_apply_font_sizes(scale_factor)
	var utility_height := _utility_height(scale_factor)
	var top := utility_height + gap
	var bottom := top + (PAD_HEIGHT + GAP) * scale_factor
	var motor_actions: Array[StringName] = [
		Options.EASY_LEFT if _easy_enabled else Options.Q, Options.W,
		Options.EASY_RIGHT if _easy_enabled else Options.O, Options.P,
	]
	var positions: Array[Vector2] = [
		Vector2(left, top), Vector2(left, bottom),
		Vector2(right, top), Vector2(right, bottom),
	]
	for index in motor_actions.size():
		var button := buttons[motor_actions[index]]
		button.position = positions[index]
		button.size = Vector2(pad_width, PAD_HEIGHT * scale_factor)
		button.show()
	var utilities := _utility_actions()
	var count := utilities.size()
	var utility_width := minf(160.0 * scale_factor, (size.x - gap * (count - 1)) / count)
	var utility_left := (size.x - utility_width * count - gap * (count - 1)) * 0.5
	if _layout != 0:
		utility_width = (group_width - gap * (count - 1)) / count
		utility_left = left
	for index in utilities.size():
		var button := buttons[utilities[index]]
		button.position = Vector2(utility_left + index * (utility_width + gap), 0.0)
		button.size = Vector2(utility_width, utility_height)
		button.show()
