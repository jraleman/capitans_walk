extends RefCounted

## The live InputMap is shared by gameplay and the spike, including Settings rebindings.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")


## Platform-specific input stays outside the deterministic model.
func sample() -> InputFrame:
	return InputFrame.new(
		Input.get_action_strength(Options.Q), Input.get_action_strength(Options.W),
		Input.get_action_strength(Options.O), Input.get_action_strength(Options.P),
		Input.is_action_pressed(Options.WHISTLE)
	)
