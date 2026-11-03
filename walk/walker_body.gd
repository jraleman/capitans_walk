extends RefCounted

## Fixed-step Verlet joints, ground contacts and lateral balance, with no scene dependencies.

const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Profiles = preload("res://games/capitans_walk/walk/walker_profiles.gd")

const STEP := 1.0 / 120.0
const GRAVITY := 9.81
const SOLVER_ITERATIONS := 12
const EPSILON := 0.0000001
const VELOCITY_DAMPING := 0.998
const MOTOR_STIFFNESS := 240.0
const NEUTRAL_STIFFNESS := 640.0
const ANKLE_STIFFNESS := 360.0
const MOTOR_DAMPING := 40.0
const ANKLE_DAMPING := 4.0
const TORSO_STIFFNESS := 1200.0
const TORSO_DAMPING := 80.0
const STEADY_STIFFNESS := 800.0
const ARM_STIFFNESS := 25.0
const ARM_DAMPING := 2.0
const ARM_REST_OFFSET := Vector2(0.30, -0.233238)
const ARM_REST_ANGLE := -2.23184
const SPINE_STIFFNESS := 0.75
const BASE_MASS := 70.0
const THIGH_RANGE := 0.30
const KNEE_RANGE := 0.60
const HIP_MIN := -1.35
const HIP_MAX := 1.55
const KNEE_MIN := 0.025
const KNEE_MAX := 2.45
const ANKLE_MIN := 0.20
const ANKLE_MAX := 2.90
const CONTACT_SLOP := 0.002
const GROUND_FRICTION := 0.90
const FRICTION_SCALE := 2.5
const PATH_HALF_WIDTH := 0.30
const EDGE_ALLOWANCE := 0.10
const FALL_ANGLE := 80.0 * PI / 180.0
const FALL_SECONDS := 0.50
const STANCE_SPRING := 48.0
const SINGLE_STANCE_SPRING := 5.0
const STANCE_DAMPING := 6.0
const SINGLE_STANCE_DAMPING := 1.5
const AIR_DAMPING := 0.3
const CATCH_STEP := 0.45
const MAX_CATCH_STEP := 0.075
const STANDING_RECENTER := 0.10
const MIN_COM_HEIGHT := 0.35
const DEFAULT_GROUND: Array[Vector2] = [
	Vector2(-1000.0, 0.0), Vector2(100000.0, 0.0),
]

const HIP := 0
const NECK := 1
const HEAD := 2
const LEFT_KNEE := 3
const LEFT_ANKLE := 4
const LEFT_TOE := 5
const RIGHT_KNEE := 6
const RIGHT_ANKLE := 7
const RIGHT_TOE := 8
const HAND := 9
const PARTICLE_COUNT := 10
const KNEES := [LEFT_KNEE, RIGHT_KNEE]
const ANKLES := [LEFT_ANKLE, RIGHT_ANKLE]
const TOES := [LEFT_TOE, RIGHT_TOE]
const RADII := [0.10, 0.07, 0.11, 0.055, 0.06, 0.045, 0.055, 0.06, 0.045, 0.045]
const MASSES := [24.0, 18.0, 6.0, 5.0, 2.0, 1.0, 5.0, 2.0, 1.0, 6.0]
const BONE_PAIRS: Array[Vector2i] = [
	Vector2i(HIP, NECK), Vector2i(NECK, HEAD), Vector2i(HIP, HEAD),
	Vector2i(HIP, LEFT_KNEE), Vector2i(LEFT_KNEE, LEFT_ANKLE),
	Vector2i(LEFT_ANKLE, LEFT_TOE), Vector2i(HIP, RIGHT_KNEE),
	Vector2i(RIGHT_KNEE, RIGHT_ANKLE), Vector2i(RIGHT_ANKLE, RIGHT_TOE),
	Vector2i(NECK, HAND),
]

