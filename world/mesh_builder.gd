extends RefCounted

## Game-owned, vertex-coloured geometry, using the host games' batched mesh pattern.

var _surface := SurfaceTool.new()


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, c, b]:
		_vertex(point, normal, color)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	triangle(a, b, c, color)
	triangle(a, c, d, color)


func box(at: Vector3, dimensions: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	var primitive := BoxMesh.new()
	primitive.size = dimensions
	_append(primitive, Transform3D(Basis.from_euler(rotation), at), color)


func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var primitive := BoxMesh.new()
	primitive.size = Vector3(width, a.distance_to(b), width)
	_append(primitive, Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())),
		(a + b) * 0.5), color)


func cylinder(
	at: Vector3, radius: float, height: float, color: Color,
	segments := 10, top_ratio := 1.0, rotation := Vector3.ZERO
) -> void:
	var primitive := CylinderMesh.new()
	primitive.bottom_radius = radius
	primitive.top_radius = radius * top_ratio
	primitive.height = height
	primitive.radial_segments = segments
	primitive.rings = 1
	_append(primitive, Transform3D(Basis.from_euler(rotation), at), color)


func ellipsoid(at: Vector3, dimensions: Vector3, color: Color, segments := 10) -> void:
	var primitive := SphereMesh.new()
	primitive.radius = 0.5
	primitive.height = 1.0
	primitive.radial_segments = segments
	primitive.rings = maxi(4, segments / 2)
	_append(primitive, Transform3D(Basis.from_scale(dimensions), at), color)


func finish() -> ArrayMesh:
	_surface.index()
	return _surface.commit()


static func material() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.92
	result.metallic_specular = 0.18
	return result


func _append(primitive: Mesh, transform: Transform3D, color: Color) -> void:
	var arrays := primitive.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for index in indices:
		_vertex(transform * vertices[index], (normal_basis * normals[index]).normalized(), color)


func _vertex(point: Vector3, normal: Vector3, color: Color) -> void:
	_surface.set_color(color)
	_surface.set_normal(normal)
	_surface.add_vertex(point)
