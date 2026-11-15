extends Control

## Park silhouettes and the diagnostic spike read the same actual solver positions.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const Hazards = preload("res://games/capitans_walk/walk/hazards.gd")
const WalkHUD = preload("res://games/capitans_walk/ui/walk_hud.gd")
const INK := Color("23252b")
const SKY := Color("bfe3f0")
const PAVEMENT := Color("c9c1b4")
const GRASS := Color("6fae4f")
const LEFT := Color("245b94")
const RIGHT := Color("a34a28")
const CREAM := Color("fdf5e6")
const MARGIN := 24.0
const PARTICLE_LABELS := ["HIP", "NECK", "HEAD", "L KNEE", "L ANKLE", "L TOE",
	"R KNEE", "R ANKLE", "R TOE", "HAND"]

var _body: Body
var _frame := InputFrame.new()
var _keys := PackedStringArray(["Q", "W", "O", "P"])
var _walk: Walk
var _whistle_key := "Space"
var _easy_keys := PackedStringArray(["A", "D"])
var _easy_enabled := false
var _hud := WalkHUD.new()
var control_tray := HFlowContainer.new()
var game_presentation := false
var reduced_motion := false
var unit := 1.0
var _key_labels: Array[Label] = []
var show_keycaps := true:
	set(value):
		show_keycaps = value
		_hud.compact = not value
		_hud.queue_redraw()
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240.0, 260.0)
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(control_tray)
	control_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_tray.hide()
	control_tray.visibility_changed.connect(queue_redraw)
	for index in 5:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control_tray.add_child(label)
		_key_labels.append(label)


## Both entry scenes supply the same model; the view never advances it.
func present(body: Body, frame: InputFrame, walk: Walk = null) -> void:
	_body = body
	_frame = frame
	_walk = walk
	_hud.minimal = game_presentation
	_hud.unit = unit
	_hud.present(body, walk)
	if control_tray.visible:
		_sync_controls()
	queue_redraw()


## Keycaps reflect Settings rather than becoming a second set of hardcoded controls.
func configure_keys(
	labels: PackedStringArray, whistle_key := "Space",
	easy_labels := PackedStringArray(["A", "D"]), easy_enabled := false
) -> void:
	_keys = labels.duplicate()
	_whistle_key = whistle_key
	_easy_keys = easy_labels.duplicate()
	_easy_enabled = easy_enabled
	_sync_controls()
	queue_redraw()


func _sync_controls() -> void:
	if _key_labels.is_empty():
		return
	var labels := _easy_keys if _easy_enabled else _keys
	var strengths := PackedFloat32Array([_frame.easy_left, _frame.easy_right]) if _easy_enabled \
		else PackedFloat32Array([_frame.q, _frame.w, _frame.o, _frame.p])
	var names := ["Left leg", "Right leg"] if _easy_enabled \
		else ["Left thigh", "Right thigh", "Left calf", "Right calf"]
	control_tray.add_theme_constant_override("h_separation", roundi(12 * unit))
	control_tray.add_theme_constant_override("v_separation", roundi(4 * unit))
	for index in 5:
		var label := _key_labels[index]
		label.add_theme_font_size_override("font_size", roundi(13 * unit))
		label.visible = index < labels.size() or index == 4
		if index < labels.size():
			label.text = "%s  %s" % [labels[index], names[index]]
			label.add_theme_color_override("font_color", LEFT if strengths[index] > 0 else INK)
		elif index == 4:
			label.text = "%s  Whistle" % _whistle_key
	control_tray.size.x = maxf(1, size.x - 24 * unit)
	control_tray.position = Vector2(12 * unit,
		size.y - control_tray.get_combined_minimum_size().y - 12 * unit)


