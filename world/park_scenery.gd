extends Node3D

## A finite, original toy park; route queries are read-only and consume no model RNG.

const Meshes = preload("res://games/capitans_walk/world/mesh_builder.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")
const PathWalk = preload("res://games/capitans_walk/walk/path_walk.gd")
const CREAM := Color("f5e8c9")
const WOOD := Color("9b603f")
const DARK := Color("294c4b")
const PATH := Color("cbbd99")
const GRASS := Color("83af64")

var seed_value := 0
var _route: Route
var _material: Material
var _ground := PackedVector2Array()


func _init(route: Route, surface: Material) -> void:
	_route = route
	_material = surface
	seed_value = route.seed_value
	var terrain := Meshes.new()
	var plants := Meshes.new()
	var furniture := Meshes.new()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value ^ 73337
	for cell in range(-1, 13):
		var chunk := route.chunk_at(cell)
		var ground: PackedVector2Array = chunk["ground"]
		for point in ground:
			if _ground.is_empty() or point.x > _ground[-1].x:
				_ground.append(point)
		for index in ground.size() - 1:
			var a := ground[index]
			var b := ground[index + 1]
			_strip(terrain, a, b, -35.0, 35.0, 0.0, GRASS)
			_strip(terrain, a, b, -PathWalk.HALF_WIDTH, PathWalk.HALF_WIDTH, 0.012, PATH)
			for side: float in [-1.0, 1.0]:
				var edge := side * PathWalk.HALF_WIDTH
				_strip(terrain, a, b, minf(edge, edge - side * 0.07),
					maxf(edge, edge - side * 0.07), 0.016, CREAM)
		for slot: Dictionary in chunk["surfaces"]:
			var start := float(slot["from"])
			var end := float(slot["to"])
			_strip(terrain, Vector2(start, _height(start)), Vector2(end, _height(end)),
				-0.78, 0.78, 0.025, Color("7ba8b5"))
		for tree in 8:
			var x := cell * 20.0 + random.randf_range(0.0, 20.0)
			var side := -1.0 if tree % 2 == 0 else 1.0
			var z := side * random.randf_range(3.2, 12.0)
			_tree(plants, Vector3(z, _height(x), -x), random.randf_range(0.8, 1.4), tree % 3)
		for flower in 10:
			var x := cell * 20.0 + random.randf_range(0.0, 20.0)
			var z := (-1.0 if flower % 2 == 0 else 1.0) * random.randf_range(1.25, 3.0)
			var at := Vector3(z, _height(x), -x)
			plants.ellipsoid(at + Vector3(0, 0.15, 0), Vector3(0.34, 0.30, 0.4),
				Color("4f8357"), 8)
			plants.ellipsoid(at + Vector3(0, 0.30, 0), Vector3(0.15, 0.11, 0.15),
				Color("efbb60") if flower % 2 == 0 else Color("de8f92"), 6)
	for x in range(-10, 251, 5):
		for side: float in [-1.0, 1.0]:
			var at := Vector3(side * 8.0, _height(x), -float(x))
			furniture.box(at + Vector3(0, 0.45, 0), Vector3(0.12, 0.9, 0.12), CREAM)
			furniture.beam(at + Vector3(0, 0.67, 0),
				Vector3(side * 8.0, _height(x + 5.0) + 0.67, -float(x + 5)), 0.075, CREAM)
	for x in range(12, 201, 28):
		var side := -1.0 if x % 3 == 0 else 1.0
		_bench(furniture, Vector3(side * 3.3, _height(x), -float(x)))
		var at := Vector3(-side * 2.5, _height(x + 7.0), -float(x + 7))
		furniture.cylinder(at + Vector3(0, 1.2, 0), 0.045, 2.4, DARK)
		furniture.box(at + Vector3(0, 2.4, 0), Vector3(0.27, 0.33, 0.27), CREAM)
		furniture.cylinder(at + Vector3(0, 2.63, 0), 0.23, 0.17, DARK, 4, 0.05)
	for x in [25, 50, 100, 150]:
		_sign(furniture, Vector3(-1.6, _height(x), -float(x)), "%d m" % x, 0.8, 0.42)
	_sign(furniture, Vector3(-1.7, _height(3.0), -3.0), "PARK WALK\n200 m", 1.05, 0.9)
	var finish_y := _height(PathWalk.FINISH_DISTANCE)
	for side: float in [-1.0, 1.0]:
		furniture.box(Vector3(side * 1.4, finish_y + 1.4, -PathWalk.FINISH_DISTANCE),
			Vector3(0.16, 2.8, 0.16), DARK)
	furniture.box(Vector3(0, finish_y + 2.7, -PathWalk.FINISH_DISTANCE),
		Vector3(3.05, 0.58, 0.16), CREAM)
	_label("FINISH", Vector3(0, finish_y + 2.7, -PathWalk.FINISH_DISTANCE + 0.09), 0.006)
	for row in 2:
		for column in 8:
			furniture.box(Vector3(-0.7875 + column * 0.225, finish_y + 0.021,
				-PathWalk.FINISH_DISTANCE + row * 0.225),
				Vector3(0.225, 0.012, 0.225), CREAM if (row + column) % 2 == 0 else DARK)
	_attach(terrain, "GroundPathAndPuddles")
	_attach(plants, "TreesAndFlowers")
	_attach(furniture, "ParkFurnitureAndFinish")


