extends SceneTree

## Full momentum/contact snapshots pin reproducibility, not merely a matching score.

const Body = preload("res://games/capitans_walk/walk/walker_body.gd")
const InputFrame = preload("res://games/capitans_walk/walk/input_frame.gd")
const WalkerTests = preload("res://games/capitans_walk/tests/walker_body_test.gd")


func _initialize() -> void:
	var first := Body.new(null, 731)
	var second := Body.new(null, 731)
	for tick in 7200:
		var frame := WalkerTests.gait(tick)
		first.step(frame)
		second.step(frame)
		if first.snapshot() != second.snapshot():
			printerr("Identical inputs diverged at tick %d." % tick)
			quit(1)
			return
	if first.ticks != 7200:
		printerr("Determinism must exercise a live 60-second walk, not a frozen early fall.")
		quit(1)
		return
	var at_30 := Body.new()
	var at_60 := Body.new()
	var at_144 := Body.new()
	var neutral := InputFrame.new()
	for frame in 90:
		at_30.advance(1.0 / 30.0, neutral)
	for frame in 180:
		at_60.advance(1.0 / 60.0, neutral)
	for frame in 432:
		at_144.advance(1.0 / 144.0, neutral)
	if at_30.ticks != 360 or at_60.ticks != 360 or at_144.ticks != 360 \
		or at_30.positions != at_60.positions or at_30.positions != at_144.positions \
		or at_30.previous != at_144.previous or at_30.z != at_144.z:
		printerr("30, 60 and 144 FPS must produce identical fixed-step state.")
		quit(1)
		return
	var hitched := Body.new()
	hitched.advance(3.0, neutral)
	if hitched.positions != at_60.positions or hitched.ticks != 360:
		printerr("A frame hitch must not discard simulation time.")
		quit(1)
		return
	var walking: Array[Dictionary] = []
	for fps: int in [30, 60, 144]:
		var body := Body.new()
		for frame in fps * 3:
			body.advance(1.0 / float(fps), WalkerTests.gait(body.ticks))
		if body.ticks != 360 or body.is_over():
			printerr("The render-rate check must exercise a live three-second gait.")
			quit(1)
			return
		var state := body.snapshot()
		# A sub-tick render-clock remainder is not part of the fixed-step physics state.
		state.erase("accumulator")
		walking.append(state)
	if walking[0] != walking[1] or walking[0] != walking[2]:
		printerr("A changing four-key gait must match at 30, 60 and 144 FPS.")
		quit(1)
		return
	print("Capitan's Walk determinism tests passed (60 seconds; 30/60/144 FPS; hitch).")
	quit(0)
