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
	push_error("CATACLYSM HAMMER STRESS: " + message)


func _prepare_build(player) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.rune_hammer = 6
	player.evolved_weapons.rune_hammer = true
	player.crit_chance = -1.0
	player.last_direction = Vector2.RIGHT


func _spawn_horde(world) -> void:
	for index in range(ENEMY_COUNT):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 13 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var ring: float = [70.0, 160.0, 270.0, 405.0, 515.0][index % 5]
		enemy.global_position = Vector2.RIGHT.rotated(TAU * float(index) / float(ENEMY_COUNT)) * ring
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _spawn_rupture(world, direction: Vector2) -> Node:
	var rupture = world.spawn_cataclysm_rupture(
		world.player.global_position + direction * 190.0, direction, 230.0, 184.0
	)
	if is_instance_valid(rupture):
		rupture.set_process(false)
	return rupture


func _measure(world) -> Dictionary:
	var active_ruptures: Array[Node] = []
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	var spawned_count := 0
	var peak_effects := 0
	for frame_index in range(MEASURED_FRAMES):
		if frame_index in [0, 36, 72, 108, 144]:
			var direction := Vector2.RIGHT.rotated(float(spawned_count) * 0.84)
			var rupture := _spawn_rupture(world, direction)
			_check(is_instance_valid(rupture), "ruptura %d não nasceu" % spawned_count)
			if is_instance_valid(rupture):
				active_ruptures.append(rupture)
			spawned_count += 1
		for rupture in active_ruptures:
			if is_instance_valid(rupture) and not rupture.is_queued_for_deletion():
				rupture._process(1.0 / 120.0)
		peak_effects = maxi(peak_effects, world.effects.get_child_count())
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(frame_times.size() * 0.95) - 1)
	return {
		"average_ms": total_ms / float(MEASURED_FRAMES),
		"p95_ms": frame_times[p95_index],
		"spawned_count": spawned_count,
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
	world.player.global_position = Vector2.ZERO
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
	_check(int(metrics.spawned_count) == 5, "não percorreu as cinco rupturas repetidas")
	_check(int(metrics.peak_effects) <= world.MAX_EFFECTS, "Cataclismo ultrapassou o teto de efeitos")
	print(
		"CATACLYSM HAMMER STRESS: 90 inimigos e 5 rupturas; média %.2f ms, p95 %.2f ms, pico %d efeitos"
		% [average_ms, p95_ms, int(metrics.peak_effects)]
	)

	for effect in world.effects.get_children():
		effect.queue_free()
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
