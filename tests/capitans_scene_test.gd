extends SceneTree

## Genuine input, falls, pause and instant restart through the inherited shell.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Dog = preload("res://games/capitans_walk/walk/dog_brain.gd")
const WalkControls = preload("res://games/capitans_walk/input/walk_controls.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")
const RouteTests = preload("res://games/capitans_walk/tests/route_generator_test.gd")
const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const HazardTests = preload("res://games/capitans_walk/tests/hazards_test.gd")
const Hazards = preload("res://games/capitans_walk/walk/hazards.gd")

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
	test_values[Options.EASY_LEGS_KEY] = false
	test_values[Options.LONG_WARNINGS_KEY] = false
	test_values[Options.TOUCH_LAYOUT_KEY] = 0
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
	var controls: WalkControls = game.get("_controls")
	if body == null or walk == null or view == null or controls == null:
		game.free()
		settings.set("_values", values)
		save_timer.process_mode = save_mode
		printerr("Capitan's Walk scene failed to construct its model, view or controls.")
		quit(1)
		return
	var hud := view.get("_hud") as Control
	_expect(bool(game.get("_round_active")) and view != null,
		"Gameplay must start with its model bound to the debug view.")
	_expect(walk.body == body and view.get("_walk") == walk,
		"The real gameplay and renderer must share one coupled dog/leash controller.")
	_expect(hud != null and hud.get("_walk") == walk and hud.get("_body") == body,
		"The happiness/combo/telegraph HUD must read the same model inside the shell.")
	_expect((game.get_node("%RoundTimer") as Timer).is_stopped(),
		"The shell timer must not end a self-paced walk.")
	_expect(walk.route != null and walk.route.seed_value == int(game.get("_walk_seed"))
		and body.ground_profile() == walk.route.ground(),
		"The live Park must supply actual contact geometry and the same restart seed.")
	await _test_park_terrain(game)
	await _test_moving_hazards(game)

	Input.action_press(Options.Q, 0.5)
	Input.action_press(Options.O, 0.75)
	game.call("_update_round", Body.STEP, 0.0)
	var frame: InputFrame = game.get("_frame")
	_expect(frame.q == 0.5 and frame.o == 0.75,
		"The real input source must preserve independent analogue strengths.")
	_expect((game.get_node("%PlayerOneStreak") as Label).visible
		and (game.get_node("%PlayerOneStreak") as Label).text.contains("POINTS"),
		"Live points and combo must remain visible alongside the headline distance.")
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
	live_values[Options.EASY_LEGS_KEY] = true
	live_values[Options.LONG_WARNINGS_KEY] = true
	settings.emit_signal("changed", Options.EASY_LEGS_KEY, true)
	settings.emit_signal("changed", Options.LONG_WARNINGS_KEY, true)
	_expect(walk.easy_legs and walk.dog.long_warnings and bool(view.get("_easy_enabled")),
		"Easy legs and Long warnings must apply live through ordinary Settings.")
	var old_easy_key := int(settings.call("binding_keycode", Options.EASY_BINDINGS[0]))
	_expect(bool(settings.call("set_binding_key", Options.EASY_BINDINGS[0], KEY_B, Options.GAME_ID)),
		"Easy leg controls must be rebindable through the existing controls screen.")
	press = InputEventKey.new()
	press.physical_keycode = KEY_B
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	game.call("_update_round", Body.STEP / 0.7, 0.0)
	frame = game.get("_frame")
	_expect(frame.easy_left == 1.0 and walk.last_frame.q > 0.0
		and view.get("_easy_keys")[0] == "B"
		and (game.get_node("%Hint") as Label).text.contains("B left leg"),
		"A rebound physical Easy key must drive the macro and its visible keycaps/hint.")
	press = InputEventKey.new()
	press.physical_keycode = KEY_B
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	settings.call("set_binding_key", Options.EASY_BINDINGS[0], old_easy_key, Options.GAME_ID)
	live_values[Options.EASY_LEGS_KEY] = false
	live_values[Options.LONG_WARNINGS_KEY] = false
	settings.emit_signal("changed", Options.EASY_LEGS_KEY, false)
	settings.emit_signal("changed", Options.LONG_WARNINGS_KEY, false)

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
	live_values[Options.STEADY_KEY] = 0.0
	live_values[Options.WALK_SPEED_KEY] = 100
	settings.emit_signal("changed", Options.STEADY_KEY, 0.0)
	settings.emit_signal("changed", Options.WALK_SPEED_KEY, 100)
	_expect(not bool(game.call("_using_assists")),
		"The badge check must really disable every assist before ending the walk.")

	body.z = 0.50
	game.call("_update_round", Body.STEP / 0.7, 0.0)
	_expect(body.end_cause == "off_path" and not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible,
		"A genuine off-path ending must reach shell results.")
	var subtitle := (game.get_node("%RoundSubtitle") as Label).text
	var stats: Dictionary = game.call("_player_stats", 0)
	var totals: Dictionary = game.call("_round_totals")
	_expect(int(game.get("_scores")[0]) == walk.final_score()
		and (game.get_node("%ResultLabel") as Label).text == "%.1f METRES" % body.distance
		and subtitle.contains("Off the path") and subtitle.contains("%d/5 tail wags" % (
			walk.dog.verdict_wags()))
		and totals["distance_cm"] == roundi(body.distance * 100.0)
		and stats["happiness"] == walk.dog.happiness and stats["assisted"],
		"Results must keep distance separate from points, with the real cause, verdict and assist badge.")
	_expect((game.get_node("%RoundPlayerOneScore") as Label).text == str(walk.final_score())
		and game.get_node("%PlayerOneStatsScore").get_parent()
			.get_node_or_null("ExtraStats") != null,
		"The shared results/stat panels must display the points and game-owned detail rows.")
	await create_timer(0.4, true, false, true).timeout
	await _capture_if_requested("results")
	game.call("_on_see_score_pressed")
	await create_timer(0.4, true, false, true).timeout
	await _capture_if_requested("stats")
	var result_size := get_root().size
	get_root().size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	await _capture_if_requested("stats-portrait")
	get_root().size = result_size
	await process_frame
	await process_frame
	game.call("_show_round_results")
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
		var expected := Rect2(bounds.position,
			Vector2(bounds.size.x, bounds.size.y - controls.touch_height()))
		_expect(view.get_rect() == expected and view.size.x > 0.0 and view.size.y > 0.0,
			"The debug view must track shell bounds from portrait to ultrawide.")
		_expect(hud.size == view.size,
			"The game-owned HUD must remain anchored to the actual playfield at every aspect ratio.")
		await _capture_if_requested("%dx%d" % [resolution.x, resolution.y])
	get_root().size = original_size
	await process_frame
	await process_frame
	await _capture_if_requested()

	await _test_gamepad_and_touch(game, settings)
	await _test_park_walk(game)
	await _test_park_encounter_walk(game)
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
	Input.action_release(Options.EASY_LEFT)
	Input.action_release(Options.EASY_RIGHT)
	await create_timer(0.15, true, false, true).timeout
	if _failures.is_empty():
		print("Capitan's Walk scene tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _capture_if_requested(suffix := "") -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capitan-capture="):
			continue
		if DisplayServer.get_name() == "headless":
			_expect(false, "A rendered capture requires a real graphics window.")
			return
		await RenderingServer.frame_post_draw
		var path := argument.trim_prefix("--capitan-capture=")
		if not suffix.is_empty():
			path = "%s-%s.png" % [path.get_basename(), suffix]
		var error := get_root().get_texture().get_image().save_png(path)
		_expect(error == OK, "The rendered physics capture must save successfully.")


