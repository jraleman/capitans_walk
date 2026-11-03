extends Control

## The physics spike draws the actual particles and support axis, not an invented gait.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240.0, 260.0)


## Both entry scenes supply the same model; the view never advances it.
func present(body: Body, frame: InputFrame, walk: Walk = null) -> void:
	_body = body
	_frame = frame
	_walk = walk
	queue_redraw()


## Keycaps reflect Settings rather than becoming a second set of hardcoded controls.
func configure_keys(labels: PackedStringArray, whistle_key := "Space") -> void:
	_keys = labels.duplicate()
	_whistle_key = whistle_key
	queue_redraw()


func _draw() -> void:
	if _body == null or size.x < 100.0 or size.y < 100.0:
		return
	var font := get_theme_default_font()
	var ground_y := size.y * 0.77
	var hip_x := _body.positions[Body.HIP].x
	var left_x := hip_x - 1.4
	var right_x := hip_x + 2.8
	if _walk != null:
		left_x = minf(left_x, _walk.dog.position.x - 0.7)
		right_x = maxf(right_x, _walk.dog.position.x + 0.7)
	var scale_factor := minf(size.y * 0.27, (size.x - MARGIN * 2.0) / (right_x - left_x))
	var base_y := _body.ground_height(hip_x)
	var origin := Vector2(MARGIN + (hip_x - left_x) * scale_factor, ground_y)
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	draw_rect(Rect2(Vector2(0.0, ground_y), Vector2(size.x, size.y - ground_y)), GRASS)
	var ground_points := PackedVector2Array()
	for index in 81:
		var screen_x := size.x * float(index) / 80.0
		var world_x := hip_x + (screen_x - origin.x) / scale_factor
		ground_points.append(Vector2(screen_x,
			ground_y - (_body.ground_height(world_x) - base_y) * scale_factor))
	draw_polyline(ground_points, INK, 5.0, true)
	for metre in range(floori(hip_x - origin.x / scale_factor),
		ceili(hip_x + (size.x - origin.x) / scale_factor) + 1):
		var x := origin.x + (float(metre) - hip_x) * scale_factor
		var y := ground_y - (_body.ground_height(float(metre)) - base_y) * scale_factor
		draw_line(Vector2(x, y), Vector2(x, y + 16.0), INK, 2.0)
		draw_string(font, Vector2(x + 5.0, y + 34.0), "%d m" % metre,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, INK)

	var points := PackedVector2Array()
	for point in _body.positions:
		points.append(origin + Vector2((point.x - hip_x) * scale_factor,
			-(point.y - base_y) * scale_factor))
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
	draw_string(font, Vector2(MARGIN, 30.0),
		"PHYSICS SPIKE / SAM" if _walk == null else "GREY BOX / SAM + CAPITAN",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, INK)
	draw_string(font, Vector2(MARGIN, 57.0),
		"Lean %+.0f deg  /  %d supporting legs" % [
			rad_to_deg(_body.torso_angle()), _body.stance_count(),
		], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, INK)
	if _walk != null:
		var status := "%s / %.0f N" % [_walk.dog.caption(), _walk.leash.tension]
		draw_multiline_string(font, Vector2(MARGIN, 83.0), status,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - MARGIN * 2.0, 16, 2, INK)
	_draw_balance(font)
	_draw_keys(font)
	if _body.is_over():
		draw_string(font, Vector2(MARGIN, size.y - (114.0 if _walk != null else 84.0)),
			"OFF THE PATH" if _body.end_cause == "off_path" else "A MAGNIFICENT TUMBLE",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, INK)


func _draw_balance(font: Font) -> void:
	var width := minf(300.0, size.x * 0.38)
	var centre := Vector2(size.x - MARGIN - width * 0.5, 40.0 if size.x >= 900.0 else 132.0)
	var limit := _body.half_width + Body.EDGE_ALLOWANCE
	draw_rect(Rect2(centre - Vector2(width * 0.5, 12.0), Vector2(width, 24.0)), CREAM)
	draw_line(centre - Vector2(width * 0.5, 0.0), centre + Vector2(width * 0.5, 0.0), INK, 2.0)
	for edge in [-1.0, 1.0]:
		var x: float = centre.x + edge * width * 0.5 * _body.half_width / limit
		draw_line(Vector2(x, centre.y - 12.0), Vector2(x, centre.y + 12.0), INK, 3.0)
	draw_line(centre - Vector2(0.0, 9.0), centre + Vector2(0.0, 9.0), INK, 1.0)
	var bubble_x := centre.x + clampf(_body.z / limit, -1.0, 1.0) * width * 0.5
	draw_circle(Vector2(bubble_x, centre.y), 7.0, LEFT)
	draw_string(font, Vector2(centre.x - width * 0.5, centre.y + 37.0),
		"Z %+.2f m / edge +/- %.2f" % [_body.z, limit],
		HORIZONTAL_ALIGNMENT_LEFT, width, 18, INK)


func _draw_keys(font: Font) -> void:
	if _walk != null:
		draw_string(font, Vector2(MARGIN, size.y - 80.0),
			"%s whistle / %s" % [_whistle_key,
				"READY" if _walk.dog.cooldown_ticks == 0
				else "%.1f S COOLDOWN" % (_walk.dog.cooldown_ticks * Body.STEP)],
			HORIZONTAL_ALIGNMENT_LEFT, size.x - MARGIN * 2.0, 18, INK)
	var width := minf(110.0, (size.x - MARGIN * 2.0 - 30.0) / 4.0)
	var strengths: Array[float] = [_frame.q, _frame.w, _frame.o, _frame.p]
	for index in 4:
		var rect := Rect2(Vector2(MARGIN + float(index) * (width + 10.0), size.y - 60.0),
			Vector2(width, 40.0))
		draw_rect(rect, INK if strengths[index] > 0.0 else CREAM)
		draw_rect(rect, INK, false, 2.0)
		draw_string(font, rect.position + Vector2(10.0, 27.0),
			"%s%s" % [_keys[index], " +" if strengths[index] > 0.0 else ""],
			HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 22,
			CREAM if strengths[index] > 0.0 else INK)


func _draw_dog_and_leash(
	font: Font, hand: Vector2, origin: Vector2, scale_factor: float, hip_x: float, base_y: float
) -> void:
	var dog := _walk.dog
	var ground := origin + Vector2((dog.position.x - hip_x) * scale_factor,
		-(_body.ground_height(dog.position.x) - base_y) * scale_factor
		+ dog.position.y * scale_factor * 0.2)
	var collar := ground - Vector2(0.0, Dog.COLLAR_HEIGHT * scale_factor)
	var sag := maxf(0.0, _walk.leash.length - _walk.leash.separation) * scale_factor * 0.5
	var rope := PackedVector2Array()
	for index in 25:
		var along := float(index) / 24.0
		rope.append(hand.lerp(collar, along) + Vector2(0.0, sag * 4.0 * along * (1.0 - along)))
	draw_polyline(rope, INK, 3.0, true)
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
		draw_string(font, bubble + Vector2(-5.0, 7.0), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, INK)
