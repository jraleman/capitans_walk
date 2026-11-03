extends SceneTree

## One clock must preserve both endpoint momentum, seeded events and frozen results.

const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_coupling()
	_test_fixed_determinism()
	_test_frame_rates()
	_test_end_and_reset()
	if _failures.is_empty():
		print("Capitan's Walk walk state tests passed (60 seconds; events; FPS; hitch; restart).")
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
	var states: Array[Dictionary] = []
	for fps: int in [30, 60, 144]:
		var walk := Walk.new(null, 731)
		for frame in fps * 15:
			var input := WalkerTests.gait(walk.body.ticks) \
				if walk.body.ticks < 360 else InputFrame.new()
			walk.advance(1.0 / float(fps), input)
		_expect(walk.body.ticks == 1800 and walk.dog.telegraphs > 0,
			"Render-rate checks must advance a moving walk through a squirrel lunge.")
		var snapshot := walk.snapshot()
		snapshot.erase("accumulator")
		states.append(snapshot)
	_expect(states[0] == states[1] and states[0] == states[2],
		"30/60/144 FPS must agree on all coupled physical and event state.")
	var hitched := Walk.new(null, 731)
	hitched.advance(3.0, InputFrame.new())
	var stepped := Walk.new(null, 731)
	for tick in 360:
		stepped.step(InputFrame.new())
	_expect(hitched.body.ticks == 360 and hitched.dog.ticks == 360
		and hitched.body.snapshot() == stepped.body.snapshot()
		and hitched.dog.snapshot() == stepped.dog.snapshot(),
		"A three-second hitch must not discard dog time or body ticks.")


func _test_end_and_reset() -> void:
	var walk := Walk.new(null, 731)
	walk.body.steady = 0.4
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
	_expect(walk.snapshot() == fresh.snapshot(),
		"Same-seed restart must reset every coupled state while preserving assists.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
