extends SceneTree

const SaveStoreScript = preload("res://scripts/save_store.gd")
const WORLD_SCENE = preload("res://scenes/world.tscn")
const SAVE_PATH := "user://realm_of_chaos.cfg"
const TEST_SAVE_PATH := "user://world_persistence_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WORLD PERSISTENCE: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.4f, obtido %.4f)" % [message, expected, actual])


func _save_bytes() -> PackedByteArray:
	if not FileAccess.file_exists(SAVE_PATH):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(SAVE_PATH)


func _load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	_check(config.load(path) == OK, "nao foi possivel reler o save de teste")
	return config


func _seed_test_config() -> void:
	_cleanup_test_save()
	var config := ConfigFile.new()
	config.set_value("record", "best_time", 900.0)
	config.set_value("record", "best_kills", 400)
	config.set_value("record", "victories", 2)
	config.set_value("meta", "essence", 40)
	config.set_value("progress", "active_cycle", 4)
	config.set_value("progress", "highest_cycle", 7)
	config.set_value("campaign", "schema_version", 1)
	config.set_value("campaign", "selected_map_id", "profaned_forest")
	config.set_value("campaign", "unlocked_maps", PackedStringArray(["profaned_forest"]))
	config.set_value("campaign", "completed_maps", PackedStringArray())
	config.set_value("achievements", "first_boss", true)
	_check(config.save(TEST_SAVE_PATH) == OK, "nao foi possivel criar o save exclusivo de teste")


func _remove_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_test_save() -> void:
	for path in [
		TEST_SAVE_PATH,
		TEST_SAVE_PATH + ".bak",
		TEST_SAVE_PATH + ".tmp",
		TEST_SAVE_PATH + ".swap",
		TEST_SAVE_PATH + ".bak.tmp",
		TEST_SAVE_PATH + ".bak.swap",
		TEST_SAVE_PATH + ".corrupt",
		TEST_SAVE_PATH + ".bak.corrupt",
	]:
		_remove_test_file(path)
	for index in range(1, 8):
		_remove_test_file("%s.corrupt.%d" % [TEST_SAVE_PATH, index])
		_remove_test_file("%s.bak.corrupt.%d" % [TEST_SAVE_PATH, index])
	var temporary_absolute := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".tmp")
	if DirAccess.dir_exists_absolute(temporary_absolute):
		DirAccess.remove_absolute(temporary_absolute)


func _expected_settings(config: ConfigFile) -> Dictionary:
	var settings := GameDefs.default_settings()
	for setting_id in settings:
		settings[setting_id] = config.get_value("settings", setting_id, settings[setting_id])
	return settings


func _expected_player_state(config: ConfigFile) -> Dictionary:
	var state := {
		"damage": 1.0 + int(config.get_value("meta", "power", 0)) * 0.05,
		"max_hp": 125.0 + int(config.get_value("meta", "vitality", 0)) * 10.0,
		"speed": 235.0 * (1.0 + int(config.get_value("meta", "speed", 0)) * 0.03),
		"crit": 0.05 + int(config.get_value("meta", "fortune", 0)) * 0.015,
		"armor": 0.0,
		"cooldown": 1.0,
		"life_steal": 0.0
	}
	match str(config.get_value("profile", "character", "eclipse_hunter")):
		"glacial_oracle":
			state.armor += 3.0
			state.cooldown *= 0.90
		"crimson_knight":
			state.max_hp += 35.0
			state.life_steal += 0.004
		"void_automaton":
			state.damage *= 1.18
			state.speed *= 1.08
			state.max_hp -= 15.0
		_:
			state.damage *= 1.08
			state.crit += 0.05
	return state


func _expected_achievement_titles(config: ConfigFile) -> Array[String]:
	var titles: Array[String] = []
	for definition in GameDefs.achievements():
		if not bool(config.get_value("achievements", str(definition.id), false)):
			titles.append(str(definition.title))
	return titles


func _own_six_evolved_weapons(player) -> void:
	for index in range(player.MAX_WEAPONS):
		var weapon_id: String = player.WEAPON_IDS[index]
		player.weapon_levels[weapon_id] = 1
		player.evolved_weapons[weapon_id] = true


