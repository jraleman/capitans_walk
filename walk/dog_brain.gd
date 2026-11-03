extends RefCounted

## Grey-box Capitan follows the centre line, with one seeded distraction and recall.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Leash = preload("res://games/capitans_walk/walk/leash.gd")
const TROT := &"trot"
const SQUIRREL_WARNING := &"squirrel_warning"
const SQUIRREL_LUNGE := &"squirrel_lunge"
const MASS := 14.0
const COLLAR_HEIGHT := 0.32
const TRACK_SPRING := 22.0
const TRACK_DAMPING := 8.0
const TROT_PULL := 32.0
const MAX_DRIVE_FORCE := 280.0
const LUNGE_FORWARD := 1.15
const LUNGE_SIDE := 1.65
const WARNING_TICKS := 96
const LUNGE_TICKS := 48
const WHISTLE_RESPONSE_TICKS := 36
const WHISTLE_COOLDOWN_TICKS := 720
const FIRST_SQUIRREL_MIN := 1080
const FIRST_SQUIRREL_MAX := 1320
const SQUIRREL_INTERVAL_MIN := 1800
const SQUIRREL_INTERVAL_MAX := 2400

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var state := TROT
var ticks := 0
var seed_value := 0
var telegraphs := 0
var whistles := 0
var recalls := 0
var cooldown_ticks := 0
var response_ticks := 0
var _state_ticks := 0
var _next_squirrel_ticks := 0
var _warning_position := Vector2.ZERO
var _lunge_side := 1.0
var _whistle_held := false
var _random := RandomNumberGenerator.new()


## Start with 0.3 m of slack rather than a surprise preload on the first tick.
func reset(walk_seed: int, hand: Vector2, leash_length: float) -> void:
	if not hand.is_finite() or not is_finite(leash_length) \
		or leash_length <= Leash.START_SLACK:
		push_error("Capitan's Walk dog reset requires a finite hand and usable leash length.")
		return
	seed_value = walk_seed
	_random.seed = walk_seed
	position = Vector2(hand.x + leash_length - Leash.START_SLACK, 0.0)
	velocity = Vector2.ZERO
	state = TROT
	ticks = 0
	telegraphs = 0
	whistles = 0
	recalls = 0
	cooldown_ticks = 0
	response_ticks = 0
	_state_ticks = 0
	_next_squirrel_ticks = _random.randi_range(FIRST_SQUIRREL_MIN, FIRST_SQUIRREL_MAX)
	_warning_position = position
	_lunge_side = 1.0
	_whistle_held = false


## The caller supplies the rope's reaction; steering cannot bypass it or move the walker.
func step(
	whistle: bool, hand: Vector2, hand_velocity: Vector2,
	rope_force: Vector2, leash_length: float
) -> void:
	if not hand.is_finite() or not hand_velocity.is_finite() or not rope_force.is_finite() \
		or not position.is_finite() or not velocity.is_finite() \
		or not is_finite(leash_length) or leash_length <= Leash.START_SLACK:
		push_error("Capitan's Walk dog step requires finite state and usable leash length.")
		return
	ticks += 1
	_update_whistle(whistle)
	_update_distraction()
	var target := Vector2(hand.x + leash_length, 0.0)
	var target_velocity := Vector2(hand_velocity.x, 0.0)
	var drive := Vector2(TROT_PULL, 0.0)
	if state == SQUIRREL_WARNING:
		target = _warning_position
		target_velocity = Vector2.ZERO
		drive = Vector2.ZERO
	elif state == SQUIRREL_LUNGE:
		target = _warning_position + Vector2(LUNGE_FORWARD, LUNGE_SIDE * _lunge_side)
		target_velocity = Vector2.ZERO
		drive = Vector2.ZERO
	drive += MASS * (TRACK_SPRING * (target - position)
		+ TRACK_DAMPING * (target_velocity - velocity))
	drive = drive.limit_length(MAX_DRIVE_FORCE)
	velocity += (drive + rope_force) / MASS * Body.STEP
	position += velocity * Body.STEP


## Captions remain meaningful when sound, colour or the placeholder dog is unavailable.
func caption() -> String:
	if response_ticks > 0:
		return "WHISTLE HEARD / RECALL IN %.1f S" % (response_ticks * Body.STEP)
	if state == SQUIRREL_WARNING:
		return "SQUIRREL! / PLANT BOTH FEET"
	if state == SQUIRREL_LUNGE:
		return "LUNGE! / HOLD YOUR STANCE"
	return "CAPITAN TROTS / LEAN AGAINST THE PULL"


## Timers and generator state are required to reproduce the next distraction exactly.
func snapshot() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "state": state,
		"ticks": ticks, "seed": seed_value, "telegraphs": telegraphs,
		"whistles": whistles, "recalls": recalls, "cooldown_ticks": cooldown_ticks,
		"response_ticks": response_ticks, "state_ticks": _state_ticks,
		"next_squirrel_ticks": _next_squirrel_ticks, "warning_position": _warning_position,
		"lunge_side": _lunge_side, "whistle_held": _whistle_held, "random": _random.state,
	}


func _update_whistle(pressed: bool) -> void:
	cooldown_ticks = maxi(0, cooldown_ticks - 1)
	if response_ticks > 0:
		response_ticks -= 1
		if response_ticks == 0:
			recalls += 1
			if state != TROT:
				_return_to_trot()
	if pressed and not _whistle_held and cooldown_ticks == 0:
		whistles += 1
		cooldown_ticks = WHISTLE_COOLDOWN_TICKS
		response_ticks = WHISTLE_RESPONSE_TICKS
	_whistle_held = pressed


func _update_distraction() -> void:
	if state == TROT:
		_next_squirrel_ticks -= 1
		if _next_squirrel_ticks == 0:
			state = SQUIRREL_WARNING
			_state_ticks = WARNING_TICKS
			_warning_position = position
			_lunge_side = -1.0 if _random.randi_range(0, 1) == 0 else 1.0
			telegraphs += 1
		return
	_state_ticks -= 1
	if _state_ticks > 0:
		return
	if state == SQUIRREL_WARNING:
		state = SQUIRREL_LUNGE
		_state_ticks = LUNGE_TICKS
	else:
		_return_to_trot()


func _return_to_trot() -> void:
	state = TROT
	_state_ticks = 0
	_next_squirrel_ticks = _random.randi_range(SQUIRREL_INTERVAL_MIN, SQUIRREL_INTERVAL_MAX)