func _draw() -> void:
	if _body == null or size.x < 100.0 or size.y < 100.0:
		return
	var font := get_theme_default_font()
	var ground_y := size.y * (0.72 if game_presentation else 0.77)
	var hip_x := _body.positions[Body.HIP].x
	var left_x := hip_x - 1.4
	var right_x := hip_x + 2.8
	if _walk != null:
		left_x = minf(left_x, _walk.dog.position.x - 0.7)
		right_x = maxf(right_x, _walk.dog.position.x + 0.7)
		for state in _walk.hazards.moving_states():
			if state["phase"] not in [Hazards.Phase.WARNING, Hazards.Phase.ACTIVE]:
				continue
			var actor: Vector2 = state["actor"]
			left_x = minf(left_x, actor.x - 0.6)
			right_x = maxf(right_x, actor.x + 0.6)
	var header_height := _hud.header_height()
	var scale_factor := minf(maxf(16.0, (ground_y - header_height) / 1.6),
		(size.x - MARGIN * 2.0) / (right_x - left_x))
	var base_y := _body.ground_height(hip_x)
	var origin := Vector2(MARGIN + (hip_x - left_x) * scale_factor, ground_y)
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	if game_presentation:
		_draw_park_backdrop(ground_y, scale_factor, hip_x)
	var ground_points := PackedVector2Array()
	var visible_start := hip_x - origin.x / scale_factor
	var visible_end := hip_x + (size.x - origin.x) / scale_factor
	ground_points.append(Vector2(0.0,
		ground_y - (_body.ground_height(visible_start) - base_y) * scale_factor))
	for point in _body.ground_profile():
		if point.x > visible_start and point.x < visible_end:
			ground_points.append(origin + Vector2((point.x - hip_x) * scale_factor,
				-(point.y - base_y) * scale_factor))
	ground_points.append(Vector2(size.x,
		ground_y - (_body.ground_height(visible_end) - base_y) * scale_factor))
	var fill := ground_points.duplicate()
	fill.append(Vector2(size.x, size.y))
	fill.append(Vector2(0.0, size.y))
	draw_colored_polygon(fill, Color("718367") if game_presentation else GRASS)
	if game_presentation:
		var path := ground_points.duplicate()
		for index in range(ground_points.size() - 1, -1, -1):
			path.append(ground_points[index] + Vector2(0, 0.14 * scale_factor))
		draw_colored_polygon(path, Color("cbbfa0"))
		draw_polyline(ground_points, Color("eadbc0"), maxf(1, 0.018 * scale_factor), true)
	else:
		draw_polyline(ground_points, INK, 5.0, true)
	if _walk != null and _walk.route != null:
		_draw_route(font, origin, scale_factor, hip_x, base_y)
		_draw_moving_hazards(font, origin, scale_factor, hip_x, base_y)
	for metre in range(floori(hip_x - origin.x / scale_factor),
		ceili(hip_x + (size.x - origin.x) / scale_factor) + 1):
		if game_presentation:
			break
		var x := origin.x + (float(metre) - hip_x) * scale_factor
		var y := ground_y - (_body.ground_height(float(metre)) - base_y) * scale_factor
		draw_line(Vector2(x, y), Vector2(x, y + 16.0), INK, 2.0)
		draw_string(font, Vector2(x + 5.0, y + 34.0), "%d m" % metre,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, INK)
	if _walk != null:
		for spot in _walk.sniff_spots():
			var point := origin + Vector2((spot.x - hip_x) * scale_factor,
				-(_body.ground_height(spot.x) - base_y) * scale_factor)
			if point.x < MARGIN or point.x > size.x - MARGIN:
				continue
			draw_arc(point, 18.0, 0.0, TAU, 24, CREAM, 7.0, true)
			draw_arc(point, 18.0, 0.0, TAU, 24, INK, 2.0, true)
			if not game_presentation:
				draw_string(font, point + Vector2(-24.0, -25.0), "SNIFF",
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, INK)

	var points := PackedVector2Array()
	for point in _body.positions:
		points.append(origin + Vector2((point.x - hip_x) * scale_factor,
			-(point.y - base_y) * scale_factor))
	if game_presentation:
		_draw_walker(points, scale_factor)
		if _walk != null:
			_draw_dog_and_leash(font, points[Body.HAND], origin, scale_factor, hip_x, base_y)
		return
	for leg in [1, 0]:
		var color := LEFT if leg == 0 else RIGHT
		var knee: int = Body.KNEES[leg]
		var ankle: int = Body.ANKLES[leg]
		var toe: int = Body.TOES[leg]
		draw_line(points[Body.HIP], points[knee], color, 9.0, true)
		draw_line(points[knee], points[ankle], color, 9.0, true)
		draw_line(points[ankle], points[toe], color, 12.0, true)
	draw_line(points[Body.HIP], points[Body.NECK], INK, 14.0, true)
	draw_line(points[Body.NECK], points[Body.HEAD], INK, 8.0, true)
	draw_line(points[Body.NECK], points[Body.HAND], INK, 6.0, true)
	draw_circle(points[Body.HEAD], Body.RADII[Body.HEAD] * scale_factor, CREAM)
	draw_arc(points[Body.HEAD], Body.RADII[Body.HEAD] * scale_factor, 0.0, TAU, 32, INK, 2.0)
	for particle in Body.PARTICLE_COUNT:
		draw_circle(points[particle], 5.0, CREAM)
		draw_circle(points[particle], 5.0, INK, false, 1.5)
		if _body.contacts[particle]:
			draw_rect(Rect2(points[particle] - Vector2(7.0, 7.0), Vector2(14.0, 14.0)),
				INK, false, 2.0)
		if particle in [Body.HIP, Body.NECK, Body.HAND, Body.LEFT_KNEE, Body.RIGHT_KNEE]:
			var offset := Vector2(-92.0, -10.0) if particle == Body.RIGHT_KNEE \
				else Vector2(10.0, -10.0)
			draw_string(font, points[particle] + offset, PARTICLE_LABELS[particle],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, INK)
	if _walk != null:
		_draw_dog_and_leash(font, points[Body.HAND], origin, scale_factor, hip_x, base_y)
	_draw_keys(font)
	if _body.is_over():
		draw_string(font, Vector2(MARGIN, size.y - (114.0 if _walk != null else 84.0)),
			"OFF THE PATH" if _body.end_cause == "off_path" else "A MAGNIFICENT TUMBLE",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, INK)


