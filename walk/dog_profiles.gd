extends RefCounted

## Capitan's authored parameters change the dog, never the walker's joint solver.

const SQUIRREL := &"squirrel"
const HYDRANT := &"hydrant"
const PIGEON := &"pigeon"
const FOOD := &"food"
const PROTEST := &"protest"
const MOODS: Array[StringName] = [SQUIRREL, HYDRANT, PIGEON, FOOD, PROTEST]

var id := &"dog_capitan"
var mass := 14.0
var collar_height := 0.32
var leash_length := 1.8
var trot_pull := 32.0
var track_spring := 22.0
var track_damping := 8.0
var max_drive := 280.0
var warning_ticks := 96
var interval_min := 1800
var interval_max := 2400
var distance_rate := 0.002
var sniff_fill := 4.0
var walking_drain := 1.0
var distraction_weights: Array[int] = [1, 1, 1, 1, 1]


## Invalid authored data must not reach division, force integration or the seeded picker.
func is_valid() -> bool:
	for value: float in [mass, collar_height, leash_length, trot_pull, track_spring,
		track_damping, max_drive, sniff_fill, walking_drain, distance_rate]:
		if not is_finite(value) or value < 0.0:
			return false
	if mass <= 0.0 or leash_length <= 0.3 or max_drive <= 0.0 \
		or warning_ticks <= 0 or interval_min <= 0 or interval_max < interval_min \
		or distraction_weights.size() != MOODS.size():
		return false
	var total := 0
	for weight in distraction_weights:
		if weight < 0:
			return false
		total += weight
	return total > 0
