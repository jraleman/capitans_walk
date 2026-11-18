extends Node3D

## Original toy Capitan: white wiry coat, floppy black ears, tan points and a curled tail.

const Meshes = preload("res://games/capitans_walk/world/mesh_builder.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const PathWalk = preload("res://games/capitans_walk/walk/path_walk.gd")
const COAT := Color("faf6ef")
const INK := Color("23252b")
const TAN := Color("a8683a")
const RED := Color("e2553d")

var _material: Material
var _head := Node3D.new()
var _tail := Node3D.new()
var _legs: Array[Node3D] = []
var _ears: Array[Node3D] = []


func _init(surface: Material = null) -> void:
	_material = surface if surface != null else Meshes.material()
	var body := Meshes.new()
	body.ellipsoid(Vector3(0, 0.39, 0.04), Vector3(0.38, 0.37, 0.66), COAT)
	body.ellipsoid(Vector3(0, 0.43, -0.22), Vector3(0.39, 0.4, 0.28), COAT)
	for side: float in [-1.0, 1.0]:
		for tuft in 5:
			body.ellipsoid(Vector3(side * 0.17, 0.29, -0.16 + tuft * 0.095),
				Vector3(0.105, 0.14, 0.12), COAT, 6)
	body.cylinder(Vector3(0, 0.48, -0.27), 0.17, 0.065, RED, 12, 1.0,
		Vector3(PI / 2.0, 0, 0))
	_attach(self, body, "CoatAndCollar")
	_head.position = Vector3(0, 0.53, -0.33)
	_head.name = "Head"
	add_child(_head)
	var face := Meshes.new()
	face.ellipsoid(Vector3.ZERO, Vector3(0.38, 0.34, 0.32), INK)
	face.ellipsoid(Vector3(0, 0.035, -0.035), Vector3(0.13, 0.34, 0.32), COAT)
	for side: float in [-1.0, 1.0]:
		face.ellipsoid(Vector3(side * 0.12, -0.06, -0.11), Vector3(0.14, 0.13, 0.12), TAN)
		face.ellipsoid(Vector3(side * 0.075, -0.075, -0.17),
			Vector3(0.19, 0.15, 0.18), COAT)
		face.ellipsoid(Vector3(side * 0.11, 0.035, -0.137),
			Vector3(0.10, 0.115, 0.065), COAT)
		face.ellipsoid(Vector3(side * 0.11, 0.031, -0.167),
			Vector3(0.075, 0.09, 0.035), INK)
		face.ellipsoid(Vector3(side * 0.101, 0.05, -0.186),
			Vector3(0.022, 0.026, 0.012), Color.WHITE, 8)
		face.ellipsoid(Vector3(side * 0.112, 0.106, -0.125),
			Vector3(0.105, 0.042, 0.045), TAN)
		for tuft in 3:
			face.ellipsoid(Vector3(side * (0.13 + tuft * 0.02), -0.10, -0.10),
				Vector3(0.08, 0.09, 0.10), COAT, 6)
	face.ellipsoid(Vector3(0, -0.04, -0.263), Vector3(0.105, 0.075, 0.065), INK)
	face.ellipsoid(Vector3(0, -0.15, -0.18), Vector3(0.12, 0.07, 0.11), INK)
	face.ellipsoid(Vector3(0, -0.18, -0.22), Vector3(0.075, 0.10, 0.045), Color("e88f9c"))
	_attach(_head, face, "BlazeEyesAndBeard")
	for side: float in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(side * 0.16, 0.06, 0.01)
		_head.add_child(ear)
		_ears.append(ear)
		var shape := Meshes.new()
		shape.ellipsoid(Vector3(side * 0.035, -0.105, 0.0),
			Vector3(0.13, 0.28, 0.15), INK)
		_attach(ear, shape, "FloppyEar")
	for index in 4:
		var leg := Node3D.new()
		leg.position = Vector3(-0.13 if index % 2 == 0 else 0.13, 0.28,
			-0.20 if index < 2 else 0.25)
		add_child(leg)
		_legs.append(leg)
		var shape := Meshes.new()
		shape.ellipsoid(Vector3(0, -0.08, 0), Vector3(0.115, 0.25, 0.13), COAT)
		shape.ellipsoid(Vector3(0, -0.22, -0.035), Vector3(0.145, 0.10, 0.19), COAT)
		_attach(leg, shape, "LegAndPaw")
	_tail.position = Vector3(0, 0.48, 0.28)
	add_child(_tail)
	var plume := Meshes.new()
	for index in 7:
		var angle := float(index) / 6.0 * PI * 1.3 - PI * 0.5
		plume.ellipsoid(Vector3(0, 0.17 + sin(angle) * 0.13, cos(angle) * 0.13),
			Vector3(0.12, 0.14, 0.12), COAT, 8)
	_attach(_tail, plume, "CurledPlume")


## The rig cannot advance physics; even its decorative phase comes from model ticks.
func present(walk: Walk, reduced_motion: bool) -> void:
	var dog := walk.dog
	rotation.y = -atan2(dog.velocity.y, maxf(0.5, dog.velocity.x)) * 0.55
	position = Vector3(dog.position.y, walk.body.ground_height(dog.position.x), -dog.position.x) \
		- basis * Vector3(0, 0, -0.27)
	var phase := walk.path.ticks * Body.STEP * 11.0
	var moving := minf(1.0, dog.velocity.length() / 1.4)
	for index in _legs.size():
		_legs[index].rotation.x = 0.0 if reduced_motion else sin(
			phase + (PI if index in [0, 3] else 0.0)) * 0.45 * moving
	_tail.rotation.z = 0.0 if reduced_motion else sin(phase * 0.55) * 0.25
	var watching := walk.path.phase != PathWalk.Phase.QUIET
	_head.rotation.y = -walk.path.interest_side * 0.45 if watching else 0.0
	if dog.response_ticks > 0:
		_head.rotation.y = PI * 0.8
	for index in _ears.size():
		_ears[index].rotation.z = (0.4 if index == 0 else -0.4) if watching else 0.0


func _attach(parent: Node3D, builder: Meshes, title: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = title
	instance.mesh = builder.finish()
	instance.material_override = _material
	parent.add_child(instance)
