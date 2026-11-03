extends RefCounted

## One fixed clock couples Capitan, the wrist-looped rope and the actual walker.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Profiles = preload("res://games/capitans_walk/walk/walker_profiles.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Leash = preload("res://games/capitans_walk/walk/leash.gd")

var body: Body
var dog := Dog.new()
var leash := Leash.new()
var peak_tension := 0.0
var _accumulator := 0.0


func _init(walker: Profiles = null, walk_seed := 0) -> void:
	body = Body.new(walker, walk_seed)
	reset(walk_seed)


## Restart preserves the body's route and assists and repeats the same squirrel schedule.
func reset(walk_seed := 0) -> void:
	if not is_finite(leash.length) or leash.length <= Leash.START_SLACK:
		push_error("Capitan's Walk walk requires a usable leash length.")
		return
	body.reset(walk_seed)
	leash.reset()
	dog.reset(walk_seed, hand_position(), leash.length)
	leash.update(hand_position(), dog.position, Vector2.ZERO, Vector2.ZERO)
	peak_tension = 0.0
	_accumulator = 0.0


## No render hitch discards time, and pause stops the caller rather than a second clock.
func advance(delta: float, frame: InputFrame, external_force := Vector3.ZERO) -> void:
	if not is_finite(delta) or delta < 0.0:
		push_error("Capitan's Walk requires a finite, nonnegative frame duration.")
		return
	if not _valid_frame(frame, external_force) or body.is_over():
		return
	_accumulator += delta
	while _accumulator + Body.EPSILON >= Body.STEP and not body.is_over():
		_accumulator = maxf(0.0, _accumulator - Body.STEP)
		step(frame, external_force)


## Both endpoints receive the same measured force on the same tick, with opposite signs.
func step(frame: InputFrame, external_force := Vector3.ZERO) -> void:
	if not _valid_frame(frame, external_force) or body.is_over():
		return
	var hand := hand_position()
	var hand_velocity := Vector2(
		(body.positions[Body.HAND].x - body.previous[Body.HAND].x) / Body.STEP,
		body.z_velocity
	)
	if not leash.update(hand, dog.position, hand_velocity, dog.velocity):
		return
	peak_tension = maxf(peak_tension, leash.tension)
	dog.step(frame.whistle, hand, hand_velocity, -leash.force, leash.length)
	body.step(frame, Vector3(leash.force.x, 0.0, leash.force.y) + external_force)


## The rope acts at the real hand's X and the body's lateral balance coordinate.
func hand_position() -> Vector2:
	return Vector2(body.positions[Body.HAND].x, body.z)


## Complete momentum, input edges, cooldowns and RNG state survive exact comparisons.
func snapshot() -> Dictionary:
	return {"body": body.snapshot(), "dog": dog.snapshot(), "leash": leash.snapshot(),
		"peak_tension": peak_tension, "accumulator": _accumulator}


func _valid_frame(frame: InputFrame, external_force: Vector3) -> bool:
	if frame == null or not frame.is_valid() or not external_force.is_finite():
		push_error("Capitan's Walk requires a valid input frame and finite hand force.")
		return false
	if not dog.position.is_finite() or not dog.velocity.is_finite():
		push_error("Capitan's Walk dog position and velocity must be finite.")
		return false
	if not is_finite(leash.length) or leash.length <= Leash.START_SLACK:
		push_error("Capitan's Walk walk requires a usable leash length.")
		return false
	return true