func _test_park_terrain(game: Node) -> void:
	var walk: Walk = game.get("_walk")
	var view := game.get("_view") as Control
	var controls: WalkControls = game.get("_controls")
	var original_size := get_root().size
	game.set_process(false)
	await create_timer(2.5, true, false, true).timeout
	for kind in [Chunks.PUDDLE, Chunks.SLOPE]:
		game.call("_reset_round_state")
		var hazard := RouteTests._find_hazard(walk.route, kind)
		_expect(not hazard.is_empty(), "The live Park needs each implemented surface hazard.")
		if hazard.is_empty():
			continue
		var x := (float(hazard["from"]) + float(hazard["to"])) * 0.5 \
			if kind == Chunks.PUDDLE else float(hazard["from"]) + 1.0
		RouteTests._place_walk(walk, x)
		game.call("_update_round", Body.STEP, 0.0)
		_expect((game.get("_callout") as Label).text.contains(str(kind).to_upper()),
			"Actual terrain contacts and grades must reach the shared gameplay caption.")
		_expect(kind != Chunks.PUDDLE or walk.hazards.splashes > 0,
			"The scene must generate splash feedback from real wet foot contacts.")
		var snapshot := walk.snapshot()
		for resolution in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(2560, 1080)]:
			get_root().size = resolution
			await process_frame
			await process_frame
			view.call("present", walk.body, InputFrame.new(), walk)
			await _capture_if_requested("park-%s-fixture-%dx%d" % [
				kind, resolution.x, resolution.y,
			])
		_expect(walk.snapshot() == snapshot,
			"Rendering, resizing and reading terrain must not advance route RNG or physics.")
	get_root().size = original_size
	await process_frame
	controls.clear_input()
	game.call("_start_round")
	game.set_process(true)