func _tree(builder: Meshes, at: Vector3, scale_value: float, variant: int) -> void:
	builder.cylinder(at + Vector3(0, 1.0, 0) * scale_value,
		0.15 * scale_value, 2.0 * scale_value, WOOD, 8, 0.6)
	var colors: Array[Color] = [Color("4c895d"), Color("69974d"), Color("95ad5b")]
	builder.ellipsoid(at + Vector3(0, 2.65, 0) * scale_value,
		Vector3(2.1, 2.4, 2.0) * scale_value, colors[variant], 10)
	builder.ellipsoid(at + Vector3(-0.5, 2.1, 0.15) * scale_value,
		Vector3(1.6, 1.4, 1.6) * scale_value, colors[variant].lightened(0.08), 8)


func _bench(builder: Meshes, at: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		builder.box(at + Vector3(side * 0.48, 0.23, 0), Vector3(0.09, 0.46, 0.43), DARK)
	for slat in 3:
		builder.box(at + Vector3(0, 0.48, -0.17 + slat * 0.15),
			Vector3(1.35, 0.07, 0.13), WOOD.lightened(0.12))
	for row in 2:
		builder.box(at + Vector3(0, 0.72 + row * 0.16, 0.23),
			Vector3(1.35, 0.13, 0.07), WOOD.lightened(0.12))


func _sign(builder: Meshes, at: Vector3, text: String, width: float, height: float) -> void:
	builder.box(at + Vector3(0, 0.65, 0), Vector3(0.09, 1.3, 0.09), WOOD)
	builder.box(at + Vector3(0, 1.2, 0), Vector3(width, height, 0.10), CREAM)
	_label(text, at + Vector3(0, 1.2, 0.06), 0.0035)


func _label(text: String, at: Vector3, pixel_scale: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = pixel_scale
	label.modulate = DARK
	label.outline_size = 0
	label.position = at
	add_child(label)


func _strip(
	builder: Meshes, a: Vector2, b: Vector2, left: float, right: float,
	lift: float, color: Color
) -> void:
	builder.quad(Vector3(left, a.y + lift, -a.x), Vector3(right, a.y + lift, -a.x),
		Vector3(right, b.y + lift, -b.x), Vector3(left, b.y + lift, -b.x), color)


func _height(x: float) -> float:
	for index in _ground.size() - 1:
		if x <= _ground[index + 1].x:
			var a := _ground[index]
			var b := _ground[index + 1]
			return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))
	return _ground[-1].y if not _ground.is_empty() else 0.0


func _attach(builder: Meshes, title: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = builder.finish()
	mesh.material_override = _material
	add_child(mesh)
