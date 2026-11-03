extends SceneTree

## Physical invariants of the first walker, exercised without scenes or autoloads.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Profiles = preload("res://games/capitans_walk/walk/walker_profiles.gd")
const GAIT_PHASE_TICKS := 12

var _failures := PackedStringArray()


func _initialize() -> void:
	_test_stance()
	_test_inputs()
	_test_gait()
	_test_ground()
	_test_lateral_tug()
	_test_endings()
	_test_distance_and_reset()
	if _failures.is_empty():
		print("Capitan's Walk walker body tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_stance() -> void:
	var body := Body.new(Profiles.new())
	var frame := InputFrame.new()
	for tick in 12000:
		body.step(frame)
	_expect(not body.is_over() and body.ticks == 12000,
		"A relaxed walker must remain standing for 100 seconds, not just survive startup.")
	_expect(body.stance_count() == 2 and absf(body.torso_angle()) < deg_to_rad(15.0),
		"A neutral pose must settle into double stance.")
	_expect(absf(body.positions[Body.HIP].x) < 0.20 and body.max_bone_error() < 0.025,
		"Standing must not drift along the path or stretch the bones.")
	body.z = 0.10
	for tick in 600:
		body.step(frame)
	_expect(not body.is_over() and absf(body.z) < 0.01,
		"Standing still must recenter a small lateral wobble.")


func _test_inputs() -> void:
	var frame := InputFrame.new(-1.0, 2.0, 0.75, 0.25, true)
	_expect(frame.q == 0.0 and frame.w == 1.0 and frame.calves() == 0.5 and frame.whistle,
		"Input strengths must be clamped while preserving analogue values and whistle.")
	var neutral := Body.new()
	var cancelled := Body.new()
	for tick in 300:
		neutral.step(InputFrame.new())
		cancelled.step(InputFrame.new(0.8, 0.8, 0.4, 0.4))
	_expect(neutral.snapshot() == cancelled.snapshot(),
		"Equal opposing keys must produce the exact neutral simulation.")
	var half := Body.new()
	var full := Body.new()
	for tick in 12:
		half.step(InputFrame.new(0.5, 0.0, 0.5, 0.0))
		full.step(InputFrame.new(1.0, 0.0, 1.0, 0.0))
	_expect(full.positions != half.positions,
		"Analogue strengths must affect joint motion rather than becoming booleans.")
	var rejected := InputFrame.new(NAN)
	_expect(not rejected.is_valid(), "Rejected nonfinite strengths must not become neutral input.")
	var guarded := Body.new()
	var before := guarded.snapshot()
	guarded.step(rejected)
	_expect(guarded.snapshot() == before, "Invalid input must not advance the simulation.")


func _test_gait() -> void:
	var body := Body.new()
	var worst_bone := 0.0
	var worst_knee := 0.0
	for tick in 12000:
		body.step(gait(tick))
		worst_bone = maxf(worst_bone, body.max_bone_error())
		var joints := body.joint_angles()
		worst_knee = maxf(worst_knee,
			maxf(float(joints["left_knee"]), float(joints["right_knee"])))
		_expect(float(joints["left_knee"]) >= Body.KNEE_MIN - 0.025
			and float(joints["right_knee"]) >= Body.KNEE_MIN - 0.025,
			"Knees must not bend forward during a gait.")
		for key in ["left_hip", "right_hip"]:
			_expect(float(joints[key]) >= Body.HIP_MIN - 0.035
				and float(joints[key]) <= Body.HIP_MAX + 0.035,
				"Hip limits must hold during locomotion.")
		if body.is_over():
			break
	print("Four-key gait: %.2f m, %d ticks, %d plants, end=%s, bone=%.4f" % [
		body.distance, body.ticks, body.steps, body.end_cause, worst_bone,
	])
	_expect(body.distance >= 10.0, "The scripted four-key gait must walk at least 10 metres.")
	_expect(worst_bone < 0.035 and worst_knee <= Body.KNEE_MAX + 0.035,
		"Bone lengths and knee limits must hold during locomotion.")


func _test_ground() -> void:
	var body := Body.new()
	_expect(body.set_ground(PackedVector2Array([
		Vector2(-20.0, -0.40), Vector2(0.0, 0.0), Vector2(20.0, 0.40),
	]), [{"from": -20.0, "to": 20.0, "friction": 0.35}]),
		"A continuous slope with authored friction must load.")
	body.reset()
	for tick in 240:
		body.step(InputFrame.new())
	for particle in Body.PARTICLE_COUNT:
		_expect(body.positions[particle].y >= body.ground_height(body.positions[particle].x)
			+ float(Body.RADII[particle]) - 0.003,
			"Particles must stay above the sloped ground.")
	_expect(is_equal_approx(body.ground_height(10.0), 0.2)
		and is_equal_approx(body.ground_friction(0.0), 0.35),
		"Contacts must query the actual polyline and authored surface.")
	var dry := Body.new()
	var slick := Body.new()
	slick.set_ground(PackedVector2Array([Vector2(-20.0, 0.0), Vector2(20.0, 0.0)]),
		[{"from": -20.0, "to": 20.0, "friction": 0.0}])
	for particle in Body.PARTICLE_COUNT:
		dry.previous[particle].x -= Body.STEP
		slick.previous[particle].x -= Body.STEP
	for tick in 60:
		dry.step(InputFrame.new())
		slick.step(InputFrame.new())
	var dry_feet := (dry.positions[Body.LEFT_ANKLE].x + dry.positions[Body.RIGHT_ANKLE].x) * 0.5
	var slick_feet := (slick.positions[Body.LEFT_ANKLE].x + slick.positions[Body.RIGHT_ANKLE].x) * 0.5
	_expect(slick_feet > dry_feet + 0.10,
		"Zero-friction ground must allow more sliding than dry pavement.")


func _test_lateral_tug() -> void:
	var standing := Body.new()
	var striding := Body.new()
	for tick in 120:
		standing.step(InputFrame.new())
		striding.step(InputFrame.new())
	for tick in 120:
		standing.step(InputFrame.new(), Vector3(0.0, 0.0, 220.0))
		striding.step(gait(tick), Vector3(0.0, 0.0, 220.0))
	_expect(not standing.is_over() and absf(standing.z) < Body.PATH_HALF_WIDTH,
		"Double stance must survive the debug sideways tug.")
	_expect(absf(striding.z) > absf(standing.z) + 0.02,
		"The same tug must cause more sway while striding than while braced.")


func _test_endings() -> void:
	for side in [-1.0, 1.0]:
		var off_path := Body.new()
		off_path.z = side * (Body.PATH_HALF_WIDTH + Body.EDGE_ALLOWANCE + 0.01)
		off_path.step(InputFrame.new())
		_expect(off_path.end_cause == "off_path", "Either path edge must end the walk.")
	var fallen := Body.new()
	_shift(fallen, Vector2(0.0, -1.70))
	fallen.step(InputFrame.new())
	_expect(fallen.end_cause == "fall", "A head or neck ground contact must end the walk.")
	var tilted := Body.new()
	var hip := tilted.positions[Body.HIP]
	for particle in Body.PARTICLE_COUNT:
		tilted.positions[particle] = hip + (tilted.positions[particle] - hip).rotated(PI / 2.0) \
			+ Vector2(0.0, 20.0)
	tilted.previous = tilted.positions.duplicate()
	tilted.contacts.fill(false)
	tilted.foot_contacts.fill(false)
	for tick in 59:
		tilted.step(InputFrame.new())
	_expect(not tilted.is_over(), "A torso beyond 80 degrees gets a half-second grace period.")
	tilted.step(InputFrame.new())
	_expect(tilted.end_cause == "fall", "A sustained sideways torso must end after half a second.")
	var kneeling := Body.new()
	kneeling.profile.motor_strength = 0.0
	kneeling.positions[Body.HIP] = Vector2(0.0, 0.40)
	kneeling.positions[Body.NECK] = Vector2(0.0, 0.40 + kneeling.profile.torso_length)
	kneeling.positions[Body.HEAD] = kneeling.positions[Body.NECK] \
		+ Vector2(0.0, kneeling.profile.head_length)
	kneeling.positions[Body.HAND] = kneeling.positions[Body.NECK] + Vector2(0.30, -0.233238)
	var knee_x := sqrt(kneeling.profile.thigh_length ** 2 - (0.40 - 0.055) ** 2)
	var ankle_x := knee_x - sqrt(kneeling.profile.calf_length ** 2 - (0.11 - 0.055) ** 2)
	var toe_x := ankle_x + sqrt(kneeling.profile.foot_length ** 2 - (0.11 - 0.045) ** 2)
	for leg in 2:
		kneeling.positions[Body.KNEES[leg]] = Vector2(knee_x, 0.055)
		kneeling.positions[Body.ANKLES[leg]] = Vector2(ankle_x, 0.11)
		kneeling.positions[Body.TOES[leg]] = Vector2(toe_x, 0.045)
	kneeling.previous = kneeling.positions.duplicate()
	kneeling.step(InputFrame.new())
	_expect(kneeling.contacts[Body.LEFT_KNEE] and not kneeling.is_over(),
		"A real knee contact alone is not a fall.")


func _test_distance_and_reset() -> void:
	var body := Body.new(null, 42)
	_shift(body, Vector2(5.0, 0.0))
	body.step(InputFrame.new())
	var furthest := body.distance
	_shift(body, Vector2(-3.0, 0.0))
	body.step(InputFrame.new())
	_expect(body.distance == furthest and furthest > 4.9,
		"Distance records the furthest hip position, not current displacement.")
	body.z = 1.0
	body.step(InputFrame.new())
	var ended := body.snapshot()
	body.advance(1.0, InputFrame.new(1.0))
	_expect(body.snapshot() == ended, "Ended walks must not continue behind results.")
	body.reset(42)
	_expect(body.snapshot() == Body.new(null, 42).snapshot(),
		"Restart must clear all momentum, balance, contact and end state.")


## The four authored phases bend a swinging leg, plant it, then swap sides.
static func gait(tick: int) -> InputFrame:
	match (tick / GAIT_PHASE_TICKS) % 4:
		0:
			return InputFrame.new(1.0, 0.0, 1.0, 0.0)
		1:
			return InputFrame.new(1.0, 0.0, 0.0, 1.0)
		2:
			return InputFrame.new(0.0, 1.0, 0.0, 1.0)
		_:
			return InputFrame.new(0.0, 1.0, 1.0, 0.0)


func _shift(body: Body, offset: Vector2) -> void:
	for particle in Body.PARTICLE_COUNT:
		body.positions[particle] += offset
		body.previous[particle] += offset


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