func _test_moving_hazards(game: Node) -> void:
	var walk: Walk = game.get("_walk")
	var controls: WalkControls = game.get("_controls")
	var original_size := get_root().size
	game.set_process(false)
	await create_timer(2.5, true, false, true).timeout
	for kind in Chunks.MOVING_KINDS:
		game.call("_reset_round_state")
		if not HazardTests.place(walk, kind, kind == Chunks.SPRINKLER):
			_expect(false, "Each moving Park hazard needs a real scene fixture.")
			continue
		game.call("_update_round", Body.STEP, 0.0)
		_expect(walk.hazards.is_warning()
			and (game.get("_callout") as Label).text == walk.cue_caption()
			and int((game.get("_audio") as RefCounted).get("_heard_hazards")) == 1,
			"A generated moving slot must reach the shared caption, HUD and original audio.")
		await _capture_moving_fixture(game, kind, "warning")
		if kind == Chunks.SPRINKLER:
			game.call("open_pause_menu")
			await process_frame
			var frozen := walk.snapshot()
			await process_frame
			await process_frame
			_expect(paused and walk.snapshot() == frozen,
				"Shared Pause must freeze moving warnings and their actor positions.")
			(game.get("_pause_menu") as Node).call("resume")
			await process_frame
		var extra := 300 if kind == Chunks.JOGGER else 60
		for tick in Hazards.WARNING_TICKS + extra:
			game.call("_update_round", Body.STEP, 0.0)
		_expect(walk.hazards.is_busy() and not walk.hazards.is_warning()
			and not walk.body.is_over(),
			"The scene must actually advance each warned physical encounter.")
		await _capture_moving_fixture(game, kind, "active")
		if kind == Chunks.PIGEON_FLOCK:
			Input.action_press(Options.WHISTLE)
			for tick in Dog.WHISTLE_RESPONSE_TICKS + 1:
				game.call("_update_round", Body.STEP, 0.0)
			Input.action_release(Options.WHISTLE)
			_expect(walk.dog.recalls == 1 and not walk.hazards.focus_enabled
				and int((game.get("_audio") as RefCounted).get("_heard_whistles")) == 1,
				"Real sampled Whistle input must cancel the flock, not only change a caption.")
		var stats: Dictionary = game.call("_player_stats", 0)
		_expect(int(stats["hazard_warnings"]) == walk.hazards.telegraphs
			and int(stats["greetings"]) == walk.hazards.greetings,
			"Shared stats must report actual Park warning and greeting counters.")
	get_root().size = original_size
	await process_frame
	controls.clear_input()
	game.call("_start_round")
	game.set_process(true)


func _capture_moving_fixture(game: Node, kind: StringName, phase: String) -> void:
	var walk: Walk = game.get("_walk")
	var view := game.get("_view") as Control
	var snapshot := walk.snapshot()
	for resolution in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		get_root().size = resolution
		await process_frame
		await process_frame
		view.call("present", walk.body, game.get("_frame"), walk)
		await _capture_if_requested("park-%s-%s-fixture-%dx%d" % [
			kind, phase, resolution.x, resolution.y,
		])
	_expect(walk.snapshot() == snapshot,
		"Drawing or resizing moving actors must never advance warnings, physics or RNG.")


