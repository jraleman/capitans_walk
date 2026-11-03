extends SceneTree

## Real platform events exercise independent sources without requiring attached hardware.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const PadSource = preload("res://games/capitans_walk/input/pad_source.gd")
const WalkControls = preload("res://games/capitans_walk/input/walk_controls.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")

var _failures := PackedStringArray()
var _restarts := 0
var _pauses := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_pad_strengths()
	var controls := WalkControls.new()
	get_root().add_child(controls)
	controls.position = Vector2(38.0, 190.0)
	controls.size = Vector2(1844.0, 700.0)
	controls.configure_keys(PackedStringArray(["Q", "W", "O", "P"]), "Space",
		PackedStringArray(["A", "D"]), false, 0)
	controls.set_enabled(true)
	controls.restart_requested.connect(_on_restart)
	controls.pause_requested.connect(_on_pause)
	await process_frame
	_test_touch_contacts(controls)
	_test_mixed_sources_and_focus(controls)
	_test_layouts_and_easy_legs(controls)
	_test_commands(controls)
	controls.free()
	await process_frame
	if _failures.is_empty():
		print("Capitan's Walk input source tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_pad_strengths() -> void:
	var pad := PadSource.new()
	pad.handle_event(_button(JOY_BUTTON_LEFT_SHOULDER, true))
	pad.handle_event(_button(JOY_BUTTON_RIGHT_SHOULDER, true))
	pad.handle_event(_axis(JOY_AXIS_TRIGGER_LEFT, 0.25))
	pad.handle_event(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.75))
	var frame := pad.sample()
	_expect(frame.q == 1.0 and frame.w == 0.25 and frame.o == 1.0 and frame.p == 0.75,
		"LB/RB and feathered LT/RT must remain four independent motor strengths.")
	pad.handle_event(_axis(JOY_AXIS_TRIGGER_LEFT, 0.9, 14))
	_expect(pad.sample().w == 0.25,
		"A second controller must not mix a different trigger into the active controller.")
	pad.handle_event(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	pad.handle_event(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	_expect(pad.sample().thighs() == 0.0 and pad.sample().calves() == 0.0,
		"Fully opposing gamepad controls must cancel in the same model frame.")
	pad.handle_event(_axis(JOY_AXIS_TRIGGER_LEFT, 0.02))
	pad.handle_event(_axis(JOY_AXIS_TRIGGER_RIGHT, -1.0))
	pad.handle_event(_button(JOY_BUTTON_A, true))
	_expect(pad.sample().w == 0.0 and pad.sample().p == 0.0 and pad.sample().whistle,
		"Released/noisy triggers must be neutral and A must remain a held Whistle input.")
	frame.q = 0.0
	_expect(pad.sample().q == 1.0,
		"Mutating a sampled frame must not change the adapter's held state.")
	pad.disconnect_device(14)
	_expect(pad.sample().whistle, "Unplugging another pad must not release this controller.")
	pad.disconnect_device(13)
	_expect(pad.sample().q == 0.0 and not pad.sample().whistle,
		"Unplugging the active pad must release every motor and Whistle.")


func _test_touch_contacts(controls: WalkControls) -> void:
	# A hybrid desktop reveals its controls on the first actual screen touch.
	var reveal := InputEventScreenTouch.new()
	reveal.index = 99
	reveal.position = Vector2.ZERO
	reveal.pressed = true
	get_root().push_input(reveal, true)
	Input.flush_buffered_events()
	_expect(controls.touch_pads.visible and controls.touch_height() > 0.0,
		"Touch controls must appear even if startup did not detect a touchscreen.")
	for index in Options.LEG_ACTIONS.size():
		_touch(controls, index, Options.LEG_ACTIONS[index], true)
	var frame := controls.sample()
	_expect(frame.q == 1.0 and frame.w == 1.0 and frame.o == 1.0 and frame.p == 1.0
		and frame.thighs() == 0.0 and frame.calves() == 0.0
		and not Input.is_action_pressed(Options.Q),
		"Four contacts must coexist without pressing shared keyboard actions.")
	_touch(controls, 0, Options.Q, false)
	_touch(controls, 4, Options.W, true)
	_touch(controls, 1, Options.W, false)
	_expect(controls.sample().q == 0.0 and controls.sample().w == 1.0,
		"Releasing one finger must not release another, including two on the same pad.")
	_touch(controls, 4, Options.W, false, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2.ZERO
	get_root().push_input(drag, true)
	Input.flush_buffered_events()
	_expect(controls.sample().o == 0.0 and controls.sample().p == 1.0
		and controls.sample().w == 0.0,
		"Cancellation and dragging off a pad must release only the affected contacts.")
	drag = InputEventScreenDrag.new()
	drag.index = 2
	drag.position = controls.touch_pads.buttons[Options.P].get_global_rect().get_center()
	get_root().push_input(drag, true)
	Input.flush_buffered_events()
	_touch(controls, 3, Options.P, false)
	_expect(controls.sample().p == 1.0,
		"A retained finger may slide onto another motor without losing independent ownership.")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = controls.touch_pads.buttons[Options.RESTART].get_global_rect().get_center()
	get_root().push_input(mouse, true)
	Input.flush_buffered_events()
	mouse = mouse.duplicate() as InputEventMouseButton
	mouse.pressed = false
	get_root().push_input(mouse, true)
	Input.flush_buffered_events()
	_expect(_restarts == 0,
		"Touch-emulated mouse events must not duplicate a contact into an accidental restart.")
	controls.clear_input()


func _test_mixed_sources_and_focus(controls: WalkControls) -> void:
	Input.action_press(Options.Q, 0.6)
	Input.parse_input_event(_axis(JOY_AXIS_TRIGGER_LEFT, 0.4))
	_touch(controls, 10, Options.P, true)
	var frame := controls.sample()
	_expect(is_equal_approx(frame.q, 0.6) and is_equal_approx(frame.w, 0.4) and frame.p == 1.0,
		"Keyboard, gamepad and touch must compose without overwriting each other.")
	_touch(controls, 10, Options.P, false)
	_expect(is_equal_approx(controls.sample().q, 0.6)
		and is_equal_approx(controls.sample().w, 0.4) and controls.sample().p == 0.0,
		"Releasing touch must preserve the held keyboard and controller strengths.")
	Input.joy_connection_changed.emit(13, false)
	_expect(is_equal_approx(controls.sample().q, 0.6) and controls.sample().w == 0.0,
		"A real disconnect notification must clear the pad without releasing keyboard input.")
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	frame = controls.sample()
	_expect(frame.q == 0.0 and frame.w == 0.0 and frame.p == 0.0,
		"Losing application focus must clear every source, not leave a stuck motor.")
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(controls.sample().q == 0.0 and controls.sample().w == 0.0,
		"Returning focus must not resurrect stale held inputs.")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse.position = controls.touch_pads.buttons[Options.W].get_global_rect().get_center()
	mouse.global_position = mouse.position
	mouse.pressed = true
	get_root().push_input(mouse, true)
	var other := mouse.duplicate() as InputEventMouseButton
	other.button_index = MOUSE_BUTTON_RIGHT
	other.pressed = false
	get_root().push_input(other, true)
	_expect(controls.sample().w == 1.0,
		"Releasing another mouse button must not release the primary motor hold.")
	mouse = mouse.duplicate() as InputEventMouseButton
	mouse.pressed = false
	mouse.button_mask = 0
	get_root().push_input(mouse, true)


func _test_layouts_and_easy_legs(controls: WalkControls) -> void:
	var original_left := controls.touch_pads.buttons[Options.Q].position.x
	var original_right := controls.touch_pads.buttons[Options.O].position.x
	for layout in [1, 2, 0]:
		_touch(controls, 11, Options.Q, true)
		controls.configure_keys(PackedStringArray(["Z", "W", "O", "P"]), "X",
			PackedStringArray(["B", "D"]), false, layout)
		_expect(controls.sample().q == 0.0,
			"Switching touch layout must release fingers rather than remapping a held action.")
		var left := controls.touch_pads.buttons[Options.Q].position.x
		var right := controls.touch_pads.buttons[Options.O].position.x
		_expect((layout != 1 or right < controls.size.x * 0.5)
			and (layout != 2 or left > controls.size.x * 0.5)
			and (layout != 0 or (left == original_left and right == original_right)),
			"Handed layouts must actually group both motor columns on the selected side.")
	_touch(controls, 11, Options.Q, true)
	controls.size.x -= 20.0
	_expect(controls.sample().q == 0.0,
		"Resizing or rotating the viewport must not retain a finger over a relocated pad.")
	controls.configure_keys(PackedStringArray(["Z", "W", "O", "P"]), "X",
		PackedStringArray(["B", "D"]), true, 0)
	_expect(not controls.touch_pads.buttons[Options.Q].visible
		and controls.touch_pads.buttons[Options.EASY_LEFT].visible
		and controls.touch_pads.buttons[Options.W].visible
		and controls.touch_pads.buttons[Options.P].visible
		and controls.touch_pads.buttons[Options.EASY_LEFT].text.contains("B"),
		"Easy touch must show rebind-aware leg choices and retain both manual brace pads.")
	_touch(controls, 12, Options.EASY_LEFT, true)
	var walk := Walk.new()
	walk.easy_legs = true
	walk.advance(Body.STEP, controls.sample())
	_expect(walk.last_frame.q == 1.0 and walk.last_frame.o == 1.0,
		"A real Easy touch must drive the authored macro on the original joint motors.")
	_touch(controls, 13, Options.EASY_RIGHT, true)
	walk.advance(Body.STEP, controls.sample())
	_expect(walk.last_frame.thighs() == 0.0 and walk.last_frame.calves() == 0.0,
		"Opposing Easy touches must cancel, not start an automatic gait.")
	controls.clear_input()
	Input.parse_input_event(_button(JOY_BUTTON_DPAD_RIGHT, true))
	Input.flush_buffered_events()
	_expect(controls.sample().easy_right == 1.0,
		"D-pad right must select the same Easy leg without replacing the manual triggers.")
	Input.parse_input_event(_button(JOY_BUTTON_DPAD_RIGHT, false))
	controls.touch_pads.whistle_available = false
	controls.configure_keys(PackedStringArray(["Z", "W", "O", "P"]), "X",
		PackedStringArray(["B", "D"]), false, 0)
	_expect(not controls.touch_pads.buttons[Options.WHISTLE].visible
		and controls.touch_pads.buttons[&"pause"].visible,
		"The walker-only spike must keep Pause without advertising a nonexistent dog recall.")


func _test_commands(controls: WalkControls) -> void:
	for button in [JOY_BUTTON_Y, JOY_BUTTON_BACK, JOY_BUTTON_START]:
		Input.parse_input_event(_button(button, true))
		Input.parse_input_event(_button(button, true))
		Input.parse_input_event(_button(button, false))
	Input.flush_buffered_events()
	_expect(_restarts == 2 and _pauses == 1,
		"Y/Back restart and Start pause must fire once per press, not repeat while held.")
	controls.set_enabled(false)
	Input.parse_input_event(_button(JOY_BUTTON_LEFT_SHOULDER, true))
	_expect(controls.sample().q == 0.0,
		"Modal results must reject live motors while command buttons remain available.")
	Input.parse_input_event(_button(JOY_BUTTON_Y, true))
	Input.parse_input_event(_button(JOY_BUTTON_Y, false))
	Input.flush_buffered_events()
	_expect(_restarts == 3, "Y must still request a fresh walk from results.")


func _touch(
	controls: WalkControls, index: int, action: StringName, pressed: bool, canceled := false
) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = controls.touch_pads.buttons[action].get_global_rect().get_center()
	event.pressed = pressed
	event.canceled = canceled
	get_root().push_input(event, true)
	Input.flush_buffered_events()


func _button(button: int, pressed: bool, device := 13) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	return event


func _axis(axis: int, value: float, device := 13) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event


func _on_restart() -> void:
	_restarts += 1


func _on_pause() -> void:
	_pauses += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
