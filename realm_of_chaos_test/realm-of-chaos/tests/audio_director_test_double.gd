extends "res://scripts/audio_director.gd"

var test_stream: AudioStreamWAV


func _init() -> void:
	test_stream = AudioStreamWAV.new()
	test_stream.format = AudioStreamWAV.FORMAT_16_BITS
	test_stream.mix_rate = 8000
	test_stream.stereo = false
	var silent_data := PackedByteArray()
	silent_data.resize(16000)
	test_stream.data = silent_data


func _sample_for(_key: String, _variants: Array) -> AudioStream:
	return test_stream
