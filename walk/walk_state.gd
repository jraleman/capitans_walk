extends RefCounted

## One fixed clock couples Capitan, the wrist-looped rope and the actual walker.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Profiles = preload("res://games/capitans_walk/walk/walker_profiles.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const DogProfiles = preload("res://games/capitans_walk/walk/dog_profiles.gd")
const Leash = preload("res://games/capitans_walk/walk/leash.gd")
const EasyLegs = preload("res://games/capitans_walk/walk/easy_legs.gd")
const Rhythm = preload("res://games/capitans_walk/walk/stride_rhythm.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")
const Hazards = preload("res://games/capitans_walk/walk/hazards.gd")
const REST_SPEED := 0.08
const WALKING_SPEED := 0.08
const SNIFF_REST_TICKS := 30
const NEAR_FALL_ANGLE := 60.0 * PI / 180.0
const YANK_TENSION := 40.0
const SNIFF_SPOTS: Array[Vector2] = [
	Vector2(4.0, 0.0), Vector2(12.0, 0.0), Vector2(20.0, 0.0), Vector2(28.0, 0.0),
]

var body: Body
var dog: Dog
var leash := Leash.new()
var rhythm := Rhythm.new()
var route: Route
var hazards := Hazards.new()
var easy_legs := false
var last_frame := InputFrame.new()
var peak_tension := 0.0
var near_falls := 0
var _easy := EasyLegs.new()
var _near_fall := false
var _rest_ticks := 0
var _accumulator := 0.0
var _terrain_revision := -1


func _init(
	walker: Profiles = null, walk_seed := 0, dog_profile: DogProfiles = null,
	park_route: Route = null
) -> void:
	body = Body.new(walker, walk_seed)
	dog = Dog.new(dog_profile)
	route = park_route
	leash.length = dog.profile.leash_length
	reset(walk_seed)


## Restart preserves the body's route and assists and repeats the same squirrel schedule.
func reset(walk_seed := 0) -> void:
	if dog.profile == null or not dog.profile.is_valid():
		push_error("Capitan's Walk reset requires a valid dog profile.")
		return
	if not is_finite(leash.length) or leash.length <= Leash.START_SLACK:
		push_error("Capitan's Walk walk requires a usable leash length.")
		return
	if route != null:
		if not route.is_valid():
			push_error("Capitan's Walk reset requires a valid route.")
			return
		route.reset(walk_seed)
		if not body.set_ground(route.ground(), route.surfaces()):
			return
		_terrain_revision = route.revision
	body.reset(walk_seed)
	leash.reset()
	dog.reset(walk_seed, hand_position(), leash.length)
	leash.update(hand_position(), dog.position, Vector2.ZERO, Vector2.ZERO)
	rhythm.reset()
	hazards.reset()
	_easy.reset()
	last_frame = InputFrame.new()
	peak_tension = 0.0
	near_falls = 0
	_near_fall = false
	_rest_ticks = 0
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
	if route != null:
		if not route.prepare(minf(body.positions[Body.HIP].x, dog.position.x) - 2.0,
			maxf(body.positions[Body.HIP].x, dog.position.x) + 2.0):
			return
		if route.revision != _terrain_revision:
			if not body.set_ground(route.ground(), route.surfaces()):
				return
			_terrain_revision = route.revision
	var hand := hand_position()
	var hand_velocity := Vector2(
		(body.positions[Body.HAND].x - body.previous[Body.HAND].x) / Body.STEP,
		body.z_velocity
	)
	if not leash.update(hand, dog.position, hand_velocity, dog.velocity):
		return
	if not easy_legs:
		_easy.reset()
	last_frame = _easy.compose(frame) if easy_legs else frame
	peak_tension = maxf(peak_tension, leash.tension)
	var hip_speed := (body.positions[Body.HIP].x - body.previous[Body.HIP].x) / Body.STEP
	var powered := absf(last_frame.thighs()) > Body.EPSILON \
		or absf(last_frame.calves()) > Body.EPSILON
	var resting := body.stance_count() == 2 \
		and absf(hip_speed) < REST_SPEED and absf(body.z_velocity) < REST_SPEED
	var walking := not resting and absf(hip_speed) > WALKING_SPEED
	_rest_ticks = _rest_ticks + 1 if resting else 0
	if _rest_ticks >= SNIFF_REST_TICKS:
		for spot in sniff_spots():
			dog.sniff_at(spot)
	hazards.step(body, dog, route, resting, _rest_ticks >= SNIFF_REST_TICKS)
	var grade := body.ground_slope(dog.position.x)
	var slope_force := Vector2(-dog.profile.mass * Body.GRAVITY * grade
		/ (1.0 + grade * grade), 0.0)
	dog.step(frame.whistle, hand, hand_velocity, -leash.force, leash.length,
		body.distance, walking, resting, slope_force, hazards.dog_target,
		hazards.focus_enabled, not hazards.is_busy())
	body.step(last_frame, Vector3(leash.force.x, 0.0, leash.force.y)
		+ external_force + hazards.walker_force)
	hazards.observe(body, route, dog)
	var happy_strides := rhythm.observe(body.ticks, body.foot_contacts,
		body.contacts[Body.LEFT_KNEE] or body.contacts[Body.RIGHT_KNEE],
		body.torso_angle(), powered)
	if happy_strides > 0:
		dog.change_happiness(float(happy_strides))
	_update_near_fall()


