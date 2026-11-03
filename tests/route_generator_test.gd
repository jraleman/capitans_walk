extends SceneTree

## Route rules, real contacts and the coupled clock, without nodes or a physics server.

const Route = preload("res://games/capitans_walk/walk/route_generator.gd")
const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Hazards = preload("res://games/capitans_walk/walk/hazards.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_authored_data()
	_test_seeded_rules()
	_test_streaming()
	_test_puddle_contacts()
	_test_slope_coupling()
	_test_clock_and_reset()
	_test_physical_walk()
	if _failures.is_empty():
		print("Capitan's Walk route tests passed (seeded rules; surfaces; coupled clock).")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_authored_data() -> void:
	var pool := Chunks.park_pool()
	for chunk in pool:
		_expect(Chunks.validation_error(chunk).is_empty(),
			"Every authored Park chunk must satisfy geometry, surface, slot and safety rules.")
	var bad := pool[2].duplicate(true)
	bad["ground"][2].y = 0.30
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject excessive height changes.")
	bad = pool[2].duplicate(true)
	bad["ground"][2].x = bad["ground"][1].x
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject non-increasing ground X.")
	bad = pool[1].duplicate(true)
	bad["sniffs"] = PackedVector2Array([Vector2(12.0, 0.0)])
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject hazards beside sniff spots.")
	bad = pool[2].duplicate(true)
	bad["sniffs"] = PackedVector2Array([Vector2(8.0, 0.0)])
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject slopes beside sniff spots.")
	bad = pool[1].duplicate(true)
	bad["surfaces"][0]["friction"] = NAN
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject nonfinite surface data.")
	bad = pool[0].duplicate(true)
	bad["items"] = [{"kind": &"treat", "position": Vector2(21.0, 0.0)}]
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject out-of-bounds item slots.")
	bad = pool[1].duplicate(true)
	bad["hazards"][0]["kind"] = &"banana_peel"
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject unimplemented hazard kinds.")
	bad = pool[-1].duplicate(true)
	bad["hazards"][0]["side"] = NAN
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject nonfinite moving-hazard sides.")
	bad = pool[8].duplicate(true)
	bad["hazards"][1]["from"] = 13.0
	_expect(not Chunks.validation_error(bad).is_empty(), "Reject cramped hazard intervals.")


func _test_seeded_rules() -> void:
	var sequences: Array[PackedStringArray] = []
	for seed_value: int in [0, 1, 731, 20261103]:
		var route := Route.new(seed_value)
		var reference := Route.new(seed_value)
		var sequence := PackedStringArray()
		var sniffs := PackedVector2Array()
		var hazards: Array[Dictionary] = []
		var markers: Array[Dictionary] = []
		var previous_end := Vector2.ZERO
		for index in 201:
			var chunk := route.chunk_at(index)
			var points: PackedVector2Array = chunk["ground"]
			_expect(points[0] == previous_end,
				"Generated chunks must join without duplicate-X steps or height discontinuities.")
			previous_end = points[-1]
			sequence.append(chunk["id"])
			sniffs.append_array(chunk["sniffs"])
			for hazard: Dictionary in chunk["hazards"]:
				_expect(int(chunk["tier"]) <= Route.tier_at(float(hazard["from"])),
					"Higher-tier terrain cannot start before its authored distance band.")
				hazards.append(hazard)
			for marker: Dictionary in chunk["reservations"]:
				markers.append(marker)
		for index in range(1, sniffs.size()):
			_expect(sniffs[index].x - sniffs[index - 1].x <= Chunks.MAX_SNIFF_GAP,
				"Even adjacent event/boss reservations must leave a sniff spot every forty metres.")
		for spot in sniffs:
			for hazard in hazards:
				_expect(spot.x <= float(hazard["from"]) - Chunks.SNIFF_CLEARANCE \
					or spot.x >= float(hazard["to"]) + Chunks.SNIFF_CLEARANCE,
					"Sniff clearance must include hazard widths and neighbouring chunk seams.")
			for marker in markers:
				_expect(absf(spot.x - float(marker["distance"])) >= Chunks.SNIFF_CLEARANCE,
					"Seed %d: reserved %.0f m must stay clear of sniff %.0f m." % [
						seed_value, marker["distance"], spot.x,
					])
		for index in range(1, hazards.size()):
			_expect(float(hazards[index]["from"]) - float(hazards[index - 1]["to"]) \
				>= Chunks.hazard_spacing(Route.tier_at(float(hazards[index]["from"]))),
				"Tier spacing must hold between hazard intervals across chunk seams.")
		for kind in [&"event", &"boss"]:
			var found := 0
			var interval := Route.EVENT_INTERVAL if kind == &"event" else Route.BOSS_INTERVAL
			for marker in markers:
				if marker["kind"] == kind:
					found += 1
					_expect(float(marker["distance"]) == found * interval,
						"Set-piece reservations must appear once at each authored interval.")
			_expect(found == floori(4020.0 / interval),
				"Reserved spaces must remain endless, including coincident event/boss distances.")
		sequences.append(sequence)
		for index in range(200, -1, -1):
			_expect(route.chunk_at(index) == reference.chunk_at(index),
				"Preview and reverse query order cannot consume or change route randomness.")
	_expect(sequences[0] != sequences[1] and sequences[1] != sequences[2],
		"Different seeds must produce different Park sequences, not only different metadata.")


func _test_streaming() -> void:
	var route := Route.new(731)
	var fresh := route.snapshot()
	var untouched := route.chunk_at(3)
	var edited := route.chunk_at(3)
	edited["ground"][0].y = 100.0
	_expect(route.chunk_at(3) == untouched, "Chunk callers must not mutate authored templates.")
	for distance in range(0, 20001, 1000):
		_expect(route.prepare(float(distance) - 2.0, float(distance) + 4.0),
			"Streaming must accept forward travel without a route length limit.")
		_expect(route.visible_chunks().size() <= 7,
			"Streaming must evict old chunks instead of accumulating the whole travelled path.")
		var ground := route.ground()
		for point in range(1, ground.size()):
			_expect(ground[point].x > ground[point - 1].x,
				"Shared seam vertices must be deduplicated before the contact solver reads them.")
	_expect(route.prepare(-2.0, 4.0) and route.visible_chunks() == fresh["chunks"],
		"Backtracking must reconstruct the original terrain without saving all old chunks.")
	var copied := route.visible_chunks()
	copied[0]["ground"][0].y = 100.0
	_expect(route.visible_chunks() == fresh["chunks"], "Renderer copies must not change terrain.")
	var before := route.snapshot()
	_expect(not route.prepare(NAN, 4.0) and route.snapshot() == before,
		"Invalid bounds must be rejected before altering any streaming state.")
	_expect(not route.prepare(4.0, -2.0) and route.snapshot() == before,
		"Reversed bounds must not silently swap or discard the current route.")
	route.reset(731)
	_expect(route.snapshot() == fresh, "Restart must reproduce the complete streaming window.")


func _test_puddle_contacts() -> void:
	var route := Route.new(731)
	var puddle := _find_hazard(route, Chunks.PUDDLE)
	if puddle.is_empty():
		_expect(false, "The seeded Park fixture needs an actual authored puddle.")
		return
	var x := (float(puddle["from"]) + float(puddle["to"])) * 0.5
	route.prepare(x - 2.0, x + 4.0)
	var dry := Body.new()
	var wet := Body.new()
	dry.set_ground(route.ground())
	wet.set_ground(route.ground(), route.surfaces())
	for body in [dry, wet]:
		_shift_body(body, Vector2(x, 0.0))
		for particle in Body.PARTICLE_COUNT:
			body.previous[particle].x -= 2.0 * Body.STEP
	for tick in 60:
		dry.step(InputFrame.new())
		wet.step(InputFrame.new())
	var dry_feet := dry.positions[Body.LEFT_ANKLE].x + dry.positions[Body.RIGHT_ANKLE].x
	var wet_feet := wet.positions[Body.LEFT_ANKLE].x + wet.positions[Body.RIGHT_ANKLE].x
	_expect(wet_feet > dry_feet + 0.01 and wet.ground_friction(x) == 0.30
		and wet.ground_friction(float(puddle["to"])) == Body.GROUND_FRICTION,
		"An authored puddle must physically slide more, only within its half-open width.")
	var planted := Body.new()
	planted.set_ground(route.ground(), route.surfaces())
	_shift_body(planted, Vector2(x, 0.0))
	var feedback := Hazards.new()
	for tick in 240:
		planted.step(InputFrame.new())
		feedback.observe(planted, route)
	var splashes := feedback.splashes
	for tick in 120:
		planted.step(InputFrame.new())
		feedback.observe(planted, route)
	_expect(splashes == 2 and feedback.splashes == splashes
		and feedback.caption(planted).contains("PUDDLE"),
		"Real wet shoe-contact edges must splash once, not every planted tick.")
	print("Park puddle: %.3f m extra summed ankle slide; %d planted splashes." % [
		wet_feet - dry_feet, feedback.splashes,
	])


func _test_slope_coupling() -> void:
	var route := Route.new(731)
	var slope := _find_hazard(route, Chunks.SLOPE)
	if slope.is_empty():
		_expect(false, "The seeded Park fixture needs an actual authored slope.")
		return
	var walk := Walk.new(null, 731, null, route)
	_place_walk(walk, float(slope["from"]) - 1.5)
	var grade := walk.body.ground_slope(walk.dog.position.x)
	var expected := Dog.new()
	expected.reset(731, walk.hand_position(), walk.leash.length)
	var flat := Dog.new()
	flat.reset(731, walk.hand_position(), walk.leash.length)
	var gravity := Vector2(-walk.dog.profile.mass * Body.GRAVITY * grade
		/ (1.0 + grade * grade), 0.0)
	expected.step(false, walk.hand_position(), Vector2.ZERO, Vector2.ZERO,
		walk.leash.length, 0.0, false, true, gravity)
	flat.step(false, walk.hand_position(), Vector2.ZERO, Vector2.ZERO, walk.leash.length)
	walk.step(InputFrame.new())
	_expect(absf(grade) > 0.0 and walk.dog.snapshot() == expected.snapshot()
		and signf(walk.dog.velocity.x - flat.velocity.x) == -signf(grade),
		"Slope gravity must reach the real collar, separately from happiness-scaled drive and rope.")


func _test_clock_and_reset() -> void:
	var states: Array[Dictionary] = []
	for fps: int in [30, 60, 144]:
		var walk := Walk.new(null, 731, null, Route.new())
		var puddle := _find_hazard(walk.route, Chunks.PUDDLE)
		_place_walk(walk, (float(puddle["from"]) + float(puddle["to"])) * 0.5)
		for frame in fps * 15:
			walk.advance(1.0 / fps, InputFrame.new())
		var snapshot := walk.snapshot()
		snapshot.erase("accumulator")
		states.append(snapshot)
		_expect(walk.body.ticks > 120 and walk.hazards.splashes > 0,
			"Frame-rate comparisons must actually advance wet contacts and coupled dog events.")
	_expect(states[0] == states[1] and states[0] == states[2],
		"30/60/144 FPS must reproduce terrain windows, splashes, physical state and dog RNG.")
	var hitched := Walk.new(null, 731, null, Route.new())
	var stepped := Walk.new(null, 731, null, Route.new())
	hitched.advance(3.0, InputFrame.new())
	for tick in 360:
		stepped.step(InputFrame.new())
	var hitch_state := hitched.snapshot()
	var step_state := stepped.snapshot()
	hitch_state.erase("accumulator")
	step_state.erase("accumulator")
	_expect(hitch_state == step_state, "A hitch must not skip route or terrain clock state.")
	stepped.body.z = 0.5
	stepped.step(InputFrame.new())
	var ended := stepped.snapshot()
	stepped.advance(30.0, InputFrame.new(1.0))
	_expect(stepped.snapshot() == ended, "An ending must freeze route streaming and surface events.")
	stepped.reset(731)
	_expect(stepped.snapshot() == Walk.new(null, 731, null, Route.new()).snapshot(),
		"Same-seed Restart must reset terrain, sniff spots, splashes and both physical endpoints.")
	stepped.reset(732)
	_expect(stepped.snapshot() == Walk.new(null, 732, null, Route.new()).snapshot(),
		"A new walk seed must reach both the route and the dog's independent generator.")


func _test_physical_walk() -> void:
	var walk := Walk.new(null, 1, null, Route.new())
	var initial_revision := walk.route.revision
	for tick in 28800:
		var frame := WalkerTests.gait(tick)
		frame.whistle = walk.dog.is_warning()
		walk.step(frame)
		if walk.body.is_over() or walk.hazards.splashes > 0:
			break
	_expect(walk.body.distance > Chunks.LENGTH and walk.route.revision > initial_revision
		and walk.body.max_bone_error() < 0.035 and walk.hazards.splashes > 0,
		"A genuine authored gait must leave the opening chunk and reach a generated puddle.")
	print("Seeded Park gait: %.2f m / %d ticks / %d splashes / end=%s." % [
		walk.body.distance, walk.body.ticks, walk.hazards.splashes, walk.body.end_cause,
	])


static func _find_hazard(route: Route, kind: StringName) -> Dictionary:
	for index in range(1, 201):
		for hazard: Dictionary in route.chunk_at(index)["hazards"]:
			if hazard["kind"] == kind:
				return hazard
	return {}


## These are explicit terrain unit fixtures, not a claimed walk or production translation.
static func _place_walk(walk: Walk, x: float) -> void:
	walk.route.prepare(x - 2.0, x + 4.0)
	walk.body.set_ground(walk.route.ground(), walk.route.surfaces())
	_shift_body(walk.body, Vector2(x, walk.body.ground_height(x)))
	walk.dog.reset(walk.body.seed_value, walk.hand_position(), walk.leash.length)


static func _shift_body(body: Body, offset: Vector2) -> void:
	for particle in Body.PARTICLE_COUNT:
		body.positions[particle] += offset
		body.previous[particle] += offset


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
