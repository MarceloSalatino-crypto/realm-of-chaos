extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const RELEASE_SCRIPT := preload("res://scripts/spirit_devourer_release.gd")
const ENEMY_TYPES := ["prowler", "bat", "brute", "assassin", "guardian"]
const ENEMY_COUNT := 90
const WARMUP_FRAMES := 24
const MEASURED_FRAMES := 180
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0

var failures: Array[String] = []
var stress_mode := "evolved"


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SOUL DEVOURER STRESS: " + message)


func _prepare_build(player: Node) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	if stress_mode == "no_attack":
		return
	player.weapon_levels.soul_orbit = 6
	player.evolved_weapons.soul_orbit = stress_mode != "base"
	player.equipped_weapon_id = "soul_orbit"
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.crit_chance = -1.0
	player.life_steal = 0.0
	player.orbit_angle = 0.0
	player.orbit_tick = 0.0
	player.orbit_hit_times.clear()
	player.combat.reset_soul_devourer_state()
	if stress_mode == "legacy":
		player.combat.soul_devourer_release_cooldown = 9999.0


func _spawn_horde(world: Node) -> void:
	for index in range(ENEMY_COUNT):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 19 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var band := index % 3
		var angle := TAU * float(index % 30) / 30.0 + float(band) * 0.035
		var radius := 168.0 + float(band - 1) * 12.0
		enemy.global_position = world.player.global_position + Vector2.RIGHT.rotated(angle) * radius
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _active_releases(world: Node) -> int:
	var count := 0
	for effect in world.effects.get_children():
		if effect.get_script() == RELEASE_SCRIPT and not effect.is_queued_for_deletion():
			count += 1
	return count


func _measure(world: Node) -> Dictionary:
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	var peak_effects := 0
	var peak_releases := 0
	for _frame_index in range(MEASURED_FRAMES):
		if stress_mode != "no_attack":
			if stress_mode == "legacy":
				world.player.combat.soul_devourer_release_cooldown = 9999.0
			world.player.combat.update_weapons(1.0 / 60.0)
		peak_effects = maxi(peak_effects, world.effects.get_child_count())
		peak_releases = maxi(peak_releases, _active_releases(world))
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(frame_times.size() * 0.95) - 1)
	return {
		"average_ms": total_ms / float(MEASURED_FRAMES),
		"p95_ms": frame_times[p95_index],
		"peak_effects": peak_effects,
		"peak_releases": peak_releases,
		"release_count": world.player.combat.soul_devourer_release_count,
	}


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for candidate in ["no_attack", "base", "legacy"]:
		if candidate in arguments:
			stress_mode = candidate
	var world := WORLD_SCENE.instantiate()
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
	world.camera.position_smoothing_enabled = false
	_prepare_build(world.player)
	_spawn_horde(world)
	_check(world.enemies.get_child_count() == ENEMY_COUNT, "cenário não contém 90 inimigos")
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
	_check(int(metrics.peak_effects) <= world.MAX_EFFECTS, "ultrapassou 120 efeitos")
	_check(int(metrics.peak_releases) <= 2, "liberações temporárias acumularam além do limite previsto")
	print(
		"SOUL DEVOURER STRESS [%s]: 90 inimigos; média %.2f ms, p95 %.2f ms; pico %d efeitos/%d liberações; %d descargas"
		% [stress_mode, average_ms, p95_ms, int(metrics.peak_effects), int(metrics.peak_releases), int(metrics.release_count)]
	)
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
