extends Control

## A read-only eye-height 3D park inside GameShell's isolated Compatibility viewport.

const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Frame = preload("res://games/capitans_walk/walk/input_frame.gd")
const PathWalk = preload("res://games/capitans_walk/walk/path_walk.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const Meshes = preload("res://games/capitans_walk/world/mesh_builder.gd")
const Park = preload("res://games/capitans_walk/world/park_scenery.gd")
const DogRig = preload("res://games/capitans_walk/world/dog_rig.gd")
const INK := Color("213e3b")
const CREAM := Color("fff3d8")

var world_viewport: SubViewport
var world_camera: Camera3D
var dog_rig: DogRig
var control_tray := HFlowContainer.new()
var reduced_motion := false
var unit := 1.0
var _walk: Walk
var _frame := Frame.new()
var _world := Node3D.new()
var _park: Park
var _material := Meshes.material()
var _rope := MeshInstance3D.new()
var _hand := MeshInstance3D.new()
var _sleeve := MeshInstance3D.new()
var _interest := Node3D.new()
var _interest_shapes: Array[MeshInstance3D] = []
var _interest_label := Label3D.new()
var _overlay := Control.new()
var _status := Label.new()
var _whistle := Label.new()
var _keys := PackedStringArray(["A", "D"])
var _whistle_key := "Space"
var _legends: Array[Label] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	world_viewport = SubViewport.new()
	world_viewport.name = "ParkViewport"
	world_viewport.own_world_3d = true
	world_viewport.gui_disable_input = true
	world_viewport.msaa_3d = Viewport.MSAA_2X
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_viewport)
	world_viewport.add_child(_world)
	world_camera = Camera3D.new()
	world_camera.name = "FirstPersonEyes"
	world_camera.near = 0.05
	world_camera.far = 110.0
	world_camera.current = true
	world_camera.rotation_degrees.x = -14.0
	_world.add_child(world_camera)
	_build_light()
	dog_rig = DogRig.new(_material)
	dog_rig.name = "Capitan"
	_world.add_child(dog_rig)
	_rope.name = "ActualLeash"
	_rope.material_override = _material
	_world.add_child(_rope)
	var hand := Meshes.new()
	hand.ellipsoid(Vector3.ZERO, Vector3(0.105, 0.12, 0.12), Color("c38a65"))
	_hand.mesh = hand.finish()
	_hand.material_override = _material
	_world.add_child(_hand)
	var sleeve := Meshes.new()
	sleeve.box(Vector3.ZERO, Vector3(0.11, 1.0, 0.11), Color("345865"))
	_sleeve.mesh = sleeve.finish()
	_sleeve.material_override = _material
	_world.add_child(_sleeve)
	_build_interest()
	var image := TextureRect.new()
	image.name = "ParkImage"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = world_viewport.get_texture()
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	for label in [_status, _whistle]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", CREAM)
		_overlay.add_child(label)
	_whistle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	control_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_tray.hide()
	add_child(control_tray)
	for index in 3:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", CREAM)
		control_tray.add_child(label)
		_legends.append(label)
	control_tray.visibility_changed.connect(_resize_world)
	control_tray.minimum_size_changed.connect(_resize_world, CONNECT_DEFERRED)
	resized.connect(_resize_world)
	_resize_world()


