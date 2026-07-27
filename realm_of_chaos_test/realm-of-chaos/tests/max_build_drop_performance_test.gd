extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const DEATH_COUNT := 520
const WARMUP_FRAMES := 30
const MEASURED_FRAMES := 60
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0

var failures: Array[String] = []


class DropEnemy:
	extends Node2D

	var final_boss := false
	var enemy_type := "prowler"
	var hit_radius := 21.0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MAX BUILD DROP LOAD: " + message)


func _count_pickups(world: Node, kind: String) -> int:
	var count := 0
	for pickup in world.pickups.get_children():
		if is_instance_valid(pickup) and str(pickup.pickup_kind) == kind:
			count += 1
	return count


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
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	world.player.experience = 0
	world.player.experience_needed = 1_000_000
	for index in range(world.player.MAX_WEAPONS):
		var weapon_id: String = world.player.WEAPON_IDS[index]
		world.player.weapon_levels[weapon_id] = world.player._upgrade_max(weapon_id)
	for passive_id in world.player.passive_levels:
		world.player.passive_levels[passive_id] = world.player._upgrade_max(str(passive_id))
	_check(world.player.refresh_build_complete(), "configuração máxima ainda possui upgrade disponível")

	seed(9127)
	var enemy := DropEnemy.new()
	for index in range(DEATH_COUNT):
		var ring := 245.0 + float(index % 12) * 72.0
		enemy.global_position = Vector2.RIGHT.rotated(TAU * index / DEATH_COUNT) * ring
		world.handle_enemy_death(enemy, 1, false, false)

	var xp_pickups := _count_pickups(world, "xp")
	var heal_pickups := _count_pickups(world, "heal")
	_check(xp_pickups == 0, "mortes com build completa ainda criaram %d pickups de XP" % xp_pickups)
	for _frame in range(WARMUP_FRAMES):
		await process_frame
	var metrics := await _measure_frames(MEASURED_FRAMES)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	_check(
		average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS,
		"regressão: média %.2f ms, p95 %.2f ms (limites %.1f/%.1f ms)"
		% [average_ms, p95_ms, MAX_AVERAGE_MS, MAX_P95_MS]
	)
	print(
		"MAX BUILD DROP LOAD: %d mortes, %d XP pickups, %d curas; média %.2f ms, p95 %.2f ms"
		% [DEATH_COUNT, xp_pickups, heal_pickups, average_ms, p95_ms]
	)

	enemy.free()
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
