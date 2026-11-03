extends RefCounted

## The shared recorder drives real keyboard actions, never particle poses or scores.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const STEPS: Array[Dictionary] = [
	{"time": 0.0, "title": "Seeded Park grey-box prototype",
		"body": "Real joint motors, rope and terrain. Capitan is a placeholder, not final art."},
	{"time": 4.0, "title": "Thighs and calves",
		"body": "Q / W swing thighs. O / P bend and straighten knees. Equal opposing keys cancel."},
	{"time": 8.0, "title": "Plant before the lunge",
		"body": "A ! and caption warn of a squirrel. Release the leg motors to plant both feet."},
	{"time": 12.0, "title": "Whistle calls him back",
		"body": "Space recalls Capitan after 0.3 s. Six-second cooldown; release before calling again."},
	{"time": 14.0, "title": "Let go to settle",
		"body": "Grass rings are safe sniff stops. Puddles ahead lower foot grip; slopes use real gravity."},
	{"time": 18.0, "title": "Restart, not a punishment",
		"body": "R resets the walker and distance immediately, even after a fall. Escape pauses."},
	{"time": 21.0, "title": "Choose your legs",
		"body": "Game settings offer two-key Easy legs and longer warnings. Rhythm points survive a fall."},
]

var _gait_start_tick := -1
var _furthest := 0.0
var _settled := false
var _restarted := false
var _saw_warning := false
var _saw_lunge := false
var _whistled := false
var _recalled := false


func configure(variant: String) -> bool:
	_gait_start_tick = -1
	_furthest = 0.0
	_settled = false
	_restarted = false
	_saw_warning = false
	_saw_lunge = false
	_whistled = false
	_recalled = false
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return STEPS


func duration() -> float:
	return 24.0


func settings_overrides() -> Dictionary:
	var overrides := {
		Options.STEADY_KEY: 0.0, Options.WALK_SPEED_KEY: 100,
		Options.EASY_LEGS_KEY: false, Options.LONG_WARNINGS_KEY: false,
	}
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		overrides[binding["key"]] = binding["default"]
	return overrides


func configure_session(session: Node) -> void:
	session.call("configure_single_player")


func start(scene: Node) -> void:
	_release_keys()
	# Leave the physical diagram's own keycaps above the shared caption card.
	var view := scene.get("_view") as Control
	view.size.y -= 180.0


func update(scene: Node, time: float, _delta: float) -> void:
	var body := scene.get("_body") as Body
	var walk := scene.get("_walk") as Walk
	_furthest = maxf(_furthest, body.distance)
	_saw_warning = _saw_warning or walk.dog.state == Dog.SQUIRREL_WARNING
	_saw_lunge = _saw_lunge or walk.dog.state == Dog.SQUIRREL_LUNGE
	_whistled = _whistled or walk.dog.whistles > 0
	_recalled = _recalled or walk.dog.recalls > 0
	_release_keys()
	if ((time >= 4.0 and time < 8.0) or time >= 21.0) \
		and walk.dog.state == Dog.TROT and walk.dog.response_ticks == 0:
		if _gait_start_tick < 0:
			_gait_start_tick = body.ticks
		var input := WalkerTests.gait(body.ticks - _gait_start_tick)
		var strengths: Array[float] = [input.q, input.w, input.o, input.p]
		for index in 4:
			if strengths[index] > 0.0:
				Input.action_press(Options.LEG_ACTIONS[index], strengths[index])
	if walk.dog.state == Dog.SQUIRREL_LUNGE and not _whistled:
		Input.action_press(Options.WHISTLE)
	if time >= 17.5 and time < 18.0:
		_settled = not body.is_over() and body.stance_count() == 2
	if time >= 18.0 and not _restarted:
		var restart := InputEventAction.new()
		restart.action = Options.RESTART
		restart.pressed = true
		scene.call("_unhandled_input", restart)
		_restarted = body.ticks == 0 and is_zero_approx(body.distance)
		_gait_start_tick = -1


func validate_finished(scene: Node) -> bool:
	_release_keys()
	var body := scene.get("_body") as Body
	var complete := _furthest > 0.5 and _settled and _restarted and not body.is_over() \
		and _saw_warning and _saw_lunge and _whistled and _recalled
	if not complete:
		push_error(("Grey-box tutorial incomplete: distance=%.2f, settled=%s, restart=%s, "
			+ "warning=%s, lunge=%s, whistle=%s, recall=%s, end=%s.")
			% [_furthest, _settled, _restarted, _saw_warning, _saw_lunge,
				_whistled, _recalled, body.end_cause])
	return complete


func _release_keys() -> void:
	for action in Options.LEG_ACTIONS:
		Input.action_release(action)
	Input.action_release(Options.WHISTLE)
	Input.action_release(Options.EASY_LEFT)
	Input.action_release(Options.EASY_RIGHT)
