extends SceneTree

const LAB_SCENE := preload("res://scenes/biome_vertical_slice_lab.tscn")
const ENEMY_TYPES := [
	"prowler", "bat", "mage", "brute", "ember", "bomber",
	"necromancer", "archer", "assassin", "swarm", "guardian",
]
const ENEMY_COUNT := 90
const WARMUP_FRAMES := 45
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
	push_error("FOREST COLLISION PERFORMANCE: " + message)


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
	var lab = LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await lab.load_slice("forest_production")
	var world = lab.current_world
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.hud.hide()
	for existing_enemy in world.enemies.get_children():
		existing_enemy.free()
	world.time_survived = world.RUN_DURATION
	world.player.max_hp = 1_000_000.0
	world.player.hp = world.player.max_hp

	var dense_center := Vector2(world.environment_builder.terrain_composer.capture_point("DENSE_REGION"))
	var target_position: Vector2 = world.environment_builder.find_clear_spawn_position(dense_center, 330.0, 460.0)
	_check(is_finite(target_position.x), "não existe espaço jogável ao redor da massa densa")
	if is_finite(target_position.x):
		world.player.global_position = target_position

	var initial_positions: Dictionary = {}
	for index in range(ENEMY_COUNT):
		var enemy = world.spawn_enemy_near(
			ENEMY_TYPES[index % ENEMY_TYPES.size()], dense_center,
			225.0 + float(index % 4) * 35.0, 690.0, index % 17 == 0, 3.0
		)
		_check(is_instance_valid(enemy), "o teto global impediu o inimigo %d antes de chegar a 90" % index)
		if is_instance_valid(enemy):
			initial_positions[enemy] = enemy.global_position
	world._rebuild_spatial_grid()
	_check(world.enemies.get_child_count() == ENEMY_COUNT, "cenário não concentrou 90 inimigos nas massas florestais")
	_check(int(world.environment_builder.forest_collision_composer.summary().grove_lobes) == 55, "benchmark perdeu as massas físicas reais")

	for _frame in range(WARMUP_FRAMES):
		await process_frame
	var moved_count := 0
	for enemy in initial_positions:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(Vector2(initial_positions[enemy])) > 4.0:
			moved_count += 1
	_check(moved_count >= 60, "inimigos não estão deslizando/navegando ao redor dos sólidos (%d/90 moveram)" % moved_count)

	var metrics := await _measure_frames(MEASURED_FRAMES)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	_check(
		average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS,
		"regressão com obstáculos: média %.2f ms, p95 %.2f ms (limites %.1f/%.1f ms)"
		% [average_ms, p95_ms, MAX_AVERAGE_MS, MAX_P95_MS]
	)
	print(
		"FOREST COLLISION PERFORMANCE: 90 inimigos concentrados, 55 massas florestais e 17 sólidos de landmarks; %d moveram; média %.2f ms, p95 %.2f ms"
		% [moved_count, average_ms, p95_ms]
	)

	lab.queue_free()
	for _frame in range(5):
		await process_frame
	quit(0 if failures.is_empty() else 1)
