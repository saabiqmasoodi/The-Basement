extends AudioStreamPlayer
# A procedurally generated sub-bass drone. No external sample is used: three
# detuned low sines and a whisper of noise create a room tone that sits under
# the existing sound design and gets louder as the player goes deeper.

const MIX_RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback
var _phases := [0.0, 0.0, 0.0]
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0x51DE
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.45
	stream = generator
	volume_db = -25.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	_time += delta
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var breath := 0.42 + 0.58 * (0.5 + 0.5 * sin(_time * 0.21 + sin(_time * 0.047) * 2.3))
	for i in range(frames):
		var s := sin(_phases[0]) * 0.16
		s += sin(_phases[1]) * 0.10
		s += sin(_phases[2]) * 0.055
		s += _rng.randf_range(-1.0, 1.0) * 0.008
		s = clampf(s, -1.0, 1.0) * breath * 0.62
		buffer[i] = Vector2(s, s)
		_phases[0] = fmod(_phases[0] + TAU * 31.5 / MIX_RATE, TAU)
		_phases[1] = fmod(_phases[1] + TAU * 47.0 / MIX_RATE, TAU)
		_phases[2] = fmod(_phases[2] + TAU * 59.3 / MIX_RATE, TAU)
	_playback.push_buffer(buffer)
