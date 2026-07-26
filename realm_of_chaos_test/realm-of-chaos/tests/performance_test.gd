extends SceneTree

const ENEMY_TYPES := ["prowler", "bat", "mage", "brute", "ember", "bomber", "necromancer", "archer", "assassin", "swarm", "guardian"]
const WARMUP_FRAMES := 30
const MEASURED_FRAMES := 180
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0


func _initialize() -> void:
	call_deferred("_run")


func _measure_frames(frame_count: int) -> Dictionary:
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	for _frame in range(frame_count):
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(frame_times.size() * 0.95) - 1)
	return {
		"average_ms": total_ms / float(frame_count),
		"p95_ms": frame_times[p95_index],
	}


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	for index in range(300):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], false, 3.0)
		var ring := 420.0 + float(index % 8) * 62.0
		enemy.global_position = Vector2.RIGHT.rotated(TAU * index / 300.0) * ring
	world._rebuild_spatial_grid()
	var query_count: int = world.get_enemies_near(Vector2.ZERO, 1000.0).size()
	for _frame in range(WARMUP_FRAMES):
		await process_frame
	var metrics := await _measure_frames(MEASURED_FRAMES)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	var counts_valid: bool = query_count >= 280 and world.enemies.get_child_count() >= 280
	var timing_valid := average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS
	print(
		"PERFORMANCE: 300 inimigos, média %.2f ms, p95 %.2f ms, índice retornou %d, limites %.1f/%.1f ms"
		% [average_ms, p95_ms, query_count, MAX_AVERAGE_MS, MAX_P95_MS]
	)
	if not timing_valid:
		push_error(
			"PERFORMANCE: regressão detectada (média %.2f ms, p95 %.2f ms)"
			% [average_ms, p95_ms]
		)
	world.queue_free()
	await process_frame
	quit(0 if counts_valid and timing_valid else 1)
