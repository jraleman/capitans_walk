extends RefCounted

## Spatial encounters and real shoe contacts share the walk's fixed clock.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")
const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const WARNING_TICKS := 96
const SWEEP_TICKS := 180
const SPRAY_FORCE := 70.0
const SPRAY_RADIUS := 0.75
const JOGGER_TICKS := 360
const JOGGER_PASS_TICKS := 240
const JOGGER_TRIGGER_OFFSET := 2.0
const FLOCK_BEAT_TICKS := 60
const FLOCK_BEATS := 3
const GREETING_TICKS := 720
enum Phase { READY, WARNING, ACTIVE, DONE }

class Encounter:
	extends RefCounted

	var kind: StringName
	var start := 0.0
	var finish := 0.0
	var side := 1.0
	var phase := Phase.READY
	var remaining := 0
	var warning_ticks := WARNING_TICKS
	var recalls := 0
	var greeted := false
	var recalled := false

	func _init(slot: Dictionary) -> void:
		kind = slot["kind"]
		start = float(slot["from"])
		finish = float(slot["to"])
		side = float(slot["side"])

	func anchor() -> Vector2:
		return Vector2(start + 0.8, 0.0)

	func duration() -> int:
		match kind:
			Chunks.SPRINKLER:
				return SWEEP_TICKS
			Chunks.JOGGER:
				return JOGGER_TICKS
			Chunks.PIGEON_FLOCK:
				return FLOCK_BEAT_TICKS * FLOCK_BEATS
		return GREETING_TICKS

	func actor_position() -> Vector2:
		if kind == Chunks.JOGGER:
			var progress := clampf(float(JOGGER_TICKS - remaining) / JOGGER_PASS_TICKS,
				0.0, 1.0) if phase == Phase.ACTIVE else 1.0 if phase == Phase.DONE else 0.0
			return Vector2(lerpf(start + 4.5, start, progress), side * 0.4)
		if kind in [Chunks.PIGEON_FLOCK, Chunks.OTHER_DOG]:
			return anchor() + Vector2(0.8, 0.0)
		return anchor()

	func snapshot() -> Dictionary:
		return {"kind": kind, "from": start, "to": finish, "side": side,
			"phase": phase, "remaining": remaining, "warning_ticks": warning_ticks,
			"recalls": recalls, "greeted": greeted, "recalled": recalled,
			"actor": actor_position()}

var splashes := 0
var telegraphs := 0
var greetings := 0
var walker_force := Vector3.ZERO
var dog_target := Vector2.ZERO
var focus_enabled := false
var _wet_feet: Array[bool] = [false, false]
var _encounters: Dictionary[float, Encounter] = {}
var _active: Encounter
var _route_revision := -1
var _last_warning: StringName = &""


func reset() -> void:
	splashes = 0
	telegraphs = 0
	greetings = 0
	walker_force = Vector3.ZERO
	dog_target = Vector2.ZERO
	focus_enabled = false
	_wet_feet.fill(false)
	_encounters.clear()
	_active = null
	_route_revision = -1
	_last_warning = &""


## Ordinary moods wait their turn; every environmental effect gets its own full warning.
func step(body: Body, dog: Dog, route: Route, resting: bool, settled: bool) -> void:
	walker_force = Vector3.ZERO
	dog_target = Vector2.ZERO
	focus_enabled = false
	if route == null:
		return
	if route.revision != _route_revision:
		_sync(route)
	if _active == null:
		for encounter: Encounter in _encounters.values():
			if encounter.phase != Phase.READY:
				continue
			if body.positions[Body.HIP].x > encounter.finish:
				encounter.phase = Phase.DONE
			var reached := body.positions[Body.HIP].x >= encounter.start + JOGGER_TRIGGER_OFFSET \
				if encounter.kind == Chunks.JOGGER \
				else maxf(body.positions[Body.HIP].x, dog.position.x) >= encounter.start
			if encounter.phase == Phase.READY and reached \
				and dog.state == Dog.TROT and dog.response_ticks == 0:
				_active = encounter
				encounter.recalls = dog.recalls
				_warn(dog.long_warnings)
				break
		return
	if body.positions[Body.HIP].x > _active.finish:
		_finish()
		return
	if _active.phase == Phase.WARNING:
		var warning_ticks := WARNING_TICKS * (2 if dog.long_warnings else 1)
		if _active.warning_ticks != warning_ticks:
			_active.remaining = ceili(float(_active.remaining) * warning_ticks
				/ _active.warning_ticks)
			_active.warning_ticks = warning_ticks
		_active.remaining -= 1
		if _active.remaining > 0:
			return
		_active.phase = Phase.ACTIVE
		_active.remaining = _active.duration()
	else:
		_active.remaining = maxi(0, _active.remaining - 1)
		if _active.remaining == 0:
			if _active.kind == Chunks.SPRINKLER:
				_warn(dog.long_warnings)
				return
			if not _active.greeted or dog.state != Dog.SNIFF:
				_finish()
				return
	if not _active.recalled and not _active.greeted:
		if _active.kind in [Chunks.SPRINKLER, Chunks.OTHER_DOG] and settled:
			dog.sniff_at(_active.anchor())
			if dog.state == Dog.SNIFF:
				_active.greeted = true
				greetings += 1
		if not _active.greeted:
			focus_enabled = true
			dog_target = _active.anchor()
			match _active.kind:
				Chunks.SPRINKLER, Chunks.OTHER_DOG:
					if not resting:
						dog_target.y = _active.side * 0.8
				Chunks.JOGGER:
					dog_target = _active.actor_position()
					dog_target.y = 0.0
				Chunks.PIGEON_FLOCK:
					var beat := (FLOCK_BEAT_TICKS * FLOCK_BEATS
						- _active.remaining) / FLOCK_BEAT_TICKS
					dog_target.y = _active.side * (0.65 if beat % 2 == 0 else -0.65)
	if _active.kind == Chunks.SPRINKLER:
		var hip_x := body.positions[Body.HIP].x
		var progress := 1.0 - float(_active.remaining) / SWEEP_TICKS
		var spray_x := lerpf(_active.start, _active.finish, (1.0 - cos(PI * progress)) * 0.5)
		if hip_x >= _active.start and hip_x < _active.finish \
			and absf(hip_x - spray_x) < SPRAY_RADIUS:
			walker_force.z = _active.side * SPRAY_FORCE * sin(PI * progress)