func present(walk: Walk, frame: Frame) -> void:
	_walk = walk
	_frame = frame
	if world_viewport == null:
		return
	if _park == null or _park.seed_value != walk.route.seed_value:
		if _park != null:
			_park.free()
		_park = Park.new(walk.route, _material)
		_world.add_child(_park)
	var path := walk.path
	var height := walk.body.ground_height(path.position.x)
	world_camera.position = Vector3(path.position.y - 0.18,
		height + 1.55, -path.position.x + 0.12)
	dog_rig.present(walk, reduced_motion)
	var hand := Vector3(walk.hand_position().y, height + 1.18, -walk.hand_position().x)
	var collar := Vector3(walk.dog.position.y,
		walk.body.ground_height(walk.dog.position.x) + 0.48, -walk.dog.position.x)
	_hand.position = hand
	var elbow := Vector3(path.position.y + 0.25, height + 0.55, -path.position.x + 0.22)
	_sleeve.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, (hand - elbow).normalized())).scaled(
			Vector3(1, hand.distance_to(elbow), 1)), (hand + elbow) * 0.5)
	_draw_rope(hand, collar, walk.leash.tension)
	_interest.visible = path.phase != PathWalk.Phase.QUIET
	if _interest.visible:
		_interest.position = Vector3(path.interest_position.y,
			walk.body.ground_height(path.interest_position.x), -path.interest_position.x)
		for index in _interest_shapes.size():
			_interest_shapes[index].visible = index == path.interest_kind
		_interest_label.text = "! " + PathWalk.INTEREST_NAMES[path.interest_kind]
		_interest_label.modulate = Color("ffe6a1") if path.phase == PathWalk.Phase.WARNING else CREAM
	_status.text = path.status_caption()
	_whistle.text = "WHISTLE READY" if walk.dog.cooldown_ticks == 0 else "WHISTLE %.1f S" % (
		walk.dog.cooldown_ticks * Body.STEP)
	_overlay.queue_redraw()


func configure_keys(labels: PackedStringArray, whistle_key: String) -> void:
	_keys = labels.duplicate()
	_whistle_key = whistle_key
	_resize_world()


func _resize_world() -> void:
	if world_viewport == null or size.x < 1.0 or size.y < 1.0:
		return
	var scale_factor := minf(1.0, minf(1440.0 / size.x, 1080.0 / size.y))
	world_viewport.size = Vector2i(maxi(1, roundi(size.x * scale_factor)),
		maxi(1, roundi(size.y * scale_factor)))
	var narrow := size.x / size.y < 1.6
	world_camera.keep_aspect = Camera3D.KEEP_WIDTH if narrow else Camera3D.KEEP_HEIGHT
	world_camera.fov = 106.0 if narrow else 70.0
	var font_size := roundi(15.0 * unit)
	for label in [_status, _whistle]:
		if label.get_theme_font_size("font_size") != font_size:
			label.add_theme_font_size_override("font_size", font_size)
	_status.position = Vector2(12, 8) * unit
	_status.size = Vector2(maxf(1.0, size.x - 24 * unit), 24 * unit)
	_whistle.position = Vector2(12 * unit, 32 * unit)
	_whistle.size = Vector2(maxf(1.0, size.x - 24 * unit), 24 * unit)
	control_tray.add_theme_constant_override("h_separation", roundi(18 * unit))
	for index in _legends.size():
		if _legends[index].get_theme_font_size("font_size") != roundi(14 * unit):
			_legends[index].add_theme_font_size_override("font_size", roundi(14 * unit))
		_legends[index].text = ["%s LEFT" % _keys[0], "%s RIGHT" % _keys[1],
			"%s WHISTLE" % _whistle_key][index]
	control_tray.size.x = maxf(1.0, size.x - 24 * unit)
	control_tray.position = Vector2(12 * unit,
		size.y - control_tray.get_combined_minimum_size().y - 12 * unit)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if _walk == null:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.17, 0.16, 0.88)
	_overlay.draw_style_box(panel, Rect2(0, 0, size.x, 66 * unit))
	var width := minf(280 * unit, size.x * 0.52)
	var gauge := Rect2(12 * unit, 40 * unit, width, 8 * unit)
	_overlay.draw_rect(gauge, Color("708a79"))
	var half := width * PathWalk.HALF_WIDTH / 5.6
	var middle := gauge.position.x + width * 0.5
	_overlay.draw_rect(Rect2(middle - half, gauge.position.y, half * 2.0, gauge.size.y), CREAM)
	var x := middle + clampf(_walk.dog.position.y / 2.8, -1.0, 1.0) * width * 0.5
	_overlay.draw_circle(Vector2(x, gauge.get_center().y), 7 * unit, Color("e2553d"))
	_overlay.draw_arc(Vector2(x, gauge.get_center().y), 7 * unit, 0, TAU, 20, CREAM, 2 * unit)
	if control_tray.visible:
		_overlay.draw_style_box(panel, Rect2(0, control_tray.position.y - 6 * unit,
			size.x, size.y - control_tray.position.y + 6 * unit))


