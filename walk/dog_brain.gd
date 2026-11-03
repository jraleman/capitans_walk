extends RefCounted

## Seeded moods steer the real collar; happiness and recall share the fixed clock.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Leash = preload("res://games/capitans_walk/walk/leash.gd")
const Profiles = preload("res://games/capitans_walk/walk/dog_profiles.gd")
const TROT := &"trot"
const SQUIRREL_WARNING := &"squirrel_warning"
const SQUIRREL_LUNGE := &"squirrel_lunge"
const HYDRANT_WARNING := &"hydrant_warning"
const HYDRANT_DRAG := &"hydrant_drag"
const PIGEON_WARNING := &"pigeon_warning"
const PIGEON_ZIGZAG := &"pigeon_zigzag"
const FOOD_WARNING := &"food_warning"
const FOOD_DRAG := &"food_drag"
const PROTEST_WARNING := &"protest_warning"
const PROTEST_SIT := &"protest_sit"
const SNIFF := &"sniff"
const WARNINGS: Array[StringName] = [
	SQUIRREL_WARNING, HYDRANT_WARNING, PIGEON_WARNING, FOOD_WARNING, PROTEST_WARNING,
]
const ACTIONS: Array[StringName] = [
	SQUIRREL_LUNGE, HYDRANT_DRAG, PIGEON_ZIGZAG, FOOD_DRAG, PROTEST_SIT,
]
const MASS := 14.0
const COLLAR_HEIGHT := 0.32
const LUNGE_FORWARD := 1.15
const LUNGE_SIDE := 1.65
const WARNING_TICKS := 96
const LUNGE_TICKS := 48
const HYDRANT_TICKS := 240
const HYDRANT_SIDE := 0.8
const PIGEON_BEAT_TICKS := 60
const PIGEON_SIDE := 0.85
const FOOD_TICKS := 360
const FOOD_RUN := 1.4
const SNIFF_TICKS := 600
const PROTEST_WAIT_TICKS := 240
const UNSNIFFED_TICKS := 2400
const START_HAPPINESS := 60.0
const WHISTLE_RESPONSE_TICKS := 36
const WHISTLE_COOLDOWN_TICKS := 720
const FIRST_SQUIRREL_MIN := 1080
const FIRST_SQUIRREL_MAX := 1320

var profile: Profiles
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var state := TROT
var mood := Profiles.SQUIRREL
var happiness := START_HAPPINESS
var long_warnings := false:
	set(value):
		if value != long_warnings and is_warning():
			_state_ticks = _state_ticks * 2 if value else ceili(float(_state_ticks) / 2.0)
		long_warnings = value
var ticks := 0
var seed_value := 0
var telegraphs := 0
var whistles := 0
var recalls := 0
var sniffs := 0
var protest_pulls := 0
var cooldown_ticks := 0
var response_ticks := 0
var _state_ticks := 0
var _next_distraction_ticks := 0
var _warning_position := Vector2.ZERO
var _lunge_side := 1.0
var _pigeon_beats := 3
var _wait_ticks := 0
var _walking_ticks := 0
var _distance := 0.0
var _protest_pulled := false
var _whistle_held := false
var _random := RandomNumberGenerator.new()


func _init(dog_profile: Profiles = null) -> void:
	profile = dog_profile if dog_profile != null else Profiles.new()


## Start with 0.3 m of slack rather than a surprise preload on the first tick.
func reset(walk_seed: int, hand: Vector2, leash_length: float) -> void:
	if not hand.is_finite() or not is_finite(leash_length) \
		or leash_length <= Leash.START_SLACK or profile == null or not profile.is_valid():
		push_error("Capitan's Walk dog reset requires a finite hand and usable leash length.")
		return
	seed_value = walk_seed
	_random.seed = walk_seed
	position = Vector2(hand.x + leash_length - Leash.START_SLACK, 0.0)
	velocity = Vector2.ZERO
	state = TROT
	mood = Profiles.SQUIRREL
	happiness = START_HAPPINESS
	ticks = 0
	telegraphs = 0
	whistles = 0
	recalls = 0
	sniffs = 0
	protest_pulls = 0
	cooldown_ticks = 0
	response_ticks = 0
	_state_ticks = 0
	_next_distraction_ticks = _random.randi_range(FIRST_SQUIRREL_MIN, FIRST_SQUIRREL_MAX)
	_warning_position = position
	_lunge_side = 1.0
	_pigeon_beats = 3
	_wait_ticks = 0
	_walking_ticks = 0
	_distance = 0.0
	_protest_pulled = false
	_whistle_held = false