var profile: Profiles
var positions := PackedVector2Array()
var previous := PackedVector2Array()
var contacts: Array[bool] = [false, false, false, false, false, false, false, false, false, false]
var foot_contacts: Array[bool] = [true, true]
var foot_z := PackedFloat64Array([0.0, 0.0])
var z := 0.0
var z_velocity := 0.0
var half_width := PATH_HALF_WIDTH
var steady := 0.0
var distance := 0.0
var steps := 0
var ticks := 0
var seed_value := 0
var end_cause := ""
var _bone_lengths := PackedFloat64Array()
var _inverse_masses := PackedFloat64Array()
var _neutral_thighs := PackedFloat64Array()
var _neutral_knees := PackedFloat64Array()
var _neutral_ankles := PackedFloat64Array()
var _motor_acceleration := PackedVector2Array()
var _ground := PackedVector2Array(DEFAULT_GROUND)
var _surfaces: Array[Dictionary] = []
var _accumulator := 0.0
var _tilt_seconds := 0.0
var _head_contact := false
var _neck_contact := false


func _init(walker: Profiles = null, walk_seed := 0) -> void:
	profile = walker if walker != null else Profiles.new()
	_bone_lengths = PackedFloat64Array([
		profile.torso_length, profile.head_length,
		profile.torso_length + profile.head_length,
		profile.thigh_length, profile.calf_length, profile.foot_length,
		profile.thigh_length, profile.calf_length, profile.foot_length,
		profile.arm_length,
	])
	for mass: float in MASSES:
		_inverse_masses.append(BASE_MASS / (mass * profile.mass))
	reset(walk_seed)


## Reset preserves the route and assists, not any momentum, contact or end state.
func reset(walk_seed := 0) -> void:
	seed_value = walk_seed
	positions.resize(PARTICLE_COUNT)
	var ground_y := ground_height(0.0)
	positions[HIP] = Vector2(0.0, ground_y + profile.hip_height)
	positions[NECK] = positions[HIP] + Vector2(0.0, profile.torso_length)
	positions[HEAD] = positions[NECK] + Vector2(0.0, profile.head_length)
	positions[HAND] = positions[NECK] + ARM_REST_OFFSET
	_neutral_thighs.clear()
	_neutral_knees.clear()
	_neutral_ankles.clear()
	for leg in 2:
		var ankle_x := profile.stance_width * (0.5 if leg == 0 else -0.5)
		var ankle := Vector2(ankle_x, ground_height(ankle_x) + RADII[ANKLES[leg]])
		positions[ANKLES[leg]] = ankle
		positions[KNEES[leg]] = _standing_knee(positions[HIP], ankle)
		var sole_drop: float = RADII[ANKLES[leg]] - RADII[TOES[leg]]
		var sole_run := sqrt(profile.foot_length * profile.foot_length - sole_drop * sole_drop)
		positions[TOES[leg]] = ankle + Vector2(sole_run, -sole_drop)
		_neutral_thighs.append(_joint_angle(NECK, HIP, KNEES[leg], positions))
		_neutral_knees.append(-_joint_angle(HIP, KNEES[leg], ANKLES[leg], positions))
		_neutral_ankles.append(_joint_angle(KNEES[leg], ANKLES[leg], TOES[leg], positions))
	previous = positions.duplicate()
	contacts.fill(false)
	foot_contacts.fill(true)
	foot_z.fill(0.0)
	z = 0.0
	z_velocity = 0.0
	distance = 0.0
	steps = 0
	ticks = 0
	end_cause = ""
	_accumulator = 0.0
	_tilt_seconds = 0.0
	_head_contact = false
	_neck_contact = false


## This spike adapter never drops hitch time; the full walk will own its tick loop.
func advance(delta: float, frame: InputFrame, hand_force := Vector3.ZERO) -> void:
	if not is_finite(delta) or delta < 0.0:
		push_error("Capitan's Walk requires a finite, nonnegative frame duration.")
		return
	if not _valid_step(frame, hand_force) or is_over():
		return
	_accumulator += delta
	while _accumulator + EPSILON >= STEP and not is_over():
		_accumulator = maxf(0.0, _accumulator - STEP)
		step(frame, hand_force)


