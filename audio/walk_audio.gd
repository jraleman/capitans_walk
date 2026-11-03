extends RefCounted

## Two original placeholder tones accompany captions; neither pretends to be Capitan's bark.

const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const SAMPLE_RATE := 22050

var _warning := _tone(550.0, 1100.0, 0.16)
var _whistle := _tone(1500.0, 1900.0, 0.12)
var _heard_warnings := 0
var _heard_whistles := 0


## A restart resets event tracking, not Settings volume or the host's audio ownership.
func reset() -> void:
	_heard_warnings = 0
	_heard_whistles = 0


## Both entry scenes use the same cues; headless models never need an audio singleton.
func update(walk: Walk, manager: Node) -> void:
	if walk.dog.telegraphs > _heard_warnings:
		manager.call("play_sfx", _warning, -8.0)
		manager.call("request_caption", "Capitan spots a SQUIRREL! Plant both feet.")
		_heard_warnings = walk.dog.telegraphs
	if walk.dog.whistles > _heard_whistles:
		manager.call("play_sfx", _whistle, -8.0)
		manager.call("request_caption", "Whistle heard. Capitan recalls after 0.3 seconds.")
		_heard_whistles = walk.dog.whistles


func _tone(start_hz: float, end_hz: float, duration: float) -> AudioStreamWAV:
	var samples := roundi(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for index in samples:
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		phase += TAU * lerpf(start_hz, end_hz, progress) / SAMPLE_RATE
		var envelope := minf(time / 0.015, (duration - time) / 0.03)
		var value := roundi(sin(phase) * clampf(envelope, 0.0, 1.0) * 16000.0)
		data[index * 2] = value & 0xff
		data[index * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
