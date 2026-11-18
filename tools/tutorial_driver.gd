extends RefCounted

## The shared recorder plays the actual first-person route using input, never assigned state.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const PathWalk = preload("res://games/capitans_walk/walk/path_walk.gd")
const STEPS: Array[Dictionary] = [
	{"time": 0.0, "title": "Walkies, in first person",
		"body": "Walking is automatic. Keep Capitan between the cream path edges. Start with 100 points."},
	{"time": 4.0, "title": "Watch the warning",
		"body": "A squirrel, pigeons or a friendly dog can tempt Capitan onto the grass. Read the side."},
	{"time": 7.5, "title": "One second to react",
		"body": "OFF PATH gives a one-second grace period, then costs 10 points each second outside."},
	{"time": 10.0, "title": "Whistle brings him back",
		"body": "Space recalls Capitan after 0.3 seconds. Wait six seconds and release before calling again."},
	{"time": 13.0, "title": "Steer the real leash",
		"body": "A guides left; D guides right. Returning stops the penalty. Earn +1 point per safe metre."},
	{"time": 17.0, "title": "Make it to the finish",
		"body": "Reach 200 m with points left to win. Zero points ends the walk, not a human fall."},
	{"time": 20.0, "title": "A fresh walk, one key away",
		"body": "R restarts the same Park route with 100 points. Escape pauses. Gamepad and touch work too."},
]

var _furthest := 0.0
var _saw_warning := false
var _saw_drain := false
var _returned := false
var _whistled := false
var _recalled := false
var _restarted := false


func configure(variant: String) -> bool:
	_furthest = 0.0
	_saw_warning = false
	_saw_drain = false
	_returned = false
	_whistled = false
	_recalled = false
	_restarted = false
	return variant == "solo"


func steps() -> Array[Dictionary]:
	return STEPS


func duration() -> float:
	return 24.0


func settings_overrides() -> Dictionary:
	var overrides := {Options.WALK_SPEED_KEY: 100, Options.LONG_WARNINGS_KEY: false}
	for binding in Options.CONTROL_BINDINGS:
		overrides[binding["key"]] = binding["default"]
	return overrides


func configure_session(session: Node) -> void:
	session.call("configure_single_player")


func start(scene: Node) -> void:
	_release_keys()
	(scene.get_node("%HudHelpButton") as Button).pressed.emit()


func update(scene: Node, time: float, _delta: float) -> void:
	var walk: Walk = scene.get("_walk")
	_furthest = maxf(_furthest, walk.path.distance)
	_saw_warning = _saw_warning or walk.path.phase == PathWalk.Phase.WARNING
	_saw_drain = _saw_drain or walk.path.is_draining()
	_returned = _returned or (_saw_drain and walk.path.on_path)
	_whistled = _whistled or walk.dog.whistles > 0
	_recalled = _recalled or walk.dog.recalls > 0
	_release_keys()
	if time >= 10.0 and not _whistled:
		Input.action_press(Options.WHISTLE)
	if time >= 12.0:
		var demand := -walk.dog.position.y * 2.8 - walk.dog.velocity.y * 0.8
		if absf(demand) > 0.1:
			Input.action_press(Options.STEER_LEFT if demand < 0.0 else Options.STEER_RIGHT)
	if time >= 20.0 and not _restarted:
		var restart := InputEventAction.new()
		restart.action = Options.RESTART
		restart.pressed = true
		scene.call("_unhandled_input", restart)
		_restarted = walk.path.ticks == 0 and walk.path.points == PathWalk.START_POINTS


func validate_finished(scene: Node) -> bool:
	_release_keys()
	var walk: Walk = scene.get("_walk")
	var complete := _furthest > 20.0 and _saw_warning and _saw_drain and _returned \
		and _whistled and _recalled and _restarted and not walk.is_over()
	if not complete:
		push_error(("First-person tutorial incomplete: distance=%.2f, warning=%s, drain=%s, "
			+ "returned=%s, whistle=%s, recall=%s, restart=%s.") % [
			_furthest, _saw_warning, _saw_drain, _returned, _whistled, _recalled, _restarted,
		])
	return complete


func _release_keys() -> void:
	for action in Options.STEER_ACTIONS:
		Input.action_release(action)
	Input.action_release(Options.WHISTLE)
