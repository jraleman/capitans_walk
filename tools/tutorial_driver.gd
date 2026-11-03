extends RefCounted

## The shared recorder drives real keyboard actions, never particle poses or scores.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")
const STEPS: Array[Dictionary] = [
	{"time": 0.0, "title": "Walker-only physics prototype",
		"body": "Capitan and the leash are not built yet. Start by learning the human's legs."},
	{"time": 4.0, "title": "Thighs and calves",
		"body": "Q / W swing thighs. O / P bend and straighten knees. Equal opposing keys cancel."},
	{"time": 8.0, "title": "Bend, plant, swap",
		"body": "Try Q+O, Q+P, W+P, W+O. Hold each pair briefly and repeat to move along the path."},
	{"time": 14.0, "title": "Let go to settle",
		"body": "Release all four keys to relax the motors. The gauge shows sideways sway and the edge."},
	{"time": 18.0, "title": "Restart, not a punishment",
		"body": "R resets the walker and distance immediately, even after a fall. Escape pauses."},
	{"time": 21.0, "title": "Now playtest the legs",
		"body": "This is the first physics spike. Dog, leash, touch controls and 3D art are later milestones."},
]

var _gait_start_tick := -1
var _furthest := 0.0
var _settled := false
var _restarted := false


func configure(variant: String) -> bool:
	_gait_start_tick = -1
	_furthest = 0.0
	_settled = false
	_restarted = false
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return STEPS


func duration() -> float:
	return 24.0


func settings_overrides() -> Dictionary:
	var overrides := {Options.STEADY_KEY: 0.0, Options.WALK_SPEED_KEY: 100}
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
	_furthest = maxf(_furthest, body.distance)
	_release_keys()
	if (time >= 4.0 and time < 14.0) or time >= 21.0:
		if _gait_start_tick < 0:
			_gait_start_tick = body.ticks
		var input := WalkerTests.gait(body.ticks - _gait_start_tick)
		var strengths: Array[float] = [input.q, input.w, input.o, input.p]
		for index in 4:
			if strengths[index] > 0.0:
				Input.action_press(Options.LEG_ACTIONS[index], strengths[index])
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
	var complete := _furthest > 0.5 and _settled and _restarted and not body.is_over()
	if not complete:
		push_error("Walker tutorial incomplete: distance=%.2f, settled=%s, restarted=%s, end=%s."
			% [_furthest, _settled, _restarted, body.end_cause])
	return complete


func _release_keys() -> void:
	for action in Options.LEG_ACTIONS:
		Input.action_release(action)