## The caller supplies the rope's reaction; steering cannot bypass it or move the walker.
func step(
	whistle: bool, hand: Vector2, hand_velocity: Vector2,
	rope_force: Vector2, leash_length: float,
	walk_distance := 0.0, walking := false, resting := true,
	external_force := Vector2.ZERO, focus_position := Vector2.ZERO,
	focus_enabled := false, allow_distractions := true
) -> void:
	if not hand.is_finite() or not hand_velocity.is_finite() or not rope_force.is_finite() \
		or not external_force.is_finite() or not focus_position.is_finite() \
		or not position.is_finite() or not velocity.is_finite() \
		or not is_finite(walk_distance) or walk_distance < 0.0 \
		or not is_finite(happiness) or happiness < 0.0 or happiness > 100.0 \
		or profile == null or not profile.is_valid() \
		or not is_finite(leash_length) or leash_length <= Leash.START_SLACK:
		push_error("Capitan's Walk dog step requires finite state and usable leash length.")
		return
	ticks += 1
	_distance = walk_distance
	var recalls_before := recalls
	_update_whistle(whistle)
	if allow_distractions or state != TROT:
		_update_distraction(walking, resting, rope_force)
	_update_happiness(walking, resting)
	var target := Vector2(hand.x + leash_length, 0.0)
	var target_velocity := Vector2(hand_velocity.x, 0.0)
	var drive := Vector2(profile.trot_pull, 0.0)
	if is_warning() or state == SNIFF or state == PROTEST_SIT:
		target = _warning_position
		target_velocity = Vector2.ZERO
		drive = Vector2.ZERO
	elif state == SQUIRREL_LUNGE:
		target = _warning_position + Vector2(LUNGE_FORWARD, LUNGE_SIDE * _lunge_side)
		target_velocity = Vector2.ZERO
		drive = Vector2.ZERO
	elif state == HYDRANT_DRAG:
		var along := 1.0 - float(_state_ticks) / HYDRANT_TICKS
		target = _warning_position + Vector2(0.0, HYDRANT_SIDE * _lunge_side * along)
		target_velocity = Vector2.ZERO
		drive = Vector2.ZERO
	elif state == PIGEON_ZIGZAG:
		var beat := (_pigeon_beats * PIGEON_BEAT_TICKS - _state_ticks) / PIGEON_BEAT_TICKS
		var side := _lunge_side if beat % 2 == 0 else -_lunge_side
		target = _warning_position + Vector2(0.25, PIGEON_SIDE * side)
		target_velocity = Vector2.ZERO
		drive = Vector2.ZERO
	elif state == FOOD_DRAG:
		target = _warning_position + Vector2(FOOD_RUN * _lunge_side, 0.0)
		target_velocity = Vector2.ZERO
		drive = Vector2(45.0 * _lunge_side, 0.0)
	if focus_enabled and state == TROT and recalls == recalls_before:
		target = focus_position
		target_velocity = Vector2.ZERO
		drive = Vector2.ZERO
	var steering := profile.mass * (profile.track_spring * (target - position)
		+ profile.track_damping * (target_velocity - velocity))
	drive = ((drive + steering) * pull_multiplier()).limit_length(profile.max_drive)
	velocity += (drive + rope_force + external_force) / profile.mass * Body.STEP
	position += velocity * Body.STEP


