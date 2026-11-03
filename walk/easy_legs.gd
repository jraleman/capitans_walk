extends RefCounted

## Each chosen leg plays one authored motor stride, not an animation or automatic walk.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const PHASE_TICKS := 12

var _leg := 0
var _phase_ticks := 0


## Restart and disabling the assist discard a partially played stride.
func reset() -> void:
	_leg = 0
	_phase_ticks = 0


## Holding both cancels; releasing stops immediately; holding one cannot keep stepping.
func compose(frame: InputFrame) -> InputFrame:
	var strength := frame.easy_left - frame.easy_right
	if absf(strength) <= Body.EPSILON:
		reset()
		if frame.easy_left > 0.0 or frame.easy_right > 0.0:
			return InputFrame.new(0.0, 0.0, 0.0, 0.0, frame.whistle)
		return InputFrame.new(frame.q, frame.w, frame.o, frame.p, frame.whistle)
	var leg := 1 if strength > 0.0 else -1
	if leg != _leg:
		_leg = leg
		_phase_ticks = 0
	if _phase_ticks >= PHASE_TICKS * 2:
		return InputFrame.new(0.0, 0.0, 0.0, 0.0, frame.whistle)
	var first_phase := _phase_ticks < PHASE_TICKS
	var magnitude := absf(strength)
	_phase_ticks += 1
	return InputFrame.new(
		magnitude if leg == 1 else 0.0, magnitude if leg == -1 else 0.0,
		magnitude if first_phase == (leg == 1) else 0.0,
		magnitude if first_phase != (leg == 1) else 0.0, frame.whistle
	)


## The phase is simulation state, so render FPS cannot change its timing.
func snapshot() -> Dictionary:
	return {"leg": _leg, "phase_ticks": _phase_ticks}
