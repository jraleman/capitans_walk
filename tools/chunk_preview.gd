extends Control

## Development-only catalogue view; it never creates or moves a pretend walker.

const Route = preload("res://games/capitans_walk/walk/route_generator.gd")
const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const INK := Color("23252b")
const CREAM := Color("fdf5e6")
const GRASS := Color("6fae4f")
const WATER := Color("245b94")

var _seed := 0
var _index := 0
var _route := Route.new()
var _chunk: Dictionary = {}


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		for prefix in ["--route-seed=", "--chunk-index="]:
			if not argument.begins_with(prefix):
				continue
			var value := argument.trim_prefix(prefix)
			if not value.is_valid_int():
				push_error("Park preview requires integer seed and chunk arguments.")
				get_tree().quit(1)
				return
			if prefix == "--route-seed=":
				_seed = int(value)
			else:
				_index = int(value)
	_refresh()
	resized.connect(queue_redraw)
	_capture_if_requested.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_LEFT:
			_index = maxi(0, _index - 1)
		KEY_RIGHT:
			_index += 1
		KEY_R:
			_seed += 1
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	_refresh()
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	_route.reset(_seed)
	_chunk = _route.chunk_at(_index)
	queue_redraw()


func _draw() -> void:
	if _chunk.is_empty():
		return
	var font := get_theme_default_font()
	var margin := 32.0
	var width := size.x - margin * 2.0
	var baseline := size.y * 0.52
	var scale_x := width / Chunks.LENGTH
	var scale_y := minf(250.0, size.y * 0.4)
	var origin := float(_chunk["origin"])
	draw_rect(Rect2(Vector2.ZERO, size), CREAM)
	draw_multiline_string(font, Vector2(margin, 40.0),
		"PARK CHUNK / %s\nSeed %d / cell %d / %.0f-%.0f m / tier %d" % [
			_chunk["id"], _seed, _index, origin, origin + Chunks.LENGTH,
			_chunk["difficulty_tier"],
		], HORIZONTAL_ALIGNMENT_LEFT, width, 22, 3, INK)
	var points := PackedVector2Array()
	for point: Vector2 in _chunk["ground"]:
		points.append(Vector2(margin + (point.x - origin) * scale_x,
			baseline - point.y * scale_y))
	var fill := points.duplicate()
	fill.append(Vector2(size.x - margin, baseline + 30.0))
	fill.append(Vector2(margin, baseline + 30.0))
	draw_colored_polygon(fill, GRASS)
	draw_polyline(points, INK, 4.0, true)
	for spot: Vector2 in _chunk["sniffs"]:
		var centre := Vector2(margin + (spot.x - origin) * scale_x, baseline)
		draw_arc(centre, 12.0, 0.0, TAU, 24, INK, 3.0, true)
		draw_string(font, centre + Vector2(-25.0, 55.0), "SNIFF",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, INK)
	for hazard: Dictionary in _chunk["hazards"]:
		var start := float(hazard["from"]) - origin
		var finish := float(hazard["to"]) - origin
		var left := margin + start * scale_x
		var label := "^ SLOPE / GRAVITY"
		if hazard["kind"] == Chunks.PUDDLE:
			draw_rect(Rect2(Vector2(left, baseline),
				Vector2((finish - start) * scale_x, 10.0)), WATER)
			label = "~ PUDDLE / GRIP 0.30"
		elif hazard["kind"] in Chunks.MOVING_KINDS:
			draw_dashed_line(Vector2(left, baseline),
				Vector2(margin + finish * scale_x, baseline), INK, 3.0, 6.0)
			label = {
				Chunks.SPRINKLER: "* SPRINKLER / TICKS THEN SWEEP\nSTOP TO PLAY; WATER PUSHES",
				Chunks.JOGGER: "J JOGGER / APPROACH AND PASS\nBACKWARD DRAG",
				Chunks.PIGEON_FLOCK: "VV PIGEON FLOCK\nTHREE SIDEWAYS TUG BEATS",
				Chunks.OTHER_DOG: "D FRIENDLY DOG\nSTOP TO GREET; WALKING TUGS",
			}[hazard["kind"]]
			label += "\nSide %+.0f / 0.8 s warning" % float(hazard["side"])
		draw_multiline_string(font, Vector2(left, baseline + 55.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, maxf(180.0, (finish - start) * scale_x),
			16, 4, INK)
	for marker: Dictionary in _chunk["reservations"]:
		var x := margin + (float(marker["distance"]) - origin) * scale_x
		draw_dashed_line(Vector2(x, baseline - 70.0), Vector2(x, baseline + 20.0),
			INK, 2.0, 6.0)
		draw_string(font, Vector2(clampf(x, margin, size.x - 240.0), baseline - 85.0),
			"%s SPACE (NOT ACTIVE)" % str(marker["kind"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, 240.0, 16, INK)
	draw_multiline_string(font, Vector2(margin, size.y - 100.0),
		("Left / Right: chunk   R: next seed   Esc: quit\n"
			+ "Static slots, not a walk; vertical scale exaggerated. Long warnings doubles telegraphs.\n"
			+ "Pickups, events and bosses are not implemented."),
		HORIZONTAL_ALIGNMENT_LEFT, width, 18, 5, INK)


func _capture_if_requested() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capitan-route-capture="):
			continue
		if DisplayServer.get_name() == "headless":
			push_error("A Park preview capture requires a graphics window.")
			get_tree().quit(1)
			return
		await RenderingServer.frame_post_draw
		var path := argument.trim_prefix("--capitan-route-capture=")
		var error := get_viewport().get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Park preview capture failed: %s." % error_string(error))
		else:
			print("Park preview captured seed %d / cell %d / %s." % [
				_seed, _index, _chunk["id"],
			])
		get_tree().quit(0 if error == OK else 1)
