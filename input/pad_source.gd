extends RefCounted

## Fixed joystick events keep analogue motors independent of keyboard rebinding.

const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const TRIGGER_DEADZONE := 0.03
const STICK_DEADZONE := 0.15
const BUTTONS: Array[int] = [
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_A, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
]
const PATH_BUTTONS: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const MOTOR_AXES: Array[int] = [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
const PATH_AXES: Array[int] = [JOY_AXIS_LEFT_X]

var device := -1
var path_mode := false
var _frame := InputFrame.new()
var _stick := 0.0


## One active controller owns the walk until reset, focus loss or disconnection.
func handle_event(event: InputEvent) -> bool:
	var strength := 0.0
	var buttons: Array[int] = PATH_BUTTONS if path_mode else BUTTONS
	var axes: Array[int] = PATH_AXES if path_mode else MOTOR_AXES
	if event is InputEventJoypadButton and event.button_index in buttons:
		strength = float(event.pressed)
	elif event is InputEventJoypadMotion and event.axis in axes:
		if not is_finite(event.axis_value):
			push_error("Capitan's Walk gamepad axes must be finite.")
			return false
		if path_mode:
			strength = signf(event.axis_value) * clampf(
				(absf(event.axis_value) - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 0.0, 1.0)
		else:
			strength = clampf(event.axis_value, 0.0, 1.0)
			if strength <= TRIGGER_DEADZONE:
				strength = 0.0
	else:
		return false
	if device < 0:
		if strength == 0.0:
			return true
		device = event.device
	if event.device != device:
		return false
	if event is InputEventJoypadMotion:
		if path_mode:
			_stick = strength
		elif event.axis == JOY_AXIS_TRIGGER_LEFT:
			_frame.w = strength
		else:
			_frame.p = strength
	else:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_frame.q = strength
			JOY_BUTTON_RIGHT_SHOULDER:
				_frame.o = strength
			JOY_BUTTON_A:
				_frame.whistle = strength > 0.0
			JOY_BUTTON_DPAD_LEFT:
				if path_mode:
					_frame.steer_left = strength
				else:
					_frame.easy_left = strength
			JOY_BUTTON_DPAD_RIGHT:
				if path_mode:
					_frame.steer_right = strength
				else:
					_frame.easy_right = strength
	return true


## Callers receive a value copy, never the adapter's held state.
func sample() -> InputFrame:
	return InputFrame.new(_frame.q, _frame.w, _frame.o, _frame.p, _frame.whistle,
		_frame.easy_left, _frame.easy_right,
		maxf(_frame.steer_left, -_stick), maxf(_frame.steer_right, _stick))


func clear_input() -> void:
	device = -1
	_frame = InputFrame.new()
	_stick = 0.0


func disconnect_device(disconnected: int) -> void:
	if disconnected == device:
		clear_input()
