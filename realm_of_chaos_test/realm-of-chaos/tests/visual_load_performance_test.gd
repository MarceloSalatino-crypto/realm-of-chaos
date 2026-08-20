extends SceneTree

const BulletScene = preload("res://scenes/bullet.tscn")
const EffectScript = preload("res://scripts/effect.gd")
const ArenaHazardScript = preload("res://scripts/arena_hazard.gd")

const ENEMY_TYPES := ["prowler", "bat", "mage", "brute", "ember", "bomber", "necromancer", "archer", "assassin", "swarm", "guardian"]
const TOTAL_ENEMY_COUNT := 90
const ELITE_COUNT := 4
const REGULAR_ENEMY_COUNT := TOTAL_ENEMY_COUNT - ELITE_COUNT - 1
const PICKUP_COUNT := 520
const PLAYER_PROJECTILE_COUNT := 180
const ENEMY_PROJECTILE_COUNT := 96
const EFFECT_COUNT := 120
const WARMUP_FRAMES := 30
const BURST_WARMUP_FRAMES := 8
const MEASURED_FRAMES := 60
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("VISUAL LOAD: " + message)


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


func _spawn_horde(world: Node) -> void:
	for index in range(REGULAR_ENEMY_COUNT):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], false, 3.0)
		var ring := 460.0 + float(index % 8) * 56.0
		enemy.global_position = Vector2.RIGHT.rotated(TAU * index / REGULAR_ENEMY_COUNT) * ring
	for index in range(ELITE_COUNT):
		var elite = world.spawn_enemy("guardian" if index % 2 == 0 else "assassin", true, 3.0)
		elite.global_position = Vector2.RIGHT.rotated(TAU * index / ELITE_COUNT) * 430.0
	var boss = world._spawn_scheduled_boss(GameDefs.boss_schedule()[0], 0)
	boss.global_position = Vector2(520.0, 0.0)
	world._rebuild_spatial_grid()


func _spawn_pickups_and_validate_tiers(world: Node) -> void:
	var first_pickup: Node
	for index in range(PICKUP_COUNT):
		var pickup_position: Vector2
		if index < 80:
			var visible_ring := 245.0 + float(index % 4) * 22.0
			pickup_position = Vector2.RIGHT.rotated(TAU * index / 80.0) * visible_ring
		else:
			var offscreen_index := index - 80
			var offscreen_ring := 860.0 + float(offscreen_index % 9) * 72.0
			pickup_position = Vector2.RIGHT.rotated(TAU * offscreen_index / 440.0) * offscreen_ring
		var pickup = world._spawn_pickup(1, pickup_position, "xp")
		if index == 0:
			first_pickup = pickup
		if index == 158:
			first_pickup._refresh_visual_load()
			_check(
				is_equal_approx(first_pickup.redraw_interval, first_pickup.NORMAL_REDRAW_INTERVAL),
				"pickups abaixo de 160 não usam 30 Hz"
			)
		elif index == 159:
			first_pickup._refresh_visual_load()
			_check(
				is_equal_approx(first_pickup.redraw_interval, first_pickup.MEDIUM_REDRAW_INTERVAL),
				"160 pickups não ativam 20 Hz"
			)
		elif index == 359:
			first_pickup._refresh_visual_load()
			_check(
				is_equal_approx(first_pickup.redraw_interval, first_pickup.HIGH_REDRAW_INTERVAL),
				"360 pickups não ativam 15 Hz"
			)


func _validate_hazard_budget(world: Node) -> void:
	var kinds := ["roots", "ice", "void"]
	for index in range(kinds.size()):
		var hazard = ArenaHazardScript.new()
		world.add_child(hazard)
		hazard.setup(kinds[index], Vector2(4800.0, 4800.0 + index * 180.0), 100.0, 100 + index)
		_check(is_instance_valid(hazard.screen_notifier), "perigo %s não criou notifier" % kinds[index])
		if kinds[index] == "roots":
			_check(not hazard.is_processing(), "raízes ainda processam redesenho contínuo")
		elif kinds[index] == "ice":
			_check(is_equal_approx(hazard.redraw_interval, 1.0 / 14.0), "gelo não usa aproximadamente 14 Hz")
		else:
			_check(is_equal_approx(hazard.redraw_interval, 1.0 / 20.0), "vazio não usa 20 Hz")
		hazard._on_screen_entered()
		_check(hazard.visual_on_screen, "perigo %s não ativa ao entrar na câmera" % kinds[index])
		hazard._on_screen_exited()
		_check(not hazard.visual_on_screen, "perigo %s não suspende redraw fora da câmera" % kinds[index])
		hazard.queue_free()
	await process_frame


