extends RefCounted

## A simulation tick carries strengths, not keyboard, controller or touch events.

var q := 0.0
var w := 0.0
var o := 0.0
var p := 0.0
var whistle := false


func _init(
	thigh_a := 0.0, thigh_b := 0.0,
	calf_a := 0.0, calf_b := 0.0, whistle_pressed := false
) -> void:
	# Rejected values stay invalid rather than becoming a successful neutral tick.
	q = thigh_a
	w = thigh_b
	o = calf_a
	p = calf_b
	whistle = whistle_pressed
	for strength: float in [q, w, o, p]:
		if not is_finite(strength):
			push_error("Capitan's Walk input strengths must be finite.")
			return
	q = clampf(q, 0.0, 1.0)
	w = clampf(w, 0.0, 1.0)
	o = clampf(o, 0.0, 1.0)
	p = clampf(p, 0.0, 1.0)


## Equal opposing inputs really are neutral, including analogue strengths.
func thighs() -> float:
	return q - w


## Each side of the same knee motor receives the opposite target.
func calves() -> float:
	return o - p


## Mutated or deserialized frames must meet the same contract as live inputs.
func is_valid() -> bool:
	for strength: float in [q, w, o, p]:
		if not is_finite(strength) or strength < 0.0 or strength > 1.0:
			return false
	return true
