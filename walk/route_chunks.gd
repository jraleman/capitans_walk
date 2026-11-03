extends RefCounted

## Authored Park cells keep terrain and moving encounters reproducible on demand.

const LENGTH := 20.0
const SNIFF_CLEARANCE := 6.0
const MAX_SNIFF_GAP := 40.0
const MAX_STEP := 0.25
const PUDDLE := &"puddle"
const SLOPE := &"slope"
const SPRINKLER := &"sprinkler"
const JOGGER := &"jogger"
const PIGEON_FLOCK := &"pigeon_flock"
const OTHER_DOG := &"other_dog"
const MOVING_KINDS: Array[StringName] = [SPRINKLER, JOGGER, PIGEON_FLOCK, OTHER_DOG]
const PUDDLE_FRICTION := 0.30


static func park_pool() -> Array[Dictionary]:
	return [
		_chunk("opening_path", 1, _flat()),
		_chunk("small_puddle", 1, _flat(), [_puddle(12.0, 14.0)]),
		_chunk("low_rise", 1, _hill(0.08), [_slope()]),
		_chunk("shallow_dip", 1, _hill(-0.08), [_slope()]),
		_chunk("quiet_verge", 2, _flat()),
		_chunk("long_puddle", 2, _flat(), [_puddle(11.0, 16.0)]),
		_chunk("garden_rise", 2, _hill(0.16), [_slope()]),
		_chunk("garden_dip", 2, _hill(-0.16), [_slope()]),
		_chunk("split_puddles", 3, _flat(), [
			_puddle(11.0, 12.5), _puddle(15.5, 17.0),
		]),
		_chunk("double_rise", 3, PackedVector2Array([
			Vector2.ZERO, Vector2(10.0, 0.0), Vector2(12.0, 0.16),
			Vector2(14.0, 0.0), Vector2(16.0, 0.16), Vector2(18.0, 0.0),
			Vector2(LENGTH, 0.0),
		]), [_slope()]),
		_chunk("high_rise", 3, _hill(0.22), [_slope()]),
		_chunk("deep_dip", 3, _hill(-0.22), [_slope()]),
		_chunk("sprinkler_lawn", 2, _flat(), [_moving(SPRINKLER, 16.0)]),
		_chunk("approaching_jogger", 2, _flat(), [_moving(JOGGER, 16.0)]),
		_chunk("park_pigeon_flock", 3, _flat(), [_moving(PIGEON_FLOCK, 15.0)]),
		_chunk("friendly_dog", 3, _flat(), [_moving(OTHER_DOG, 15.0)]),
	]


static func hazard_spacing(tier: int) -> float:
	return [3.0, 2.5, 2.0][clampi(tier, 1, 3) - 1]