func _draw_route(
	font: Font, origin: Vector2, scale_factor: float, hip_x: float, base_y: float
) -> void:
	for chunk in _walk.route.visible_chunks():
		for hazard: Dictionary in chunk["hazards"]:
			if hazard["kind"] in Chunks.MOVING_KINDS:
				continue
			var start := float(hazard["from"])
			var finish := float(hazard["to"])
			var left := origin.x + (start - hip_x) * scale_factor
			var right := origin.x + (finish - hip_x) * scale_factor
			if right < MARGIN or left > size.x - MARGIN:
				continue
			var middle := (start + finish) * 0.5
			var y := origin.y - (_body.ground_height(middle) - base_y) * scale_factor
			var label := "^ SLOPE"
			if hazard["kind"] == Chunks.PUDDLE:
				label = "~ PUDDLE"
				draw_rect(Rect2(Vector2(left, y), Vector2(right - left, 10.0)), LEFT)
				for ripple in 3:
					var x := lerpf(left, right, float(ripple + 1) / 4.0)
					draw_line(Vector2(x - 6.0, y + 5.0),
						Vector2(x + 6.0, y + 5.0), CREAM, 2.0, true)
			var text_x := clampf((left + right) * 0.5 - 38.0,
				MARGIN, size.x - MARGIN - 90.0)
			if not game_presentation:
				draw_string(font, Vector2(text_x, y - 25.0), label,
					HORIZONTAL_ALIGNMENT_LEFT, 90.0, 14, INK)


