extends Control

## Game-owned model readouts sit inside the inherited shell, including the isolated spike.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const INK := Color("23252b")
const LEFT := Color("245b94")
const CREAM := Color("fdf5e6")
const GRASS := Color("6fae4f")
const MARGIN := 24.0

var _body: Body
var _walk: Walk
var _layout_size := Vector2.ZERO
var compact := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Reading the same fixed state keeps captions and countdowns in sync with actual pulls.
func present(body: Body, walk: Walk = null) -> void:
	_body = body
	_walk = walk
	queue_redraw()


## The diagnostic camera leaves room for readable phone-sized information, not just labels.
func header_height() -> float:
	if _walk != null and _compact_layout():
		return 125.0 * _layout_scale()
	return (205.0 if _walk != null else 110.0) * _layout_scale()


func _draw() -> void:
	if _body == null or size.x < 100.0 or size.y < 100.0:
		return
	var font := get_theme_default_font()
	var scale_factor := _layout_scale()
	_layout_size = size / scale_factor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	var title := "PHYSICS SPIKE / SAM" if _walk == null else "GREY BOX / SAM + CAPITAN"
	if _walk != null and _walk.route != null:
		title = "PARK / SEED %d / TIER %d" % [
			_walk.route.seed_value, _walk.route.tier_at(_body.positions[Body.HIP].x),
		]
	draw_string(font, Vector2(MARGIN, 30.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, _layout_size.x - MARGIN * 2.0, 20, INK)
	draw_string(font, Vector2(MARGIN, 57.0),
		"Lean %+.0f deg / %d supporting legs" % [
			rad_to_deg(_body.torso_angle()), _body.stance_count(),
		], HORIZONTAL_ALIGNMENT_LEFT, _layout_size.x - MARGIN * 2.0, 18, INK)
	if _walk != null:
		var cue := _walk.cue_caption()
		var status := "%s / %.0f N" % [
			_walk.dog.caption() if cue.is_empty() else cue, _walk.leash.tension,
		]
		if _walk.dog.is_warning():
			status += " / %.1f S WARNING" % _walk.dog.warning_seconds()
		var middle := _layout_size.x * 0.32
		var condensed := _compact_layout()
		draw_multiline_string(font, Vector2(middle if condensed else MARGIN,
			30.0 if condensed else 83.0), status,
			HORIZONTAL_ALIGNMENT_LEFT,
			_layout_size.x * 0.38 if condensed else _layout_size.x - MARGIN * 2.0,
			16, 2, INK)
		_draw_happiness(font, Vector2(middle - MARGIN, -47.0) if condensed else Vector2.ZERO)
		var combo := "COMBO %d / %s / x%.1f / %.0f BANKED" % [
			_walk.rhythm.combo, _walk.rhythm.tier(),
			_walk.rhythm.multiplier(), _walk.rhythm.points,
		]
		draw_multiline_string(font, Vector2(MARGIN, 86.0 if condensed else 181.0),
			combo, HORIZONTAL_ALIGNMENT_LEFT,
			middle - MARGIN * 2.0 if condensed else _layout_size.x - MARGIN * 2.0, 16, 2, INK)
	_draw_balance(font)


func _draw_happiness(font: Font, offset := Vector2.ZERO) -> void:
	var width := minf(160.0, _layout_size.x * 0.30)
	var start := Vector2(MARGIN + 8.0, 126.0) + offset
	draw_rect(Rect2(start, Vector2(width, 16.0)), CREAM)
	draw_rect(Rect2(start, Vector2(width * _walk.dog.happiness / 100.0, 16.0)), GRASS)
	draw_rect(Rect2(start, Vector2(width, 16.0)), INK, false, 2.0)
	for end in [start.x, start.x + width]:
		for y in [start.y + 3.0, start.y + 13.0]:
			draw_circle(Vector2(end, y), 7.0, CREAM)
			draw_circle(Vector2(end, y), 7.0, INK, false, 2.0)
	var tail := Vector2(start.x + width + 18.0, start.y + 13.0)
	draw_polyline(PackedVector2Array([
		tail, tail + Vector2(8.0, -13.0), tail + Vector2(16.0, -8.0),
	]), INK, 3.0, true)
	draw_string(font, Vector2(MARGIN, 158.0) + offset,
		"HAPPY %.0f/100 / %d WAGS" % [_walk.dog.happiness, _walk.dog.verdict_wags()],
		HORIZONTAL_ALIGNMENT_LEFT, _layout_size.x * 0.55, 14, INK)


func _draw_balance(font: Font) -> void:
	var width := minf(300.0, _layout_size.x * 0.38)
	var centre := Vector2(_layout_size.x - MARGIN - width * 0.5,
		40.0 if _layout_size.x >= 900.0 else 132.0)
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


func _layout_scale() -> float:
	return 2.0 if Responsive.is_portrait(get_viewport_rect().size) else 1.2


func _compact_layout() -> bool:
	return compact and not Responsive.is_portrait(get_viewport_rect().size) \
		and size.x / _layout_scale() >= 900.0
