extends SceneTree

## Genuine input, falls, pause and instant restart through the inherited shell.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := get_root().get_node("Settings")
	var session := get_root().get_node("GameSession")
	var values := (settings.get("_values") as Dictionary).duplicate(true)
	var save_timer := settings.get("_save_timer") as Timer
	var save_mode := save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	save_timer.stop()
	var test_values: Dictionary = settings.get("_values")
	test_values[Options.STEADY_KEY] = 0.0
	test_values[Options.WALK_SPEED_KEY] = 100
	GameCatalog.select(Options.GAME_ID)
	session.call("configure_single_player")
	var packed := load("res://games/capitans_walk/gameplay.tscn") as PackedScene
	if packed == null:
		printerr("Capitan's Walk gameplay did not load.")
		quit(1)
		return
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var body: Body = game.get("_body")
	var walk: Walk = game.get("_walk")
	var view := game.get("_view") as Control
	_expect(bool(game.get("_round_active")) and view != null,
		"Gameplay must start with its model bound to the debug view.")
	_expect(walk.body == body and view.get("_walk") == walk,
		"The real gameplay and renderer must share one coupled dog/leash controller.")
	_expect((game.get_node("%RoundTimer") as Timer).is_stopped(),
		"The shell timer must not end a self-paced walk.")

	Input.action_press(Options.Q, 0.5)
	Input.action_press(Options.O, 0.75)
	game.call("_update_round", Body.STEP, 0.0)
	var frame: InputFrame = game.get("_frame")
	_expect(frame.q == 0.5 and frame.o == 0.75,
		"The real input source must preserve independent analogue strengths.")
	Input.action_release(Options.Q)
	Input.action_release(Options.O)

	var old_key := int(settings.call("binding_keycode", Options.LEG_BINDINGS[0]))
	_expect(bool(settings.call("set_binding_key", Options.LEG_BINDINGS[0], KEY_Z, Options.GAME_ID)),
		"The first thigh must be rebindable through Settings.")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_Z
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	frame = game.get("_frame")
	_expect(frame.q == 1.0 and (game.get_node("%Hint") as Label).text.contains("Z"),
		"Rebound physical keys and the visible hint must agree.")
	press = InputEventKey.new()
	press.physical_keycode = KEY_Z
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	settings.call("set_binding_key", Options.LEG_BINDINGS[0], old_key, Options.GAME_ID)

	var old_whistle := int(settings.call("binding_keycode", Options.WHISTLE_BINDING))
	_expect(bool(settings.call("set_binding_key", Options.WHISTLE_BINDING, KEY_X, Options.GAME_ID)),
		"Whistle must be rebindable through the same controls screen.")
	press = InputEventKey.new()
	press.physical_keycode = KEY_X
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	_expect(walk.dog.whistles == 1 and (game.get("_frame") as InputFrame).whistle
		and view.get("_whistle_key") == "X",
		"The rebound key must trigger recall: whistles=%d, frame=%s, label=%s."
		% [walk.dog.whistles, (game.get("_frame") as InputFrame).whistle,
			view.get("_whistle_key")])
	press = InputEventKey.new()
	press.physical_keycode = KEY_X
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	settings.call("set_binding_key", Options.WHISTLE_BINDING, old_whistle, Options.GAME_ID)

	var live_values: Dictionary = settings.get("_values")
	live_values[Options.STEADY_KEY] = 0.65
	live_values[Options.WALK_SPEED_KEY] = 70
	settings.emit_signal("changed", Options.STEADY_KEY, 0.65)
	settings.emit_signal("changed", Options.WALK_SPEED_KEY, 70)
	_expect(is_equal_approx(body.steady, 0.65)
		and is_equal_approx(float(game.get("_walk_speed")), 0.7),
		"Steady and Walk speed must apply to the running simulation.")
	var ticks := body.ticks
	game.call("_update_round", 1.0, 0.0)
	_expect(body.ticks - ticks == 84,
		"70% speed must simulate 84 fixed ticks per real second.")

	game.call("open_pause_menu")
	await process_frame
	ticks = body.ticks
	var paused_walk := walk.snapshot()
	await process_frame
	await process_frame
	_expect(paused and body.ticks == ticks and walk.snapshot() == paused_walk,
		"Pausing must freeze the dog, cooldown and rope as well as the walker.")
	var pause_menu := game.get("_pause_menu") as Node
	pause_menu.call("resume")
	await process_frame
	_expect(not paused, "The normal pause menu must resume the walk.")

	for tick in Dog.FIRST_SQUIRREL_MAX + 1:
		if walk.dog.state == Dog.SQUIRREL_WARNING:
			break
		game.call("_update_round", Body.STEP / 0.7, 0.0)
	_expect(walk.dog.state == Dog.SQUIRREL_WARNING
		and (game.get("_callout") as Label).text.contains("SQUIRREL"),
		"A real warning must reach the caption: state=%s, text=%s, response=%d, whistles=%d, end=%s."
		% [walk.dog.state, (game.get("_callout") as Label).text,
			walk.dog.response_ticks, walk.dog.whistles, body.end_cause])
	Input.action_press(Options.WHISTLE)
	for tick in Dog.WHISTLE_RESPONSE_TICKS + 1:
		game.call("_update_round", Body.STEP / 0.7, 0.0)
	Input.action_release(Options.WHISTLE)
	_expect(walk.dog.state == Dog.TROT and walk.dog.recalls == 2
		and walk.dog.cooldown_ticks > 0,
		"Real action input must cancel the warned distraction after the delayed recall.")

	body.z = 0.50
	game.call("_update_round", Body.STEP / 0.7, 0.0)
	_expect(body.end_cause == "off_path" and not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible,
		"A genuine off-path ending must reach shell results.")
	_expect(int(game.get("_scores")[0]) == roundi(body.distance * 100.0)
		and (game.get_node("%RoundSubtitle") as Label).text.contains("Off the path"),
		"Results must use furthest distance in centimetres and the real cause.")
	var started := Time.get_ticks_usec()
	var restart := InputEventAction.new()
	restart.action = Options.RESTART
	restart.pressed = true
	game.call("_unhandled_input", restart)
	_expect(Time.get_ticks_usec() - started < 2000000 and game.get("_view") == view
		and game.get("_body") == body and body.distance == 0.0 and not body.is_over()
		and bool(game.get("_round_active")) and game.get("_walk") == walk
		and walk.dog.ticks == 0 and walk.dog.cooldown_ticks == 0 and walk.leash.tension == 0.0,
		"Restart from results must reset every coupled model in place in under two seconds.")
	game.set("_round_active", false)

	var original_size := get_root().size
	for resolution in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		get_root().size = resolution
		await process_frame
		await process_frame
		var bounds: Rect2 = game.call("_playfield_bounds")
		_expect(view.get_rect() == bounds and view.size.x > 0.0 and view.size.y > 0.0,
			"The debug view must track shell bounds from portrait to ultrawide.")
	get_root().size = original_size
	await process_frame
	await process_frame
	await _capture_if_requested()

	game.free()
	var spike_packed := load("res://games/capitans_walk/tools/physics_spike.tscn") as PackedScene
	_expect(spike_packed != null, "The menu-free physics playtest scene must load.")
	if spike_packed != null:
		var spike := spike_packed.instantiate()
		get_root().add_child(spike)
		await process_frame
		_expect(spike.get("_view") != null and spike.get("_body") is Body,
			"The development spike must use the same model and debug view.")
		spike.free()
	settings.set("_values", values)
	save_timer.process_mode = save_mode
	for action in Options.LEG_ACTIONS:
		Input.action_release(action)
	Input.action_release(Options.WHISTLE)
	await create_timer(0.15, true, false, true).timeout
	if _failures.is_empty():
		print("Capitan's Walk scene tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _capture_if_requested() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capitan-capture="):
			continue
		if DisplayServer.get_name() == "headless":
			_expect(false, "A rendered capture requires a real graphics window.")
			return
		await RenderingServer.frame_post_draw
		var path := argument.trim_prefix("--capitan-capture=")
		var error := get_root().get_texture().get_image().save_png(path)
		_expect(error == OK, "The rendered physics capture must save successfully.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
