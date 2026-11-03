extends GameShell

## The shared pause/results flow around the deliberately art-free dog/leash walk.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkControls = preload("res://games/capitans_walk/input/walk_controls.gd")
const DebugView = preload("res://games/capitans_walk/ui/walker_debug_view.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const WalkAudio = preload("res://games/capitans_walk/audio/walk_audio.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")

var _walk := Walk.new(null, 0, null, Route.new())
var _body: Body = _walk.body
var _audio := WalkAudio.new()
var _controls: WalkControls
var _frame := InputFrame.new()
var _view: DebugView
var _walk_speed := 1.0
var _walk_seed := 0
var _assisted := false


## The manifest, rather than the framework, names the running game.
func game_id() -> String:
	return Options.GAME_ID


func _prepare_session() -> void:
	if not GameSession.is_single_player():
		GameSession.configure_single_player()
	super()


func _load_round_settings() -> void:
	super()
	_body.steady = Settings.tunable(Options.STEADY_KEY)
	_walk_speed = float(Settings.tunable_choice(Options.WALK_SPEED_KEY)) / 100.0
	_walk.easy_legs = Settings.tunable_bool(Options.EASY_LEGS_KEY)
	_walk.dog.long_warnings = Settings.tunable_bool(Options.LONG_WARNINGS_KEY)
	if _round_active:
		_assisted = _assisted or _using_assists()


func _build_playfield() -> void:
	_view = DebugView.new()
	_view.name = "WalkerDebugView"
	_playfield.add_child(_view)
	_controls = WalkControls.new()
	_controls.name = "WalkControls"
	_controls.restart_requested.connect(_start_round)
	_controls.pause_requested.connect(_on_pad_pause_requested)
	_controls.layout_changed.connect(_resize_view)
	_controls.gamepad_changed.connect(_configure_mode_ui)
	_playfield.add_child(_controls)
	get_viewport().size_changed.connect(_resize_view)
	_resize_view()
	_view.present(_body, _frame, _walk)
	_configure_mode_ui()


func _reset_round_state() -> void:
	_walk.reset(_walk_seed)
	_audio.reset()
	_controls.set_enabled(true)
	_controls.touch_pads.set_whistle_cooldown(0.0)
	_frame = InputFrame.new()
	_assisted = _using_assists()
	_view.present(_body, _frame, _walk)


func _activate_round() -> void:
	_show_announcement("PLANT, STEP, BRACE!", StudioInfo.CREAM)


func _update_round(delta: float, _time_left: float) -> void:
	_frame = _controls.sample()
	_walk.advance(delta * _walk_speed, _frame)
	_controls.touch_pads.set_whistle_cooldown(_walk.dog.cooldown_ticks * Body.STEP)
	_audio.update(_walk, AudioManager)
	_scores[PLAYER_ONE] = _walk.final_score()
	_streaks[PLAYER_ONE] = _walk.rhythm.combo
	_best_streaks[PLAYER_ONE] = _walk.rhythm.best_combo
	_assisted = _assisted or _using_assists()
	_update_scores()
	_update_balance()
	_view.present(_body, _frame, _walk)
	if _body.is_over():
		_end_round()


## The shell filters inactive gameplay input; Restart must also work from results.
func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused and not is_instance_valid(_pause_menu) \
		and event.is_action_pressed(Options.RESTART) and not event.is_echo():
		get_viewport().set_input_as_handled()
		_start_round()
		return
	super(event)


func _end_round() -> void:
	_controls.set_enabled(false)
	super()


func open_pause_menu() -> void:
	_controls.set_enabled(false)
	super()
	if not is_instance_valid(_pause_menu):
		_controls.set_enabled(_round_active)


func _on_pause_closed() -> void:
	super()
	_controls.set_enabled(_round_active)


## Forward Start through the shared pause/back path, including nested Settings.
func _on_pad_pause_requested() -> void:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	if is_instance_valid(_pause_menu):
		_pause_menu.call("_input", event)
	else:
		_unhandled_input(event)


func _update_scores() -> void:
	_player_one_score.text = "%.1f m" % _body.distance
	_player_one_streak.show()
	_player_one_streak.text = "%d POINTS / COMBO %d" % [
		_scores[PLAYER_ONE], _walk.rhythm.combo,
	]


func _configure_mode_ui() -> void:
	super()
	_player_one_caption.text += " / DISTANCE"
	var result_caption := _round_player_one_score.get_parent().get_node("Caption") as Label
	result_caption.text += " / WALK SCORE"
	_time_caption.text = "SWAY / %.2f M EDGE" % (_body.half_width + Body.EDGE_ALLOWANCE)
	_time_progress.hide()
	_player_one_streak.show()
	_round_instructions.text = "Restart for another walk, or see rhythm and physics stats."
	var labels := PackedStringArray()
	for binding in Options.LEG_BINDINGS:
		labels.append(Settings.binding_key_label(binding))
	var easy_labels := PackedStringArray()
	for binding in Options.EASY_BINDINGS:
		easy_labels.append(Settings.binding_key_label(binding))
	var legs := "%s / %s thighs  |  %s / %s calves" % [
		labels[0], labels[1], labels[2], labels[3],
	]
	if _walk.easy_legs:
		legs = "%s left leg / %s right leg  |  %s + %s manual brace" % [
			easy_labels[0], easy_labels[1], labels[1], labels[3],
		]
	_hint.text = "%s  |  %s whistle  |  %s restart  |  Esc pause" % [
		legs, Settings.binding_key_label(Options.WHISTLE_BINDING),
		Settings.binding_key_label(Options.RESTART_BINDING),
	]
	if _view != null:
		_view.configure_keys(labels, Settings.binding_key_label(Options.WHISTLE_BINDING),
			easy_labels, _walk.easy_legs)
	if _controls != null:
		_controls.configure_keys(labels, Settings.binding_key_label(Options.WHISTLE_BINDING),
			easy_labels, _walk.easy_legs, int(Settings.tunable_choice(Options.TOUCH_LAYOUT_KEY)))
		if _controls.has_gamepad():
			_hint.text += (
				"\nPad: LB / LT thighs | RB / RT calves | A whistle | Y or Back restart | Start pause"
				+ (" | D-pad left / right: Easy legs" if _walk.easy_legs else "")
			)
	_update_balance()


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key in [Options.STEADY_KEY, Options.WALK_SPEED_KEY,
		Options.EASY_LEGS_KEY, Options.LONG_WARNINGS_KEY, Options.TOUCH_LAYOUT_KEY]:
		_load_round_settings()
		_configure_mode_ui()


func _round_totals() -> Dictionary:
	return {
		"hits": _walk.rhythm.plants, "attempts": _walk.rhythm.plants,
		"distance_cm": roundi(_body.distance * 100.0),
		"walk_score": _scores[PLAYER_ONE],
	}


func _player_stats(player_index: int) -> Dictionary:
	var active := player_index == PLAYER_ONE
	return {
		"score": _scores[player_index], "hits": _walk.rhythm.plants if active else 0,
		"misses": int(_body.is_over()) if active else 0, "accuracy": 0,
		"streak": _walk.rhythm.best_combo if active else 0,
		"distance": _body.distance if active else 0.0,
		"cause": _body.end_cause if active else "",
		"simulation_seconds": _body.ticks * Body.STEP if active else 0.0,
		"assisted": _assisted,
		"whistles": _walk.dog.whistles if active else 0,
		"peak_tension": _walk.peak_tension if active else 0.0,
		"happiness": _walk.dog.happiness if active else 0.0,
		"verdict_wags": _walk.dog.verdict_wags() if active else 0,
		"sniffs": _walk.dog.sniffs if active else 0,
		"route_seed": _walk_seed, "splashes": _walk.hazards.splashes if active else 0,
		"hazard_warnings": _walk.hazards.telegraphs if active else 0,
		"greetings": _walk.hazards.greetings if active else 0,
		"details": [
			{"label": "Distance", "value": "%.1f m" % _body.distance},
			{"label": "Park route", "value": "Seed %d / %d shoe splashes" % [
				_walk_seed, _walk.hazards.splashes,
			]},
			{"label": "Park cues", "value": "%d warnings / %d play or greeting sniffs" % [
				_walk.hazards.telegraphs, _walk.hazards.greetings,
			]},
			{"label": "Rhythm", "value": "%d good strides / %d plants / best combo %d" % [
				_walk.rhythm.good_strides, _walk.rhythm.plants, _walk.rhythm.best_combo,
			]},
			{"label": "Capitan", "value": "%.0f/100 happiness / %d/5 tail wags" % [
				_walk.dog.happiness, _walk.dog.verdict_wags(),
			]},
			{"label": "Model walk", "value": "%.1f s / %d whistles / %d sniffs" % [
				_body.ticks * Body.STEP, _walk.dog.whistles, _walk.dog.sniffs,
			]},
			{"label": "Peak leash", "value": "%.0f N" % _walk.peak_tension},
			{"label": "Legs", "value": "ASSISTED" if _assisted else "Classic"},
		] if active else [],
	}


func _describe_round_outcome(_player_one_total: int, _player_two_total: int) -> Dictionary:
	var cause := "Off the path!" if _body.end_cause == "off_path" \
		else "And down goes the human." if _body.end_cause == "fall" else "Practice complete."
	return {
		"result": "%.1f METRES" % _body.distance,
		"subtitle": "%s Capitan: %d/5 tail wags / happiness %.0f/100." % [
			cause, _walk.dog.verdict_wags(), _walk.dog.happiness,
		],
		"color": player_one_color,
	}


func _round_highlight_summary() -> String:
	return "Best combo %d / %.0f banked x %.2f happiness / %d whistles / %s" % [
		_walk.rhythm.best_combo, _walk.rhythm.points, _walk.dog.score_multiplier(),
		_walk.dog.whistles, "ASSISTED" if _assisted else "Classic legs",
	]


func _using_assists() -> bool:
	return _body.steady > 0.0 or _walk_speed < 1.0 \
		or _walk.easy_legs or _walk.dog.long_warnings


func _update_balance() -> void:
	_time_label.text = "%+.2f m" % _body.z
	var cue := _walk.cue_caption()
	if not cue.is_empty():
		_callout.text = cue
	elif _body.stance_count() == 2:
		_callout.text = "DOUBLE STANCE / RELEASE TO SETTLE"
	elif _body.stance_count() == 0:
		_callout.text = "AIRBORNE / NO LATERAL SUPPORT"
	else:
		_callout.text = "LEFT FOOT PLANTED" if _body.foot_contacts[0] else "RIGHT FOOT PLANTED"


func _resize_view() -> void:
	if _view == null:
		return
	var bounds := _playfield_bounds()
	_controls.position = bounds.position
	_controls.size = bounds.size
	_view.position = bounds.position
	_view.size = Vector2(bounds.size.x, bounds.size.y - _controls.touch_height())
	_view.show_keycaps = not _controls.touch_pads.visible
	_pause_button.visible = DisplayServer.is_touchscreen_available() \
		and not _controls.touch_pads.visible
