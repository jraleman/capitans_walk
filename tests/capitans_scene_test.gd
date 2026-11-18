extends SceneTree

## Real first-person controls, complete walks, shared results and responsive rendered layouts.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const PathWalk = preload("res://games/capitans_walk/walk/path_walk.gd")
const Frame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Controls = preload("res://games/capitans_walk/input/walk_controls.gd")
const View = preload("res://games/capitans_walk/world/walk_view.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := get_root().get_node("Settings")
	var saved: Dictionary = settings.get("_values").duplicate(true)
	var save_timer := settings.get("_save_timer") as Timer
	var save_mode := save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	save_timer.stop()
	var values: Dictionary = settings.get("_values")
	values[Options.WALK_SPEED_KEY] = 100
	values[Options.LONG_WARNINGS_KEY] = false
	values[Options.TOUCH_LAYOUT_KEY] = 0
	GameCatalog.select(Options.GAME_ID)
	get_root().get_node("GameSession").call("configure_single_player")
	var packed := load("res://games/capitans_walk/gameplay.tscn") as PackedScene
	if packed == null:
		printerr("Capitan's first-person gameplay did not load.")
		quit(1)
		return
	var game := packed.instantiate()
	get_root().add_child(game)
	game.set_process(false)
	await process_frame
	await process_frame
	var walk: Walk = game.get("_walk")
	var view: View = game.get("_view")
	var controls: Controls = game.get("_controls")
	_expect(walk.path != null and view._walk == walk and controls.path_mode,
		"The live first-person scene must share one guided model with its view and adapters.")
	_expect(view.world_viewport.own_world_3d and view.world_camera.projection
		== Camera3D.PROJECTION_PERSPECTIVE and (game.get_node("%RoundTimer") as Timer).is_stopped(),
		"The game needs an isolated real perspective world, not a 2D view or shell timer.")
	_expect((game.get_node("%TimeLabel") as Label).text == "100 PTS"
		and (game.get_node("%TimeLabel") as Label).is_visible_in_tree()
		and (game.get_node("%Callout") as Label).is_visible_in_tree(),
		"A fresh walk must display its actual 100 starting points.")
	await _test_keys_and_settings(game, settings)
	await _test_pause(game)
	await _test_touch(game)
	await _test_layouts(game, settings)
	await _test_runs(game)
	game.free()
	var spike_scene := load("res://games/capitans_walk/tools/physics_spike.tscn") as PackedScene
	var spike := spike_scene.instantiate()
	get_root().add_child(spike)
	await process_frame
	_expect(spike.get("_body") is Body and (spike.get("_walk") as Walk).path == null,
		"The diagnostic spike must retain its original ragdoll and classic walking rules.")
	spike.free()
	settings.set("_values", saved)
	save_timer.stop()
	save_timer.process_mode = save_mode
	await create_timer(0.4, true, false, true).timeout
	if _failures.is_empty():
		print("Capitan's Walk first-person scene tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_keys_and_settings(game: Node, settings: Node) -> void:
	var walk: Walk = game.get("_walk")
	var view: View = game.get("_view")
	var old_key := int(settings.call("binding_keycode", Options.STEER_BINDINGS[0]))
	_expect(bool(settings.call("set_binding_key", Options.STEER_BINDINGS[0], KEY_Z, Options.GAME_ID)),
		"Leash steering must be rebindable through ordinary Settings.")
	_key(KEY_Z, true)
	game.call("_update_round", Body.STEP, 0.0)
	_expect((game.get("_frame") as Frame).steer_left == 1.0 and view._keys[0] == "Z"
		and (game.get_node("%Hint") as Label).text.contains("Z /"),
		"Physical rebound keys, model steering and visible hints must agree.")
	Input.action_press(Options.STEER_RIGHT)
	game.call("_update_round", Body.STEP, 0.0)
	_expect((game.get("_frame") as Frame).steering() == 0.0,
		"Opposing physical and action inputs must cancel.")
	_key(KEY_Z, false)
	Input.action_release(Options.STEER_RIGHT)
	settings.call("set_binding_key", Options.STEER_BINDINGS[0], old_key, Options.GAME_ID)
	var old_whistle := int(settings.call("binding_keycode", Options.WHISTLE_BINDING))
	settings.call("set_binding_key", Options.WHISTLE_BINDING, KEY_X, Options.GAME_ID)
	_key(KEY_X, true)
	for tick in 38:
		game.call("_update_round", Body.STEP, 0.0)
	_expect(walk.dog.whistles == 1 and walk.dog.recalls == 1 and view._whistle_key == "X",
		"Rebound Whistle must reach the real edge-triggered delayed recall.")
	_key(KEY_X, false)
	settings.call("set_binding_key", Options.WHISTLE_BINDING, old_whistle, Options.GAME_ID)
	var values: Dictionary = settings.get("_values")
	values[Options.WALK_SPEED_KEY] = 70
	settings.emit_signal("changed", Options.WALK_SPEED_KEY, 70)
	var ticks := walk.path.ticks
	game.call("_update_round", 1.0, 0.0)
	_expect(walk.path.ticks - ticks == 84 and walk.dog.ticks == walk.path.ticks,
		"Slower pace must slow the complete coupled clock, including scoring and cooldowns.")
	while walk.path.phase != PathWalk.Phase.WARNING and walk.path.ticks < 2400:
		game.call("_update_round", Body.STEP / 0.7, 0.0)
	var remaining := walk.path.phase_ticks
	values[Options.LONG_WARNINGS_KEY] = true
	settings.emit_signal("changed", Options.LONG_WARNINGS_KEY, true)
	_expect(walk.path.phase_ticks == remaining * 2 and walk.path.long_warnings,
		"Enabling Long warnings must double the currently visible warning.")
	values[Options.WALK_SPEED_KEY] = 100
	values[Options.LONG_WARNINGS_KEY] = false
	settings.emit_signal("changed", Options.WALK_SPEED_KEY, 100)
	settings.emit_signal("changed", Options.LONG_WARNINGS_KEY, false)
	_expect(bool(game.get("_assisted")) and not bool(game.call("_using_assists")),
		"The assist badge must remember assists used earlier in the walk.")
	game.call("_start_round")
	_pad_axis(0.575)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(is_equal_approx((game.get("_frame") as Frame).steer_right, 0.5),
		"The left stick must retain feathered steering beyond its release deadzone.")
	var round_id := int(game.get("_round_id"))
	_pad_button(JOY_BUTTON_Y, true, 14)
	_expect(int(game.get("_round_id")) == round_id,
		"A second controller must not restart the active controller's walk.")
	_pad_button(JOY_BUTTON_Y, false, 14)
	_pad_axis(0.0)


func _test_pause(game: Node) -> void:
	var walk: Walk = game.get("_walk")
	var controls: Controls = game.get("_controls")
	Input.action_press(Options.STEER_LEFT)
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	var frozen := walk.snapshot()
	var round_id := int(game.get("_round_id"))
	game.set_process(true)
	_pad_button(JOY_BUTTON_Y, true)
	_pad_button(JOY_BUTTON_Y, false)
	await process_frame
	await process_frame
	_expect(paused and walk.snapshot() == frozen and int(game.get("_round_id")) == round_id,
		"Pause must freeze automatic pacing, points, dog and rope; Restart cannot bypass it.")
	var pause_menu := game.get("_pause_menu") as Node
	pause_menu.call("_on_settings_pressed")
	await process_frame
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	await process_frame
	_expect(paused and pause_menu.get("_settings_overlay") == null,
		"Start must leave nested Settings before resuming the game.")
	game.set_process(false)
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	_expect(not paused and controls.sample().steering() == 0.0,
		"Resume must not resurrect held steering.")
	Input.action_press(Options.STEER_RIGHT)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(controls.sample().steering() == 0.0, "Focus loss must release held steering.")


func _test_touch(game: Node) -> void:
	var controls: Controls = game.get("_controls")
	var reveal := InputEventScreenTouch.new()
	reveal.index = 99
	reveal.position = Vector2.ZERO
	reveal.pressed = true
	get_root().push_input(reveal, true)
	await process_frame
	await process_frame
	_expect(controls.touch_pads.visible, "The first hybrid-screen touch must reveal the pads.")
	_touch(game, 0, Options.STEER_LEFT, true)
	_touch(game, 1, Options.STEER_LEFT, true)
	_touch(game, 2, Options.STEER_RIGHT, true)
	_touch(game, 0, Options.STEER_LEFT, false)
	_expect(controls.sample().steering() == 0.0 and not Input.is_action_pressed(Options.STEER_LEFT),
		"Independent fingers must cancel without sharing or releasing keyboard actions.")
	_touch(game, 1, Options.STEER_LEFT, false)
	_expect(controls.sample().steering() == 1.0,
		"Releasing the final left finger must leave the right finger held.")
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2.ZERO
	get_root().push_input(drag, true)
	_expect(controls.sample().steering() == 0.0, "Dragging away must release only that finger.")
	_touch(game, 3, Options.WHISTLE, true)
	game.call("_update_round", Body.STEP, 0.0)
	_expect((game.get("_walk") as Walk).dog.whistles == 1
		and controls.touch_pads.buttons[Options.WHISTLE].text.ends_with(" S"),
		"Touch Whistle must show the real model cooldown.")
	_touch(game, 4, &"pause", true)
	await process_frame
	_expect(paused, "Touch Pause must open the shared overlay.")
	(game.get("_pause_menu") as Node).call("resume")
	await process_frame
	_expect(not controls.sample().whistle and controls.sample().steering() == 0.0,
		"Pause must discard all fingers, even when their release events never arrive.")
	_touch(game, 5, Options.RESTART, true)
	_touch(game, 5, Options.RESTART, false)
	_expect((game.get("_walk") as Walk).path.points == 100.0,
		"Touch Restart must restore the real starting points.")


func _test_layouts(game: Node, settings: Node) -> void:
	var walk: Walk = game.get("_walk")
	var view: View = game.get("_view")
	var controls: Controls = game.get("_controls")
	var original := get_root().size
	var frozen := walk.snapshot()
	for resolution in [Vector2i(360, 800), Vector2i(720, 1280),
			Vector2i(1280, 720), Vector2i(2560, 1080)]:
		get_root().size = resolution
		await process_frame
		await process_frame
		for layout in [0, 1, 2]:
			var values: Dictionary = settings.get("_values")
			values[Options.TOUCH_LAYOUT_KEY] = layout
			settings.emit_signal("changed", Options.TOUCH_LAYOUT_KEY, layout)
			var pad_rect := controls.touch_pads.get_global_rect()
			_expect(view.get_global_rect().end.y <= pad_rect.position.y + 0.1
				and view.size.y > 150.0,
				"Touch controls must reserve space outside the first-person view at every aspect.")
			var occupied: Array[Rect2] = []
			for button in controls.touch_pads.buttons.values():
				if not button.visible:
					continue
				_expect(pad_rect.encloses(button.get_global_rect()) and button.size.y >= 64.0
					and not button.accessibility_name.is_empty(),
					"Every pad must fit and retain a readable, non-colour action label.")
				for other in occupied:
					_expect(not other.intersects(button.get_global_rect()),
						"Touch hit targets cannot overlap.")
				occupied.append(button.get_global_rect())
			_expect(not controls.touch_pads.buttons[Options.Q].visible
				and controls.touch_pads.buttons[Options.STEER_LEFT].visible,
				"The first-person touch layout must not advertise obsolete leg controls.")
		(game.get_node("%HudHelpButton") as Button).pressed.emit()
		_expect(controls.touch_pads.visible and view._status.is_visible_in_tree()
			and (game.get_node("%TimeLabel") as Label).is_visible_in_tree()
			and (game.get_node("%Callout") as Label).is_visible_in_tree(),
			"Help may collapse key legends, never the active pads, points or warning.")
		view.present(walk, game.get("_frame"))
		var collar := Vector3(walk.dog.position.y, 0.48, -walk.dog.position.x)
		var projected := view.world_camera.unproject_position(collar)
		_expect(not view.world_camera.is_position_behind(collar)
			and Rect2(Vector2.ZERO, Vector2(view.world_viewport.size)).has_point(projected),
			"Capitan must remain visible from a real eye-height perspective camera.")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var calls := view.world_viewport.get_render_info(
				Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			_expect(calls > 0 and calls < 60,
				"The Compatibility park must actually render in fewer than 60 draw calls.")
		await _capture("touch-%dx%d" % [resolution.x, resolution.y])
	_expect(walk.snapshot() == frozen,
		"Rendering, resizing and changing touch layout must never advance model state.")
	get_root().size = original
	var values: Dictionary = settings.get("_values")
	values[Options.TOUCH_LAYOUT_KEY] = 0
	settings.emit_signal("changed", Options.TOUCH_LAYOUT_KEY, 0)
	controls.touch_pads.hide()
	game.call("_resize_view")
	await process_frame
	await process_frame
	await _capture("first-person")


func _test_runs(game: Node) -> void:
	var walk: Walk = game.get("_walk")
	game.call("_start_round")
	var checked_drain := false
	for frame in 6000:
		if walk.is_over():
			break
		game.call("_update_round", Body.STEP * 4.0, 0.0)
		if walk.path.is_draining() and not checked_drain:
			checked_drain = true
			await _test_off_path_view(game)
		if frame % 240 == 0:
			await process_frame
	_expect(walk.path.end_cause == "points_depleted" and not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible
		and (game.get_node("%RoundSubtitle") as Label).text.contains("Out of points"),
		"A genuinely unsteered walk must drain points and reach the shared loss results.")
	await _capture("loss-results")
	var reference := {}
	for source in ["keyboard", "gamepad", "touch"]:
		var started := Time.get_ticks_usec()
		_key(KEY_R, true)
		_key(KEY_R, false)
		_expect(Time.get_ticks_usec() - started < 2000000 and game.get("_walk") == walk
			and walk.path.points == 100.0 and walk.path.distance == 0.0,
			"Restart from results must reset in place in under two seconds.")
		var controls: Controls = game.get("_controls")
		if source == "touch":
			controls.touch_pads.show()
			game.call("_resize_view")
			await process_frame
			await process_frame
		var previous := 0
		for frame in 6000:
			if walk.is_over():
				break
			var demand := -walk.dog.position.y * 2.8 - walk.dog.velocity.y * 0.8
			var direction := int(signf(demand)) if absf(demand) > 0.10 else 0
			if direction != previous:
				_steer(game, source, direction)
				previous = direction
			game.call("_update_round", Body.STEP * 4.0, 0.0)
			if frame % 240 == 0:
				await process_frame
		_steer(game, source, 0)
		_expect(walk.path.end_cause == "finished" and walk.path.distance == 200.0
			and walk.path.points > 0.0 and (game.get_node("%RoundSubtitle") as Label).text
				.contains("Walk complete"),
			"Real %s steering must complete the finite route and show shared win results." % source)
		var totals: Dictionary = game.call("_round_totals")
		var stats: Dictionary = game.call("_player_stats", 0)
		_expect(totals["distance_cm"] == 20000 and stats["completed"]
			and (game.get_node("%RoundPlayerOneScore") as Label).text == str(walk.final_score()),
			"Results must retain points separately from completed distance and real deductions.")
		var shared: Dictionary = game.call("_share_payload")
		_expect((game.get_node("%GameDurationStat") as Label).text == "%.1f SEC" % (
			walk.path.ticks * Body.STEP) and shared["hits_caption"] == "ON-PATH METRES"
			and shared["combo"] == str(walk.path.excursions),
			"Results and shared scorecards must describe the path walk, not obsolete foot plants.")
		if source == "keyboard":
			reference = walk.snapshot()
		else:
			_expect(walk.snapshot() == reference,
				"Keyboard, gamepad and touch must yield identical full model and score state.")
		print("%s first-person walk: %.1f m / %d points / %d ticks." % [
			source, walk.path.distance, walk.final_score(), walk.path.ticks,
		])
	await _capture("win-results")
	game.call("_on_see_score_pressed")
	await process_frame
	await process_frame
	await _capture("win-stats")


func _test_off_path_view(game: Node) -> void:
	var walk: Walk = game.get("_walk")
	var view: View = game.get("_view")
	var original := get_root().size
	_expect(view._status.text.contains("-10 POINTS")
		and (game.get_node("%Callout") as Label).text.contains("STEER"),
		"A real off-path excursion must show both the running penalty and its counter.")
	for resolution in [Vector2i(360, 800), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		get_root().size = resolution
		await process_frame
		await process_frame
		var collar := Vector3(walk.dog.position.y,
			walk.body.ground_height(walk.dog.position.x) + 0.48, -walk.dog.position.x)
		var projected := view.world_camera.unproject_position(collar)
		_expect(not view.world_camera.is_position_behind(collar)
			and Rect2(Vector2.ZERO, Vector2(view.world_viewport.size)).grow(-12).has_point(projected),
			"The genuinely straying dog must remain in shot, including on a narrow phone.")
		for side: float in [-0.35, 0.35]:
			_expect(Rect2(Vector2.ZERO, Vector2(view.world_viewport.size)).has_point(
				view.world_camera.unproject_position(collar + Vector3(side, 0, 0))),
				"Off-path framing must leave room for Capitan's body, not just his collar.")
		await _capture("off-path-%dx%d" % [resolution.x, resolution.y])
	get_root().size = original
	await process_frame
	await process_frame


func _steer(game: Node, source: String, direction: int) -> void:
	if source == "keyboard":
		_key(KEY_A, direction < 0)
		_key(KEY_D, direction > 0)
	elif source == "gamepad":
		_pad_axis(float(direction))
	else:
		_touch(game, 10, Options.STEER_LEFT, direction < 0)
		_touch(game, 11, Options.STEER_RIGHT, direction > 0)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _pad_button(button: int, pressed: bool, device := 13) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _pad_axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 13
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(game: Node, index: int, action: StringName, pressed: bool) -> void:
	var controls: Controls = game.get("_controls")
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = controls.touch_pads.buttons[action].get_global_rect().get_center()
	event.pressed = pressed
	get_root().push_input(event, true)
	Input.flush_buffered_events()


func _capture(suffix: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capitan-capture="):
			continue
		if DisplayServer.get_name() == "headless":
			_expect(false, "Rendered coverage requires a real graphics window.")
			return
		await create_timer(0.9, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var path := "%s-%s.png" % [argument.trim_prefix("--capitan-capture=").get_basename(), suffix]
		_expect(get_root().get_texture().get_image().save_png(path) == OK,
			"The rendered first-person capture must be saved.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
