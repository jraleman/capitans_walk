extends RefCounted

## First-person pacing, leash-hand motors and path rules share Walk's fixed clock.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const FINISH_DISTANCE := 200.0
const HALF_WIDTH := 0.9
const START_POINTS := 100.0
const POINTS_PER_METRE := 1.0
const PENALTY_PER_SECOND := 10.0
const GRACE_TICKS := 120
const PACE := 1.6
const MASS := 70.0
const HAND_REACH := 1.15
const WARNING_TICKS := 120
const INTEREST_TICKS := 840
const INTEREST_NAMES := ["SQUIRREL", "PIGEONS", "FRIENDLY DOG"]

enum Phase { QUIET, WARNING, INTEREST }

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var hand_offset := 0.0
var hand_speed := 0.0
var applied_rope_force := Vector2.ZERO
var distance := 0.0
var points := START_POINTS
var safe_distance := 0.0
var points_lost := 0.0
var off_path_ticks := 0
var total_off_path_ticks := 0
var excursions := 0
var on_path := true
var ticks := 0
var end_cause := ""
var phase := Phase.QUIET
var phase_ticks := 0
var warnings := 0
var interest_kind := 0
var interest_side := 1.0
var interest_position := Vector2.ZERO
var long_warnings := false:
	set(value):
		if value != long_warnings and phase == Phase.WARNING:
			phase_ticks = phase_ticks * 2 if value else ceili(float(phase_ticks) / 2.0)
		long_warnings = value
var _next_interest := 8.0
var _recalls := 0
var _random := RandomNumberGenerator.new()


func reset(walk_seed: int) -> void:
	position = Vector2.ZERO
	velocity = Vector2.ZERO
	hand_offset = 0.0
	hand_speed = 0.0
	applied_rope_force = Vector2.ZERO
	distance = 0.0
	points = START_POINTS
	safe_distance = 0.0
	points_lost = 0.0
	off_path_ticks = 0
	total_off_path_ticks = 0
	excursions = 0
	on_path = true
	ticks = 0
	end_cause = ""
	phase = Phase.QUIET
	phase_ticks = 0
	warnings = 0
	interest_kind = 0
	interest_side = 1.0
	interest_position = Vector2.ZERO
	_next_interest = 8.0
	_recalls = 0
	_random.seed = walk_seed


## Ground-limited motors move the guide; the rope still reacts on the human.
func integrate(steering: float, rope_force: Vector2, grade: float, friction: float) -> void:
	ticks += 1
	applied_rope_force = rope_force
	var motor := MASS * Vector2(6.0 * (PACE - velocity.x),
		-32.0 * position.y - 10.0 * velocity.y)
	motor = motor.limit_length(MASS * Body.GRAVITY * friction)
	var slope_force := Vector2(-MASS * Body.GRAVITY * grade / (1.0 + grade * grade), 0.0)
	velocity += (motor + rope_force + slope_force) / MASS * Body.STEP
	position += velocity * Body.STEP
	hand_speed += (70.0 * (steering * HAND_REACH - hand_offset)
		- 16.0 * hand_speed) * Body.STEP
	hand_offset += hand_speed * Body.STEP


func hand_position() -> Vector2:
	return position + Vector2(0.55, hand_offset)


func hand_velocity() -> Vector2:
	return velocity + Vector2(0.0, hand_speed)


## A completed recall cancels interest, not merely a pressed key or a cooldown.
func update_interest(recalls: int) -> void:
	if recalls != _recalls:
		_recalls = recalls
		_finish_interest()
		return
	if phase == Phase.QUIET:
		if distance < _next_interest or distance > FINISH_DISTANCE - 8.0:
			return
		interest_kind = 0 if warnings == 0 else _random.randi_range(0, 2)
		interest_side = -1.0 if _random.randi_range(0, 1) == 0 else 1.0
		phase = Phase.WARNING
		phase_ticks = WARNING_TICKS * (2 if long_warnings else 1)
		warnings += 1
	else:
		phase_ticks -= 1
		if phase_ticks <= 0:
			if phase == Phase.WARNING:
				phase = Phase.INTEREST
				phase_ticks = INTEREST_TICKS
			else:
				_finish_interest()
	interest_position = Vector2(position.x + 4.0, interest_side * 2.7)


