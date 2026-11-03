extends SceneTree

## Seeded telegraph/lunge timing and the edge-triggered panic button, without a scene.

const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Leash = preload("res://games/capitans_walk/walk/leash.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_distraction()
	_test_whistle()
	_test_idle_whistle()
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


func _step(dog: Dog, whistle := false) -> void:
	dog.step(whistle, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Leash.DEFAULT_LENGTH)


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