## Safe route spots start a sniff only while the player has genuinely settled.
func sniff_at(spot: Vector2) -> void:
	if not spot.is_finite():
		push_error("Capitan's Walk sniff spots must be finite.")
		return
	if state != TROT or response_ticks > 0 or cooldown_ticks > 0:
		return
	if position.distance_to(spot) > 0.65:
		return
	state = SNIFF
	_warning_position = spot
	_state_ticks = SNIFF_TICKS
	sniffs += 1


## Named events grant or spend happiness without ever making it an ending rule.
func change_happiness(amount: float) -> void:
	if not is_finite(amount):
		push_error("Capitan's Walk happiness changes must be finite.")
		return
	happiness = clampf(happiness + amount, 0.0, 100.0)


## Unhappy means determined: stronger pulling, never a sad or failed dog.
func pull_multiplier() -> float:
	return lerpf(1.5, 0.7, happiness / 100.0)


## Banking stride points is separate from this end-of-walk multiplier.
func score_multiplier() -> float:
	return 1.0 + happiness / 100.0


## Five equal happiness bands produce an accessible numeric verdict.
func verdict_wags() -> int:
	return mini(5, 1 + floori(happiness / 20.0))


## Every mood's warning is identifiable independently of its colour or sound.
func is_warning() -> bool:
	return state in WARNINGS


## The HUD reads the same remaining model time used by the state transition.
func warning_seconds() -> float:
	return _state_ticks * Body.STEP if is_warning() else 0.0


## These compact symbols accompany the full written mood and counter.
func icon() -> String:
	if state == SNIFF:
		return "S"
	return ["!", "H", "V", "~", "Z"][Profiles.MOODS.find(mood)]


## Audio adapters retain the original warning even if a render hitch spans its action.
func telegraph_caption() -> String:
	if mood == Profiles.FOOD:
		return "FOOD SMELL / %s DRAG; BRACE" % ("FORWARD" if _lunge_side > 0.0 else "BACKWARD")
	return [
		"SQUIRREL! / PLANT BOTH FEET",
		"HYDRANT / STOP FOR A SNIFF",
		"PIGEON / STEP BETWEEN TUGS",
		"FOOD SMELL / LEAN AGAINST THE DRAG",
		"SIT-DOWN PROTEST / STOP AND WAIT 2 S",
	][Profiles.MOODS.find(mood)]


## Captions remain meaningful when sound, colour or the placeholder dog is unavailable.
func caption() -> String:
	if response_ticks > 0:
		return "WHISTLE HEARD / RECALL IN %.1f S" % (response_ticks * Body.STEP)
	if is_warning():
		return telegraph_caption()
	if state == SQUIRREL_LUNGE:
		return "LUNGE! / HOLD YOUR STANCE"
	if state == HYDRANT_DRAG:
		return "HYDRANT DRAG / STOP FOR A SNIFF"
	if state == PIGEON_ZIGZAG:
		return "PIGEON ZIGZAG / STEP BETWEEN TUGS"
	if state == FOOD_DRAG:
		return "FOOD SMELL / %s DRAG" % ("FORWARD" if _lunge_side > 0.0 else "BACKWARD")
	if state == PROTEST_SIT:
		return "CAPITAN SITS / WAIT %.1f S; PULLING RESETS IT" % (
			(PROTEST_WAIT_TICKS - _wait_ticks) * Body.STEP)
	if state == SNIFF:
		return "CAPITAN SNIFFS / STAND STILL: +4 HAPPINESS/S"
	return "CAPITAN TROTS / LEAN AGAINST THE PULL"


## Timers and generator state are required to reproduce the next distraction exactly.
func snapshot() -> Dictionary:
	return {
		"position": position, "velocity": velocity, "state": state, "mood": mood,
		"happiness": happiness, "long_warnings": long_warnings,
		"ticks": ticks, "seed": seed_value, "telegraphs": telegraphs,
		"whistles": whistles, "recalls": recalls, "cooldown_ticks": cooldown_ticks,
		"sniffs": sniffs, "protest_pulls": protest_pulls, "wait_ticks": _wait_ticks,
		"walking_ticks": _walking_ticks, "distance": _distance,
		"response_ticks": response_ticks, "state_ticks": _state_ticks,
		"next_distraction_ticks": _next_distraction_ticks, "warning_position": _warning_position,
		"pigeon_beats": _pigeon_beats, "protest_pulled": _protest_pulled,
		"lunge_side": _lunge_side, "whistle_held": _whistle_held, "random": _random.state,
	}