func _validate_offscreen_pickup_physics(world: Node) -> void:
	var pickup = world.pickups.get_child(0)
	pickup.global_position = Vector2(1100.0, 0.0)
	pickup.velocity = Vector2.ZERO
	pickup.attracted = true
	pickup._on_screen_exited()
	var age_before: float = pickup.age
	var position_before: Vector2 = pickup.global_position
	for _frame in range(4):
		await process_frame
	_check(pickup.age > age_before, "pickup fora da câmera parou de envelhecer")
	_check(pickup.global_position != position_before, "pickup fora da câmera parou atração/movimento")
	_check(not pickup.visual_on_screen, "pickup fora da câmera manteve redraw ativo")
	pickup._on_screen_entered()
	_check(pickup.visual_on_screen, "pickup não redesenha imediatamente ao entrar na câmera")


func _spawn_projectile_burst(world: Node) -> void:
	for index in range(PLAYER_PROJECTILE_COUNT):
		var projectile = BulletScene.instantiate()
		var angle := TAU * index / PLAYER_PROJECTILE_COUNT
		projectile.global_position = Vector2.RIGHT.rotated(angle) * (120.0 + float(index % 5) * 14.0)
		projectile.setup(Vector2.RIGHT.rotated(angle + PI * 0.5), 0.0, 24.0, 999, 8.0, Color("a96cff"))
		projectile.lifetime = 5.0
		world.add_player_projectile(projectile)
	for index in range(ENEMY_PROJECTILE_COUNT):
		var angle := TAU * index / ENEMY_PROJECTILE_COUNT
		var projectile = world.spawn_enemy_projectile(
			Vector2.RIGHT.rotated(angle) * (210.0 + float(index % 4) * 15.0),
			Vector2.RIGHT.rotated(angle + PI * 0.5),
			0.0,
			28.0,
			Color("ff496d"),
			8.0,
			index % 2 == 0
		)
		projectile.lifetime = 5.0


func _spawn_effect_burst(world: Node) -> void:
	for index in range(EFFECT_COUNT):
		var effect = EffectScript.new()
		world.effects.add_child(effect)
		var angle := TAU * index / EFFECT_COUNT
		effect.setup(
			Vector2.RIGHT.rotated(angle) * (150.0 + float(index % 7) * 34.0),
			Color("b86cff").lerp(Color("ff496d"), float(index % 5) / 4.0),
			42.0 + float(index % 4) * 8.0,
			3.0,
			index % 3 == 0,
			0
		)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	world.time_survived = world.RUN_DURATION

	_spawn_horde(world)
	_spawn_pickups_and_validate_tiers(world)
	await _validate_hazard_budget(world)
	await _validate_offscreen_pickup_physics(world)
	_check(world.pickups.get_child_count() == PICKUP_COUNT, "teto de 520 pickups não foi preservado")
	_check(get_nodes_in_group("arena_hazards").size() == 18, "mundo não manteve os 18 perigos")
	_check(
		world.enemies.get_child_count() == TOTAL_ENEMY_COUNT,
		"cenário não contém 90 inimigos totais, incluindo quatro elites e um mini-boss"
	)

	for _frame in range(WARMUP_FRAMES):
		await process_frame
	_spawn_projectile_burst(world)
	_spawn_effect_burst(world)
	for _frame in range(BURST_WARMUP_FRAMES):
		await process_frame
	_check(world.projectiles.get_child_count() >= PLAYER_PROJECTILE_COUNT, "burst não manteve 180 projéteis do jogador")
	_check(world.enemy_projectiles.get_child_count() >= ENEMY_PROJECTILE_COUNT, "burst não manteve 96 projéteis inimigos")
	_check(world.effects.get_child_count() >= EFFECT_COUNT, "burst não manteve 120 efeitos")

	var metrics := await _measure_frames(MEASURED_FRAMES)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	var timing_valid := average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS
	_check(
		timing_valid,
		"regressão: média %.2f ms, p95 %.2f ms (limites %.1f/%.1f ms)"
		% [average_ms, p95_ms, MAX_AVERAGE_MS, MAX_P95_MS]
	)
	print(
		"VISUAL LOAD: 90 inimigos totais, 520 pickups, 18 perigos, 180/96 projéteis e 120 efeitos; média %.2f ms, p95 %.2f ms"
		% [average_ms, p95_ms]
	)

	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
