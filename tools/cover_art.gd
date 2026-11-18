extends RefCounted

## The current 2D Park renderer and solver, not the unimplemented final 3D art.
const View = preload("res://games/capitans_walk/ui/walker_debug_view.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Frame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")


## A jaunty walking poster labels this as the actual Park prototype.
static func design() -> Dictionary:
	return {
		"paper": Color("f3e9cd"), "ink": Color("2d5549"), "accent": Color("dc9b52"),
		"motif": "park", "photo": Rect2(0, 345, 1024, 555),
		"lettering": [
			{"text": "CAPITAN'S", "at": Vector2(50, 167), "size": 145, "font": "round"},
			{"text": "WALK", "at": Vector2(55, 342), "size": 208, "angle": -3},
			{"text": "WHO'S WALKING WHO?", "at": Vector2(61, 945), "size": 44, "font": "round"},
			{"text": "PARK PROTOTYPE", "at": Vector2(63, 994), "size": 26, "font": "mono"},
		],
	}


## A fixed, unsaved model supplies the same silhouettes and leash as play.
static func build(parent: Node) -> Node:
	var view := View.new()
	view.game_presentation = true
	view.show_keycaps = false
	parent.add_child(view)
	var walk := Walk.new(null, 7, null, Route.new(7))
	var frame := Frame.new()
	for tick in 36:
		frame.q = 0.5
		frame.p = 0.5
		walk.step(frame)
	view.present(walk.body, frame, walk)
	(view.get("_hud") as Control).hide()
	return view
