extends SceneTree

## Rope forces, shoulder transmission and the physical advantage of planting both feet.

const Leash = preload("res://games/capitans_walk/walk/leash.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_slack_and_damping()
	_test_direction_and_clamp()
	_test_shoulder_force()
	_test_bracing()
	_test_lunge()
	if _failures.is_empty():
		print("Capitan's Walk leash tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_slack_and_damping() -> void:
	var leash := Leash.new()
	for gap in [0.0, 1.5, leash.length]:
		leash.update(Vector2.ZERO, Vector2(gap, 0.0), Vector2.ZERO, Vector2(4.0, 0.0))
		_expect(leash.force == Vector2.ZERO,
			"A slack rope exerts no force, even while its endpoints are separating.")
	leash.update(Vector2.ZERO, Vector2(2.0, 0.0), Vector2.ZERO, Vector2.ZERO)
	var resting := leash.tension
	leash.update(Vector2.ZERO, Vector2(2.0, 0.0), Vector2.ZERO, Vector2(1.0, 0.0))
	_expect(leash.tension > resting, "A taut rope damps extension, not just position.")
	leash.update(Vector2.ZERO, Vector2(2.0, 0.0), Vector2.ZERO, Vector2(-10.0, 0.0))
	_expect(leash.force == Vector2.ZERO, "A shortening rope must never push its endpoints apart.")


func _test_direction_and_clamp() -> void:
	var leash := Leash.new()
	for offset in [Vector2(10.0, 4.0), Vector2(-10.0, -4.0)]:
		leash.update(Vector2.ZERO, offset, Vector2.ZERO, Vector2.ZERO)
		_expect(is_equal_approx(leash.force.length(), Leash.MAX_FORCE)
			and leash.force.normalized().is_equal_approx(offset.normalized()),
			"The force clamp must preserve forward/backward and lateral direction.")
		var original := leash.force
		leash.update(offset, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		_expect(leash.force == -original, "Swapping endpoints must reverse the same rope force.")


func _test_shoulder_force() -> void:
	var neutral := Body.new()
	var pulled := Body.new()
	var frame := InputFrame.new()
	for tick in 240:
		neutral.step(frame)
		pulled.step(frame)
	for tick in 12:
		neutral.step(frame)
		pulled.step(frame, Vector3(60.0, 0.0, 0.0))
	var neck_shift := pulled.positions[Body.NECK].x - neutral.positions[Body.NECK].x
	var hip_shift := pulled.positions[Body.HIP].x - neutral.positions[Body.HIP].x
	_expect(neck_shift > hip_shift and pulled.torso_angle() > neutral.torso_angle(),
		"A hand pull must create a shoulder-height torque, not only translate the hip.")
	_expect(pulled.max_bone_error() < 0.025,
		"The arm carries the load without stretching its constraint or bypassing the solver.")


func _test_bracing() -> void:
	var braced := Walk.new(null, 731)
	var fighting := Walk.new(null, 731)
	for tick in 600:
		braced.step(InputFrame.new(0.0, 0.75, 0.0, 0.75))
		fighting.step(InputFrame.new(0.0, 1.0, 1.0, 0.0))
	var lean := rad_to_deg(braced.body.torso_angle())
	print("Trot brace: %.2f deg / %.2f N; fighting: %.2f deg" % [
		lean, braced.leash.tension, rad_to_deg(fighting.body.torso_angle()),
	])
	_expect(not braced.body.is_over() and braced.body.stance_count() == 2
		and lean < -4.0 and lean > -13.0,
		"A graded knee/thigh brace must hold roughly eight degrees back against a real trot pull.")
	var braced_peak := 0.0
	var fighting_peak := 0.0
	for tick in 1800:
		braced.step(InputFrame.new(0.0, 0.75, 0.0, 0.75))
		fighting.step(InputFrame.new(0.0, 1.0, 1.0, 0.0))
		if braced.dog.telegraphs > 0:
			braced_peak = maxf(braced_peak, absf(braced.body.torso_angle()))
			fighting_peak = maxf(fighting_peak, absf(fighting.body.torso_angle()))
	_expect(not braced.body.is_over() and braced.dog.telegraphs > 0
		and fighting_peak > braced_peak + deg_to_rad(20.0),
		"Leaning against a real lunge must control pitch better than leaning forward into it.")


func _test_lunge() -> void:
	var braced := Walk.new(null, 731)
	var striding := Walk.new(null, 731)
	var braced_sway := 0.0
	var striding_sway := 0.0
	for tick in 2400:
		braced.step(InputFrame.new())
		striding.step(WalkerTests.gait(tick))
		braced_sway = maxf(braced_sway, absf(braced.body.z))
		striding_sway = maxf(striding_sway, absf(striding.body.z))
	_expect(braced.dog.telegraphs > 0 and braced.peak_tension > 100.0,
		"The stance check must experience a real telegraphed squirrel lunge.")
	_expect(not braced.body.is_over() and braced.body.ticks == 2400
		and braced_sway < Body.PATH_HALF_WIDTH,
		"Double stance must survive the lunge and its return toward the centre.")
	_expect(striding_sway > braced_sway + 0.02,
		"The same seeded lunge must produce more lateral drift during a stride.")
	_expect(striding.dog.sniffs == 0,
		"A passing gait's momentary foot plants must not count as stopping at a sniff spot.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
