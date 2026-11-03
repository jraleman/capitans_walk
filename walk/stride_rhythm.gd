extends RefCounted

## Contact edges bank points immediately; a fall breaks the combo, never the bank.

const MIN_STRIDE_TICKS := 54
const MAX_STRIDE_TICKS := 108
const GOOD_ANGLE := 15.0 * PI / 180.0
const BREAK_ANGLE := 30.0 * PI / 180.0
const STRIDE_POINTS := 10.0

var combo := 0
var best_combo := 0
var good_strides := 0
var plants := 0
var points := 0.0
var _feet: Array[bool] = [true, true]
var _driven_feet: Array[bool] = [false, false]
var _last_foot := -1
var _last_tick := -1


## New walks retain neither contact history nor a previous points bank.
func reset() -> void:
	combo = 0
	best_combo = 0
	good_strides = 0
	plants = 0
	points = 0.0
	_feet.fill(true)
	_driven_feet.fill(false)
	_last_foot = -1
	_last_tick = -1


## Returns happiness-earning strides; passive settling cannot farm points or a combo.
func observe(
	tick: int, feet: Array[bool], knee_contact: bool, torso_angle: float, powered: bool
) -> int:
	if tick < 0 or feet.size() != 2 or not is_finite(torso_angle):
		push_error("Capitan's Walk rhythm needs a fixed tick and finite contact state.")
		return 0
	if knee_contact or absf(torso_angle) > BREAK_ANGLE:
		combo = 0
	var happy_strides := 0
	for foot in 2:
		if not feet[foot]:
			_driven_feet[foot] = _driven_feet[foot] or powered
		if feet[foot] and not _feet[foot]:
			var interval := tick - _last_tick
			var driven := powered or _driven_feet[foot]
			var good := driven and not knee_contact and absf(torso_angle) <= GOOD_ANGLE \
				and _last_foot >= 0 and foot != _last_foot \
				and interval >= MIN_STRIDE_TICKS and interval <= MAX_STRIDE_TICKS
			combo = combo + 1 if good else 0
			best_combo = maxi(best_combo, combo)
			if driven:
				plants += 1
				points += STRIDE_POINTS * multiplier()
			if good:
				good_strides += 1
				if combo >= 5:
					happy_strides += 1
			_last_foot = foot
			_last_tick = tick
		if feet[foot]:
			_driven_feet[foot] = false
		_feet[foot] = feet[foot]
	return happy_strides


## Tiers apply on the stride that reaches their threshold, not on the next one.
func multiplier() -> float:
	if combo >= 50:
		return 4.0
	if combo >= 25:
		return 3.0
	if combo >= 12:
		return 2.0
	if combo >= 5:
		return 1.5
	return 1.0


## A named tier and numeric streak keep feedback independent of colour.
func tier() -> String:
	if combo >= 50:
		return "Best in Show"
	if combo >= 25:
		return "Parade"
	if combo >= 12:
		return "Swagger"
	if combo >= 5:
		return "Strut"
	return "Find the rhythm"


## Hidden contact and timing history are part of a deterministic walk.
func snapshot() -> Dictionary:
	return {
		"combo": combo, "best_combo": best_combo, "good_strides": good_strides,
		"plants": plants, "points": points, "feet": _feet.duplicate(),
		"driven_feet": _driven_feet.duplicate(),
		"last_foot": _last_foot, "last_tick": _last_tick,
	}
