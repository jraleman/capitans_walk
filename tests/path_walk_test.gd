extends SceneTree

## Exact path rules plus complete input-driven walks, without assigning progress or poses.

const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const PathWalk = preload("res://games/capitans_walk/walk/path_walk.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Frame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_scoring()
	_test_finish_priority()
	_test_steering_and_recall()
	_test_clocks()
	_test_complete_walks()
	if _failures.is_empty():
		print("Capitan's Walk first-person model tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_scoring() -> void:
	var path := PathWalk.new()
	path.reset(0)
	path.position.x = 1.0
	path.observe(Vector2(2.0, PathWalk.HALF_WIDTH))
	_expect(path.on_path and path.points == 101.0 and path.safe_distance == 1.0,
		"The inclusive visible edge earns exactly one point per forward metre.")
	for tick in PathWalk.GRACE_TICKS:
		path.observe(Vector2(2.0, PathWalk.HALF_WIDTH + 0.001))
	_expect(path.points == 101.0 and not path.is_draining() and path.excursions == 1,
		"One continuous second outside the dog path must be entirely free.")
	for tick in 120:
		path.observe(Vector2(2.0, -PathWalk.HALF_WIDTH - 0.001))
	_expect(is_equal_approx(path.points, 91.0) and is_equal_approx(path.points_lost, 10.0),
		"The second outside second must cost exactly ten points, on either side.")
	path.position.x = 2.0
	path.observe(Vector2.ZERO)
	_expect(is_equal_approx(path.points, 92.0) and path.off_path_ticks == 0,
		"Returning immediately stops draining, resets grace and resumes distance rewards.")
	path.position.x = 1.0
	path.observe(Vector2.ZERO)
	_expect(is_equal_approx(path.points, 92.0) and path.distance == 2.0,
		"Backtracking must not erase distance or farm another metre of points.")
	for tick in PathWalk.GRACE_TICKS:
		path.observe(Vector2(0.0, 2.0))
	_expect(is_equal_approx(path.points, 92.0) and path.excursions == 2,
		"A new excursion gets a new grace period, not the previous excursion's debt.")
	path.reset(0)
	_expect(path.points == 100.0 and path.distance == 0.0 and path.excursions == 0
		and path.off_path_ticks == 0 and not path.is_over(),
		"Restart must clear the complete scoring and excursion state.")


func _test_finish_priority() -> void:
	var path := PathWalk.new()
	path.reset(0)
	path.position.x = PathWalk.FINISH_DISTANCE + 0.5
	path.observe(Vector2.ZERO)
	_expect(path.end_cause == "finished" and path.distance == 200.0 and path.points == 300.0,
		"Crossing the finish caps rewarded distance and wins with remaining points.")
	path.reset(0)
	path.position.x = PathWalk.FINISH_DISTANCE
	path.points = 0.01
	path.off_path_ticks = PathWalk.GRACE_TICKS
	path.observe(Vector2(0.0, 2.0))
	_expect(path.end_cause == "points_depleted" and path.points == 0.0,
		"Depleting points on the finish tick is a loss, never a negative score or a win.")


func _test_steering_and_recall() -> void:
	var left := _walk()
	var right := _walk()
	var neutral := _walk()
	var opposed := _walk()
	var left_frame := Frame.new()
	left_frame.steer_left = 1.0
	var right_frame := Frame.new()
	right_frame.steer_right = 1.0
	var both := Frame.new()
	both.steer_left = 1.0
	both.steer_right = 1.0
	for tick in 240:
		left.step(left_frame)
		right.step(right_frame)
		neutral.step(Frame.new())
		opposed.step(both)
	_expect(left.dog.position.y < -0.02 and right.dog.position.y > 0.02,
		"Steering must move the collar through the rope, in the chosen direction.")
	_expect(left.path.applied_rope_force == left.leash.force
		and right.path.applied_rope_force == right.leash.force,
		"The first-person guide must receive the measured rope reaction.")
	_expect(neutral.snapshot() == opposed.snapshot(),
		"Opposing pulls must be physically identical to releasing the leash controls.")
	var walk := _walk()
	while walk.path.phase != PathWalk.Phase.INTEREST and walk.path.ticks < 2000:
		walk.step(Frame.new())
	_expect(walk.path.warnings == 1, "The first interest must have a real fixed-clock warning.")
	var whistle := Frame.new()
	whistle.whistle = true
	for tick in Dog.WHISTLE_RESPONSE_TICKS + 2:
		walk.step(whistle)
	_expect(walk.dog.recalls == 1 and walk.path.phase == PathWalk.Phase.QUIET,
		"Whistle must physically recall and cancel interest only after its response delay.")
	for tick in Dog.WHISTLE_COOLDOWN_TICKS + 5:
		walk.step(whistle)
	_expect(walk.dog.whistles == 1,
		"Holding Whistle beyond cooldown must never trigger automatic repeated recalls.")
	walk.step(Frame.new())
	walk.step(whistle)
	_expect(walk.dog.whistles == 2, "Releasing and pressing Whistle rearms the recall.")


func _test_clocks() -> void:
	var reference := _walk()
	var empty := Frame.new()
	for tick in 120 * 24:
		reference.step(empty)
	for fps in [30, 60, 144]:
		var candidate := _walk()
		for frame in fps * 24:
			candidate.advance(1.0 / fps, empty)
		var actual := candidate.snapshot()
		var expected := reference.snapshot()
		actual.erase("accumulator")
		expected.erase("accumulator")
		_expect(actual == expected, "Guided physics and scoring must match at %d FPS." % fps)
	var hitch := _walk()
	hitch.advance(3.0, empty)
	_expect(hitch.path.ticks == 360 and hitch.dog.ticks == 360,
		"A three-second hitch must not discard scoring, warning or motor ticks.")
	var frozen := hitch.snapshot()
	hitch.advance(0.0, empty)
	_expect(hitch.snapshot() == frozen, "Zero elapsed time must leave every coupled state frozen.")
	var invalid := Frame.new()
	invalid.steer_left = NAN
	hitch.advance(1.0, invalid)
	_expect(hitch.snapshot() == frozen, "Invalid steering must be rejected before either actor advances.")
	hitch.body.end_cause = "fall"
	hitch.step(empty)
	_expect(hitch.path.ticks == 361 and not hitch.is_over(),
		"Legacy human fall rules must not terminate the new dog-guidance game.")
	hitch.reset(0)
	_expect(hitch.snapshot() == _walk().snapshot(),
		"A same-seed restart must restore every motor, dog, path, timer and random state.")


func _test_complete_walks() -> void:
	var idle := _walk()
	for tick in 24000:
		if idle.is_over():
			break
		idle.step(Frame.new())
	_expect(idle.path.end_cause == "points_depleted" and idle.path.distance < 200.0,
		"Ignoring repeated distractions must eventually deplete points before the finish.")
	var final_state := idle.snapshot()
	idle.advance(30.0, Frame.new())
	_expect(idle.snapshot() == final_state, "A loss must freeze all coupled simulation state.")
	for seed_value in [0, 1, 731]:
		var guided := _walk(seed_value)
		for tick in 24000:
			if guided.is_over():
				break
			guided.step(guide_frame(guided))
		print("Guided seed %d: %.2f m / %.2f points / %.2f penalties / %s." % [
			seed_value, guided.path.distance, guided.path.points,
			guided.path.points_lost, guided.path.end_cause,
		])
		_expect(guided.path.end_cause == "finished" and guided.path.points > 0.0,
			"Readable leash steering must complete the real 200 m walk for seed %d." % seed_value)
		_expect(guided.dog.happiness == Dog.START_HAPPINESS,
			"Automatic pacing must not drain an invisible legacy sniff/happiness meter.")
		final_state = guided.snapshot()
		guided.advance(10.0, Frame.new())
		_expect(guided.snapshot() == final_state, "A win must freeze the walk as completely as a loss.")


## A reproducible player uses visible dog motion, not assigned positions or scores.
static func guide_frame(walk: Walk) -> Frame:
	var frame := Frame.new()
	var pull := clampf(-walk.dog.position.y * 2.8 - walk.dog.velocity.y * 0.8, -1.0, 1.0)
	frame.steer_left = maxf(0.0, -pull)
	frame.steer_right = maxf(0.0, pull)
	return frame


func _walk(seed_value := 0) -> Walk:
	return Walk.new(null, seed_value, null, Route.new(), true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
