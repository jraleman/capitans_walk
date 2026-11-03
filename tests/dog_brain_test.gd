extends SceneTree

## Seeded telegraph/lunge timing and the edge-triggered panic button, without a scene.

const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Leash = preload("res://games/capitans_walk/walk/leash.gd")
const Profiles = preload("res://games/capitans_walk/walk/dog_profiles.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Audio = preload("res://games/capitans_walk/audio/walk_audio.gd")

class CueSink:
	extends Node
	var tones: Array[AudioStreamWAV] = []
	var captions := PackedStringArray()

	## Capture pooled playback without needing an actual sound device.
	func play_sfx(stream: AudioStreamWAV, _volume: float) -> void:
		tones.append(stream)

	## Captions remain testable even when optional audio captions are disabled.
	func request_caption(text: String) -> void:
		captions.append(text)

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_distraction()
	_test_whistle()
	_test_idle_whistle()
	_test_moods()
	_test_protest()
	_test_happiness()
	_test_frequency()
	_test_cues()
	if _failures.is_empty():
		print("Capitan's Walk dog brain tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_distraction() -> void:
	var dog := Dog.new()
	dog.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	var first := Dog.new()
	first.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	while dog.state == Dog.TROT:
		_step(dog)
		_step(first)
		_expect(dog.snapshot() == first.snapshot(),
			"The same seed must reproduce all dog momentum and the warning schedule.")
	var warning_tick := dog.ticks
	_expect(dog.caption().contains("SQUIRREL") and dog.telegraphs == 1,
		"A lunge must first enter a labelled telegraph state.")
	for tick in Dog.WARNING_TICKS - 1:
		_step(dog)
	_expect(dog.state == Dog.SQUIRREL_WARNING,
		"The complete 0.8-second warning must be available for bracing.")
	_step(dog)
	_expect(dog.state == Dog.SQUIRREL_LUNGE and dog.ticks - warning_tick == Dog.WARNING_TICKS,
		"The lunge must begin on the fixed warning boundary.")
	for tick in Dog.LUNGE_TICKS - 1:
		_step(dog)
	_expect(dog.state == Dog.SQUIRREL_LUNGE, "The sharp pull must last 0.4 model seconds.")
	_step(dog)
	_expect(dog.state == Dog.TROT and absf(dog.position.y) > 0.01,
		"The lunge must move the real dog off-centre before returning to trot.")
	for tick in 600:
		_step(dog)
	_expect(absf(dog.position.y) < 0.01 and dog.position.is_finite(),
		"Capitan must steer back to the centre line rather than remain at the squirrel.")


func _test_whistle() -> void:
	var dog := Dog.new()
	dog.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	while dog.state != Dog.SQUIRREL_LUNGE:
		_step(dog)
	_step(dog, true)
	var accepted_tick := dog.ticks
	for tick in Dog.WHISTLE_RESPONSE_TICKS - 1:
		_step(dog, true)
	_expect(dog.state == Dog.SQUIRREL_LUNGE and dog.whistles == 1,
		"A whistle must not cancel immediately or retrigger while held.")
	_step(dog, true)
	_expect(dog.state == Dog.TROT and dog.recalls == 1
		and dog.ticks - accepted_tick == Dog.WHISTLE_RESPONSE_TICKS,
		"A whistle must end the active distraction after exactly 0.3 model seconds.")
	_step(dog, false)
	_step(dog, true)
	_expect(dog.whistles == 1, "Pressing again during cooldown must not restart recall.")
	while dog.cooldown_ticks > 0:
		_step(dog, true)
	_expect(dog.whistles == 1 and dog.ticks - accepted_tick == Dog.WHISTLE_COOLDOWN_TICKS,
		"Holding through the six-second cooldown must not call again.")
	_step(dog, false)
	_step(dog, true)
	_expect(dog.whistles == 2, "A released, fresh press must work after cooldown.")
	dog.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	var fresh := Dog.new()
	fresh.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	_expect(dog.snapshot() == fresh.snapshot(),
		"Restart must clear recall, input edges, cooldown and the consumed random sequence.")


func _step(
	dog: Dog, whistle := false, walking := false, resting := true,
	rope_force := Vector2.ZERO, distance := 0.0
) -> void:
	dog.step(whistle, Vector2.ZERO, Vector2.ZERO, rope_force, Leash.DEFAULT_LENGTH,
		distance, walking, resting)


func _mood_dog(index: int, seed_value := 731) -> Dog:
	var profile := Profiles.new()
	profile.distraction_weights.fill(0)
	profile.distraction_weights[index] = 1
	profile.interval_min = 120
	profile.interval_max = 120
	var dog := Dog.new(profile)
	dog.reset(seed_value, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	while dog.telegraphs < 2 and dog.ticks < 3000:
		_step(dog)
	return dog


func _test_moods() -> void:
	var icons := PackedStringArray()
	for index in Profiles.MOODS.size():
		var dog := _mood_dog(index)
		var caption := dog.telegraph_caption()
		_expect(dog.is_warning() and dog.mood == Profiles.MOODS[index]
			and not caption.is_empty() and not icons.has(dog.icon()),
			"Each weighted mood must reach a seeded, distinct captioned/icon warning.")
		icons.append(dog.icon())
		for tick in 20:
			_step(dog)
		var remaining := int(dog.snapshot()["state_ticks"])
		dog.long_warnings = true
		_expect(int(dog.snapshot()["state_ticks"]) == remaining * 2,
			"Enabling Long warnings must also extend an already visible telegraph.")
		for tick in remaining * 2 - 1:
			_step(dog)
		_expect(dog.is_warning(), "Every mood must preserve its full doubled warning.")
		_step(dog)
		_expect(dog.state == Dog.ACTIONS[index],
			"The warned mood must enter its own action on the exact fixed boundary.")
		var start := dog.position
		var sides: Array[int] = []
		var action_ticks := int(dog.snapshot()["state_ticks"])
		for tick in action_ticks:
			_step(dog)
			if dog.state == Dog.PIGEON_ZIGZAG and absf(dog.velocity.y) > 0.05:
				var side := 1 if dog.velocity.y > 0.0 else -1
				if sides.is_empty() or sides.back() != side:
					sides.append(side)
		if index == 0:
			_expect(absf(dog.position.y - start.y) > 0.05,
				"Squirrel lunges must move the collar sideways, not just change a caption.")
		elif index == 1:
			_expect(dog.state == Dog.SNIFF and absf(dog.position.y - start.y) > 0.3,
				"A hydrant must slowly drag sideways and then become a genuine sniff stop.")
		elif index == 2:
			_expect(sides.size() >= 3 and dog.state == Dog.TROT,
				"Pigeon beats must reverse real lateral velocity at least three times.")
		elif index == 3:
			var direction := float(dog.snapshot()["lunge_side"])
			_expect((dog.position.x - start.x) * direction > 0.5,
				"Food must sustain actual movement in its seeded forward/backward direction.")
	var directions: Array[float] = []
	for seed_value in 8:
		var dog := _mood_dog(3, seed_value)
		var direction := float(dog.snapshot()["lunge_side"])
		if not directions.has(direction):
			directions.append(direction)
	_expect(directions.size() == 2, "Food smells must support both forward and backward drags.")


func _test_protest() -> void:
	var dog := _mood_dog(4)
	for tick in Dog.WARNING_TICKS:
		_step(dog)
	for tick in 60:
		_step(dog)
	_step(dog, false, true, false, Vector2(30.0, 0.0))
	_expect(dog.state == Dog.PROTEST_SIT and int(dog.snapshot()["wait_ticks"]) == 0
		and dog.happiness == 45.0 and dog.protest_pulls == 1,
		"Actually pulling a protest must cost 15 and reset, not shorten, the wait.")
	for tick in 120:
		_step(dog, false, true, false, Vector2(30.0, 0.0))
	_expect(dog.happiness == 45.0 and dog.protest_pulls == 1,
		"A prolonged pull must not charge the same protest penalty every simulation tick.")
	for tick in Dog.PROTEST_WAIT_TICKS - 1:
		_step(dog)
	_expect(dog.state == Dog.PROTEST_SIT, "Stopping must still require the full two seconds.")
	_step(dog)
	_expect(dog.state == Dog.TROT, "Two uninterrupted settled seconds must resolve a protest.")


func _test_happiness() -> void:
	var dog := Dog.new()
	dog.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	dog.sniff_at(dog.position)
	for tick in 120:
		_step(dog, false, false, false)
	_expect(dog.happiness == 60.0, "Being near a sniff is not enough unless genuinely settled.")
	for tick in 120:
		_step(dog)
	_expect(is_equal_approx(dog.happiness, 64.0),
		"One settled sniff second must fill four happiness, in fixed model time.")
	var before_whistle := dog.happiness
	_step(dog, true)
	for tick in Dog.WHISTLE_RESPONSE_TICKS:
		_step(dog, true)
	_expect(dog.state == Dog.TROT and is_equal_approx(
		dog.happiness, before_whistle + 4.0 * Body.STEP * Dog.WHISTLE_RESPONSE_TICKS - 10.0),
		"Only a completed recall off an active sniff costs ten, after its actual delay.")
	var recalled_happiness := dog.happiness
	for tick in 120:
		_step(dog, true)
	_expect(dog.happiness == recalled_happiness,
		"Holding a whistle must not repeat the interrupted-sniff cost.")
	dog.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	for tick in Dog.UNSNIFFED_TICKS:
		_step(dog, false, true, false)
	_expect(dog.happiness == 60.0, "The first twenty unsniffed walking seconds are free.")
	for tick in 120:
		_step(dog, false, true, false)
	_expect(is_equal_approx(dog.happiness, 59.0),
		"Unsniffed walking must drain one per subsequent model second.")
	for happiness: float in [0.0, 100.0]:
		dog.happiness = happiness
		var expected_pull := 1.5 if happiness == 0.0 else 0.7
		var expected_score := 1.0 if happiness == 0.0 else 2.0
		_expect(is_equal_approx(dog.pull_multiplier(), expected_pull)
			and dog.score_multiplier() == expected_score
			and dog.verdict_wags() == (1 if happiness == 0.0 else 5),
			"Happiness endpoints must drive the specified pull, score and verdict.")
	dog.change_happiness(1000.0)
	_expect(dog.happiness == 100.0, "Happiness fills must clamp rather than overflow.")
	dog.change_happiness(-1000.0)
	_expect(dog.happiness == 0.0 and dog.position.is_finite(),
		"Zero happiness must remain a playable, determined dog.")


func _test_frequency() -> void:
	var intervals: Array[int] = []
	for index in 3:
		var profile := Profiles.new()
		profile.interval_min = 600
		profile.interval_max = 600
		profile.distraction_weights = [1, 0, 0, 0, 0]
		var dog := Dog.new(profile)
		dog.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
		dog.happiness = 0.0 if index == 0 else 100.0
		while dog.state != Dog.SQUIRREL_LUNGE:
			_step(dog, false, false, true, Vector2.ZERO, 50.0 if index == 2 else 0.0)
		for tick in Dog.LUNGE_TICKS:
			_step(dog, false, false, true, Vector2.ZERO, 50.0 if index == 2 else 0.0)
		intervals.append(int(dog.snapshot()["next_distraction_ticks"]))
	_expect(intervals[0] < intervals[1] and intervals[2] < intervals[1],
		"The next seeded interval must depend on the breed profile, happiness and distance.")


func _test_cues() -> void:
	var walk := Walk.new()
	var audio := Audio.new()
	var sink := CueSink.new()
	for index in Profiles.MOODS.size():
		walk.dog.mood = Profiles.MOODS[index]
		walk.dog.telegraphs += 1
		audio.update(walk, sink)
		audio.update(walk, sink)
		_expect(sink.tones.size() == index + 1 and sink.captions.size() == index + 1
			and sink.captions[index] == walk.dog.telegraph_caption(),
			"Each new mood must emit its matching caption and cue once, not every render frame.")
		for previous in index:
			_expect(sink.tones[index].data != sink.tones[previous].data,
				"Five meaningful telegraphs must use distinct original sound cues.")
	audio.reset()
	walk.reset()
	audio.update(walk, sink)
	_expect(sink.tones.size() == 5, "Reset must not replay a stale distraction's sound.")
	sink.free()


func _test_idle_whistle() -> void:
	var quiet := Dog.new()
	var called := Dog.new()
	quiet.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	called.reset(731, Vector2.ZERO, Leash.DEFAULT_LENGTH)
	for tick in Dog.FIRST_SQUIRREL_MAX:
		_step(quiet)
		_step(called, tick == 0)
		if quiet.state == Dog.SQUIRREL_WARNING:
			_expect(called.state == Dog.SQUIRREL_WARNING,
				"Whistling during a quiet trot must not postpone an unseen distraction.")
			return
	_expect(false, "The idle-whistle comparison must reach a real warning.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