func _test_gamepad_and_touch(game: Node, settings: Node) -> void:
	var body: Body = game.get("_body")
	var walk: Walk = game.get("_walk")
	var controls: WalkControls = game.get("_controls")
	var view := game.get("_view") as Control
	game.set_process(false)
	game.call("_on_play_again_pressed")
	var keyboard_walk := _drive_to_results(game, "keyboard")
	_expect(body.is_over() and body.distance > 0.1 and not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible,
		"A physical-key gait must genuinely walk and reach shared results.")
	_pad_button(JOY_BUTTON_Y, true)
	_pad_button(JOY_BUTTON_Y, false)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	_pad_axis(JOY_AXIS_TRIGGER_LEFT, 0.35)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.65)
	game.call("_update_round", Body.STEP, 0.0)
	var frame: InputFrame = game.get("_frame")
	_expect(frame.q == 1.0 and frame.o == 1.0
		and is_equal_approx(frame.w, 0.35) and is_equal_approx(frame.p, 0.65)
		and (game.get_node("%Hint") as Label).text.contains("LB / LT"),
		"Actual joystick events must feather all four live motors and show fixed pad controls.")
	_pad_button(JOY_BUTTON_A, true)
	for tick in Dog.WHISTLE_RESPONSE_TICKS + 1:
		game.call("_update_round", Body.STEP, 0.0)
	_expect(walk.dog.whistles == 1 and walk.dog.cooldown_ticks > 0,
		"Gamepad A must recall through the same held-input/cooldown path as keyboard Whistle.")
	_pad_button(JOY_BUTTON_A, false)

	game.set_process(true)
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	var snapshot := walk.snapshot()
	var round_id := int(game.get("_round_id"))
	_pad_button(JOY_BUTTON_Y, true)
	_pad_button(JOY_BUTTON_Y, false)
	await process_frame
	await process_frame
	_expect(paused and walk.snapshot() == snapshot and int(game.get("_round_id")) == round_id,
		"Start must open the real pause menu; held motors and Y must not advance or restart it.")
	var pause_menu := game.get("_pause_menu") as Node
	pause_menu.call("_on_settings_pressed")
	await process_frame
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	await process_frame
	_expect(paused and pause_menu.get("_settings_overlay") == null,
		"Start must close nested Settings through the shared pause/back path before resuming.")
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	_expect(not paused, "A fresh Start press must resume the shared pause overlay.")
	game.set_process(false)
	game.call("_update_round", Body.STEP, 0.0)
	frame = game.get("_frame")
	_expect(frame.q == 0.0 and frame.w == 0.0 and frame.o == 0.0 and frame.p == 0.0,
		"Resuming must not resurrect the motors held before pause.")
	_pad_button(JOY_BUTTON_BACK, true)
	_pad_button(JOY_BUTTON_BACK, false)
	_expect(body.ticks == 0 and bool(game.get("_round_active")),
		"Back must restart this game's walk, rather than opening the shell's generic pause action.")
	var gamepad_walk := _drive_to_results(game, "gamepad")
	_expect(body.is_over() and body.distance > 0.1 and not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible,
		"A gamepad-driven gait must genuinely walk and reach shared results without assigning a fall.")
	await create_timer(2.5, true, false, true).timeout
	await _capture_if_requested("gamepad-results")
	_pad_button(JOY_BUTTON_Y, true)
	_pad_button(JOY_BUTTON_Y, false)
	_expect(body.ticks == 0 and walk.dog.ticks == 0 and walk.rhythm.points == 0.0,
		"Y from real results must reset body, dog and scoring in place.")

	var reveal := InputEventScreenTouch.new()
	reveal.index = 99
	reveal.position = Vector2.ZERO
	reveal.pressed = true
	get_root().push_input(reveal, true)
	_touch(game, 20, Options.Q, true)
	_touch(game, 21, Options.P, true)
	game.call("_update_round", Body.STEP, 0.0)
	frame = game.get("_frame")
	_expect(frame.q == 1.0 and frame.p == 1.0,
		"Independent fingers must reach the actual coupled gameplay motors.")
	_touch(game, 22, Options.WHISTLE, true)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(walk.dog.whistles == 1 and (game.get("_frame") as InputFrame).whistle
		and controls.touch_pads.buttons[Options.WHISTLE].text.ends_with(" S"),
		"The on-screen Whistle must reach the real dog's edge-triggered recall.")
	_touch(game, 23, &"pause", true)
	await process_frame
	_expect(paused, "The touch Pause button must open the inherited pause overlay.")
	pause_menu = game.get("_pause_menu") as Node
	pause_menu.call("resume")
	await process_frame
	game.call("_update_round", Body.STEP, 0.0)
	frame = game.get("_frame")
	_expect(frame.q == 0.0 and frame.p == 0.0 and not frame.whistle,
		"Touch fingers held across pause must be released even if no up event arrives.")
	var started := Time.get_ticks_usec()
	_touch(game, 24, Options.RESTART, true)
	_touch(game, 24, Options.RESTART, false)
	_expect(body.ticks == 0 and body.distance == 0.0
		and controls.touch_pads.buttons[Options.WHISTLE].text.ends_with("READY")
		and Time.get_ticks_usec() - started < 2000000,
		"The touch Restart button must clear the actual walk in under two seconds.")
	var live_values: Dictionary = settings.get("_values")
	live_values[Options.EASY_LEGS_KEY] = true
	settings.emit_signal("changed", Options.EASY_LEGS_KEY, true)
	_touch(game, 25, Options.EASY_LEFT, true)
	game.call("_update_round", Body.STEP, 0.0)
	_expect(walk.last_frame.q == 1.0 and walk.last_frame.o == 1.0,
		"Live Easy touch must drive the same authored macro through gameplay.")
	live_values[Options.EASY_LEGS_KEY] = false
	settings.emit_signal("changed", Options.EASY_LEGS_KEY, false)
	_touch(game, 26, Options.RESTART, true)
	_touch(game, 26, Options.RESTART, false)
	var touch_walk := _drive_to_results(game, "touch")
	_expect(body.is_over() and body.distance > 0.1 and not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible,
		"A touch-driven gait must genuinely walk and reach shared results without assigning a fall.")
	_expect(keyboard_walk == gamepad_walk and gamepad_walk == touch_walk,
		"Keyboard, gamepad and touch must reach identical complete model, RNG and scoring state.")
	await create_timer(2.5, true, false, true).timeout
	await _capture_if_requested("touch-results")
	game.call("_on_play_again_pressed")
	game.call("_update_round", Body.STEP, 0.0)
	await create_timer(2.5, true, false, true).timeout

	var original_size := get_root().size
	for resolution in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		get_root().size = resolution
		await process_frame
		await process_frame
		for layout in [0, 1, 2]:
			live_values[Options.TOUCH_LAYOUT_KEY] = layout
			settings.emit_signal("changed", Options.TOUCH_LAYOUT_KEY, layout)
			var touch_rect := controls.touch_pads.get_global_rect()
			_expect(view.get_global_rect().end.y <= touch_rect.position.y
				and view.size.y > 260.0 and not bool(view.get("show_keycaps")),
				"Touch pads must reserve real space below, never obscure the walker or keycaps.")
			var occupied: Array[Rect2] = []
			for action in controls.touch_pads.buttons:
				var button := controls.touch_pads.buttons[action]
				if not button.visible:
					continue
				_expect(touch_rect.encloses(button.get_global_rect())
					and button.size.y >= 64.0 and not button.accessibility_name.is_empty(),
					"Every visible pad must fit, remain large and have a non-colour action label.")
				for other in occupied:
					_expect(not button.get_global_rect().intersects(other),
						"Touch hit targets must not overlap, including native two-line minimum heights.")
				occupied.append(button.get_global_rect())
			await _capture_if_requested("touch-%dx%d-layout%d" % [
				resolution.x, resolution.y, layout,
			])
	get_root().size = original_size
	await process_frame
	live_values[Options.TOUCH_LAYOUT_KEY] = 0
	settings.emit_signal("changed", Options.TOUCH_LAYOUT_KEY, 0)
	controls.clear_input()