## A shoulder-height hand force leaves the leash outside the solver's ownership.
func step(frame: InputFrame, hand_force := Vector3.ZERO) -> void:
	if not _valid_step(frame, hand_force) or is_over():
		return
	ticks += 1
	_head_contact = false
	_neck_contact = false
	var planted_before := foot_contacts.duplicate()
	_build_motor_accelerations(frame)
	for particle in PARTICLE_COUNT:
		var current := positions[particle]
		var acceleration := Vector2(0.0, -GRAVITY) + _motor_acceleration[particle]
		if particle == HAND:
			acceleration += Vector2(hand_force.x, hand_force.y) * _inverse_masses[HAND]
		positions[particle] += (current - previous[particle]) * VELOCITY_DAMPING \
			+ acceleration * STEP * STEP
		previous[particle] = current

	for iteration in SOLVER_ITERATIONS:
		_solve_angle(HIP, NECK, HEAD, 0.0, SPINE_STIFFNESS)
		_solve_limits()
		for bone in BONE_PAIRS.size():
			_solve_distance(BONE_PAIRS[bone], _bone_lengths[bone])
		_solve_ground()

	_update_contacts(planted_before, frame)
	_update_lateral(frame, hand_force.z)
	distance = maxf(distance, positions[HIP].x)
	_detect_ending()


## Route data is copied in; invalid geometry cannot silently replace a working route.
func set_ground(polyline: PackedVector2Array, surfaces: Array[Dictionary] = []) -> bool:
	if polyline.size() < 2:
		push_error("Capitan's Walk ground needs at least two points.")
		return false
	for index in polyline.size():
		var point := polyline[index]
		if not point.is_finite() or (index > 0 and point.x <= polyline[index - 1].x):
			push_error("Capitan's Walk ground must be finite and strictly increasing in X.")
			return false
	for surface in surfaces:
		if not surface.has_all(["from", "to", "friction"]):
			push_error("Capitan's Walk surfaces need from, to and friction.")
			return false
		var start := float(surface["from"])
		var finish := float(surface["to"])
		var friction := float(surface["friction"])
		if not is_finite(start) or not is_finite(finish) or not is_finite(friction) \
			or start >= finish or friction < 0.0 or friction > 1.0:
			push_error("Capitan's Walk surface bounds and friction are invalid.")
			return false
	_ground = polyline.duplicate()
	_surfaces = surfaces.duplicate(true)
	return true


## The same ground query serves contacts and the read-only debug renderer.
func ground_height(x: float) -> float:
	var segment := _ground_segment(x)
	var start := _ground[segment]
	var finish := _ground[segment + 1]
	return lerpf(start.y, finish.y, (x - start.x) / (finish.x - start.x))


## Authored surfaces replace friction, never the contact or joint solver.
func ground_friction(x: float) -> float:
	for surface in _surfaces:
		if x >= float(surface["from"]) and x < float(surface["to"]):
			return float(surface["friction"])
	return GROUND_FRICTION


## Zero is upright; positive angles lean forward along the path.
func torso_angle() -> float:
	var torso := positions[NECK] - positions[HIP]
	return atan2(torso.x, torso.y)


## Count supporting legs, not four shoe particles.
func stance_count() -> int:
	return int(foot_contacts[0]) + int(foot_contacts[1])


## The diagnostic view and tests use the exact signed angles constrained by the solver.
func joint_angles() -> Dictionary:
	return {
		"left_hip": _joint_angle(NECK, HIP, LEFT_KNEE, positions),
		"right_hip": _joint_angle(NECK, HIP, RIGHT_KNEE, positions),
		"left_knee": -_joint_angle(HIP, LEFT_KNEE, LEFT_ANKLE, positions),
		"right_knee": -_joint_angle(HIP, RIGHT_KNEE, RIGHT_ANKLE, positions),
	}