func _update_whistle(pressed: bool) -> void:
	cooldown_ticks = maxi(0, cooldown_ticks - 1)
	if response_ticks > 0:
		response_ticks -= 1
		if response_ticks == 0:
			recalls += 1
			if state != TROT:
				if state == SNIFF:
					change_happiness(-10.0)
				_return_to_trot()
	if pressed and not _whistle_held and cooldown_ticks == 0:
		whistles += 1
		cooldown_ticks = WHISTLE_COOLDOWN_TICKS
		response_ticks = WHISTLE_RESPONSE_TICKS
	_whistle_held = pressed


func _update_distraction(walking: bool, resting: bool, rope_force: Vector2) -> void:
	if state == TROT:
		_next_distraction_ticks -= 1
		if _next_distraction_ticks == 0:
			mood = Profiles.SQUIRREL if telegraphs == 0 else _pick_mood()
			state = WARNINGS[Profiles.MOODS.find(mood)]
			_state_ticks = profile.warning_ticks * (2 if long_warnings else 1)
			_warning_position = position
			_lunge_side = -1.0 if _random.randi_range(0, 1) == 0 else 1.0
			_pigeon_beats = _random.randi_range(3, 5) if mood == Profiles.PIGEON else 3
			telegraphs += 1
		return
	if state == PROTEST_SIT:
		if resting:
			_wait_ticks += 1
			if _wait_ticks >= PROTEST_WAIT_TICKS:
				_return_to_trot()
		else:
			_wait_ticks = 0
			if walking and rope_force.x > 10.0:
				_penalize_protest_pull()
		return
	if state == SNIFF and walking:
		_return_to_trot()
		return
	_state_ticks -= 1
	if _state_ticks > 0:
		return
	if is_warning():
		state = ACTIONS[Profiles.MOODS.find(mood)]
		_state_ticks = [LUNGE_TICKS, HYDRANT_TICKS,
			_pigeon_beats * PIGEON_BEAT_TICKS, FOOD_TICKS, 0][Profiles.MOODS.find(mood)]
		_wait_ticks = 0
		_protest_pulled = false
	elif state == HYDRANT_DRAG:
		state = SNIFF
		_warning_position += Vector2(0.0, HYDRANT_SIDE * _lunge_side)
		_state_ticks = SNIFF_TICKS
		sniffs += 1
	else:
		_return_to_trot()


func _update_happiness(walking: bool, resting: bool) -> void:
	if state == SNIFF and resting:
		_walking_ticks = 0
		change_happiness(profile.sniff_fill * Body.STEP)
	elif walking:
		_walking_ticks += 1
		if _walking_ticks > UNSNIFFED_TICKS:
			change_happiness(-profile.walking_drain * Body.STEP)


func _penalize_protest_pull() -> void:
	if not _protest_pulled:
		change_happiness(-15.0)
		protest_pulls += 1
		_protest_pulled = true


func _pick_mood() -> StringName:
	var total := 0
	for weight in profile.distraction_weights:
		total += weight
	var choice := _random.randi_range(1, total)
	for index in Profiles.MOODS.size() - 1:
		choice -= profile.distraction_weights[index]
		if choice <= 0:
			return Profiles.MOODS[index]
	return Profiles.MOODS.back()


func _return_to_trot() -> void:
	state = TROT
	_state_ticks = 0
	_wait_ticks = 0
	var interval := _random.randi_range(profile.interval_min, profile.interval_max)
	var rate := lerpf(0.7, 1.2, happiness / 100.0) / (1.0 + _distance * profile.distance_rate)
	_next_distraction_ticks = maxi(1, roundi(interval * rate))
