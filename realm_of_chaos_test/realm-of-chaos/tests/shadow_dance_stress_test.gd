extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const SEQUENCE_SCRIPT := preload("res://scripts/shadow_dance_sequence.gd")
const ENEMY_TYPES := ["prowler", "bat", "brute", "assassin", "guardian"]
const ENEMY_COUNT := 90
const WARMUP_FRAMES := 24
const MEASURED_FRAMES := 180
const CAST_FRAMES := [0, 20, 40, 60, 80, 100, 120, 140, 160]
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
	push_error("SHADOW DANCE STRESS: " + message)


func _prepare_build(player: Node, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.shadow_blades = 6
	player.evolved_weapons.shadow_blades = evolved
	player.equipped_weapon_id = "shadow_blades"
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.projectile_bonus = 0


func _spawn_horde(world: Node) -> void:
	for index in range(ENEMY_COUNT):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 17 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var angle := TAU * float(index) / float(ENEMY_COUNT)
		var radius := 150.0 + float(index % 10) * 45.0
		enemy.global_position = Vector2.RIGHT.rotated(angle) * radius
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _active_sequences(world: Node) -> int:
	var count := 0
	for effect in world.effects.get_children():
		if effect.get_script() == SEQUENCE_SCRIPT and not effect.is_queued_for_deletion():
			count += 1
	return count


func _active_return_shadows(world: Node) -> int:
	var count := 0
	for projectile in world.projectiles.get_children():
		if str(projectile.get("visual_style")) == "shadow_return":
			count += 1
	return count


func _fire_legacy_dance(player: Node) -> void:
	for index in range(16):
		player._spawn_player_projectile(
			Vector2.RIGHT.rotated(TAU * index / 16.0), 45.36, 820.0,
			3, 8.0, Color("df63ff"), "shadow_blades"
		)


func _measure(world: Node) -> Dictionary:
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	var cast_count := 0
	var peak_projectiles := 0
	var peak_effects := 0
	var peak_sequences := 0
	var peak_return_shadows := 0
	for frame_index in range(MEASURED_FRAMES):
		if frame_index in CAST_FRAMES:
			match stress_mode:
				"no_cast":
					pass
				"legacy":
					_fire_legacy_dance(world.player)
					cast_count += 1
				_:
					world.player._fire_shadow_blades(6)
					cast_count += 1
		peak_projectiles = maxi(peak_projectiles, world.projectiles.get_child_count())
		peak_effects = maxi(peak_effects, world.effects.get_child_count())
		peak_sequences = maxi(peak_sequences, _active_sequences(world))
		peak_return_shadows = maxi(peak_return_shadows, _active_return_shadows(world))
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(frame_times.size() * 0.95) - 1)
	return {
		"average_ms": total_ms / float(MEASURED_FRAMES),
		"p95_ms": frame_times[p95_index],
		"cast_count": cast_count,
		"peak_projectiles": peak_projectiles,
		"peak_effects": peak_effects,
		"peak_sequences": peak_sequences,
		"peak_return_shadows": peak_return_shadows,
	}


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "legacy" in arguments:
		stress_mode = "legacy"
	elif "no_cast" in arguments:
		stress_mode = "no_cast"

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
	_prepare_build(world.player, stress_mode != "base")
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
	_check(
		int(metrics.cast_count) == (0 if stress_mode == "no_cast" else CAST_FRAMES.size()),
		"quantidade de ativações do modo %s divergiu" % stress_mode
	)
	_check(int(metrics.peak_projectiles) <= world.MAX_PLAYER_PROJECTILES, "ultrapassou 360 projéteis")
	_check(int(metrics.peak_effects) <= world.MAX_EFFECTS, "ultrapassou 120 efeitos")
	if stress_mode == "evolved":
		# O teste força nove ativações sem aguardar o cooldown real de 0,78s.
		# O teto correto aqui é, portanto, uma sequência e oito retornos por cast.
		_check(int(metrics.peak_sequences) <= CAST_FRAMES.size(), "sequências superaram uma entidade por ativação forçada")
		_check(int(metrics.peak_return_shadows) <= CAST_FRAMES.size() * 8, "sombras superaram oito retornos por ativação")
	print(
		(
			"SHADOW DANCE STRESS [%s]: 90 inimigos/9 ativações; média %.2f ms, p95 %.2f ms; "
			+ "pico %d projéteis/%d sombras/%d efeitos/%d sequências"
		) % [
			stress_mode, average_ms, p95_ms, int(metrics.peak_projectiles),
			int(metrics.peak_return_shadows), int(metrics.peak_effects),
			int(metrics.peak_sequences),
		]
	)

	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