## Constraint error is a physical playtest diagnostic, not a visual approximation.
func max_bone_error() -> float:
	var error := 0.0
	for bone in BONE_PAIRS.size():
		var pair := BONE_PAIRS[bone]
		error = maxf(error, absf(positions[pair.x].distance_to(positions[pair.y])
			- _bone_lengths[bone]))
	return error


## An ended walk remains frozen until reset, keeping results and later replays stable.
func is_over() -> bool:
	return not end_cause.is_empty()


## A deep value snapshot includes hidden momentum and contact history for exact tests.
func snapshot() -> Dictionary:
	return {
		"positions": positions.duplicate(), "previous": previous.duplicate(),
		"contacts": contacts.duplicate(), "foot_contacts": foot_contacts.duplicate(),
		"foot_z": foot_z.duplicate(), "z": z, "z_velocity": z_velocity,
		"distance": distance, "steps": steps, "ticks": ticks, "seed": seed_value,
		"end_cause": end_cause, "accumulator": _accumulator, "tilt_seconds": _tilt_seconds,
	}


func _valid_step(frame: InputFrame, hand_force: Vector3) -> bool:
	if frame == null or not frame.is_valid() or not hand_force.is_finite():
		push_error("Capitan's Walk requires a valid input frame and finite hand force.")
		return false
	return true


func _standing_knee(hip: Vector2, ankle: Vector2) -> Vector2:
	var offset := ankle - hip
	var length := offset.length()
	var along := (profile.thigh_length * profile.thigh_length
		- profile.calf_length * profile.calf_length + length * length) / (2.0 * length)
	var height := sqrt(maxf(0.0, profile.thigh_length * profile.thigh_length - along * along))
	var direction := offset / length
	return hip + direction * along + Vector2(-direction.y, direction.x) * height


func _build_motor_accelerations(frame: InputFrame) -> void:
	_motor_acceleration.resize(PARTICLE_COUNT)
	_motor_acceleration.fill(Vector2.ZERO)
	var thigh_drive := frame.thighs()
	var calf_drive := frame.calves()
	var thigh_spring := (NEUTRAL_STIFFNESS + MOTOR_STIFFNESS * absf(thigh_drive)) \
		* profile.motor_strength
	var knee_spring := (NEUTRAL_STIFFNESS + MOTOR_STIFFNESS * absf(calf_drive)) \
		* profile.motor_strength
	for leg in 2:
		var side := 1.0 if leg == 0 else -1.0
		var thigh := _neutral_thighs[leg] + thigh_drive * THIGH_RANGE * side
		var knee := clampf(_neutral_knees[leg] + calf_drive * KNEE_RANGE * side,
			KNEE_MIN, KNEE_MAX)
		_add_joint_motor(NECK, HIP, KNEES[leg], thigh, thigh_spring, MOTOR_DAMPING)
		_add_joint_motor(HIP, KNEES[leg], ANKLES[leg], -knee, knee_spring, MOTOR_DAMPING)
		_add_joint_motor(KNEES[leg], ANKLES[leg], TOES[leg],
			_neutral_ankles[leg], ANKLE_STIFFNESS * profile.motor_strength, ANKLE_DAMPING)
	var support := float(stance_count()) / 2.0
	_add_upright_motor(TORSO_STIFFNESS * support
		+ STEADY_STIFFNESS * clampf(steady, 0.0, 1.0))
	_add_joint_motor(HIP, NECK, HAND, ARM_REST_ANGLE, ARM_STIFFNESS, ARM_DAMPING)


