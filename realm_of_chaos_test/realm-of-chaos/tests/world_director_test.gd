extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")
const WORLD_SCENE = preload("res://scenes/world.tscn")
const EXPECTED_PICK_FINGERPRINT := "0.0:prowler,prowler,prowler,prowler|17.9:prowler,prowler,prowler,prowler|18.0:bat,bat,bat,bat|51.9:bat,bat,prowler,prowler|52.0:prowler,bat,mage,prowler|114.9:archer,prowler,prowler,mage|115.0:archer,archer,prowler,bat|204.9:brute,mage,bat,prowler|205.0:bat,mage,prowler,bat|300.0:bat,archer,mage,swarm|600.0:mage,swarm,swarm,swarm|900.0:brute,swarm,swarm,mage"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WORLD DIRECTOR: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.4f, obtido %.4f)" % [message, expected, actual])


func _pick_fingerprint(world) -> String:
	seed(71623)
	var picks: Array[String] = []
	for elapsed in [0.0, 17.9, 18.0, 51.9, 52.0, 114.9, 115.0, 204.9, 205.0, 300.0, 600.0, 900.0]:
		world.time_survived = elapsed
		var sample: Array[String] = []
		for _index in range(4):
			sample.append(world._pick_enemy_type())
		picks.append("%.1f:%s" % [elapsed, ",".join(sample)])
	return "|".join(picks)


