extends GameShell

## The shared pause/results flow around the deliberately art-free dog/leash walk.

const Options = preload("res://games/capitans_walk/capitans_walk_options.gd")
const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const KeySource = preload("res://games/capitans_walk/input/key_source.gd")
const DebugView = preload("res://games/capitans_walk/ui/walker_debug_view.gd")
const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const WalkAudio = preload("res://games/capitans_walk/audio/walk_audio.gd")

var _walk := Walk.new()
var _body: Body = _walk.body
var _audio := WalkAudio.new()
var _keys := KeySource.new()
var _frame := InputFrame.new()
var _view: DebugView
var _walk_speed := 1.0
var _walk_seed := 0


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


func _build_playfield() -> void:
	_view = DebugView.new()
	_view.name = "WalkerDebugView"
	_playfield.add_child(_view)
	get_viewport().size_changed.connect(_resize_view)
	_resize_view()
	_view.present(_body, _frame, _walk)
	_configure_mode_ui()


func _reset_round_state() -> void:
	_walk.reset(_walk_seed)
	_audio.reset()
	_frame = InputFrame.new()
	_view.present(_body, _frame, _walk)


func _activate_round() -> void:
	_show_announcement("PLANT, STEP, BRACE!", StudioInfo.CREAM)


func _update_round(delta: float, _time_left: float) -> void:
	_frame = _keys.sample()
	_walk.advance(delta * _walk_speed, _frame)
	_audio.update(_walk, AudioManager)
	_scores[PLAYER_ONE] = roundi(_body.distance * 100.0)
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


func _update_scores() -> void:
	_player_one_score.text = "%.1f m" % (float(_scores[PLAYER_ONE]) / 100.0)


func _configure_mode_ui() -> void:
	super()
	_player_one_caption.text += " / DISTANCE"
	var result_caption := _round_player_one_score.get_parent().get_node("Caption") as Label
	result_caption.text += " / DISTANCE (CM)"
	_time_caption.text = "SWAY / %.2f M EDGE" % (_body.half_width + Body.EDGE_ALLOWANCE)
	_time_progress.hide()
	_player_one_streak.hide()
	_round_instructions.text = "Restart for another try, or see the physics stats."
	var labels := PackedStringArray()
	for binding in Options.LEG_BINDINGS:
		labels.append(Settings.binding_key_label(binding))
	_hint.text = "%s / %s thighs  |  %s / %s calves  |  %s whistle  |  %s restart  |  Esc pause" % [
		labels[0], labels[1], labels[2], labels[3],
		Settings.binding_key_label(Options.WHISTLE_BINDING),
		Settings.binding_key_label(Options.RESTART_BINDING),
	]
	if _view != null:
		_view.configure_keys(labels, Settings.binding_key_label(Options.WHISTLE_BINDING))
	_update_balance()


func _on_game_setting_changed(key: String, _value: Variant) -> void:
	if key == Options.STEADY_KEY or key == Options.WALK_SPEED_KEY:
		_load_round_settings()


func _round_totals() -> Dictionary:
	return {"hits": _body.steps, "attempts": _body.steps, "distance_cm": _scores[PLAYER_ONE]}


func _player_stats(player_index: int) -> Dictionary:
	var active := player_index == PLAYER_ONE
	return {
		"score": _scores[player_index], "hits": _body.steps if active else 0,
		"misses": int(_body.is_over()) if active else 0, "accuracy": 0, "streak": 0,
		"distance": _body.distance if active else 0.0,
		"cause": _body.end_cause if active else "",
		"simulation_seconds": _body.ticks * Body.STEP if active else 0.0,
		"assisted": _body.steady > 0.0 or _walk_speed < 1.0,
		"whistles": _walk.dog.whistles if active else 0,
		"peak_tension": _walk.peak_tension if active else 0.0,
	}


func _describe_round_outcome(player_one_total: int, _player_two_total: int) -> Dictionary:
	var cause := "Off the path!" if _body.end_cause == "off_path" \
		else "And down goes the human." if _body.end_cause == "fall" else "Practice complete."
	return {
		"result": "%.1f METRES" % (float(player_one_total) / 100.0),
		"subtitle": "%s Kneeling is legal; Restart is one key." % cause,
		"color": player_one_color,
	}


func _round_highlight_summary() -> String:
	return "Grey-box walk / %d foot plants / %d whistles / %s" % [
		_body.steps,
		_walk.dog.whistles,
		"Steady or slowed time" if _body.steady > 0.0 or _walk_speed < 1.0 else "Classic legs",
	]


func _update_balance() -> void:
	_time_label.text = "%+.2f m" % _body.z
	if _walk.dog.state != _walk.dog.TROT or _walk.dog.response_ticks > 0:
		_callout.text = _walk.dog.caption()
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
	_view.position = bounds.position
	_view.size = bounds.size
