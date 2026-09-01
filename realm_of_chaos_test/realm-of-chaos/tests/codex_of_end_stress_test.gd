extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const ENEMY_TYPES := ["prowler", "bat", "brute", "assassin", "guardian"]
const ENEMY_COUNT := 90
const WARMUP_FRAMES := 20
const MEASURED_FRAMES := 180
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CODEX OF THE END STRESS: " + message)


func _prepare_build(player) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.forbidden_grimoire = 6
	player.evolved_weapons.forbidden_grimoire = true
	player.crit_chance = -1.0
	player.last_direction = Vector2.RIGHT


func _spawn_horde(world) -> void:
	var ritual_center := Vector2(220.0, 0.0)
	for index in range(ENEMY_COUNT):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 13 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var ring: float = [65.0, 125.0, 190.0, 260.0, 345.0][index % 5]
		enemy.global_position = ritual_center + Vector2.RIGHT.rotated(TAU * float(index) / float(ENEMY_COUNT)) * ring
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _measure(ritual: Node) -> Dictionary:
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	for frame_index in range(MEASURED_FRAMES):
		if frame_index == 0:
			ritual._process(0.12)
		elif frame_index == 45:
			ritual._process(0.14)
		elif frame_index == 100:
			ritual._process(0.28)
		elif frame_index == 150:
			ritual._process(0.32)
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(frame_times.size() * 0.95) - 1)
	return {
		"average_ms": total_ms / float(MEASURED_FRAMES),
		"p95_ms": frame_times[p95_index],
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
	world.player.global_position = Vector2.ZERO
	_prepare_build(world.player)
	_spawn_horde(world)
	_check(world.enemies.get_child_count() == ENEMY_COUNT, "cenário não manteve 90 inimigos")
	for _frame in range(WARMUP_FRAMES):
		await process_frame

	world.player._cast_forbidden_grimoire(6)
	var ritual = world.effects.get_node_or_null("CodexRitual")
	_check(is_instance_valid(ritual), "ritual não foi criado para o benchmark")
	if is_instance_valid(ritual):
		ritual.set_process(false)
	var metrics := await _measure(ritual)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	_check(
		average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS,
		"regressão: média %.2f ms, p95 %.2f ms (limites %.1f/%.1f ms)"
		% [average_ms, p95_ms, MAX_AVERAGE_MS, MAX_P95_MS]
	)
	_check(world.effects.get_child_count() <= world.MAX_EFFECTS, "ritual ultrapassou o teto de efeitos")
	_check(int(ritual.damage_stage_count) == 3, "benchmark não percorreu os três estágios")
	print(
		"CODEX OF THE END STRESS: 90 inimigos e ritual completo; média %.2f ms, p95 %.2f ms, %d efeitos no fim"
		% [average_ms, p95_ms, world.effects.get_child_count()]
	)

	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