func _drive_to_results(game: Node, source: String) -> Dictionary:
	var body: Body = game.get("_body")
	var keys: Array[int] = []
	if source == "keyboard":
		var settings := get_root().get_node("Settings")
		for binding in Options.LEG_BINDINGS:
			keys.append(int(settings.call("binding_keycode", binding)))
	for tick in 120 * 60:
		if body.is_over():
			break
		if tick % 12 == 0:
			var frame := WalkerTests.gait(tick)
			if source == "gamepad":
				_pad_button(JOY_BUTTON_LEFT_SHOULDER, frame.q > 0.0)
				_pad_axis(JOY_AXIS_TRIGGER_LEFT, frame.w)
				_pad_button(JOY_BUTTON_RIGHT_SHOULDER, frame.o > 0.0)
				_pad_axis(JOY_AXIS_TRIGGER_RIGHT, frame.p)
			else:
				var strengths: Array[float] = [frame.q, frame.w, frame.o, frame.p]
				for index in Options.LEG_ACTIONS.size():
					if source == "keyboard":
						var event := InputEventKey.new()
						event.physical_keycode = keys[index]
						event.pressed = strengths[index] > 0.0
						Input.parse_input_event(event)
						Input.flush_buffered_events()
					else:
						_touch(game, index, Options.LEG_ACTIONS[index], strengths[index] > 0.0)
		game.call("_update_round", Body.STEP, 0.0)
	print("%s walk: %.2f m, %d ticks, ending=%s." % [
		source.capitalize(), body.distance, body.ticks, body.end_cause,
	])
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	var walk: Walk = game.get("_walk")
	return walk.snapshot()


