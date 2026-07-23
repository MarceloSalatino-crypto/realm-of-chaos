extends Node

var enabled := DisplayServer.get_name() != "headless"
var cached_streams: Dictionary = {}
var music_players: Array[AudioStreamPlayer] = []
var active_music_player_index := 0
var ambient_track_index := -1
var ambient_rotation_active := false
var music_crossfade_active := false
var music_fade_tween: Tween
var music_stage := ""
var music_level := 0.65
var sfx_level := 0.80
var last_played_msec: Dictionary = {}
var active_sfx := 0
var active_sfx_by_key: Dictionary = {}
var active_sfx_players: Dictionary = {}
var last_sample_variant: Dictionary = {}

const MUSIC_BUS_NAME := &"Music"
const SFX_BUS_NAME := &"SFX"
const AMBIENT_TRACKS := [
	preload("res://audio/music/ambient_1.mp3"),
	preload("res://audio/music/ambient_2.mp3"),
	preload("res://audio/music/ambient_3.mp3")
]
const SFX_STREAMS := {
	"hit": preload("res://audio/sfx/sfx_hit_01.mp3"),
	"critical": preload("res://audio/sfx/sfx_critical_hit_01.mp3"),
	"hurt": preload("res://audio/sfx/sfx_player_hurt_01.mp3"),
	"dash": preload("res://audio/sfx/sfx_dash_01.mp3"),
	"explosion": preload("res://audio/sfx/sfx_explosion_01.mp3"),
	"pickup_xp": preload("res://audio/sfx/sfx_pickup_xp_01.mp3"),
	"pickup_health": preload("res://audio/sfx/sfx_pickup_health_01.mp3"),
	"evolution": preload("res://audio/sfx/sfx_evolution_01.mp3"),
	"player_revive": preload("res://audio/sfx/sfx_player_revive_01.mp3"),
	"reward": preload("res://audio/sfx/sfx_reward_01.mp3"),
	"shrine": preload("res://audio/sfx/sfx_shrine_activate_01.mp3"),
	"boss": preload("res://audio/sfx/sfx_boss_spawn_01.mp3"),
	"weapon_blades": preload("res://audio/sfx/sfx_weapon_shadow_blades_01.mp3"),
	"weapon_orbit": preload("res://audio/sfx/sfx_weapon_soul_orbit_01.mp3"),
	"weapon_nova": preload("res://audio/sfx/sfx_weapon_chaos_nova_01.mp3"),
	"weapon_scythe": preload("res://audio/sfx/sfx_weapon_blood_scythe_01.mp3"),
	"weapon_grimoire": preload("res://audio/sfx/sfx_weapon_forbidden_grimoire_01.mp3"),
	"weapon_hammer": preload("res://audio/sfx/sfx_weapon_rune_hammer_01.mp3"),
	"weapon_storm": preload("res://audio/sfx/sfx_weapon_storm_relic_01.mp3"),
	"weapon_swarm": preload("res://audio/sfx/sfx_weapon_swarm_idol_01.mp3")
}
const CHAOS_BOLT_VARIANTS := [
	preload("res://audio/sfx/sfx_weapon_chaos_bolt_01.mp3"),
	preload("res://audio/sfx/sfx_weapon_chaos_bolt_02.mp3"),
	preload("res://audio/sfx/sfx_weapon_chaos_bolt_03.mp3")
]
const MUSIC_CROSSFADE_SECONDS := 1.5
const MUSIC_SILENCE_DB := -60.0
const MUSIC_HEADROOM_DB := -10.0
const SFX_HEADROOM_DB := -10.0
const SFX_BUS_TRIM_DB := -11.0
const MAX_SIMULTANEOUS_SFX := 10
const MAX_SIMULTANEOUS_PER_KEY := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if enabled:
		_configure_audio_buses()
		_ensure_music_players()


func set_levels(new_music_level: float, new_sfx_level: float) -> void:
	music_level = clampf(new_music_level, 0.0, 1.0)
	sfx_level = clampf(new_sfx_level, 0.0, 1.0)
	_set_bus_level(MUSIC_BUS_NAME, music_level)
	_set_bus_level(SFX_BUS_NAME, sfx_level)


func set_music_stage(stage_id: String) -> void:
	if not enabled:
		return
	if music_stage == "boss" and stage_id != "boss" and _active_boss_is_alive():
		return
	var was_boss := music_stage == "boss"
	music_stage = stage_id
	if stage_id == "boss":
		if was_boss:
			return
		ambient_rotation_active = false
		var key := "music_boss"
		if not cached_streams.has(key):
			cached_streams[key] = _make_music_stream("boss")
		_crossfade_to(cached_streams[key])
		return
	if ambient_rotation_active and not was_boss:
		return
	ambient_rotation_active = true
	_play_next_ambient()