## Score the dog's centre against the same edges the 3D path draws, never the human.
func observe(collar: Vector2) -> void:
	var next_distance := clampf(maxf(distance, position.x), 0.0, FINISH_DISTANCE)
	var travelled := next_distance - distance
	distance = next_distance
	var inside := absf(collar.y) <= HALF_WIDTH
	if inside:
		off_path_ticks = 0
		safe_distance += travelled
		points += travelled * POINTS_PER_METRE
	else:
		if on_path:
			excursions += 1
		off_path_ticks += 1
		total_off_path_ticks += 1
		if off_path_ticks > GRACE_TICKS:
			var loss := minf(points, PENALTY_PER_SECOND * Body.STEP)
			points_lost += loss
			points = maxf(0.0, points - loss)
	on_path = inside
	if points <= Body.EPSILON:
		points = 0.0
		end_cause = "points_depleted"
	elif distance >= FINISH_DISTANCE:
		end_cause = "finished"


func is_over() -> bool:
	return not end_cause.is_empty()


func is_draining() -> bool:
	return off_path_ticks > GRACE_TICKS and not on_path


func grace_seconds() -> float:
	return maxi(0, GRACE_TICKS - off_path_ticks) * Body.STEP


func interest_caption() -> String:
	var side := "LEFT" if interest_side < 0.0 else "RIGHT"
	var counter := "RIGHT" if interest_side < 0.0 else "LEFT"
	if phase == Phase.WARNING:
		return "%s %s / %.1f S / STEER %s" % [
			INTEREST_NAMES[interest_kind], side, phase_ticks * Body.STEP, counter,
		]
	if phase == Phase.INTEREST:
		return "%s %s / STEER %s OR WHISTLE" % [
			INTEREST_NAMES[interest_kind], side, counter,
		]
	return ""


func status_caption() -> String:
	if end_cause == "finished":
		return "WALK COMPLETE / CAPITAN MADE IT!"
	if end_cause == "points_depleted":
		return "OUT OF POINTS / TRY THE WALK AGAIN"
	if on_path:
		return "ON PATH / +1 POINT PER METRE"
	if is_draining():
		return "OFF PATH! / -10 POINTS PER SECOND"
	return "OFF PATH! / %.1f S TO RETURN" % grace_seconds()


func is_valid() -> bool:
	for value: float in [hand_offset, hand_speed, distance, points, safe_distance, points_lost]:
		if not is_finite(value):
			return false
	return position.is_finite() and velocity.is_finite() and distance >= 0.0 \
		and points >= 0.0 and safe_distance >= 0.0 and points_lost >= 0.0


func snapshot() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "hand_offset": hand_offset,
		"hand_speed": hand_speed, "rope_force": applied_rope_force,
		"distance": distance, "points": points, "safe_distance": safe_distance,
		"points_lost": points_lost, "off_path_ticks": off_path_ticks,
		"total_off_path_ticks": total_off_path_ticks, "excursions": excursions,
		"on_path": on_path, "ticks": ticks, "end_cause": end_cause,
		"phase": phase, "phase_ticks": phase_ticks, "warnings": warnings,
		"interest_kind": interest_kind, "interest_side": interest_side,
		"interest_position": interest_position, "long_warnings": long_warnings,
		"next_interest": _next_interest, "recalls": _recalls, "random": _random.state,
	}


func _finish_interest() -> void:
	phase = Phase.QUIET
	phase_ticks = 0
	_next_interest = distance + _random.randf_range(8.0, 12.0)