func _test_park_walk(game: Node) -> void:
	var walk: Walk = game.get("_walk")
	var controls: WalkControls = game.get("_controls")
	var original_seed := int(game.get("_walk_seed"))
	game.set_process(false)
	game.set("_walk_seed", 1)
	game.call("_start_round")
	for tick in 28800:
		if walk.body.is_over() or walk.hazards.splashes > 0:
			break
		if tick % 12 == 0:
			var frame := WalkerTests.gait(tick)
			var strengths: Array[float] = [frame.q, frame.w, frame.o, frame.p]
			for index in 4:
				if strengths[index] > 0.0:
					Input.action_press(Options.LEG_ACTIONS[index], strengths[index])
				else:
					Input.action_release(Options.LEG_ACTIONS[index])
		if walk.dog.is_warning():
			Input.action_press(Options.WHISTLE)
		else:
			Input.action_release(Options.WHISTLE)
		game.call("_update_round", Body.STEP, 0.0)
		if tick % 480 == 0:
			await process_frame
	controls.clear_input()
	_expect(not walk.body.is_over() and walk.body.distance > Chunks.LENGTH
		and walk.hazards.splashes > 0 and bool(game.get("_round_active")),
		"A real keyed walk with recalls must stream out of the intro and physically reach water.")
	_expect((game.get("_callout") as Label).text.contains("PUDDLE")
		and int((game.get("_audio") as RefCounted).get("_heard_splashes"))
			== walk.hazards.splashes,
		"The genuinely walked-to puddle must trigger the same visible and original audio feedback.")
	print("Live Park input walk: %.2f m / %d ticks / %d splashes / seed %d." % [
		walk.body.distance, walk.body.ticks, walk.hazards.splashes, walk.route.seed_value,
	])
	await create_timer(2.5, true, false, true).timeout
	await _capture_if_requested("park-genuine-puddle")
	game.set("_walk_seed", original_seed)
	game.call("_start_round")


func _test_park_encounter_walk(game: Node) -> void:
	var walk: Walk = game.get("_walk")
	var controls: WalkControls = game.get("_controls")
	var original_seed := int(game.get("_walk_seed"))
	game.set_process(false)
	game.set("_walk_seed", 731)
	game.call("_start_round")
	var backwards := 0.0
	var was_busy := false
	for tick in 72000:
		if walk.body.is_over() or (walk.hazards.telegraphs > 0 and not walk.hazards.is_busy()):
			break
		var busy := walk.hazards.is_busy()
		if tick % 12 == 0 or busy != was_busy:
			var frame := InputFrame.new() if busy else WalkerTests.gait(tick)
			var strengths: Array[float] = [frame.q, frame.w, frame.o, frame.p]
			for index in 4:
				if strengths[index] > 0.0:
					Input.action_press(Options.LEG_ACTIONS[index], strengths[index])
				else:
					Input.action_release(Options.LEG_ACTIONS[index])
		was_busy = busy
		if walk.dog.is_warning():
			Input.action_press(Options.WHISTLE)
		else:
			Input.action_release(Options.WHISTLE)
		game.call("_update_round", Body.STEP, 0.0)
		backwards = minf(backwards, walk.leash.force.x)
		if tick % 480 == 0:
			await process_frame
	controls.clear_input()
	_expect(not walk.body.is_over() and walk.body.distance >= 50.0 and backwards < -5.0
		and walk.hazards.warning_kind() == Chunks.JOGGER
		and int((game.get("_audio") as RefCounted).get("_heard_hazards")) == 1,
		"Real sampled leg input must reach a generated jogger and brace through its backward rope.")
	print("Live Park encounter walk: %.2f m / %d ticks / %.1f N backward rope / seed %d." % [
		walk.body.distance, walk.body.ticks, backwards, walk.route.seed_value,
	])
	await create_timer(2.5, true, false, true).timeout
	await _capture_if_requested("park-genuine-jogger")
	game.set("_walk_seed", original_seed)
	game.call("_start_round")


func _pad_button(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 13
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _pad_axis(axis: int, strength: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 13
	event.axis = axis
	event.axis_value = strength
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(game: Node, index: int, action: StringName, pressed: bool) -> void:
	var controls: WalkControls = game.get("_controls")
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = controls.touch_pads.buttons[action].get_global_rect().get_center()
	event.pressed = pressed
	get_root().push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
