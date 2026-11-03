extends SceneTree

## One clock must preserve both endpoint momentum, seeded events and frozen results.

const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")
const Rhythm = preload("res://games/capitans_walk/walk/stride_rhythm.gd")
const EasyLegs = preload("res://games/capitans_walk/walk/easy_legs.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_coupling()
	_test_fixed_determinism()
	_test_frame_rates()
	_test_end_and_reset()
	_test_easy_legs()
	_test_rhythm()
	_test_rhythm_boundaries()
	_test_sniff_spot()
	_test_near_fall()
	_test_invalid_dog_state()
	if _failures.is_empty():
		print("Capitan's Walk walk state tests passed (determinism; assists; rhythm; happiness).")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_coupling() -> void:
	var walk := Walk.new(null, 731)
	walk.dog.position = walk.hand_position() + Vector2(2.2, 0.5)
	var reference := Walk.new(null, 731)
	reference.dog.position = walk.dog.position
	reference.leash.update(reference.hand_position(), reference.dog.position,
		Vector2.ZERO, reference.dog.velocity)
	var force := reference.leash.force
	reference.dog.step(false, reference.hand_position(), Vector2.ZERO,
		-force, reference.leash.length)
	reference.body.step(InputFrame.new(), Vector3(force.x, 0.0, force.y))
	walk.step(InputFrame.new())
	_expect(walk.body.snapshot() == reference.body.snapshot()
		and walk.dog.snapshot() == reference.dog.snapshot(),
		"The hand and collar must receive equal/opposite X/Z force on the same tick.")


func _test_fixed_determinism() -> void:
	var first := Walk.new(null, 731)
	var second := Walk.new(null, 731)
	for tick in 7200:
		var frame := WalkerTests.gait(tick) if tick < 360 else InputFrame.new()
		frame.whistle = first.dog.state == Dog.SQUIRREL_LUNGE
		first.step(frame)
		second.step(frame)
		_expect(first.snapshot() == second.snapshot(),
			"Identical inputs must reproduce body, rope, dog, cooldown and RNG state.")
	_expect(first.body.ticks == 7200 and first.dog.ticks == 7200
		and first.dog.telegraphs > 1 and first.dog.recalls > 0,
		"The comparison must exercise a live 60-second walk with real recalls and distractions.")


func _test_frame_rates() -> void:
	for easy in [false, true]:
		var states: Array[Dictionary] = []
		for fps: int in [30, 60, 144]:
			var walk := Walk.new(null, 731)
			walk.easy_legs = easy
			for frame in fps * 15:
				var input := InputFrame.new()
				if walk.body.ticks < 360:
					if easy:
						var left := (walk.body.ticks / 24) % 2 == 0
						input.easy_left = 1.0 if left else 0.0
						input.easy_right = 0.0 if left else 1.0
					else:
						input = WalkerTests.gait(walk.body.ticks)
				walk.advance(1.0 / float(fps), input)
			_expect(walk.body.ticks == 1800 and walk.dog.telegraphs > 0,
				"Render-rate checks must advance a moving walk through a squirrel lunge.")
			var snapshot := walk.snapshot()
			snapshot.erase("accumulator")
			states.append(snapshot)
		_expect(states[0] == states[1] and states[0] == states[2],
			"30/60/144 FPS must agree on physical state, happiness, scoring and Easy phases.")
	var hitched := Walk.new(null, 731)
	hitched.advance(3.0, InputFrame.new())
	var stepped := Walk.new(null, 731)
	for tick in 360:
		stepped.step(InputFrame.new())
	var hitched_state := hitched.snapshot()
	var stepped_state := stepped.snapshot()
	hitched_state.erase("accumulator")
	stepped_state.erase("accumulator")
	_expect(hitched.body.ticks == 360 and hitched.dog.ticks == 360
		and hitched_state == stepped_state,
		"A three-second hitch must not discard physics, dog, rhythm or happiness time.")


func _test_end_and_reset() -> void:
	var walk := Walk.new(null, 731)
	walk.body.steady = 0.4
	walk.easy_legs = true
	walk.dog.long_warnings = true
	for tick in 240:
		walk.step(InputFrame.new(0.0, 0.0, 0.0, 0.0, tick == 0))
	walk.body.z = 0.5
	walk.step(InputFrame.new())
	var ended := walk.snapshot()
	walk.advance(6.0, InputFrame.new(1.0, 0.0, 1.0, 0.0, true))
	_expect(walk.body.is_over() and walk.snapshot() == ended,
		"Results must freeze Capitan, rope, cooldown and the next distraction too.")
	walk.reset(731)
	var fresh := Walk.new(null, 731)
	fresh.body.steady = 0.4
	fresh.easy_legs = true
	fresh.dog.long_warnings = true
	_expect(walk.snapshot() == fresh.snapshot(),
		"Same-seed restart must reset every coupled state while preserving assists.")


func _test_easy_legs() -> void:
	var classic := Walk.new(null, 731)
	var easy := Walk.new(null, 731)
	easy.easy_legs = true
	for tick in 3600:
		var whistle := classic.dog.is_warning()
		var four_keys := WalkerTests.gait(tick)
		four_keys.whistle = whistle
		var left := (tick / (EasyLegs.PHASE_TICKS * 2)) % 2 == 0
		var two_keys := InputFrame.new(0.0, 0.0, 0.0, 0.0, whistle,
			1.0 if left else 0.0, 0.0 if left else 1.0)
		classic.step(four_keys)
		easy.step(two_keys)
		_expect(classic.body.snapshot() == easy.body.snapshot()
			and classic.dog.snapshot() == easy.dog.snapshot(),
			"The two-key macro must drive the actual four-key gait, not move a pose.")
	_expect(not easy.body.is_over() and easy.body.ticks == 3600
		and easy.body.distance > 1.0 and easy.body.distance >= classic.body.distance
		and easy.final_score() == classic.final_score(),
		"A live Easy-legs walk must reach at least its equivalent four-key distance.")
	print("Easy legs: %.2f m / four keys: %.2f m / %d points" % [
		easy.body.distance, classic.body.distance, easy.final_score(),
	])
	var macro := EasyLegs.new()
	var both := macro.compose(InputFrame.new(1.0, 0.0, 1.0, 0.0, true, 1.0, 1.0))
	_expect(both.thighs() == 0.0 and both.calves() == 0.0 and both.whistle,
		"Opposing macro controls must cancel without blocking Whistle.")
	for tick in EasyLegs.PHASE_TICKS * 2 + 10:
		both = macro.compose(InputFrame.new(0.0, 0.0, 0.0, 0.0, false, 1.0, 0.0))
	_expect(both.thighs() == 0.0 and both.calves() == 0.0,
		"Holding an Easy key must finish one stride, not become an automatic walk.")
	macro.compose(InputFrame.new())
	both = macro.compose(InputFrame.new(0.0, 0.0, 0.0, 0.0, false, 1.0, 0.0))
	_expect(both.q == 1.0 and both.o == 1.0,
		"Release and a fresh leg choice must start another authored stride.")
	both = macro.compose(InputFrame.new(0.0, 0.75, 0.0, 0.75))
	_expect(both.w == 0.75 and both.p == 0.75,
		"Releasing Easy keys must immediately allow the original manual brace.")


func _plant(
	rhythm: Rhythm, foot: int, tick: int, angle := 0.0,
	knee := false, powered := true
) -> int:
	rhythm.observe(tick - 1, [false, false], knee, angle, powered)
	return rhythm.observe(tick, [foot == 0, foot == 1], knee, angle, powered)


func _test_rhythm() -> void:
	var rhythm := Rhythm.new()
	var happy_strides := 0
	for index in 51:
		happy_strides += _plant(rhythm, index % 2, 120 + index * 72)
	_expect(rhythm.combo == 50 and rhythm.best_combo == 50
		and rhythm.multiplier() == 4.0 and rhythm.tier() == "Best in Show"
		and rhythm.points == 1205.0 and happy_strides == 46,
		"All four tiers must bank their multiplier on the threshold stride and reward 5+ combos.")
	var bank := rhythm.points
	rhythm.observe(4000, [true, false], true, 0.0, false)
	_expect(rhythm.combo == 0 and rhythm.best_combo == 50 and rhythm.points == bank,
		"Kneeling breaks the live combo but must not erase already banked points.")
	var walk := Walk.new()
	walk.rhythm.points = bank
	walk.dog.happiness = 100.0
	_expect(walk.final_score() == 2410,
		"The final happiness multiplier must apply to the bank once, not to every tick.")
	walk.body.end_cause = "fall"
	var ended := walk.snapshot()
	walk.advance(10.0, InputFrame.new())
	_expect(walk.final_score() == 2410 and walk.snapshot() == ended,
		"A fall must freeze banked score, happiness and verdict until Restart.")


func _test_rhythm_boundaries() -> void:
	var rhythm := Rhythm.new()
	_plant(rhythm, 0, 120)
	_plant(rhythm, 1, 174, Rhythm.GOOD_ANGLE)
	_plant(rhythm, 0, 282, -Rhythm.GOOD_ANGLE)
	_expect(rhythm.combo == 2,
		"Alternating plants at exactly 0.45/0.9 seconds and +/-15 degrees must qualify.")
	_plant(rhythm, 1, 335)
	_expect(rhythm.combo == 0, "A plant one fixed tick too early must break the rhythm.")
	_plant(rhythm, 0, 407)
	_plant(rhythm, 1, 516)
	_expect(rhythm.combo == 0, "A plant one fixed tick too late must break the rhythm.")
	_plant(rhythm, 0, 588)
	_plant(rhythm, 0, 660)
	_expect(rhythm.combo == 0, "Two plants on the same foot must break the combo.")
	_plant(rhythm, 1, 732, deg_to_rad(16.0))
	_expect(rhythm.combo == 0, "A non-upright landing cannot extend a good-stride combo.")
	_plant(rhythm, 0, 804)
	rhythm.observe(805, [true, false], false, deg_to_rad(31.0), true)
	_expect(rhythm.combo == 0, "Passing thirty degrees must break it even without a new plant.")
	var passive := Rhythm.new()
	_plant(passive, 1, 876, 0.0, false, false)
	_expect(passive.points == 0.0 and passive.combo == 0,
		"Passive contact settling must not farm points or qualify as a powered stride.")
	var released := Rhythm.new()
	released.observe(120, [false, true], false, 0.0, true)
	released.observe(150, [false, true], false, 0.0, false)
	released.observe(174, [true, true], false, 0.0, false)
	released.observe(210, [true, false], false, 0.0, true)
	released.observe(246, [true, true], false, 0.0, false)
	_expect(released.plants == 2 and released.points == 20.0 and released.combo == 1,
		"A genuinely driven swing must still score when its foot lands after releasing the key.")


func _test_sniff_spot() -> void:
	var walk := Walk.new(null, 731)
	for tick in 2400:
		if walk.dog.position.x >= 3.7 or walk.body.is_over():
			break
		var frame := WalkerTests.gait(tick)
		frame.whistle = walk.dog.is_warning()
		walk.step(frame)
	var before := walk.dog.happiness
	for tick in 1200:
		var frame := InputFrame.new()
		frame.whistle = walk.dog.is_warning()
		walk.step(frame)
	_expect(not walk.body.is_over() and walk.dog.sniffs > 0
		and walk.dog.happiness > before
		and walk.dog.snapshot()["warning_position"] == Walk.SNIFF_SPOTS[0],
		"Actually walking to the marked safe spot and settling must let Capitan sniff.")


func _test_near_fall() -> void:
	var walk := Walk.new()
	walk.body.z = 0.29
	walk.dog.position = walk.hand_position() + Vector2(2.3, 0.7)
	for tick in 3:
		walk.step(InputFrame.new())
	_expect(walk.near_falls == 1 and walk.dog.happiness == 55.0,
		"A real taut-rope near-fall costs five once, not once per dangerous tick.")


func _test_invalid_dog_state() -> void:
	var walk := Walk.new()
	walk.easy_legs = true
	walk.dog.happiness = -1.0
	var before := walk.snapshot()
	walk.step(InputFrame.new(0.0, 0.0, 0.0, 0.0, false, 1.0, 0.0))
	_expect(walk.snapshot() == before,
		"Rejected happiness must not advance either endpoint, the macro or the points bank.")
	walk.dog.happiness = 60.0
	walk.dog.profile.mass = 0.0
	before = walk.snapshot()
	walk.advance(1.0, InputFrame.new())
	walk.reset()
	_expect(walk.snapshot() == before,
		"An invalid dog profile must reject advance and reset before changing any coupled state.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