func _add_joint_motor(
	a: int, b: int, c: int, target: float, spring: float, damping: float
) -> void:
	if spring == 0.0:
		return
	var first := positions[b] - positions[a]
	var second := positions[c] - positions[b]
	if first.length_squared() < EPSILON or second.length_squared() < EPSILON:
		return
	var gradient_a := Vector2(-first.y, first.x) / first.length_squared()
	var gradient_c := Vector2(-second.y, second.x) / second.length_squared()
	var gradient_b := -gradient_a - gradient_c
	var weight := _inverse_masses[a] * gradient_a.length_squared() \
		+ _inverse_masses[b] * gradient_b.length_squared() \
		+ _inverse_masses[c] * gradient_c.length_squared()
	var angle := _joint_angle(a, b, c, positions)
	var speed := wrapf(angle - _joint_angle(a, b, c, previous), -PI, PI) / STEP
	# Implicit spring/damping prevents light foot particles from injecting solver energy.
	var torque := (spring * wrapf(target - angle, -PI, PI) - damping * speed) \
		/ (1.0 + (damping * STEP + spring * STEP * STEP) * weight)
	_motor_acceleration[a] += gradient_a * torque * _inverse_masses[a]
	_motor_acceleration[b] += gradient_b * torque * _inverse_masses[b]
	_motor_acceleration[c] += gradient_c * torque * _inverse_masses[c]


func _add_upright_motor(spring: float) -> void:
	if spring == 0.0:
		return
	var offset := positions[NECK] - positions[HIP]
	if offset.length_squared() < EPSILON:
		return
	var gradient := Vector2(-offset.y, offset.x) / offset.length_squared()
	var weight := (_inverse_masses[HIP] + _inverse_masses[NECK]) * gradient.length_squared()
	var previous_angle := (previous[NECK] - previous[HIP]).angle()
	var speed := wrapf(offset.angle() - previous_angle, -PI, PI) / STEP
	var torque := (spring * wrapf(PI / 2.0 - offset.angle(), -PI, PI) - TORSO_DAMPING * speed) \
		/ (1.0 + (TORSO_DAMPING * STEP + spring * STEP * STEP) * weight)
	_motor_acceleration[HIP] -= gradient * torque * _inverse_masses[HIP]
	_motor_acceleration[NECK] += gradient * torque * _inverse_masses[NECK]


func _solve_limits() -> void:
	for leg in 2:
		_limit_angle(NECK, HIP, KNEES[leg], HIP_MIN, HIP_MAX)
		_limit_angle(HIP, KNEES[leg], ANKLES[leg], -KNEE_MAX, -KNEE_MIN)
		_limit_angle(KNEES[leg], ANKLES[leg], TOES[leg], ANKLE_MIN, ANKLE_MAX)


func _limit_angle(a: int, b: int, c: int, minimum: float, maximum: float) -> void:
	var angle := _joint_angle(a, b, c, positions)
	if angle < minimum or angle > maximum:
		_solve_angle(a, b, c, clampf(angle, minimum, maximum), 1.0)


func _solve_distance(pair: Vector2i, length: float) -> void:
	var offset := positions[pair.y] - positions[pair.x]
	var actual := offset.length()
	if actual < EPSILON:
		return
	var weight := _inverse_masses[pair.x] + _inverse_masses[pair.y]
	var correction := offset * ((actual - length) / (actual * weight))
	positions[pair.x] += correction * _inverse_masses[pair.x]
	positions[pair.y] -= correction * _inverse_masses[pair.y]


func _solve_angle(a: int, b: int, c: int, target: float, stiffness: float) -> void:
	var first := positions[b] - positions[a]
	var second := positions[c] - positions[b]
	if first.length_squared() < EPSILON or second.length_squared() < EPSILON:
		return
	var angle := _joint_angle(a, b, c, positions)
	var error := wrapf(angle - target, -PI, PI) * stiffness
	var gradient_a := Vector2(-first.y, first.x) / first.length_squared()
	var gradient_c := Vector2(-second.y, second.x) / second.length_squared()
	var gradient_b := -gradient_a - gradient_c
	var weight := _inverse_masses[a] * gradient_a.length_squared() \
		+ _inverse_masses[b] * gradient_b.length_squared() \
		+ _inverse_masses[c] * gradient_c.length_squared()
	var correction := -error / weight
	positions[a] += gradient_a * correction * _inverse_masses[a]
	positions[b] += gradient_b * correction * _inverse_masses[b]
	positions[c] += gradient_c * correction * _inverse_masses[c]


