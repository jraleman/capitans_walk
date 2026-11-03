extends RefCounted

## A simulation tick carries strengths, not keyboard, controller or touch events.

var q := 0.0
var w := 0.0
var o := 0.0
var p := 0.0
var whistle := false
var easy_left := 0.0
var easy_right := 0.0


func _init(
	thigh_a := 0.0, thigh_b := 0.0,
	calf_a := 0.0, calf_b := 0.0, whistle_pressed := false,
	left_step := 0.0, right_step := 0.0
) -> void:
	# Rejected values stay invalid rather than becoming a successful neutral tick.
	q = thigh_a
	w = thigh_b
	o = calf_a
	p = calf_b
	whistle = whistle_pressed
	easy_left = left_step
	easy_right = right_step
	for strength: float in [q, w, o, p, easy_left, easy_right]:
		if not is_finite(strength):
			push_error("Capitan's Walk input strengths must be finite.")
			return
	q = clampf(q, 0.0, 1.0)
	w = clampf(w, 0.0, 1.0)
	o = clampf(o, 0.0, 1.0)
	p = clampf(p, 0.0, 1.0)
	easy_left = clampf(easy_left, 0.0, 1.0)
	easy_right = clampf(easy_right, 0.0, 1.0)


## Equal opposing inputs really are neutral, including analogue strengths.
func thighs() -> float:
	return q - w


## Each side of the same knee motor receives the opposite target.
func calves() -> float:
	return o - p


## Mutated or deserialized frames must meet the same contract as live inputs.
func is_valid() -> bool:
	for strength: float in [q, w, o, p, easy_left, easy_right]:
		if not is_finite(strength) or strength < 0.0 or strength > 1.0:
			return false
	return true