func _run() -> void:
	var bytes_before := _save_bytes()
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)

	for method_name in [&"_load_progression", &"_evaluate_achievements", &"_save_record"]:
		_check(world.has_method(method_name), "API publica ausente: %s" % method_name)

	var campaign_manager = root.get_node("CampaignManager")
	var expected_map: Dictionary = campaign_manager.selected_map()
	var stored_character := str(config.get_value("profile", "character", "eclipse_hunter"))
	var expected_character_definition: Dictionary = GameDefs.character_data(stored_character)
	var expected_character := str(expected_character_definition.id)
	var expected_starting_weapon := str(expected_character_definition.starting_weapon)
	var expected_settings := _expected_settings(config)
	var expected_player := _expected_player_state(config)
	_check(world.campaign_map_id == str(expected_map.id), "mapa selecionado da campanha não foi carregado")
	_check(world.run_cycle == int(expected_map.seed_offset), "fachada legada de ciclo não acompanha a seed do mapa")
	_check(str(world.biome.id) == str(expected_map.biome_id), "bioma não corresponde ao map_id carregado")
	_check(world.player.character_id == expected_character and world.player.character_applied, "personagem do perfil nao foi aplicado")
	_check(
		world.player.equipped_weapon_id == expected_starting_weapon
		and int(world.player.weapon_levels[expected_starting_weapon]) == 1,
		"arma inicial vinculada ao personagem nao foi carregada"
	)
	_check_close(world.player.damage_multiplier, float(expected_player.damage), "meta de poder ou bonus do personagem incorreto")
	_check_close(world.player.max_hp, float(expected_player.max_hp), "meta de vitalidade ou bonus do personagem incorreto")
	_check_close(world.player.hp, float(expected_player.max_hp), "vida nao acompanhou a vitalidade carregada")
	_check_close(world.player.move_speed, float(expected_player.speed), "meta de velocidade incorreta")
	_check_close(world.player.crit_chance, float(expected_player.crit), "meta de fortuna incorreta")
	_check_close(world.player.armor, float(expected_player.armor), "armadura do personagem incorreta")
	_check_close(world.player.cooldown_multiplier, float(expected_player.cooldown), "intervalo do personagem incorreto")
	_check_close(world.player.life_steal, float(expected_player.life_steal), "roubo de vida do personagem incorreto")
	_check(world.accessibility_settings == expected_settings, "configuracoes de acessibilidade nao foram carregadas integralmente")
	_check_close(world.audio.music_level, float(expected_settings.music), "volume de musica nao foi aplicado")
	_check_close(world.audio.sfx_level, float(expected_settings.sfx), "volume de efeitos nao foi aplicado")
	_check_close(world.hud.flash_intensity, float(expected_settings.flash), "intensidade de flashes nao foi aplicada")

	world.bosses_defeated = 5
	world.enemies_killed = 500
	world.damage_taken = 100.0
	world.shrines_activated = 4
	_own_six_evolved_weapons(world.player)
	var expected_titles := _expected_achievement_titles(config)
	var first_result: Array[String] = world._evaluate_achievements(true)
	var second_result: Array[String] = world._evaluate_achievements(true)
	_check(first_result == expected_titles, "ordem ou conjunto de conquistas avaliadas mudou")
	_check(second_result == expected_titles, "suppress_save alterou o resultado entre avaliacoes")

	world.time_survived = 5000.0
	world.enemies_killed = 5000
	world.essence_earned = 5000
	world._save_record(true)
	_check(_save_bytes() == bytes_before, "suppress_save alterou o arquivo de progresso")

	_cleanup_test_save()
	world.persistence.save_path = TEST_SAVE_PATH
	world.persistence.write_failed = false
	world.suppress_save = false
	world.bosses_defeated = 0
	world.enemies_killed = 0
	world.damage_taken = 0.0
	world.shrines_activated = 0
	world.player.evolved_weapons.clear()
	_check(world._evaluate_achievements(false).is_empty(), "primeira partida sem conquista gerou desbloqueio indevido")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "avaliacao vazia criou save sem dados")
	_check(not world.persistence.write_failed, "avaliacao vazia gerou aviso falso de escrita")

	_seed_test_config()
	world.bosses_defeated = 5
	world.enemies_killed = 500
	world.damage_taken = 100.0
	world.shrines_activated = 4
	_own_six_evolved_weapons(world.player)
	var expected_persisted_titles := _expected_achievement_titles(_load_config(TEST_SAVE_PATH))
	var persisted_titles: Array[String] = world._evaluate_achievements(true)
	_check(persisted_titles == expected_persisted_titles, "conquistas nao foram retornadas na ordem esperada")
	var test_config := _load_config(TEST_SAVE_PATH)
	_check(test_config.has_section("_save_integrity"), "WorldPersistence nao aplicou checksum ao save legado")
	_check(FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "WorldPersistence nao criou backup")
	for definition in GameDefs.achievements():
		_check(bool(test_config.get_value("achievements", str(definition.id), false)), "conquista nao foi persistida: %s" % definition.id)
	_check(world._evaluate_achievements(true).is_empty(), "conquista persistida foi retornada novamente")

	world.campaign_map_id = "profaned_forest"
	world.map_seed_offset = 0
	world.map_boss_power = 1.0
	world.run_cycle = 0
	world.time_survived = 1200.0
	world.enemies_killed = 350
	world.essence_earned = 15
	world._save_record(false)
	test_config = _load_config(TEST_SAVE_PATH)
	_check_close(float(test_config.get_value("record", "best_time", 0.0)), 1200.0, "melhor tempo de derrota incorreto")
	_check(int(test_config.get_value("record", "best_kills", 0)) == 400, "recorde menor substituiu melhor numero de abates")
	_check(int(test_config.get_value("record", "victories", 0)) == 2, "derrota incrementou vitorias")
	_check(int(test_config.get_value("meta", "essence", 0)) == 55, "essencia da derrota nao foi acumulada")
	_check(int(test_config.get_value("progress", "active_cycle", 0)) == 4, "derrota alterou o ciclo ativo")
	_check(int(test_config.get_value("progress", "highest_cycle", 0)) == 7, "derrota alterou o maior ciclo")

	world.time_survived = 800.0
	world.enemies_killed = 600
	world.essence_earned = 10
	world._save_record(true)
	test_config = _load_config(TEST_SAVE_PATH)
	_check_close(float(test_config.get_value("record", "best_time", 0.0)), 1200.0, "tempo menor substituiu o melhor tempo")
	_check(int(test_config.get_value("record", "best_kills", 0)) == 600, "melhor numero de abates nao foi atualizado")
	_check(int(test_config.get_value("record", "victories", 0)) == 3, "vitoria nao foi acumulada")
	_check(int(test_config.get_value("meta", "essence", 0)) == 65, "essencia da vitoria nao foi acumulada")
	_check(int(test_config.get_value("progress", "active_cycle", 0)) == 4, "vitoria alterou o ciclo legado")
	_check(int(test_config.get_value("progress", "highest_cycle", 0)) == 7, "ciclo menor substituiu o maior ciclo")
	_check(
		"profaned_forest" in test_config.get_value("campaign", "completed_maps", PackedStringArray()),
		"vitoria não marcou o mapa da campanha como concluído"
	)
	_check(
		"frozen_ruins" in test_config.get_value("campaign", "unlocked_maps", PackedStringArray()),
		"vitoria não desbloqueou o próximo mapa"
	)

	test_config.set_value("achievements", "cartographer", false)
	_check(SaveStoreScript.save_config(test_config, TEST_SAVE_PATH) == OK, "nao foi possivel preparar suppress_save no arquivo de teste")
	world.suppress_save = true
	world.time_survived = 5000.0
	world.enemies_killed = 5000
	world.essence_earned = 5000
	var suppressed_titles: Array[String] = world._evaluate_achievements(true)
	world._save_record(true)
	test_config = _load_config(TEST_SAVE_PATH)
	_check(str(GameDefs.achievements()[-1].title) in suppressed_titles, "suppress_save alterou a avaliacao em memoria")
	_check(not bool(test_config.get_value("achievements", "cartographer", false)), "suppress_save persistiu conquista")
	_check_close(float(test_config.get_value("record", "best_time", 0.0)), 1200.0, "suppress_save alterou recorde de tempo")
	_check(int(test_config.get_value("record", "best_kills", 0)) == 600, "suppress_save alterou recorde de abates")
	_check(int(test_config.get_value("record", "victories", 0)) == 3, "suppress_save alterou vitorias")
	_check(int(test_config.get_value("meta", "essence", 0)) == 65, "suppress_save alterou essencia")
	_check(int(test_config.get_value("progress", "active_cycle", 0)) == 4, "suppress_save alterou progresso legado")
	_check(_save_bytes() == bytes_before, "teste isolado alterou o save real")

	world.suppress_save = false
	world.persistence.write_failed = false
	var protected_main := FileAccess.get_file_as_bytes(TEST_SAVE_PATH)
	var protected_backup := FileAccess.get_file_as_bytes(TEST_SAVE_PATH + ".bak")
	var blocked_temporary := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".tmp")
	_check(DirAccess.make_dir_absolute(blocked_temporary) == OK, "nao foi possivel preparar falha de escrita do World")
	world._save_record(false)
	_check(world.persistence.write_failed, "WorldPersistence nao registrou a falha de escrita")
	_check(FileAccess.get_file_as_bytes(TEST_SAVE_PATH) == protected_main, "falha do World alterou o principal")
	_check(FileAccess.get_file_as_bytes(TEST_SAVE_PATH + ".bak") == protected_backup, "falha do World alterou o backup")
	DirAccess.remove_absolute(blocked_temporary)
	_cleanup_test_save()

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD PERSISTENCE OK: carga, avaliacao de conquistas, APIs e suppress_save validados sem alterar o save")
		quit(0)
	else:
		quit(1)