func _joint_angle(a: int, b: int, c: int, points: PackedVector2Array) -> float:
	return wrapf((points[c] - points[b]).angle()
		- (points[b] - points[a]).angle(), -PI, PI)


func _solve_ground() -> void:
	for particle in PARTICLE_COUNT:
		var point := positions[particle]
		var segment := _ground_segment(point.x)
		var line := _ground[segment + 1] - _ground[segment]
		var tangent := line.normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var gap: float = (point - _ground[segment]).dot(normal) - RADII[particle]
		if gap > CONTACT_SLOP:
			continue
		if particle == HEAD:
			_head_contact = true
		elif particle == NECK:
			_neck_contact = true
		var penetration := maxf(0.0, -gap)
		positions[particle] += normal * penetration
		var travel := (positions[particle] - previous[particle]).dot(tangent)
		var grip := ground_friction(point.x) * FRICTION_SCALE \
			* (penetration + GRAVITY * STEP * STEP)
		positions[particle] -= tangent * clampf(travel, -grip, grip)
		var normal_travel := (positions[particle] - previous[particle]).dot(normal)
		if normal_travel < 0.0:
			previous[particle] += normal * normal_travel


func _update_contacts(planted_before: Array, frame: InputFrame) -> void:
	for particle in PARTICLE_COUNT:
		var point := positions[particle]
		var segment := _ground_segment(point.x)
		var line := _ground[segment + 1] - _ground[segment]
		var normal := Vector2(-line.y, line.x).normalized()
		contacts[particle] = (point - _ground[segment]).dot(normal) \
			<= RADII[particle] + CONTACT_SLOP
	for leg in 2:
		foot_contacts[leg] = contacts[ANKLES[leg]] or contacts[TOES[leg]]
		if foot_contacts[leg] and not bool(planted_before[leg]):
			foot_z[leg] = z - clampf(z * CATCH_STEP, -MAX_CATCH_STEP, MAX_CATCH_STEP)
			if absf(frame.thighs()) > EPSILON or absf(frame.calves()) > EPSILON:
				steps += 1


func _update_lateral(frame: InputFrame, side_force: float) -> void:
	var stance := stance_count()
	var spring := STANCE_SPRING if stance == 2 else SINGLE_STANCE_SPRING if stance == 1 else 0.0
	var damping := STANCE_DAMPING if stance == 2 \
		else SINGLE_STANCE_DAMPING if stance == 1 else AIR_DAMPING
	if stance == 2 and absf(frame.thighs()) < EPSILON and absf(frame.calves()) < EPSILON:
		for leg in 2:
			foot_z[leg] = move_toward(foot_z[leg], 0.0, STANDING_RECENTER * STEP)
	var feet := (foot_z[0] + foot_z[1]) * 0.5
	if stance == 1:
		feet = foot_z[0] if foot_contacts[0] else foot_z[1]
	var com_height := maxf(MIN_COM_HEIGHT, positions[HIP].y - ground_height(positions[HIP].x))
	var acceleration := GRAVITY / com_height * z - spring * (z - feet) \
		+ side_force / profile.mass
	z_velocity = (z_velocity + acceleration * STEP) * exp(-damping * STEP)
	z += z_velocity * STEP


func _detect_ending() -> void:
	if _head_contact or _neck_contact:
		end_cause = "fall"
		return
	if absf(torso_angle()) > FALL_ANGLE:
		_tilt_seconds += STEP
	else:
		_tilt_seconds = 0.0
	if _tilt_seconds + EPSILON >= FALL_SECONDS:
		end_cause = "fall"
	elif absf(z) > half_width + EDGE_ALLOWANCE:
		end_cause = "off_path"


func _ground_segment(x: float) -> int:
	for segment in _ground.size() - 1:
		if x < _ground[segment + 1].x:
			return segment
	return _ground.size() - 2
