extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const ENEMY_TYPES := ["prowler", "bat", "brute", "assassin", "guardian"]
const ENEMY_COUNT := 90
const WARMUP_FRAMES := 30
const MEASURED_FRAMES := 180
const SWING_INTERVAL_FRAMES := 40
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CRIMSON REAPER STRESS: " + message)


func _prepare_build(player) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.blood_scythe = 6
	player.evolved_weapons.blood_scythe = true
	player.crit_chance = -1.0
	player.life_steal = 0.0
	player.max_hp = 1_000_000.0
	player.hp = player.max_hp
	player.last_direction = Vector2.RIGHT


func _spawn_horde(world) -> void:
	for index in range(ENEMY_COUNT):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 13 == 0, 3.0)
		_check(is_instance_valid(enemy), "teto global impediu o inimigo %d de nascer" % index)
		if not is_instance_valid(enemy):
			continue
		var ring := 175.0 + float(index % 6) * 54.0
		enemy.global_position = Vector2.RIGHT.rotated(TAU * float(index) / float(ENEMY_COUNT)) * ring
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		# Mantém a carga gráfica de 90 alvos, mas isola o custo da Ceifadora de
		# ataques/efeitos autônomos dos inimigos. A carga combinada é coberta pelo
		# benchmark visual extremo separado.
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _measure(world) -> Dictionary:
	var frame_times: Array[float] = []
	var peak_projectiles := 0
	var peak_effects := 0
	var total_started := Time.get_ticks_usec()
	for frame_index in range(MEASURED_FRAMES):
		if frame_index % SWING_INTERVAL_FRAMES == 0:
			world.player._swing_blood_scythe(6)
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
		peak_projectiles = maxi(peak_projectiles, world.projectiles.get_child_count())
		peak_effects = maxi(peak_effects, world.effects.get_child_count())
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(frame_times.size() * 0.95) - 1)
	return {
		"average_ms": total_ms / float(MEASURED_FRAMES),
		"p95_ms": frame_times[p95_index],
		"peak_projectiles": peak_projectiles,
		"peak_effects": peak_effects,
	}


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	world.campaign_map_override_id = "profaned_forest"
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.spawn_timer = 9999.0
	world.time_survived = world.run_duration
	world.player.set_process(false)
	world.player.set_physics_process(false)
	_prepare_build(world.player)
	_spawn_horde(world)
	_check(world.enemies.get_child_count() == ENEMY_COUNT, "cenário não manteve 90 inimigos")
	for _frame in range(WARMUP_FRAMES):
		await process_frame

	var metrics := await _measure(world)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	_check(
		average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS,
		"regressão: média %.2f ms, p95 %.2f ms (limites %.1f/%.1f ms)"
		% [average_ms, p95_ms, MAX_AVERAGE_MS, MAX_P95_MS]
	)
	# Em benchmark sem VSync, tempo de jogo avança menos que o relógio real entre
	# disparos; por isso vários crescentes podem coexistir sem indicar vazamento.
	_check(int(metrics.peak_projectiles) <= 5, "crescentes ultrapassaram o total de ataques executados")
	_check(int(metrics.peak_effects) <= world.MAX_EFFECTS, "feedback da Ceifadora ultrapassou o teto visual")
	print(
		"CRIMSON REAPER STRESS: 90 inimigos, cortes repetidos; média %.2f ms, p95 %.2f ms, picos %d projéteis/%d efeitos"
		% [average_ms, p95_ms, int(metrics.peak_projectiles), int(metrics.peak_effects)]
	)

	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
