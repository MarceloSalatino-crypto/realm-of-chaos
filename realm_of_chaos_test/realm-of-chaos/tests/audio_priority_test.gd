extends SceneTree

const AudioDirectorTestDouble = preload("res://tests/audio_director_test_double.gd")

const ESSENTIAL_KEYS := ["hurt", "player_revive", "evolution", "boss", "reward", "shrine"]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("AUDIO PRIORITY: " + message)


func _active_players_for(audio: Node, key: String) -> Array:
	return audio.active_sfx_players.get(key, [])


func _count_active_essential_voices(audio: Node) -> int:
	var count := 0
	for key in ESSENTIAL_KEYS:
		count += int(audio.active_sfx_by_key.get(key, 0))
	return count


func _stop_all_audio_players(audio: Node) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			players.append(child)
	return players


func _clear_audio_tracking(audio: Node) -> void:
	audio.active_sfx = 0
	audio.active_sfx_by_key.clear()
	audio.active_sfx_players.clear()
	audio.active_sfx_voice_order.clear()


func _fill_with_common_sounds(audio: Node) -> void:
	audio.play_hit(false)
	audio.play_hit(true)
	audio.play_dash()
	audio.play_explosion()
	audio.play_pickup("xp")
	audio.play_pickup("heal")
	audio.play_weapon_attack("chaos_bolt")
	audio.play_weapon_attack("shadow_blades")
	audio.play_weapon_attack("soul_orbit")
	audio.play_weapon_attack("chaos_nova")


func _run() -> void:
	var audio = AudioDirectorTestDouble.new()
	root.add_child(audio)
	audio.enabled = true
	audio.sfx_level = 1.0
	audio._configure_audio_buses()

	var sfx_bus := AudioServer.get_bus_index(audio.SFX_BUS_NAME)
	var bus_effect_count := AudioServer.get_bus_effect_count(sfx_bus)
	_check(audio.MAX_SIMULTANEOUS_SFX == 10, "o teto global deixou de ser 10 vozes")

	_fill_with_common_sounds(audio)
	_check(audio.active_sfx == 10, "dez sons comuns não preencheram o pool")
	_check(audio.active_sfx_voice_order.size() == 10, "ordem global de vozes está incompleta")
	var oldest_common: AudioStreamPlayer = audio.active_sfx_voice_order.front()
	var oldest_common_key := str(oldest_common.get_meta(&"sfx_key", ""))

	audio.play_weapon_attack("blood_scythe")
	_check(audio.active_sfx == 10, "som comum excedeu ou reduziu o teto cheio")
	_check(_active_players_for(audio, "weapon_scythe").is_empty(), "11º som comum não foi descartado")

	audio.play_player_hurt()
	var hurt_players := _active_players_for(audio, "hurt")
	_check(audio.active_sfx == 10, "evento essencial alterou o teto global")
	_check(hurt_players.size() == 1, "dano no jogador não ganhou uma voz")
	_check(
		hurt_players.size() == 1 and (hurt_players.front() as AudioStreamPlayer).playing,
		"dano no jogador não iniciou reprodução no bus SFX"
	)
	_check(
		not audio.active_sfx_voice_order.has(oldest_common),
		"evento essencial não removeu a voz comum mais antiga (%s)" % oldest_common_key
	)
	_check(oldest_common.is_queued_for_deletion(), "voz comum preemptada não foi liberada")

	audio.last_played_msec.erase("hurt")
	audio.play_player_revive()
	audio.play_evolution()
	audio.play_boss_spawn()
	audio.play_reward()
	audio.play_shrine_activate()
	for key in ESSENTIAL_KEYS:
		_check(int(audio.active_sfx_by_key.get(key, 0)) == 1, "evento essencial ausente: %s" % key)
	_check(_count_active_essential_voices(audio) == ESSENTIAL_KEYS.size(), "nem todos os essenciais permaneceram ativos")
	_check(audio.active_sfx == 10, "priorização ultrapassou o teto de 10 vozes")

	var previous_hurt := _active_players_for(audio, "hurt").front() as AudioStreamPlayer
	audio.last_played_msec.erase("hurt")
	audio.play_player_hurt()
	var replacement_hurt := _active_players_for(audio, "hurt").front() as AudioStreamPlayer
	_check(previous_hurt != replacement_hurt, "novo dano não substituiu a voz anterior da mesma prioridade")
	_check(previous_hurt.is_queued_for_deletion(), "voz essencial antiga não foi liberada ao ser substituída")
	_check(audio.active_sfx == 10, "substituição do mesmo essencial alterou o teto")

	audio.play_weapon_attack("rune_hammer")
	_check(_active_players_for(audio, "weapon_hammer").is_empty(), "som comum expulsou uma voz com pool cheio")
	_check(
		AudioServer.get_bus_effect_count(sfx_bus) == bus_effect_count,
		"priorização alterou a cadeia de compressor/limiter"
	)

	hurt_players.clear()
	oldest_common = null
	previous_hurt = null
	replacement_hurt = null
	var players_to_free := _stop_all_audio_players(audio)
	OS.delay_msec(100)
	for player in players_to_free:
		player.free()
	players_to_free.clear()
	_clear_audio_tracking(audio)
	OS.delay_msec(100)
	audio.queue_free()
	await process_frame
	if failures.is_empty():
		print("AUDIO PRIORITY OK: 10+ comuns saturados; seis eventos essenciais preemptaram somente vozes comuns")
		quit(0)
	else:
		quit(1)
