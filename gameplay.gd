extends GameShell

## Automatic first-person walking and dog-path rules under the ordinary shared shell.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkControls = preload("res://games/capitans_walk/input/walk_controls.gd")
const WalkView = preload("res://games/capitans_walk/world/walk_view.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const WalkAudio = preload("res://games/capitans_walk/audio/walk_audio.gd")
const Route = preload("res://games/capitans_walk/walk/route_generator.gd")
const PathWalk = preload("res://games/capitans_walk/walk/path_walk.gd")

var _walk := Walk.new(null, 0, null, Route.new(), true)
var _audio := WalkAudio.new()
var _controls: WalkControls
var _frame := InputFrame.new()
var _view: WalkView
var _walk_speed := 1.0
var _walk_seed := 0
var _assisted := false
var _capture_inset := 0.0


## The manifest, rather than the framework, names the running game.
func game_id() -> String:
	return Options.GAME_ID


func _prepare_session() -> void:
	if not GameSession.is_single_player():
		GameSession.configure_single_player()
	super()


func _load_round_settings() -> void:
	super()
	_walk_speed = float(Settings.tunable_choice(Options.WALK_SPEED_KEY)) / 100.0
	_walk.dog.long_warnings = Settings.tunable_bool(Options.LONG_WARNINGS_KEY)
	_walk.path.long_warnings = _walk.dog.long_warnings
	if _round_active:
		_assisted = _assisted or _using_assists()


func _build_playfield() -> void:
	_view = WalkView.new()
	_view.name = "FirstPersonPark"
	_view.reduced_motion = _reduced_motion_enabled
	_playfield.add_child(_view)
	register_hud_controls(_view.control_tray, _resize_view, false)
	_controls = WalkControls.new()
	_controls.name = "WalkControls"
	_controls.path_mode = true
	_controls.restart_requested.connect(_start_round)
	_controls.pause_requested.connect(_on_pad_pause_requested)
	_controls.layout_changed.connect(_resize_view)
	_controls.gamepad_changed.connect(_configure_mode_ui)
	_playfield.add_child(_controls)
	get_viewport().size_changed.connect(_resize_view)
	_shell_top_bar.resized.connect(_resize_view, CONNECT_DEFERRED)
	_callout.minimum_size_changed.connect(_resize_view, CONNECT_DEFERRED)
	_resize_view()
	_view.present(_walk, _frame)
	_configure_mode_ui()


func _reset_round_state() -> void:
	_walk.reset(_walk_seed)
	_audio.reset()
	_controls.set_enabled(true)
	_controls.touch_pads.set_whistle_cooldown(0.0)
	_frame = InputFrame.new()
	_assisted = _using_assists()
	_scores[PLAYER_ONE] = _walk.final_score()
	_view.present(_walk, _frame)


func _activate_round() -> void:
	_update_scores()
	_update_path()
	_show_announcement("KEEP CAPITAN ON THE PATH!", StudioInfo.CREAM)


func _update_round(delta: float, _time_left: float) -> void:
	if not _round_active or get_tree().paused:
		return
	_frame = _controls.sample()
	_walk.advance(delta * _walk_speed, _frame)
	_controls.touch_pads.set_whistle_cooldown(_walk.dog.cooldown_ticks * Body.STEP)
	_audio.update(_walk, AudioManager)
	_scores[PLAYER_ONE] = _walk.final_score()
	_assisted = _assisted or _using_assists()
	_update_scores()
	_update_path()
	_view.present(_walk, _frame)
	if _walk.is_over():
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
	_player_one_score.text = "%.1f m" % _walk.path.distance
	_time_label.text = "%d PTS" % _scores[PLAYER_ONE]
	_player_one_streak.show()
	_player_one_streak.text = "%d POINTS / FINISH %.0f M" % [
		_scores[PLAYER_ONE], PathWalk.FINISH_DISTANCE,
	]


func _configure_mode_ui() -> void:
	super()
	_player_one_caption.text += " / DISTANCE"
	var result_caption := _round_player_one_score.get_parent().get_node("Caption") as Label
	result_caption.text += " / WALK SCORE"
	_time_label.get_parent().get_parent().show()
	_time_caption.text = "POINTS / %.0f M FINISH" % PathWalk.FINISH_DISTANCE
	_time_progress.max_value = PathWalk.FINISH_DISTANCE
	_time_progress.show()
	_callout.show()
	_player_one_streak.show()
	_round_instructions.text = "Restart the same Park route, or see your path and score breakdown."
	var labels := PackedStringArray()
	for binding in Options.STEER_BINDINGS:
		labels.append(Settings.binding_key_label(binding))
	_hint.text = "%s / %s steer leash  |  %s whistle  |  %s restart  |  Esc pause" % [
		labels[0], labels[1], Settings.binding_key_label(Options.WHISTLE_BINDING),
		Settings.binding_key_label(Options.RESTART_BINDING),
	]
	if _view != null:
		_view.configure_keys(labels, Settings.binding_key_label(Options.WHISTLE_BINDING))
	if _controls != null:
		_controls.configure_path_keys(labels, Settings.binding_key_label(Options.WHISTLE_BINDING),
			int(Settings.tunable_choice(Options.TOUCH_LAYOUT_KEY)))
		if _controls.has_gamepad():
			_hint.text += "\nPad: Left stick / D-pad steer | A whistle | Y/Back restart | Start pause"
	_update_path()


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key in [Options.WALK_SPEED_KEY, Options.LONG_WARNINGS_KEY, Options.TOUCH_LAYOUT_KEY]:
		_load_round_settings()
		_configure_mode_ui()


func _round_totals() -> Dictionary:
	return {
		"hits": floori(_walk.path.safe_distance), "attempts": ceili(_walk.path.distance),
		"distance_cm": roundi(_walk.path.distance * 100.0),
		"walk_score": _scores[PLAYER_ONE],
	}


func _populate_score_screen(result_text: String, result_color: Color) -> void:
	super(result_text, result_color)
	_game_duration_stat.text = "%.1f SEC" % (_walk.path.ticks * Body.STEP)
	_game_accuracy_stat.text = "%.1f" % _walk.path.points_lost


func _share_payload() -> Dictionary:
	var data := super()
	data["score_caption"] = "POINTS REMAINING"
	data["hits_caption"] = "ON-PATH METRES"
	data["accuracy_caption"] = "ON PATH"
	data["combo_caption"] = "EXCURSIONS"
	data["combo"] = str(_walk.path.excursions)
	data["combo_value"] = _walk.path.excursions
	data["misses_value"] = _walk.path.excursions
	return data


func _player_stats(player_index: int) -> Dictionary:
	var active := player_index == PLAYER_ONE
	var path := _walk.path
	return {
		"score": _scores[player_index], "hits": floori(path.safe_distance) if active else 0,
		"misses": path.excursions if active else 0, "accuracy": 0, "streak": 0,
		"distance": path.distance if active else 0.0,
		"cause": path.end_cause if active else "",
		"completed": active and path.end_cause == "finished",
		"simulation_seconds": path.ticks * Body.STEP if active else 0.0,
		"assisted": _assisted,
		"whistles": _walk.dog.whistles if active else 0,
		"peak_tension": _walk.peak_tension if active else 0.0,
		"points_lost": path.points_lost if active else 0.0,
		"safe_distance": path.safe_distance if active else 0.0,
		"route_seed": _walk_seed,
		"details": [
			{"label": "Distance", "value": "%.1f / %.0f m" % [
				path.distance, PathWalk.FINISH_DISTANCE,
			]},
			{"label": "Outcome", "value": path.end_cause.replace("_", " ").capitalize()},
			{"label": "On the path", "value": "%.1f m / +%.1f points" % [
				path.safe_distance, path.safe_distance * PathWalk.POINTS_PER_METRE,
			]},
			{"label": "Off the path", "value": "%d excursions / -%.1f points" % [
				path.excursions, path.points_lost,
			]},
			{"label": "Park route", "value": "Seed %d / %d warnings" % [
				_walk_seed, path.warnings,
			]},
			{"label": "Model walk", "value": "%.1f s / %d whistles" % [
				path.ticks * Body.STEP, _walk.dog.whistles,
			]},
			{"label": "Peak leash", "value": "%.0f N" % _walk.peak_tension},
			{"label": "Pace", "value": "ASSISTED" if _assisted else "Standard"},
		] if active else [],
	}


func _describe_round_outcome(_player_one_total: int, _player_two_total: int) -> Dictionary:
	var cause := "Walk complete! Capitan made it." if _walk.path.end_cause == "finished" \
		else "Out of points. Guide Capitan back sooner." if _walk.path.is_over() \
		else "Walk stopped."
	return {
		"result": "%.1f METRES" % _walk.path.distance,
		"subtitle": "%s %d points remaining." % [cause, _player_one_total],
		"color": player_one_color,
	}


func _round_highlight_summary() -> String:
	return "%.1f safe metres / %d excursions / -%.1f points / %d whistles%s" % [
		_walk.path.safe_distance, _walk.path.excursions, _walk.path.points_lost,
		_walk.dog.whistles, " / ASSISTED" if _assisted else "",
	]


func _using_assists() -> bool:
	return _walk_speed < 1.0 or _walk.dog.long_warnings


func _update_path() -> void:
	_callout.text = _walk.cue_caption()
	_time_progress.value = _walk.path.distance


func _spawn_round_confetti(color: Color) -> void:
	if _walk.path.end_cause == "finished":
		super(color)


func _set_capture_inset(bottom: float) -> void:
	_capture_inset = maxf(0, bottom)
	_resize_view()


func _resize_view() -> void:
	if _view == null:
		return
	var bounds := _playfield_bounds()
	bounds.size.y = maxf(1, minf(bounds.end.y,
		get_viewport_rect().end.y - _capture_inset) - bounds.position.y)
	_controls.position = bounds.position
	_controls.size = bounds.size
	_view.position = bounds.position
	_view.unit = _shell_hud_unit
	_view.size = Vector2(bounds.size.x, maxf(1, bounds.size.y - _controls.touch_height()))
	_pause_button.visible = DisplayServer.is_touchscreen_available() \
		and not _controls.touch_pads.visible


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.reduced_motion = value
		_view.present(_walk, _frame)