func _active_boss_is_alive() -> bool:
	var world := get_parent()
	if world == null:
		return false
	var boss = world.get("active_boss")
	return is_instance_valid(boss) and not bool(boss.get("dead"))


func _process(_delta: float) -> void:
	if not enabled or not ambient_rotation_active or music_crossfade_active or music_players.size() < 2:
		return
	var current_player := music_players[active_music_player_index]
	if not current_player.playing:
		_play_next_ambient()
		return
	var stream_length := current_player.stream.get_length() if current_player.stream else 0.0
	if stream_length > MUSIC_CROSSFADE_SECONDS and current_player.get_playback_position() >= stream_length - MUSIC_CROSSFADE_SECONDS:
		_play_next_ambient()


func _play_next_ambient() -> void:
	ambient_track_index = (ambient_track_index + 1) % AMBIENT_TRACKS.size()
	_crossfade_to(AMBIENT_TRACKS[ambient_track_index])


func _ensure_music_players() -> void:
	if music_players.size() >= 2:
		return
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (index + 1)
		player.bus = MUSIC_BUS_NAME
		player.volume_db = MUSIC_SILENCE_DB
		add_child(player)
		music_players.append(player)


func _crossfade_to(stream: AudioStream) -> void:
	if stream == null:
		return
	_ensure_music_players()
	if is_instance_valid(music_fade_tween) and music_fade_tween.is_valid():
		music_fade_tween.kill()
	var outgoing := music_players[active_music_player_index]
	var incoming_index := 1 - active_music_player_index if outgoing.playing else active_music_player_index
	var incoming := music_players[incoming_index]
	if incoming != outgoing:
		incoming.stop()
	incoming.stream = stream
	incoming.volume_db = MUSIC_SILENCE_DB
	incoming.play()
	active_music_player_index = incoming_index
	music_crossfade_active = true
	music_fade_tween = create_tween().set_parallel(true)
	music_fade_tween.tween_property(incoming, "volume_db", MUSIC_HEADROOM_DB, MUSIC_CROSSFADE_SECONDS)
	if outgoing != incoming and outgoing.playing:
		music_fade_tween.tween_property(outgoing, "volume_db", MUSIC_SILENCE_DB, MUSIC_CROSSFADE_SECONDS)
	music_fade_tween.chain().tween_callback(_finish_music_crossfade.bind(outgoing))


func _finish_music_crossfade(outgoing: AudioStreamPlayer) -> void:
	var current_player := music_players[active_music_player_index]
	if is_instance_valid(outgoing) and outgoing != current_player:
		outgoing.stop()
	music_crossfade_active = false


func play_hit(critical := false) -> void:
	_play_sample("critical" if critical else "hit")


func play_player_hurt() -> void:
	_play_sample("hurt")


func play_boss_spawn() -> void:
	_play_sample("boss")


func play_evolution() -> void:
	_play_sample("evolution")


func play_player_revive() -> void:
	_play_sample("player_revive")


func play_reward() -> void:
	_play_sample("reward")


func play_shrine_activate() -> void:
	_play_sample("shrine")


func play_dash() -> void:
	_play_sample("dash")


func play_pickup(kind := "xp") -> void:
	_play_sample("pickup_health" if kind == "heal" else "pickup_xp")


func play_explosion() -> void:
	_play_sample("explosion")


func play_weapon_attack(weapon_id: String) -> void:
	match weapon_id:
		"chaos_bolt":
			_play_sample("weapon_bolt", CHAOS_BOLT_VARIANTS)
		"shadow_blades":
			_play_sample("weapon_blades")
		"soul_orbit":
			_play_sample("weapon_orbit")
		"chaos_nova":
			_play_sample("weapon_nova")
		"blood_scythe":
			_play_sample("weapon_scythe")
		"forbidden_grimoire":
			_play_sample("weapon_grimoire")
		"rune_hammer":
			_play_sample("weapon_hammer")
		"storm_relic":
			_play_sample("weapon_storm")
		"swarm_idol":
			_play_sample("weapon_swarm")


func _play_sample(key: String, variants: Array = []) -> void:
	if not enabled or sfx_level <= 0.001:
		return
	var now := Time.get_ticks_msec()
	var minimum_interval := _minimum_interval_for(key)
	if now - int(last_played_msec.get(key, -10000)) < minimum_interval:
		return
	if int(active_sfx_by_key.get(key, 0)) >= _voice_limit_for(key):
		_stop_oldest_sfx_voice(key)
	if active_sfx >= MAX_SIMULTANEOUS_SFX:
		return
	var stream: AudioStream = _sample_for(key, variants)
	if stream == null:
		return
	last_played_msec[key] = now
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS_NAME
	player.volume_db = SFX_HEADROOM_DB
	add_child(player)
	active_sfx += 1
	active_sfx_by_key[key] = int(active_sfx_by_key.get(key, 0)) + 1
	var key_players: Array = active_sfx_players.get(key, [])
	key_players.append(player)
	active_sfx_players[key] = key_players
	player.finished.connect(_on_sfx_finished.bind(player, key))
	player.play()