## The rope acts at the real hand's X and the body's lateral balance coordinate.
func hand_position() -> Vector2:
	return Vector2(body.positions[Body.HAND].x, body.z)


func sniff_spots() -> PackedVector2Array:
	return route.sniff_spots() if route != null else PackedVector2Array(SNIFF_SPOTS)


## Recall and dog warnings outrank moving encounters, which outrank passive surface data.
func cue_caption() -> String:
	if dog.is_warning() or dog.response_ticks > 0:
		return dog.caption()
	var encounter := hazards.moving_caption(dog)
	if not encounter.is_empty():
		return encounter
	if dog.state != Dog.TROT:
		return dog.caption()
	return hazards.caption(body)


## Distance remains the headline; points include only mechanics already present.
func final_score() -> int:
	return roundi(rhythm.points * dog.score_multiplier())


## Complete momentum, input edges, cooldowns and RNG state survive exact comparisons.
func snapshot() -> Dictionary:
	return {"body": body.snapshot(), "dog": dog.snapshot(), "leash": leash.snapshot(),
		"rhythm": rhythm.snapshot(), "easy_legs": easy_legs, "macro": _easy.snapshot(),
		"peak_tension": peak_tension, "near_falls": near_falls, "near_fall": _near_fall,
		"rest_ticks": _rest_ticks,
		"motor_strengths": [last_frame.q, last_frame.w, last_frame.o, last_frame.p],
		"accumulator": _accumulator, "route": route.snapshot() if route != null else {},
		"terrain_revision": _terrain_revision, "hazards": hazards.snapshot()}


func _update_near_fall() -> void:
	var dangerous := absf(body.torso_angle()) >= NEAR_FALL_ANGLE \
		or absf(body.z) >= body.half_width * 0.9
	if dangerous and not _near_fall and leash.tension >= YANK_TENSION:
		dog.change_happiness(-5.0)
		near_falls += 1
		_near_fall = true
	elif absf(body.torso_angle()) < Rhythm.BREAK_ANGLE \
		and absf(body.z) < body.half_width * 0.5:
		_near_fall = false


func _valid_frame(frame: InputFrame, external_force: Vector3) -> bool:
	if frame == null or not frame.is_valid() or not external_force.is_finite():
		push_error("Capitan's Walk requires a valid input frame and finite hand force.")
		return false
	if not dog.position.is_finite() or not dog.velocity.is_finite():
		push_error("Capitan's Walk dog position and velocity must be finite.")
		return false
	if dog.profile == null or not dog.profile.is_valid() \
		or not is_finite(dog.happiness) or dog.happiness < 0.0 or dog.happiness > 100.0 \
		or not is_finite(body.distance) or body.distance < 0.0:
		push_error("Capitan's Walk dog profile, happiness and distance must be valid.")
		return false
	if not is_finite(leash.length) or leash.length <= Leash.START_SLACK:
		push_error("Capitan's Walk walk requires a usable leash length.")
		return false
	return true