func _draw_rope(hand: Vector3, collar: Vector3, tension: float) -> void:
	var builder := Meshes.new()
	var previous := hand
	var sag := lerpf(0.20, 0.025, clampf(tension / 70.0, 0.0, 1.0))
	for segment in range(1, 17):
		var along := float(segment) / 16.0
		var point := hand.lerp(collar, along) - Vector3.UP * sin(along * PI) * sag
		builder.beam(previous, point, 0.022, Color("e2553d"))
		previous = point
	_rope.mesh = builder.finish()


func _build_light() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("77b8cd")
	sky_material.sky_horizon_color = Color("dbe6dd")
	sky_material.ground_horizon_color = Color("dbe6dd")
	sky_material.ground_bottom_color = Color("75906c")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8cbd0")
	settings.ambient_light_energy = 0.5
	settings.tonemap_exposure = 0.72
	settings.fog_enabled = true
	settings.fog_light_color = Color("b8d0c4")
	settings.fog_density = 0.005
	settings.fog_sky_affect = 0.1
	environment.environment = settings
	_world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff1d1")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	_world.add_child(sun)


func _build_interest() -> void:
	_world.add_child(_interest)
	for kind in 3:
		var builder := Meshes.new()
		if kind == 0:
			builder.ellipsoid(Vector3(0, 0.18, 0), Vector3(0.20, 0.28, 0.32), Color("ad663d"))
			builder.ellipsoid(Vector3(0, 0.35, -0.12), Vector3(0.20, 0.20, 0.22), Color("bd7d4c"))
			builder.ellipsoid(Vector3(0, 0.37, 0.20), Vector3(0.19, 0.48, 0.24), Color("9b5b39"))
			for side: float in [-1.0, 1.0]:
				builder.cylinder(Vector3(side * 0.07, 0.48, -0.12), 0.045, 0.13,
					Color("ad663d"), 6, 0.0)
		elif kind == 1:
			for bird in 3:
				var at := Vector3((bird - 1) * 0.28, 0.28 + bird * 0.08, (bird % 2) * 0.25)
				builder.ellipsoid(at, Vector3(0.19, 0.18, 0.28), Color("879f9f"))
				builder.ellipsoid(at + Vector3(0, 0.12, -0.10),
					Vector3(0.13, 0.13, 0.14), Color("456773"))
				builder.box(at, Vector3(0.48, 0.035, 0.14), Color("abc1bd"))
		else:
			builder.ellipsoid(Vector3(0, 0.34, 0), Vector3(0.30, 0.30, 0.50), Color("b98552"))
			builder.ellipsoid(Vector3(0, 0.49, -0.25), Vector3(0.29, 0.29, 0.27), Color("ba8b60"))
			for side: float in [-1.0, 1.0]:
				builder.ellipsoid(Vector3(side * 0.16, 0.45, -0.22),
					Vector3(0.11, 0.25, 0.15), Color("704b35"))
				for end: float in [-1.0, 1.0]:
					builder.box(Vector3(side * 0.10, 0.13, end * 0.16),
						Vector3(0.08, 0.24, 0.10), Color("d5ac7a"))
		var mesh := MeshInstance3D.new()
		mesh.mesh = builder.finish()
		mesh.material_override = _material
		_interest.add_child(mesh)
		_interest_shapes.append(mesh)
	_interest_label.position.y = 1.0
	_interest_label.font_size = 48
	_interest_label.pixel_size = 0.005
	_interest_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interest_label.outline_modulate = INK
	_interest_label.outline_size = 10
	_interest.add_child(_interest_label)
	_interest.hide()