## Return an actionable validation error; callers decide whether to reject authored data.
static func validation_error(chunk: Dictionary) -> String:
	if not chunk.has_all(["id", "length", "tier", "ground", "surfaces",
		"sniffs", "items", "hazards"]):
		return "missing chunk fields"
	if not chunk["id"] is String or (chunk["id"] as String).is_empty():
		return "chunk id must be a nonempty string"
	if not _number(chunk["length"]) or float(chunk["length"]) < 8.0 \
		or float(chunk["length"]) > 20.0:
		return "chunk length must be 8-20 metres"
	if not chunk["tier"] is int or int(chunk["tier"]) < 1 or int(chunk["tier"]) > 3:
		return "chunk tier must be 1-3"
	if not chunk["ground"] is PackedVector2Array:
		return "ground must be a packed polyline"
	var ground: PackedVector2Array = chunk["ground"]
	var length := float(chunk["length"])
	if ground.size() < 2 or ground[0] != Vector2.ZERO \
		or ground[-1] != Vector2(length, 0.0):
		return "ground endpoints must join at zero height"
	for index in ground.size():
		if not ground[index].is_finite():
			return "ground points must be finite"
		if index > 0 and (ground[index].x <= ground[index - 1].x \
			or absf(ground[index].y - ground[index - 1].y) > MAX_STEP):
			return "ground X must increase and height changes must not exceed 0.25 metres"
	if not chunk["sniffs"] is PackedVector2Array \
		or (chunk["sniffs"] as PackedVector2Array).is_empty():
		return "every chunk needs a sniff spot"
	var sniffs: PackedVector2Array = chunk["sniffs"]
	for spot in sniffs:
		if not spot.is_finite() or spot.x < 0.0 or spot.x > length or absf(spot.y) > 0.30:
			return "sniff spots must lie on the path"
		for segment in ground.size() - 1:
			if ground[segment + 1].x > spot.x - SNIFF_CLEARANCE \
				and ground[segment].x < spot.x + SNIFF_CLEARANCE \
				and ground[segment].y != ground[segment + 1].y:
				return "sniff spots need six metres clear of slopes"
	for field in ["surfaces", "items", "hazards"]:
		if not chunk[field] is Array:
			return "%s must be an array" % field
	for item: Variant in chunk["items"]:
		if not item is Dictionary or not item.has_all(["kind", "position"]):
			return "items need a kind and position"
		if item["kind"] not in [&"treat", &"treat_bag", &"tennis_ball"] \
			or not item["position"] is Vector2:
			return "invalid item slot"
		var point: Vector2 = item["position"]
		if not point.is_finite() or point.x < 0.0 or point.x > length or absf(point.y) > 0.30:
			return "item slots must lie on the path"
	var previous_to := -INF
	for hazard: Variant in chunk["hazards"]:
		if not hazard is Dictionary or not hazard.has_all(["kind", "from", "to"]):
			return "hazards need a kind and bounds"
		if hazard["kind"] not in [PUDDLE, SLOPE] + MOVING_KINDS \
			or not _bounds(hazard, length):
			return "unsupported hazard or invalid bounds"
		if hazard["kind"] in MOVING_KINDS and (not hazard.has("side") \
			or not _number(hazard["side"]) or absf(float(hazard["side"])) != 1.0):
			return "moving hazards need a finite side of -1 or +1"
		var start := float(hazard["from"])
		var finish := float(hazard["to"])
		if start - previous_to < hazard_spacing(int(chunk["tier"])):
			return "hazard intervals must be ordered and separated for their tier"
		previous_to = finish
		for spot in sniffs:
			if spot.x > start - SNIFF_CLEARANCE and spot.x < finish + SNIFF_CLEARANCE:
				return "sniff spots need six metres clear of hazards"
		if hazard["kind"] == PUDDLE:
			var matching_surface := false
			for surface: Variant in chunk["surfaces"]:
				if surface is Dictionary and surface.has_all(["from", "to", "friction"]) \
					and surface["from"] == start and surface["to"] == finish \
					and surface["friction"] == PUDDLE_FRICTION:
					matching_surface = true
			if not matching_surface:
				return "puddles need a matching 0.30-friction surface"
	previous_to = -INF
	for surface: Variant in chunk["surfaces"]:
		if not surface is Dictionary or not surface.has_all(["from", "to", "friction"]) \
			or not _bounds(surface, length) or not _number(surface["friction"]):
			return "invalid surface bounds or friction"
		if float(surface["friction"]) < 0.0 or float(surface["friction"]) > 1.0 \
			or float(surface["from"]) < previous_to:
			return "surfaces must not overlap and friction must be 0-1"
		previous_to = float(surface["to"])
		var marked := false
		for hazard: Dictionary in chunk["hazards"]:
			if hazard["kind"] == PUDDLE and hazard["from"] == surface["from"] \
				and hazard["to"] == surface["to"]:
				marked = true
		if not marked:
			return "Park surfaces must have a visible puddle hazard"
	return ""


static func _chunk(
	id: String, tier: int, ground: PackedVector2Array, hazards: Array[Dictionary] = []
) -> Dictionary:
	var surfaces: Array[Dictionary] = []
	for hazard in hazards:
		if hazard["kind"] == PUDDLE:
			surfaces.append({"from": hazard["from"], "to": hazard["to"],
				"friction": PUDDLE_FRICTION})
	return {"id": id, "length": LENGTH, "tier": tier, "ground": ground,
		"surfaces": surfaces, "sniffs": PackedVector2Array([Vector2(4.0, 0.0)]),
		"items": [], "hazards": hazards}


static func _flat() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(LENGTH, 0.0)])


static func _hill(height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO, Vector2(10.0, 0.0), Vector2(12.0, height),
		Vector2(16.0, height), Vector2(18.0, 0.0), Vector2(LENGTH, 0.0),
	])


static func _puddle(start: float, finish: float) -> Dictionary:
	return {"kind": PUDDLE, "from": start, "to": finish}


static func _slope() -> Dictionary:
	return {"kind": SLOPE, "from": 10.0, "to": 18.0}


static func _moving(kind: StringName, finish: float) -> Dictionary:
	return {"kind": kind, "from": 10.0, "to": finish, "side": 1.0}


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _bounds(value: Dictionary, length: float) -> bool:
	return _number(value["from"]) and _number(value["to"]) \
		and float(value["from"]) >= 0.0 and float(value["to"]) <= length \
		and float(value["from"]) < float(value["to"])
