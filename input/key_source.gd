extends RefCounted

## The live InputMap is shared by gameplay and the spike, including Settings rebindings.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")

var path_mode := false


## Platform-specific input stays outside the deterministic model.
func sample() -> InputFrame:
	if path_mode:
		var frame := InputFrame.new()
		frame.steer_left = Input.get_action_strength(Options.STEER_LEFT)
		frame.steer_right = Input.get_action_strength(Options.STEER_RIGHT)
		frame.whistle = Input.is_action_pressed(Options.WHISTLE)
		return frame
	return InputFrame.new(
		Input.get_action_strength(Options.Q), Input.get_action_strength(Options.W),
		Input.get_action_strength(Options.O), Input.get_action_strength(Options.P),
		Input.is_action_pressed(Options.WHISTLE),
		Input.get_action_strength(Options.EASY_LEFT),
		Input.get_action_strength(Options.EASY_RIGHT)
	)


## Diagnostic controls remain available without advertising them in the new game's Settings.
static func install_physics_actions() -> void:
	for binding in Options.PHYSICS_CONTROL_BINDINGS:
		var action: StringName = binding["action"]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = int(binding["default"])
		InputMap.action_add_event(action, key)
