extends Control

## A development-only, menu-free entry point for Milestone 1's human playtest.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const KeySource = preload("res://games/capitans_walk/input/key_source.gd")
const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const DebugView = preload("res://games/capitans_walk/ui/walker_debug_view.gd")
const DEBUG_SIDE_FORCE := 220.0

var _body := Body.new()
var _keys := KeySource.new()
var _view: DebugView
var _readout: Label
var _paused := false


func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	_readout = Label.new()
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.add_theme_font_size_override("font_size", 24)
	layout.add_child(_readout)
	_view = DebugView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_view)
	var labels := PackedStringArray()
	for binding in Options.LEG_BINDINGS:
		labels.append(Settings.binding_key_label(binding))
	_view.configure_keys(labels)
	_body.steady = Settings.tunable(Options.STEADY_KEY)
	_view.present(_body, InputFrame.new())
	_update_readout()


func _process(delta: float) -> void:
	var frame := _keys.sample()
	if not _paused:
		var side := float(Input.is_physical_key_pressed(KEY_RIGHT)) \
			- float(Input.is_physical_key_pressed(KEY_LEFT))
		_body.advance(delta, frame, Vector3(0.0, 0.0, side * DEBUG_SIDE_FORCE))
	_view.present(_body, frame)
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(Options.RESTART):
		_body.reset()
		_paused = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_paused = not _paused
		get_viewport().set_input_as_handled()


func _update_readout() -> void:
	_readout.text = (
		"%.1f m / %.1f model seconds / bone error %.4f m / %s\n"
		+ "%s restart / Esc pause / Left-right arrows test sideways tugs"
	) % [
		_body.distance, _body.ticks * Body.STEP, _body.max_bone_error(),
		"PAUSED" if _paused else "LIVE" if not _body.is_over() else _body.end_cause.to_upper(),
		Settings.binding_key_label(Options.RESTART_BINDING),
	]
