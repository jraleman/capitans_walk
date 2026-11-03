extends RefCounted

## Distinct original mood tones accompany captions, never pretending to be real dog barks.

const Walk = preload("res://games/capitans_walk/walk/walk_state.gd")
const Profiles = preload("res://games/capitans_walk/walk/dog_profiles.gd")
const Chunks = preload("res://games/capitans_walk/walk/route_chunks.gd")
const SAMPLE_RATE := 22050

var _warnings: Dictionary[StringName, AudioStreamWAV] = {
	Profiles.SQUIRREL: _tone(550.0, 1100.0, 0.16),
	Profiles.HYDRANT: _tone(340.0, 220.0, 0.28),
	Profiles.PIGEON: _tone(900.0, 700.0, 0.30, 3),
	Profiles.FOOD: _tone(280.0, 420.0, 0.35),
	Profiles.PROTEST: _tone(200.0, 140.0, 0.25),
}
var _whistle := _tone(1500.0, 1900.0, 0.12)
var _splash := _tone(180.0, 90.0, 0.16, 2)
var _hazards: Dictionary[StringName, AudioStreamWAV] = {
	Chunks.SPRINKLER: _tone(1100.0, 800.0, 0.32, 4),
	Chunks.JOGGER: _tone(260.0, 420.0, 0.32, 2),
	Chunks.PIGEON_FLOCK: _tone(720.0, 1200.0, 0.28, 3),
	Chunks.OTHER_DOG: _tone(420.0, 620.0, 0.24, 2),
}
var _heard_warnings := 0
var _heard_whistles := 0
var _heard_splashes := 0
var _heard_hazards := 0


## A restart resets event tracking, not Settings volume or the host's audio ownership.
func reset() -> void:
	_heard_warnings = 0
	_heard_whistles = 0
	_heard_splashes = 0
	_heard_hazards = 0


## Both entry scenes use the same cues; headless models never need an audio singleton.
func update(walk: Walk, manager: Node) -> void:
	if walk.hazards.splashes > _heard_splashes:
		manager.call("play_sfx", _splash, -12.0)
		if walk.dog.state == walk.dog.TROT and walk.dog.response_ticks == 0 \
			and not walk.hazards.is_busy():
			manager.call("request_caption", "Splash. Puddles reduce foot grip to 0.30.")
		_heard_splashes = walk.hazards.splashes
	if walk.hazards.telegraphs > _heard_hazards:
		manager.call("play_sfx", _hazards[walk.hazards.warning_kind()], -10.0)
		if not walk.dog.is_warning() and walk.dog.response_ticks == 0:
			manager.call("request_caption", walk.hazards.telegraph_caption())
		_heard_hazards = walk.hazards.telegraphs
	if walk.dog.telegraphs > _heard_warnings:
		manager.call("play_sfx", _warnings[walk.dog.mood], -8.0)
		manager.call("request_caption", walk.dog.telegraph_caption())
		_heard_warnings = walk.dog.telegraphs
	if walk.dog.whistles > _heard_whistles:
		manager.call("play_sfx", _whistle, -8.0)
		manager.call("request_caption", "Whistle heard. Capitan recalls after 0.3 seconds.")
		_heard_whistles = walk.dog.whistles


func _tone(start_hz: float, end_hz: float, duration: float, beats := 1) -> AudioStreamWAV:
	var samples := roundi(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var beat_duration := duration / beats
	for index in samples:
		var time := float(index) / SAMPLE_RATE
		var beat_time := fmod(time, beat_duration)
		var progress := beat_time / beat_duration
		phase += TAU * lerpf(start_hz, end_hz, progress) / SAMPLE_RATE
		var envelope := minf(beat_time / 0.015, (beat_duration - beat_time) / 0.03)
		var value := roundi(sin(phase) * clampf(envelope, 0.0, 1.0) * 16000.0)
		data[index * 2] = value & 0xff
		data[index * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