func _draw_moving_hazards(
	font: Font, origin: Vector2, scale_factor: float, hip_x: float, base_y: float
) -> void:
	for state in _walk.hazards.moving_states():
		if state["phase"] == Hazards.Phase.DONE:
			continue
		var start := float(state["from"])
		var finish := float(state["to"])
		var left := origin.x + (start - hip_x) * scale_factor
		var right := origin.x + (finish - hip_x) * scale_factor
		if right < MARGIN or left > size.x - MARGIN:
			continue
		var actor: Vector2 = state["actor"]
		var point := origin + Vector2((actor.x - hip_x) * scale_factor,
			-(_body.ground_height(actor.x) - base_y) * scale_factor
			+ actor.y * scale_factor * 0.2)
		var active := int(state["phase"]) == Hazards.Phase.ACTIVE
		var label: String = {
			Chunks.SPRINKLER: "* SPRINKLER",
			Chunks.JOGGER: "J JOGGER <-",
			Chunks.PIGEON_FLOCK: "VV FLOCK",
			Chunks.OTHER_DOG: "D FRIENDLY DOG",
		}[state["kind"]]
		if state["phase"] == Hazards.Phase.WARNING:
			label += " !"
		var line_y := origin.y - (_body.ground_height(start) - base_y) * scale_factor + 14.0
		draw_dashed_line(Vector2(maxf(MARGIN, left), line_y),
			Vector2(minf(size.x - MARGIN, right), line_y), INK, 2.0, 6.0)
		var label_x := clampf(point.x - 50.0, MARGIN, size.x - MARGIN - 140.0)
		draw_rect(Rect2(Vector2(label_x - 4.0, line_y + 6.0), Vector2(148.0, 23.0)), CREAM)
		draw_string(font, Vector2(label_x, line_y + 23.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, 140.0, 14, INK)
		match state["kind"]:
			Chunks.SPRINKLER:
				var nozzle := point - Vector2(0.0, 0.2) * scale_factor
				draw_line(point, nozzle, INK, 5.0, true)
				draw_circle(nozzle, 6.0, CREAM)
				draw_circle(nozzle, 6.0, INK, false, 2.0)
				if active:
					var progress := 1.0 - float(state["remaining"]) / Hazards.SWEEP_TICKS
					var spray_x := lerpf(start, finish, (1.0 - cos(PI * progress)) * 0.5)
					var spray := origin + Vector2((spray_x - hip_x) * scale_factor,
						-(_body.ground_height(spray_x) - base_y) * scale_factor)
					draw_dashed_line(nozzle, spray, LEFT, 3.0, 5.0)
					var push := Vector2(0.0, float(state["side"]) * 0.22 * scale_factor)
					draw_line(spray, spray + push, INK, 3.0, true)
					draw_line(spray + push, spray + push * 0.65 + Vector2(6.0, 0.0),
						INK, 2.0, true)
					draw_line(spray + push, spray + push * 0.65 - Vector2(6.0, 0.0),
						INK, 2.0, true)
				else:
					draw_string(font, nozzle + Vector2(-5.0, -16.0), "*",
						HORIZONTAL_ALIGNMENT_LEFT, 20.0, 22, INK)
			Chunks.JOGGER:
				var head := point - Vector2(0.0, 1.08) * scale_factor
				var hip := point - Vector2(-0.08, 0.48) * scale_factor
				draw_circle(head, 0.10 * scale_factor, CREAM)
				draw_circle(head, 0.10 * scale_factor, INK, false, 2.0)
				draw_line(head + Vector2(0.0, 0.12) * scale_factor, hip, INK, 7.0, true)
				draw_line(head + Vector2(0.0, 0.28) * scale_factor,
					head + Vector2(-0.28, 0.38) * scale_factor, INK, 4.0, true)
				var stride := sin((Hazards.JOGGER_TICKS - int(state["remaining"]))
					* Body.STEP * 10.0) * 0.2 if active else 0.12
				for side in [-1.0, 1.0]:
					draw_line(hip, point + Vector2(stride * side, 0.0) * scale_factor,
						INK, 5.0, true)
			Chunks.PIGEON_FLOCK:
				var progress := 1.0 - float(state["remaining"]) \
					/ (Hazards.FLOCK_BEAT_TICKS * Hazards.FLOCK_BEATS) if active else 0.0
				for bird in 3:
					var centre := point + Vector2(float(bird - 1) * 0.24,
						-0.1 - progress * (0.5 + float(bird) * 0.15)) * scale_factor
					draw_circle(centre, 0.07 * scale_factor, CREAM)
					draw_circle(centre, 0.07 * scale_factor, INK, false, 2.0)
					draw_polyline(PackedVector2Array([
						centre + Vector2(-0.13, -0.07) * scale_factor, centre,
						centre + Vector2(0.13, -0.07) * scale_factor,
					]), INK, 2.0, true)
			Chunks.OTHER_DOG:
				var collar := point - Vector2(0.0, 0.28) * scale_factor
				draw_rect(Rect2(collar + Vector2(-0.38, 0.0) * scale_factor,
					Vector2(0.38, 0.18) * scale_factor), CREAM)
				draw_rect(Rect2(collar + Vector2(-0.38, 0.0) * scale_factor,
					Vector2(0.38, 0.18) * scale_factor), INK, false, 2.0)
				draw_circle(collar + Vector2(-0.4, -0.04) * scale_factor,
					0.10 * scale_factor, CREAM)
				draw_circle(collar + Vector2(-0.4, -0.04) * scale_factor,
					0.10 * scale_factor, INK, false, 2.0)
				for leg_x in [-0.3, -0.05]:
					draw_line(collar + Vector2(leg_x, 0.16) * scale_factor,
						point + Vector2(leg_x, 0.0) * scale_factor, INK, 3.0, true)
				draw_polyline(PackedVector2Array([
					collar, collar + Vector2(0.12, -0.16) * scale_factor,
					collar + Vector2(0.18, -0.12) * scale_factor,
				]), INK, 3.0, true)


func _draw_keys(font: Font) -> void:
	if not show_keycaps:
		return
	var portrait := Responsive.is_portrait(get_viewport_rect().size)
	if _walk != null:
		draw_string(font, Vector2(MARGIN, size.y - (110.0 if portrait else 80.0)),
			"%s whistle / %s" % [_whistle_key,
				"READY" if _walk.dog.cooldown_ticks == 0
				else "%.1f S COOLDOWN" % (_walk.dog.cooldown_ticks * Body.STEP)],
			HORIZONTAL_ALIGNMENT_LEFT, size.x - MARGIN * 2.0, 36 if portrait else 18, INK)
	var strengths: Array[float] = [_frame.q, _frame.w, _frame.o, _frame.p]
	var labels := _keys
	if _easy_enabled:
		strengths = [_frame.easy_left, _frame.easy_right]
		labels = _easy_keys
	var count := labels.size()
	var width := minf(110.0, (size.x - MARGIN * 2.0 - 10.0 * (count - 1)) / count)
	for index in count:
		var rect := Rect2(Vector2(MARGIN + float(index) * (width + 10.0),
			size.y - (84.0 if portrait else 60.0)), Vector2(width, 64.0 if portrait else 40.0))
		draw_rect(rect, INK if strengths[index] > 0.0 else CREAM)
		draw_rect(rect, INK, false, 2.0)
		draw_string(font, rect.position + Vector2(10.0, 44.0 if portrait else 27.0),
			"%s%s" % [labels[index], " +" if strengths[index] > 0.0 else ""],
			HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 36 if portrait else 22,
			CREAM if strengths[index] > 0.0 else INK)


func _draw_dog_and_leash(
	font: Font, hand: Vector2, origin: Vector2, scale_factor: float, hip_x: float, base_y: float
) -> void:
	var dog := _walk.dog
	var ground := origin + Vector2((dog.position.x - hip_x) * scale_factor,
		-(_body.ground_height(dog.position.x) - base_y) * scale_factor
		+ dog.position.y * scale_factor * 0.2)
	var collar := ground - Vector2(0.0, dog.profile.collar_height * scale_factor)
	var sag := maxf(0.0, _walk.leash.length - _walk.leash.separation) * scale_factor * 0.5
	var rope := PackedVector2Array()
	for index in 25:
		var along := float(index) / 24.0
		rope.append(hand.lerp(collar, along) + Vector2(0.0, sag * 4.0 * along * (1.0 - along)))
	draw_polyline(rope, INK, 3.0, true)
	if game_presentation:
		_draw_capitan(collar, ground, scale_factor)
		if dog.state != Dog.TROT:
			var bubble := collar - Vector2(0, 0.45 * scale_factor)
			draw_circle(bubble, 12 * unit, Color(CREAM, 0.85))
			draw_string(font, bubble + Vector2(-4, 5) * unit, dog.icon(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15 * unit), INK)
		return
	draw_rect(Rect2(collar + Vector2(-0.5, -0.05) * scale_factor,
		Vector2(0.54, 0.22) * scale_factor), PAVEMENT)
	draw_rect(Rect2(collar + Vector2(-0.5, -0.05) * scale_factor,
		Vector2(0.54, 0.22) * scale_factor), INK, false, 2.0)
	draw_circle(collar + Vector2(0.09, -0.08) * scale_factor, 0.12 * scale_factor, PAVEMENT)
	draw_circle(collar + Vector2(0.09, -0.08) * scale_factor, 0.12 * scale_factor, INK, false, 2.0)
	for leg_x in [-0.41, -0.1]:
		draw_line(collar + Vector2(leg_x, 0.12) * scale_factor,
			ground + Vector2(leg_x, 0.0) * scale_factor, INK, 4.0, true)
	draw_line(collar + Vector2(-0.5, 0.0) * scale_factor,
		collar + Vector2(-0.63, -0.16) * scale_factor, INK, 4.0, true)
	draw_circle(collar, 4.0, LEFT)
	draw_string(font, ground + Vector2(-0.45 * scale_factor, 22.0), "CAPITAN",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, INK)
	if dog.state != Dog.TROT:
		var bubble := collar - Vector2(0.0, 0.45 * scale_factor)
		draw_circle(bubble, 16.0, CREAM)
		draw_circle(bubble, 16.0, INK, false, 2.0)
		draw_string(font, bubble + Vector2(-5.0, 7.0), dog.icon(),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, INK)


func _draw_park_backdrop(ground_y: float, scale_factor: float, hip_x: float) -> void:
	for band in 24:
		var top := size.y * float(band) / 24
		draw_rect(Rect2(0, top, size.x, size.y / 24 + 1),
			Color("9ebfbc").lerp(Color("e5dfc5"), float(band) / 23))
	var shift := 0.0 if reduced_motion else hip_x * 0.16
	for layer in 2:
		var ridge := PackedVector2Array()
		for step in 41:
			var x := size.x * step / 40
			var phase := x / maxf(scale_factor, 1) * 0.7 + shift + layer * 2.3
			ridge.append(Vector2(x, ground_y - scale_factor * (
				0.35 + layer * 0.28 + sin(phase) * 0.23 + cos(phase * 0.47) * 0.18)))
		ridge.append(Vector2(size.x, size.y))
		ridge.append(Vector2(0, size.y))
		draw_colored_polygon(ridge, Color("bdc9ad") if layer == 0 else Color("94ad96"))
	for index in range(-2, ceili(size.x / maxf(1, scale_factor * 1.8)) + 2):
		var cell := index + floori(shift / 1.8)
		var x := (float(cell) * 1.8 - shift) * scale_factor
		var height := (0.75 + 0.15 * sin(float(cell) * 2.7)) * scale_factor
		var base := Vector2(x, ground_y - 0.22 * scale_factor)
		draw_line(base, base - Vector2(0, height), Color("7c8e7a"), 0.07 * scale_factor, true)
		var crown := base - Vector2(0, height)
		_oval(crown, Vector2(0.35, 0.43) * scale_factor, Color("809b86"))
		_oval(crown + Vector2(-0.15, 0.05) * scale_factor,
			Vector2(0.27, 0.32) * scale_factor, Color("9bb18e"))


func _draw_walker(points: PackedVector2Array, scale_factor: float) -> void:
	for leg in [1, 0]:
		var color := Color("45566a") if leg == 0 else Color("354655")
		var knee := int(Body.KNEES[leg])
		var ankle := int(Body.ANKLES[leg])
		var toe := int(Body.TOES[leg])
		for segment in [[Body.HIP, knee], [knee, ankle]]:
			draw_line(points[segment[0]], points[segment[1]], color, 0.105 * scale_factor, true)
			draw_circle(points[segment[1]], 0.052 * scale_factor, color)
		draw_line(points[ankle], points[toe], CREAM, 0.09 * scale_factor, true)
		draw_line(points[ankle] - Vector2(0, 0.018 * scale_factor),
			points[toe] - Vector2(0, 0.018 * scale_factor),
			LEFT if leg == 0 else RIGHT, 0.055 * scale_factor, true)
	var axis := (points[Body.NECK] - points[Body.HIP]).normalized()
	var side := axis.orthogonal() * 0.13 * scale_factor
	draw_colored_polygon(PackedVector2Array([
		points[Body.NECK] + side * 0.8, points[Body.NECK] - side * 0.8,
		points[Body.HIP] - side, points[Body.HIP] + side,
	]), Color("537c7d"))
	draw_line(points[Body.NECK] + side * 0.65, points[Body.HIP] + side * 0.65,
		Color("89a6a0"), 0.018 * scale_factor, true)
	draw_line(points[Body.NECK], points[Body.HAND], Color("537c7d"), 0.075 * scale_factor, true)
	draw_circle(points[Body.HAND], 0.047 * scale_factor, Color("e4b79a"))
	var head := points[Body.HEAD]
	var radius := Body.RADII[Body.HEAD] * scale_factor
	draw_line(points[Body.NECK], head, Color("d2a78d"), 0.07 * scale_factor, true)
	draw_circle(head, radius, Color("e4b79a"))
	draw_arc(head, radius * 0.9, PI * 0.85, TAU * 0.94, 20,
		Color("524e46"), radius * 0.35, true)
	draw_circle(head + Vector2(radius * 0.62, -radius * 0.08), radius * 0.09, INK)


func _draw_capitan(collar: Vector2, ground: Vector2, s: float) -> void:
	var white := Color("f5f0e2")
	_oval(ground + Vector2(-0.22, 0.03) * s, Vector2(0.38, 0.045) * s, Color(INK, 0.15))
	for x in [-0.41, -0.10]:
		draw_line(collar + Vector2(x, 0.08) * s, ground + Vector2(x, -0.025) * s,
			Color("d8d6c6"), 0.07 * s, true)
		_oval(ground + Vector2(x + 0.01, -0.025) * s, Vector2(0.06, 0.035) * s, white)
	_oval(collar + Vector2(-0.23, 0.04) * s, Vector2(0.30, 0.14) * s, white)
	for index in 6:
		var x := -0.48 + index * 0.075
		draw_colored_polygon(PackedVector2Array([
			collar + Vector2(x, -0.04) * s, collar + Vector2(x - 0.025, -0.13) * s,
			collar + Vector2(x + 0.07, -0.05) * s,
		]), white)
	draw_arc(collar + Vector2(-0.54, -0.12) * s, 0.10 * s,
		0.2, PI * 1.65, 16, white, 0.055 * s, true)
	var head := collar + Vector2(0.075, -0.075) * s
	_oval(head, Vector2(0.15, 0.14) * s, white)
	_oval(head + Vector2(-0.04, -0.02) * s, Vector2(0.083, 0.11) * s, INK)
	_oval(head + Vector2(-0.09, 0.065) * s, Vector2(0.065, 0.13) * s, INK)
	_oval(head + Vector2(0.05, 0.04) * s, Vector2(0.10, 0.065) * s, Color("dcc2a0"))
	_oval(head + Vector2(0.115, 0.035) * s, Vector2(0.095, 0.06) * s, white)
	_oval(head + Vector2(0.19, 0.015) * s, Vector2(0.035, 0.032) * s, INK)
	draw_circle(head + Vector2(0.03, -0.025) * s, 0.025 * s, INK)
	draw_circle(head + Vector2(0.037, -0.032) * s, 0.008 * s, Color.WHITE)
	draw_line(head + Vector2(0.005, -0.073) * s, head + Vector2(0.053, -0.065) * s,
		Color("c1a17c"), 0.018 * s, true)
	_oval(head + Vector2(0.12, 0.095) * s, Vector2(0.025, 0.04) * s, Color("d89892"))
	draw_line(collar + Vector2(-0.025, -0.09) * s, collar + Vector2(0.01, 0.10) * s,
		Color("b95c51"), 0.036 * s, true)
	draw_circle(collar, 0.02 * s, Color("dac695"))


func _oval(centre: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * index / 24
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