func _sample_for(key: String, variants: Array) -> AudioStream:
	if variants.is_empty():
		return SFX_STREAMS.get(key) as AudioStream
	var variant_index := randi_range(0, variants.size() - 1)
	var previous_index := int(last_sample_variant.get(key, -1))
	if variants.size() > 1 and variant_index == previous_index:
		variant_index = (variant_index + randi_range(1, variants.size() - 1)) % variants.size()
	last_sample_variant[key] = variant_index
	return variants[variant_index] as AudioStream


func _minimum_interval_for(key: String) -> int:
	if key in ["hit", "critical"]:
		return 48
	if key.begins_with("pickup_"):
		return 65
	if key.begins_with("weapon_"):
		return 85
	return 110


func _voice_limit_for(key: String) -> int:
	if key in ["hurt", "boss", "evolution", "player_revive", "reward", "shrine", "dash", "pickup_xp", "pickup_health", "explosion"]:
		return 1
	return MAX_SIMULTANEOUS_PER_KEY


func _on_sfx_finished(player: AudioStreamPlayer, key: String) -> void:
	_release_sfx_player(player, key)


func _stop_oldest_sfx_voice(key: String) -> void:
	var key_players: Array = active_sfx_players.get(key, [])
	if key_players.is_empty():
		return
	var oldest_player := key_players.front() as AudioStreamPlayer
	if is_instance_valid(oldest_player):
		oldest_player.stop()
	_release_sfx_player(oldest_player, key)


func _release_sfx_player(player: AudioStreamPlayer, key: String) -> void:
	var key_players: Array = active_sfx_players.get(key, [])
	if not key_players.has(player):
		return
	key_players.erase(player)
	if key_players.is_empty():
		active_sfx_players.erase(key)
	else:
		active_sfx_players[key] = key_players
	active_sfx = maxi(0, active_sfx - 1)
	var remaining := maxi(0, int(active_sfx_by_key.get(key, 0)) - 1)
	if remaining == 0:
		active_sfx_by_key.erase(key)
	else:
		active_sfx_by_key[key] = remaining
	if is_instance_valid(player) and not player.is_queued_for_deletion():
		player.queue_free()


func _configure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS_NAME)
	var sfx_bus := _ensure_audio_bus(SFX_BUS_NAME)
	_ensure_sfx_dynamics(sfx_bus)
	_ensure_limiter(AudioServer.get_bus_index(&"Master"), -0.8)
	_set_bus_level(MUSIC_BUS_NAME, music_level)
	_set_bus_level(SFX_BUS_NAME, sfx_level)


func _ensure_audio_bus(bus_name: StringName) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, &"Master")
	return bus_index


func _ensure_sfx_dynamics(bus_index: int) -> void:
	var has_compressor := false
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectCompressor:
			has_compressor = true
			break
	if not has_compressor:
		var compressor := AudioEffectCompressor.new()
		compressor.threshold = -12.0
		compressor.ratio = 5.0
		compressor.gain = -1.5
		compressor.attack_us = 20.0
		compressor.release_ms = 140.0
		AudioServer.add_bus_effect(bus_index, compressor)
	_ensure_limiter(bus_index, -1.2)


func _ensure_limiter(bus_index: int, ceiling_db: float) -> void:
	if bus_index < 0:
		return
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = ceiling_db
	limiter.pre_gain_db = 0.0
	limiter.release = 0.10
	AudioServer.add_bus_effect(bus_index, limiter)


func _set_bus_level(bus_name: StringName, level: float) -> void:
	if not enabled:
		return
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		var trim_db := SFX_BUS_TRIM_DB if bus_name == SFX_BUS_NAME else 0.0
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(0.0001, level)) + trim_db)


func _make_music_stream(stage_id: String) -> AudioStreamWAV:
	var sample_rate := 11025
	var duration := 8.0
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var root_frequency := 55.0
	var intensity := 0.34
	match stage_id:
		"hard":
			root_frequency = 65.5
			intensity = 0.40
		"chaos":
			root_frequency = 73.5
			intensity = 0.46
		"inferno":
			root_frequency = 82.5
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
		var loop_fade := minf(1.0, minf(time, duration - time) / 0.008)
		var sample_value := clampf(value * loop_fade * 0.78, -0.92, 0.92)
		var pcm_value := clampi(int(round(sample_value * 32767.0)), -32768, 32767)
		data[index * 2] = pcm_value & 0xff
		data[index * 2 + 1] = (pcm_value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = data
	return stream