func observe(body: Body, route: Route, dog: Dog = null) -> void:
	if _active != null and dog != null and dog.recalls > _active.recalls:
		_active.recalled = true
		focus_enabled = false
	for leg in 2:
		var wet := route != null and (
			(body.contacts[Body.ANKLES[leg]]
				and route.is_puddle_at(body.positions[Body.ANKLES[leg]].x))
			or (body.contacts[Body.TOES[leg]]
				and route.is_puddle_at(body.positions[Body.TOES[leg]].x)))
		if wet and not _wet_feet[leg]:
			splashes += 1
		_wet_feet[leg] = wet


## Active environmental focus pauses ambient RNG scheduling, not recall or sniff timers.
func is_busy() -> bool:
	return _active != null


func is_warning() -> bool:
	return _active != null and _active.phase == Phase.WARNING


func warning_kind() -> StringName:
	return _last_warning


## Retain the last warning even when a render hitch spans the complete encounter.
func telegraph_caption() -> String:
	match _last_warning:
		Chunks.SPRINKLER:
			return "* SPRINKLER TICKS / PLANT BEFORE THE SWEEP"
		Chunks.JOGGER:
			return "J JOGGER APPROACHES / BRACE FOR A BACKWARD DRAG"
		Chunks.PIGEON_FLOCK:
			return "VV PIGEON FLOCK / PLANT; STEP BETWEEN TUGS"
		Chunks.OTHER_DOG:
			return "D FRIENDLY DOG / STOP TO GREET; WALKING TUGS"
	return ""


func moving_caption(dog: Dog) -> String:
	if _active == null:
		return ""
	if is_warning():
		return "%s / %.1f S" % [telegraph_caption(), _active.remaining * Body.STEP]
	if _active.kind == Chunks.SPRINKLER:
		if _active.greeted and dog.state == Dog.SNIFF:
			return "* SPRINKLER PLAY / +4 HAPPINESS/S; WATER STILL PUSHES"
		return "* SPRINKLER SWEEP / WATER STILL PUSHES; PLANT"
	if _active.recalled:
		return "CAPITAN CALLED OFF / %s PASSES" % str(_active.kind).replace("_", " ").to_upper()
	if _active.greeted:
		return "D FRIENDLY GREETING / STAND STILL: +4 HAPPINESS/S" \
			if dog.state == Dog.SNIFF else "D FRIENDLY DOG / GREETING COMPLETE"
	return {
		Chunks.JOGGER: "J FOLLOWING JOGGER / BACKWARD DRAG",
		Chunks.PIGEON_FLOCK: "VV FLOCK TUGS / STEP BETWEEN BEATS",
		Chunks.OTHER_DOG: "D GREETING TUG / STOP AND SETTLE",
	}[_active.kind]


func caption(body: Body) -> String:
	if _wet_feet.has(true):
		return "~ PUDDLE / FOOT GRIP 0.30"
	var slope := body.ground_slope(body.positions[Body.HIP].x)
	if absf(slope) > Body.EPSILON:
		return "^ SLOPE / %s" % ("UPHILL" if slope > 0.0 else "DOWNHILL")
	return ""


func snapshot() -> Dictionary:
	return {"splashes": splashes, "wet_feet": _wet_feet.duplicate(),
		"telegraphs": telegraphs, "greetings": greetings, "walker_force": walker_force,
		"dog_target": dog_target, "focus_enabled": focus_enabled,
		"route_revision": _route_revision, "last_warning": _last_warning,
		"active": _active.start if _active != null else null, "encounters": moving_states()}


## Renderers get copies, including essential actor positions on the model clock.
func moving_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for encounter: Encounter in _encounters.values():
		result.append(encounter.snapshot())
	return result


func _sync(route: Route) -> void:
	var retained: Dictionary[float, Encounter] = {}
	for slot in route.hazard_slots():
		if slot["kind"] not in Chunks.MOVING_KINDS:
			continue
		var start := float(slot["from"])
		retained[start] = _encounters[start] if _encounters.has(start) else Encounter.new(slot)
	_encounters = retained
	if _active != null and not _encounters.has(_active.start):
		_active = null
	_route_revision = route.revision


func _warn(long_warnings: bool) -> void:
	_active.phase = Phase.WARNING
	_active.warning_ticks = WARNING_TICKS * (2 if long_warnings else 1)
	_active.remaining = _active.warning_ticks
	_last_warning = _active.kind
	telegraphs += 1


func _finish() -> void:
	_active.phase = Phase.DONE
	_active = null
