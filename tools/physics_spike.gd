extends Control

## Menu-free dog/leash bracing; --walker-only keeps the original human playtest available.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkControls = preload("res://games/capitans_walk/input/walk_controls.gd")
const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const DebugView = preload("res://games/capitans_walk/ui/walker_debug_view.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const WalkAudio = preload("res://games/capitans_walk/audio/walk_audio.gd")
const DEBUG_SIDE_FORCE := 220.0

var _walk := Walk.new()
var _body: Body = _walk.body
var _audio := WalkAudio.new()
var _controls: WalkControls
var _view: DebugView
var _readout: Label
var _paused := false
var _walker_only := false
var _walk_speed := 1.0
var _layout: VBoxContainer
var _touch_space: Control


func _ready() -> void:
	_walker_only = OS.get_cmdline_user_args().has("--walker-only")
	_layout = VBoxContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layout)
	_readout = Label.new()
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.add_theme_font_size_override("font_size", 24)
	_layout.add_child(_readout)
	_view = DebugView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(_view)
	_touch_space = Control.new()
	_layout.add_child(_touch_space)
	_controls = WalkControls.new()
	_controls.restart_requested.connect(_restart)
	_controls.pause_requested.connect(_toggle_pause)
	_controls.layout_changed.connect(_resize_controls)
	add_child(_controls)
	_controls.touch_pads.whistle_available = not _walker_only
	resized.connect(_resize_controls)
	_apply_settings()
	_controls.set_enabled(true)
	_resize_controls()
	Settings.changed.connect(_on_setting_changed)
	_view.present(_body, InputFrame.new(), null if _walker_only else _walk)
	_update_readout()


func _process(delta: float) -> void:
	var frame := _controls.sample()
	if not _paused:
		var side := float(Input.is_physical_key_pressed(KEY_RIGHT)) \
			- float(Input.is_physical_key_pressed(KEY_LEFT))
		var force := Vector3(0.0, 0.0, side * DEBUG_SIDE_FORCE)
		if _walker_only:
			_body.advance(delta * _walk_speed, frame, force)
		else:
			_walk.advance(delta * _walk_speed, frame, force)
			_audio.update(_walk, AudioManager)
	_view.present(_body, frame, null if _walker_only else _walk)
	_controls.touch_pads.set_whistle_cooldown(_walk.dog.cooldown_ticks * Body.STEP)
	if _body.is_over():
		_controls.set_enabled(false)
	_update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(Options.RESTART):
		_restart()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key in [Options.STEADY_KEY, Options.WALK_SPEED_KEY,
		Options.EASY_LEGS_KEY, Options.LONG_WARNINGS_KEY, Options.TOUCH_LAYOUT_KEY] \
		or key.begins_with("controls/"):
		_apply_settings()


func _apply_settings() -> void:
	var labels := PackedStringArray()
	for binding in Options.LEG_BINDINGS:
		labels.append(Settings.binding_key_label(binding))
	var easy_labels := PackedStringArray()
	for binding in Options.EASY_BINDINGS:
		easy_labels.append(Settings.binding_key_label(binding))
	_body.steady = Settings.tunable(Options.STEADY_KEY)
	_walk_speed = float(Settings.tunable_choice(Options.WALK_SPEED_KEY)) / 100.0
	_walk.easy_legs = not _walker_only and Settings.tunable_bool(Options.EASY_LEGS_KEY)
	_walk.dog.long_warnings = Settings.tunable_bool(Options.LONG_WARNINGS_KEY)
	_view.configure_keys(labels, Settings.binding_key_label(Options.WHISTLE_BINDING),
		easy_labels, _walk.easy_legs)
	_controls.configure_keys(labels, Settings.binding_key_label(Options.WHISTLE_BINDING),
		easy_labels, _walk.easy_legs, int(Settings.tunable_choice(Options.TOUCH_LAYOUT_KEY)))


func _restart() -> void:
	_walk.reset()
	_audio.reset()
	_paused = false
	_controls.set_enabled(true)


func _toggle_pause() -> void:
	_paused = not _paused
	_controls.set_enabled(not _paused and not _body.is_over())


func _resize_controls() -> void:
	_controls.position = Vector2.ZERO
	_controls.size = size
	_touch_space.custom_minimum_size.y = _controls.touch_height()
	_view.show_keycaps = not _controls.touch_pads.visible


func _update_readout() -> void:
	_readout.text = (
		"%s / %.1f m / %.1f model seconds / bone error %.4f m / %s\n"
		+ "%s restart / Esc pause / Left-right arrows test sideways tugs"
	) % [
		"WALKER ONLY / CLASSIC LEGS" if _walker_only else "DOG + LEASH",
		_body.distance, _body.ticks * Body.STEP, _body.max_bone_error(),
		"PAUSED" if _paused else "LIVE" if not _body.is_over() else _body.end_cause.to_upper(),
		Settings.binding_key_label(Options.RESTART_BINDING),
	]
