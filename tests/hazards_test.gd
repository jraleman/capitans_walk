extends SceneTree

## Explicit encounter fixtures test real forces and choices, not claimed walked distances.

const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")
const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const Hazards = preload("res://games/capitans_walk/walk/hazards.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const RouteTests = preload("res://games/capitans_walk/tests/route_generator_test.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")
const DogTests = preload("res://games/capitans_walk/tests/dog_brain_test.gd")
const Audio = preload("res://games/capitans_walk/audio/walk_audio.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	for kind in Chunks.MOVING_KINDS:
		if fixture(kind) == null:
			printerr("No generated Park fixture for %s." % kind)
			quit(1)
			return
	_test_warnings()
	_test_sprinkler()
	_test_jogger_and_flock()
	_test_greeting()
	_test_recall()
	_test_quiet_recall()
	_test_cues()
	_test_clock_and_streaming()
	_test_physical_encounter_walk()
	if _failures.is_empty():
		print("Capitan's Walk hazard tests passed (telegraphs; real forces; choices; fixed clock).")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_warnings() -> void:
	for kind in Chunks.MOVING_KINDS:
		var walk := fixture(kind)
		if walk == null:
			_expect(false, "Each moving Park hazard needs a generated fixture.")
			continue
		walk.step(InputFrame.new())
		var random_state: int = walk.dog.snapshot()["random"]
		var schedule: int = walk.dog.snapshot()["next_distraction_ticks"]
		for tick in Hazards.WARNING_TICKS - 1:
			_expect(walk.hazards.is_warning() and not walk.hazards.focus_enabled
				and walk.hazards.walker_force == Vector3.ZERO,
				"No moving hazard may act before its full warning.")
			walk.step(InputFrame.new())
		_expect(walk.dog.snapshot()["random"] == random_state
			and walk.dog.snapshot()["next_distraction_ticks"] == schedule,
			"A spatial warning must not consume dog RNG or stack an unseen ambient mood.")
		walk.step(InputFrame.new())
		_expect(not walk.hazards.is_warning() and walk.hazards.is_busy()
			and walk.hazards.telegraphs == 1,
			"Every moving hazard must act on the warned fixed boundary.")
		walk = fixture(kind)
		walk.step(InputFrame.new())
		for tick in 24:
			walk.step(InputFrame.new())
		var remaining := int(active_state(walk)["remaining"])
		walk.dog.long_warnings = true
		walk.step(InputFrame.new())
		_expect(int(active_state(walk)["remaining"]) == remaining * 2 - 1
			and walk.hazards.is_warning(),
			"Enabling Long warnings must double an already-visible environmental warning.")
		remaining = int(active_state(walk)["remaining"])
		walk.dog.long_warnings = false
		walk.step(InputFrame.new())
		_expect(int(active_state(walk)["remaining"]) == ceili(float(remaining) / 2.0) - 1,
			"Disabling Long warnings must preserve the elapsed fraction, not restart a warning.")
	var waiting := fixture(Chunks.OTHER_DOG)
	while not waiting.dog.is_warning():
		waiting.dog.step(false, waiting.hand_position(), Vector2.ZERO, Vector2.ZERO,
			waiting.leash.length)
	waiting.hazards.step(waiting.body, waiting.dog, waiting.route, true, true)
	_expect(not waiting.hazards.is_busy(),
		"A spatial encounter must wait until an already-telegraphed dog mood is over.")


func _test_sprinkler() -> void:
	var wet := fixture(Chunks.SPRINKLER, true)
	var dry := fixture(Chunks.SPRINKLER, true)
	dry.route = null
	var frame := InputFrame.new()
	frame.whistle = true
	wet.step(frame)
	dry.step(frame)
	var peak_push := 0.0
	var peak_drift := 0.0
	var side := float(active_state(wet)["side"])
	for tick in 540:
		wet.step(InputFrame.new())
		dry.step(InputFrame.new())
		peak_push = maxf(peak_push, wet.hazards.walker_force.z * side)
		peak_drift = maxf(peak_drift, (wet.body.z - dry.body.z) * side)
	_expect(peak_push > 30.0 and peak_drift > 0.003 and wet.dog.recalls == 1,
		"An actual sprinkler arc must push the body's lateral axis even after a completed recall.")
	_expect(not wet.hazards.focus_enabled and wet.hazards.telegraphs >= 2,
		"Water must re-telegraph each sweep, without restoring interest after recall.")
	print("Park sprinkler: %.1f N peak water / %.3f m extra lateral drift." % [
		peak_push, peak_drift,
	])
	var play := fixture(Chunks.SPRINKLER)
	for tick in 240:
		play.step(InputFrame.new())
	_expect(play.hazards.greetings == 1 and play.dog.sniffs == 1
		and play.dog.happiness > Dog.START_HAPPINESS,
		"Stopping near the sprinkler must provide one genuine, happiness-filling play/sniff.")


func _test_jogger_and_flock() -> void:
	var jogger := fixture(Chunks.JOGGER)
	var backwards := 0.0
	var first_x := INF
	var last_x := INF
	for tick in 600:
		jogger.step(InputFrame.new())
		if jogger.hazards.is_busy() and not jogger.hazards.is_warning():
			if is_inf(first_x):
				first_x = float(active_state(jogger)["actor"].x)
			last_x = float(active_state(jogger)["actor"].x)
		backwards = minf(backwards, jogger.leash.force.x)
	_expect(first_x > last_x + 3.0 and backwards < -1.0,
		"A jogger must pass from the front and pull backward through the actual rope.")
	print("Park jogger: %.2f m passing travel / %.1f N backward rope." % [
		first_x - last_x, backwards,
	])
	var flock := fixture(Chunks.PIGEON_FLOCK)
	var sides: Array[int] = []
	for tick in 420:
		flock.step(InputFrame.new())
		if flock.hazards.focus_enabled and absf(flock.dog.velocity.y) > 0.05:
			var side := 1 if flock.dog.velocity.y > 0.0 else -1
			if sides.is_empty() or sides.back() != side:
				sides.append(side)
	_expect(sides.size() >= 3 and flock.dog.telegraphs == 0
		and flock.hazards.telegraphs == 1,
		"A real environmental flock must reverse the collar in three beats, not fake a mood.")


func _test_greeting() -> void:
	var planted := fixture(Chunks.OTHER_DOG)
	var walking := fixture(Chunks.OTHER_DOG)
	var tug := 0.0
	for tick in 300:
		planted.step(InputFrame.new())
		walking.step(WalkerTests.gait(tick))
		tug = maxf(tug, absf(walking.dog.velocity.y))
	_expect(planted.hazards.greetings == 1 and planted.dog.sniffs == 1
		and planted.dog.happiness > Dog.START_HAPPINESS,
		"A sustained physical stop must turn a friendly dog into a real sniff, once per visit.")
	_expect(walking.hazards.greetings == 0 and walking.dog.sniffs == 0 and tug > 0.05,
		"Continuing the motor gait must tug toward the greeting, not award a passing sniff.")
	for tick in 1200:
		planted.step(InputFrame.new())
	_expect(planted.hazards.greetings == 1,
		"Remaining beside one friendly dog must not farm repeated greeting entries.")


func _test_recall() -> void:
	var walk := fixture(Chunks.PIGEON_FLOCK)
	while walk.hazards.telegraphs == 0 or walk.hazards.is_warning():
		walk.step(InputFrame.new())
	var frame := InputFrame.new()
	frame.whistle = true
	walk.step(frame)
	for tick in Dog.WHISTLE_RESPONSE_TICKS - 1:
		walk.step(frame)
	_expect(walk.dog.recalls == 0 and walk.hazards.focus_enabled
		and walk.cue_caption().contains("WHISTLE HEARD"),
		"Environmental interest must respect the same delayed, captioned recall.")
	walk.step(frame)
	_expect(walk.dog.recalls == 1 and not walk.hazards.focus_enabled
		and bool(active_state(walk)["recalled"]),
		"A completed recall must cancel the actual environmental drive on its exact tick.")
	for tick in 120:
		walk.step(frame)
	_expect(walk.dog.whistles == 1 and not walk.hazards.focus_enabled,
		"Holding recall must not retrigger or let the same flock regain Capitan's interest.")


func _test_clock_and_streaming() -> void:
	var snapshots: Array[Dictionary] = []
	for fps: int in [30, 60, 144]:
		var walk := fixture(Chunks.JOGGER)
		for frame in fps * 5:
			walk.advance(1.0 / fps, InputFrame.new())
		var state := walk.snapshot()
		state.erase("accumulator")
		snapshots.append(state)
		_expect(walk.hazards.telegraphs == 1 and walk.body.ticks > Hazards.WARNING_TICKS,
			"Frame-rate comparisons must actually advance a moving encounter.")
	_expect(snapshots[0] == snapshots[1] and snapshots[0] == snapshots[2],
		"Moving actors, drive, warnings, RNG and body state must match at 30/60/144 FPS.")
	var hitched := fixture(Chunks.SPRINKLER, true)
	var stepped := fixture(Chunks.SPRINKLER, true)
	hitched.advance(3.0, InputFrame.new())
	for tick in 360:
		stepped.step(InputFrame.new())
	var hitch_state := hitched.snapshot()
	var step_state := stepped.snapshot()
	hitch_state.erase("accumulator")
	step_state.erase("accumulator")
	_expect(hitch_state == step_state, "A hitch must not skip sweeps or warning boundaries.")
	stepped.body.z = 0.5
	stepped.step(InputFrame.new())
	var ended := stepped.snapshot()
	stepped.advance(10.0, InputFrame.new(1.0))
	_expect(stepped.snapshot() == ended, "An ending must freeze all environmental state.")
	stepped.reset(731)
	_expect(stepped.snapshot() == Walk.new(null, 731, null, Route.new()).snapshot(),
		"Restart must clear all hazard phases, recall/greeting latches, forces and cues.")
	var route := Route.new(731)
	var body := Body.new()
	var dog := Dog.new()
	dog.reset(731, Vector2.ZERO, 1.8)
	var hazards := Hazards.new()
	for x in range(0, 20001, 1000):
		route.prepare(float(x) - 2.0, float(x) + 4.0)
		hazards.step(body, dog, route, true, true)
		_expect(hazards.moving_states().size() <= 7,
			"Encounter state must be evicted with the route, not retain all travelled history.")
	route.prepare(-2.0, 4.0)
	hazards.step(body, dog, route, true, true)
	var initial := hazards.moving_states()
	var copied := hazards.moving_states()
	if not copied.is_empty():
		copied[0]["remaining"] = 100000
	_expect(hazards.moving_states() == initial, "Rendering must not mutate encounter state.")


func _test_quiet_recall() -> void:
	var walk := fixture(Chunks.PIGEON_FLOCK)
	var route := walk.route
	walk.route = null
	var whistle := InputFrame.new()
	whistle.whistle = true
	walk.step(whistle)
	for tick in Dog.WHISTLE_RESPONSE_TICKS:
		walk.step(InputFrame.new())
	walk.route = route
	var sideways := 0.0
	for tick in Hazards.WARNING_TICKS + 60:
		walk.step(InputFrame.new())
		sideways = maxf(sideways, absf(walk.dog.velocity.y))
	_expect(walk.dog.cooldown_ticks > 0 and walk.dog.recalls == 1
		and walk.hazards.focus_enabled and sideways > 0.05
		and not bool(active_state(walk)["recalled"]),
		"A quiet earlier recall must not immunize Capitan against an unseen encounter.")


func _test_physical_encounter_walk() -> void:
	var walk := Walk.new(null, 731, null, Route.new())
	var backwards := 0.0
	for tick in 72000:
		var frame := InputFrame.new() if walk.hazards.is_busy() else WalkerTests.gait(tick)
		frame.whistle = walk.dog.is_warning()
		walk.step(frame)
		backwards = minf(backwards, walk.leash.force.x)
		if walk.body.is_over() or (walk.hazards.telegraphs > 0 and not walk.hazards.is_busy()):
			break
	_expect(not walk.body.is_over() and walk.body.distance >= 50.0
		and walk.hazards.warning_kind() == Chunks.JOGGER and backwards < -5.0
		and walk.body.max_bone_error() < 0.035,
		"A genuine from-start motor walk must reach a generated jogger and withstand its rope drag.")
	print("Park encounter gait: %.2f m / %d ticks / %.1f N backward rope / end=%s." % [
		walk.body.distance, walk.body.ticks, backwards, walk.body.end_cause,
	])


func _test_cues() -> void:
	var sink := DogTests.CueSink.new()
	var audio := Audio.new()
	var streams: Array[PackedByteArray] = []
	for kind in Chunks.MOVING_KINDS:
		var walk := fixture(kind)
		walk.step(InputFrame.new())
		audio.reset()
		var heard := sink.tones.size()
		audio.update(walk, sink)
		_expect(sink.tones.size() == heard + 1 and not sink.captions[-1].is_empty(),
			"Every moving hazard must play an original tone with a written counter.")
		var data: PackedByteArray = sink.tones.back().data
		_expect(not streams.has(data), "The four moving-hazard cues must be distinguishable.")
		streams.append(data)
		audio.update(walk, sink)
		_expect(sink.tones.size() == heard + 1, "Rendering must not repeat a heard warning.")
	var called := fixture(Chunks.SPRINKLER)
	var whistle := InputFrame.new()
	whistle.whistle = true
	called.step(whistle)
	audio.reset()
	audio.update(called, sink)
	_expect(sink.captions[-1].contains("Whistle heard")
		and called.cue_caption().contains("WHISTLE HEARD"),
		"Both audio and HUD must protect recall from a simultaneous environmental warning.")
	var hitched := fixture(Chunks.PIGEON_FLOCK)
	hitched.advance(3.0, InputFrame.new())
	audio.reset()
	audio.update(hitched, sink)
	_expect(sink.captions[-1].contains("PIGEON FLOCK"),
		"A render hitch spanning an encounter must not lose its identifiable warning cue.")
	sink.free()


## Initial pose placement is a unit fixture; subsequent motion is only the real coupled solver.
static func fixture(kind: StringName, in_spray := false) -> Walk:
	var walk := Walk.new(null, 731, null, Route.new())
	return walk if place(walk, kind, in_spray) else null


static func place(walk: Walk, kind: StringName, in_spray := false) -> bool:
	var slot := RouteTests._find_hazard(walk.route, kind)
	if slot.is_empty():
		return false
	var offset := 1.7 if in_spray else Hazards.JOGGER_TRIGGER_OFFSET \
		if kind == Chunks.JOGGER else -1.1
	RouteTests._place_walk(walk, float(slot["from"]) + offset)
	return true


static func active_state(walk: Walk) -> Dictionary:
	for state in walk.hazards.moving_states():
		if state["phase"] in [Hazards.Phase.WARNING, Hazards.Phase.ACTIVE]:
			return state
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
