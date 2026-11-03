extends RefCounted

## A bounded window over a seeded, random-access Park. Queries never consume walk RNG.

const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const EVENT_INTERVAL := 120.0
const BOSS_INTERVAL := 250.0
const BEHIND_CELLS := 1
const AHEAD_CELLS := 4

var seed_value := 0
var revision := 0
var _pool: Array[Dictionary] = []
var _valid := true
var _first := 0
var _last := -1
var _chunks: Array[Dictionary] = []
var _ground := PackedVector2Array()
var _surfaces: Array[Dictionary] = []
var _hazards: Array[Dictionary] = []
var _sniffs := PackedVector2Array()


func _init(walk_seed := 0) -> void:
	_pool = Chunks.park_pool()
	var ids := PackedStringArray()
	for chunk in _pool:
		var error := Chunks.validation_error(chunk)
		if not error.is_empty() or float(chunk["length"]) != Chunks.LENGTH \
			or ids.has(chunk["id"]):
			push_error("Capitan's Walk Park chunk '%s' is invalid: %s." % [
				chunk.get("id", ""), error if not error.is_empty()
					else "streaming requires unique twenty-metre chunks",
			])
			_valid = false
			return
		ids.append(chunk["id"])
	reset(walk_seed)


func is_valid() -> bool:
	return _valid


func reset(walk_seed := 0) -> void:
	if not _valid:
		push_error("Capitan's Walk cannot reset an invalid Park route.")
		return
	seed_value = walk_seed
	revision = 0
	_first = 0
	_last = -1
	prepare(-2.0, 4.0)


## Terrain stays beneath both actors, including a dog behind the hand or a backtrack.
func prepare(minimum_x: float, maximum_x: float) -> bool:
	if not _valid or not is_finite(minimum_x) or not is_finite(maximum_x) \
		or minimum_x > maximum_x:
		push_error("Capitan's Walk route bounds must be finite and ordered.")
		return false
	var first := floori(minimum_x / Chunks.LENGTH) - BEHIND_CELLS
	var last := floori(maximum_x / Chunks.LENGTH) + AHEAD_CELLS
	if first == _first and last == _last:
		return true
	_first = first
	_last = last
	_chunks.clear()
	_ground.clear()
	_surfaces.clear()
	_hazards.clear()
	_sniffs.clear()
	for index in range(_first, _last + 1):
		var chunk := chunk_at(index)
		_chunks.append(chunk)
		var points: PackedVector2Array = chunk["ground"]
		for point in points:
			if _ground.is_empty() or point.x > _ground[-1].x:
				_ground.append(point)
		for surface: Dictionary in chunk["surfaces"]:
			_surfaces.append(surface.duplicate())
		for hazard: Dictionary in chunk["hazards"]:
			_hazards.append(hazard.duplicate())
		_sniffs.append_array(chunk["sniffs"])
	revision += 1
	return true


## A cell's own seed makes eviction, previewing and revisiting independent of query order.
func chunk_at(index: int) -> Dictionary:
	var origin := float(index) * Chunks.LENGTH
	var markers := _markers(origin - Chunks.SNIFF_CLEARANCE,
		origin + Chunks.LENGTH + Chunks.SNIFF_CLEARANCE)
	var chunk: Dictionary
	if index <= 0 or not markers.is_empty():
		chunk = _pool[0].duplicate(true)
		if index != 0:
			chunk["id"] = "reserved_space" if index > 0 else "before_start"
	else:
		var choices: Array[Dictionary] = []
		for candidate in _pool:
			if int(candidate["tier"]) <= tier_at(origin + 10.0):
				choices.append(candidate)
		var random := RandomNumberGenerator.new()
		random.seed = seed_value ^ (index * 104729)
		chunk = choices[random.randi_range(0, choices.size() - 1)].duplicate(true)
	chunk["index"] = index
	chunk["origin"] = origin
	chunk["difficulty_tier"] = tier_at(origin + 10.0)
	chunk["reservations"] = []
	var reservation_at_start := false
	var reservation_at_middle := false
	for marker in markers:
		var x := float(marker["distance"])
		if x >= origin and x < origin + Chunks.LENGTH:
			chunk["reservations"].append(marker)
			if x == origin:
				reservation_at_start = true
			elif x == origin + Chunks.LENGTH * 0.5:
				reservation_at_middle = true
	# The 120/250 m lattice also places markers at adjacent cell boundaries.
	var sniff_x := 16.0 if reservation_at_start and reservation_at_middle \
		else 12.0 if reservation_at_start else 4.0
	var sniffs: PackedVector2Array = chunk["sniffs"]
	if index < 0:
		sniffs.clear()
	elif not markers.is_empty():
		sniffs = PackedVector2Array([Vector2(sniff_x, 0.0)])
	for spot in sniffs.size():
		sniffs[spot].x += origin
	chunk["sniffs"] = sniffs
	var points: PackedVector2Array = chunk["ground"]
	for point in points.size():
		points[point].x += origin
	chunk["ground"] = points
	for field in ["surfaces", "hazards"]:
		for slot: Dictionary in chunk[field]:
			slot["from"] = float(slot["from"]) + origin
			slot["to"] = float(slot["to"]) + origin
			if field == "hazards" and slot["kind"] in Chunks.MOVING_KINDS:
				slot["side"] *= -1.0 if (seed_value ^ index) & 1 else 1.0
	for item: Dictionary in chunk["items"]:
		item["position"] += Vector2(origin, 0.0)
	return chunk


func ground() -> PackedVector2Array:
	return _ground.duplicate()


func surfaces() -> Array[Dictionary]:
	return _surfaces.duplicate(true)


func sniff_spots() -> PackedVector2Array:
	return _sniffs.duplicate()


func visible_chunks() -> Array[Dictionary]:
	return _chunks.duplicate(true)


## Encounter state belongs to the fixed clock, never to these copied route slots.
func hazard_slots() -> Array[Dictionary]:
	return _hazards.duplicate(true)


func is_puddle_at(x: float) -> bool:
	for hazard in _hazards:
		if hazard["kind"] == Chunks.PUDDLE and x >= float(hazard["from"]) \
			and x < float(hazard["to"]):
			return true
	return false


func snapshot() -> Dictionary:
	return {"seed": seed_value, "revision": revision,
		"first": _first, "last": _last, "chunks": _chunks.duplicate(true)}


static func tier_at(x: float) -> int:
	return 1 if x < 50.0 else 2 if x < 150.0 else 3


## These are reserved data, not playable events or an announced boss roster.
static func _markers(minimum_x: float, maximum_x: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind in [&"event", &"boss"]:
		var interval := EVENT_INTERVAL if kind == &"event" else BOSS_INTERVAL
		for number in range(maxi(1, ceili(minimum_x / interval)),
			floori(maximum_x / interval) + 1):
			result.append({"kind": kind, "distance": float(number) * interval})
	return result