func _queue_signature(queue: Array[Dictionary]) -> String:
	var signature: Array[String] = []
	for job in queue:
		if str(job.get("type", "")) == "boss":
			signature.append("boss:%s:%d" % [str(job.entry.kind), int(job.index)])
		else:
			signature.append("elite:%s:%s" % [str(job.kind), str(bool(job.get("elite", false)))])
	return "|".join(signature)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)

	for method_name in [
		&"_spawn_timer_update", &"_pick_enemy_type", &"_update_boss_schedule",
		&"_process_director_spawn_queue", &"_spawn_scheduled_boss", &"_update_stage",
		&"_next_boss_status", &"_update_world_events", &"_trigger_world_event",
		&"_end_world_event"
	]:
		_check(world.has_method(method_name), "API publica ausente: %s" % method_name)

	var fingerprint := _pick_fingerprint(world)
	print("DIRECTOR PICK FINGERPRINT: " + fingerprint)
	if not EXPECTED_PICK_FINGERPRINT.is_empty():
		_check(fingerprint == EXPECTED_PICK_FINGERPRINT, "sequencia deterministica de selecao de inimigos mudou")

	world.time_survived = 300.0
	world.boss_index = 0
	world.last_stage = GameDefs.stage_name(0.0)
	world.director_spawn_queue.clear()
	var enemies_before_staged: int = world.enemies.get_child_count()
	world.set_process(true)
	world._update_boss_schedule()
	world._update_stage()
	world.set_process(false)
	_check(world.boss_index == 1, "agenda nao avancou o indice do primeiro chefe")
	_check(world.boss_spawn_log.is_empty(), "chefe foi criado no mesmo frame em vez de entrar na fila")
	_check(world.director_spawn_queue.size() == 5, "boss e quatro elites nao foram escalonados")
	_check(
		_queue_signature(world.director_spawn_queue) == "boss:ossuary_colossus:0|elite:guardian:true|elite:assassin:true|elite:bomber:true|elite:guardian:true",
		"ordem da fila combinada de boss e elites mudou"
	)

	world._process_director_spawn_queue()
	_check(world.director_spawn_queue.size() == 4, "primeiro frame consumiu mais de um trabalho")
	_check(world.enemies.get_child_count() == enemies_before_staged + 1, "primeiro frame nao criou somente o chefe")
	_check(world.boss_spawn_log == ["ossuary_colossus"], "chefe escalonado incorreto")
	for expected_remaining in [3, 2, 1, 0]:
		var count_before: int = world.enemies.get_child_count()
		world._process_director_spawn_queue()
		_check(world.director_spawn_queue.size() == expected_remaining, "fila nao consumiu exatamente um elite por frame")
		_check(world.enemies.get_child_count() == count_before + 1, "frame de escolta criou quantidade incorreta de elites")

	world.time_survived = 600.0
	world.boss_index = 1
	var boss_count_before: int = world.boss_spawn_log.size()
	world._update_boss_schedule()
	_check(world.director_spawn_queue.is_empty(), "modo sem processamento enfileirou chefe em vez de criar imediatamente")
	_check(world.boss_index == 2 and world.boss_spawn_log.size() == boss_count_before + 1, "fallback imediato nao criou o segundo chefe")
	_check(world.boss_spawn_log[-1] == "glacial_archon", "segundo chefe agendado incorreto")

	world.director_spawn_queue.clear()
	world.last_stage = GameDefs.stage_name(300.0)
	world.time_survived = 600.0
	world.set_process(true)
	world._update_stage()
	world.set_process(false)
	_check(world.director_spawn_queue.size() == 8, "fase Caos nao escalonou oito elites")
	_check(_queue_signature(world.director_spawn_queue).begins_with("elite:guardian:true|elite:assassin:true|elite:bomber:true"), "padrao das elites da fase mudou")
	world.director_spawn_queue.clear()
	world.last_stage = GameDefs.stage_name(600.0)
	world.time_survived = 900.0
	world.set_process(true)
	world._update_stage()
	world.set_process(false)
	_check(world.director_spawn_queue.size() == 12, "fase Inferno nao escalonou doze elites")
	var inferno_signature := _queue_signature(world.director_spawn_queue)
	world._update_stage()
	_check(_queue_signature(world.director_spawn_queue) == inferno_signature, "fase inalterada enfileirou elites novamente")
	world.set_process(false)
	world.director_spawn_queue.clear()

	world.time_survived = 600.0
	world.event_spawn_multiplier = 1.65
	world.spawn_timer = 0.0
	var difficulty := GameDefs.difficulty_data(world.time_survived)
	var spawn_count_before: int = world.enemies.get_child_count()
	var expected_batch: int = mini(
		ceili(float(difficulty.batch) * world.event_spawn_multiplier),
		int(difficulty.cap) - spawn_count_before
	)
	world._spawn_timer_update(0.0)
	_check(world.enemies.get_child_count() == spawn_count_before + expected_batch, "temporizador criou lote diferente do esperado")
	_check_close(world.spawn_timer, float(difficulty.interval), "temporizador nao recarregou o intervalo da fase")
	var count_while_waiting: int = world.enemies.get_child_count()
	world._spawn_timer_update(float(difficulty.interval) * 0.5)
	_check(world.enemies.get_child_count() == count_while_waiting, "temporizador criou inimigos antes do intervalo")

	world._end_world_event()
	var base_pickup_radius: float = world.player.pickup_radius
	world.time_survived = 450.0
	world.event_index = 1
	world._update_world_events(0.0)
	_check(world.current_event == "soul_storm" and world.event_index == 2, "agenda nao iniciou Tempestade de Almas")
	_check_close(world.player.pickup_radius, base_pickup_radius * 1.8, "Tempestade de Almas nao ampliou o ima")
	_check(world.event_magnet_applied and is_equal_approx(world.event_remaining, 22.0), "estado temporario da Tempestade de Almas incorreto")
	world._update_world_events(22.1)
	_check(world.current_event.is_empty() and not world.event_magnet_applied, "evento expirado nao foi encerrado")
	_check_close(world.player.pickup_radius, base_pickup_radius, "ima nao voltou ao valor anterior")

	world._trigger_world_event("eclipse")
	_check_close(world.enemy_speed_multiplier, 1.28, "Eclipse nao alterou velocidade inimiga")
	world._end_world_event()
	_check_close(world.enemy_speed_multiplier, 1.0, "fim do Eclipse nao restaurou velocidade inimiga")

	var rain_target = world.spawn_enemy("prowler", false, 1.0)
	rain_target.global_position = world.player.global_position + Vector2(80.0, 0.0)
	world._rebuild_spatial_grid()
	var rain_hp_before: float = rain_target.hp
	world._trigger_world_event("void_rain")
	_check_close(rain_target.hp, rain_hp_before * 0.92, "Chuva do Vazio nao aplicou 8% de dano proximo")
	world._end_world_event()

	world.event_index = 0
	world.time_survived = 1350.0
	world._end_world_event()
	var catchup_pickup_radius: float = world.player.pickup_radius
	var catchup_enemy_count: int = world.enemies.get_child_count()
	world._update_world_events(0.0)
	_check(world.event_index == 5 and world.current_event == "void_rain", "catch-up nao percorreu os cinco eventos na ordem")
	_check(world.enemies.get_child_count() == catchup_enemy_count + 20, "duas Luas de Sangue no catch-up nao criaram vinte inimigos")
	_check_close(world.player.pickup_radius, catchup_pickup_radius, "catch-up deixou multiplicador intermediario do ima")
	world._end_world_event()

	world.event_spawn_multiplier = 1.0
	world.time_survived = 0.0
	var cap := int(GameDefs.difficulty_data(world.time_survived).cap)
	while world.enemies.get_child_count() < cap:
		world.enemies.add_child(Node2D.new())
	world.spawn_timer = 0.0
	var count_at_cap: int = world.enemies.get_child_count()
	world._spawn_timer_update(0.0)
	_check(world.enemies.get_child_count() == count_at_cap, "temporizador ultrapassou o teto da fase")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD DIRECTOR OK: hordas, fases, boss/elites escalonados e eventos validados")
		quit(0)
	else:
		quit(1)
