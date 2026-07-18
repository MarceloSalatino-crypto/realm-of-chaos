extends Node

var enabled := DisplayServer.get_name() != "headless"
var cached_streams: Dictionary = {}
var music_player: AudioStreamPlayer
var music_stage := ""


func set_music_stage(stage_id: String) -> void:
	if not enabled or stage_id == music_stage:
		return
	music_stage = stage_id
	if not is_instance_valid(music_player):
		music_player = AudioStreamPlayer.new()
		music_player.name = "AdaptiveMusic"
		music_player.volume_db = -23.0
		add_child(music_player)
	var key := "music_" + stage_id
	if not cached_streams.has(key):
		cached_streams[key] = _make_music_stream(stage_id)
	music_player.stream = cached_streams[key]
	music_player.play()


func play_hit(critical := false) -> void:
	_play_tone("critical" if critical else "hit", 520.0 if critical else 310.0, 0.12 if critical else 0.07, 0.65, "square")


func play_player_hurt() -> void:
	_play_tone("hurt", 105.0, 0.22, 0.72, "saw")


func play_boss_spawn() -> void:
	_play_tone("boss", 72.0, 0.65, 0.88, "saw")


func play_evolution() -> void:
	_play_tone("evolution", 740.0, 0.48, 0.74, "sine")


func play_pickup() -> void:
	_play_tone("pickup", 880.0, 0.06, 0.42, "sine")


func play_explosion() -> void:
	_play_tone("explosion", 62.0, 0.34, 0.82, "noise")


func _play_tone(key: String, frequency: float, duration: float, volume: float, waveform: String) -> void:
	if not enabled:
		return
	var stream: AudioStreamWAV
	if cached_streams.has(key):
		stream = cached_streams[key]
	else:
		stream = _make_stream(frequency, duration, volume, waveform)
		cached_streams[key] = stream
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _make_stream(frequency: float, duration: float, volume: float, waveform: String) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(waveform + str(frequency))
	for index in range(sample_count):
		var time := float(index) / sample_rate
		var phase := time * frequency * TAU
		var wave := 0.0
		match waveform:
			"square":
				wave = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":
				wave = 2.0 * fmod(time * frequency, 1.0) - 1.0
			"noise":
				wave = rng.randf_range(-1.0, 1.0)
			_:
				wave = sin(phase)
		var envelope := pow(1.0 - float(index) / sample_count, 2.0)
		data[index] = clampi(int(128.0 + wave * envelope * volume * 110.0), 0, 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_music_stream(stage_id: String) -> AudioStreamWAV:
	var sample_rate := 11025
	var duration := 8.0
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count)
	var root_frequency := 55.0
	var intensity := 0.34
	match stage_id:
		"hard":
			root_frequency = 65.41
			intensity = 0.40
		"chaos":
			root_frequency = 73.42
			intensity = 0.46
		"inferno":
			root_frequency = 82.41
			intensity = 0.52
		"boss":
			root_frequency = 49.0
			intensity = 0.58
	for index in range(sample_count):
		var time := float(index) / sample_rate
		var beat := fmod(time * (2.0 if stage_id == "boss" else 1.5), 1.0)
		var pulse := exp(-beat * 8.0)
		var drone := sin(time * root_frequency * TAU) * 0.52
		drone += sin(time * root_frequency * 1.5 * TAU) * 0.23
		drone += sin(time * root_frequency * 2.0 * TAU) * 0.12
		var percussion := sin(time * root_frequency * 0.5 * TAU) * pulse * 0.55
		var value := (drone + percussion) * intensity
		data[index] = clampi(int(128.0 + value * 105.0), 0, 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = data
	return stream
