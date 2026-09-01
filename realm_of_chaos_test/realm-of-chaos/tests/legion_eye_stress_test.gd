extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const LEGION_FOCUS_SCRIPT = preload("res://scripts/legion_focus.gd")
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
	push_error("LEGION EYE STRESS: " + message)


func _prepare_build(player) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.swarm_idol = 6
	player.evolved_weapons.swarm_idol = true
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.combat.legion_cast_count = 2


func _spawn_horde(world) -> void:
	var boss = world.spawn_enemy("ossuary_colossus", false, 3.0)
	_check(is_instance_valid(boss), "boss prioritário não nasceu")
	if is_instance_valid(boss):
		boss.global_position = Vector2(475.0, 0.0)
		_freeze_enemy(boss)
	for index in range(ENEMY_COUNT - 1):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 13 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var ring: float = [90.0, 185.0, 290.0, 420.0, 560.0][index % 5]
		var angle := TAU * float(index * 17 % ENEMY_COUNT) / float(ENEMY_COUNT)
		enemy.global_position = Vector2.RIGHT.rotated(angle) * ring
		_freeze_enemy(enemy)
	world._rebuild_spatial_grid()


func _freeze_enemy(enemy: Node) -> void:
	enemy.hp = 1_000_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)


func _active_focuses(world) -> Array[Node]:
	var focuses: Array[Node] = []
	for effect in world.effects.get_children():
		if effect.get_script() == LEGION_FOCUS_SCRIPT and not effect.is_queued_for_deletion():
			focuses.append(effect)
	return focuses


func _measure(world) -> Dictionary:
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	var spawned_count := 0
	var peak_effects := 0
	var peak_focuses := 0
	var peak_eyes := 0
	var peak_temporary_references := 0
	var completed_stages := 0
	var focus_decisions := 0
	for frame_index in range(MEASURED_FRAMES):
		if frame_index in [0, 36, 72, 108, 144]:
			world.player.combat.legion_cast_count = 2
			world.player.swarm_timer = 0.0
			world.player._release_swarm_eyes(6)
			var newest_focuses := _active_focuses(world)
			if not newest_focuses.is_empty():
				var newest_focus: Node = newest_focuses[-1]
				newest_focus.set_process(false)
				focus_decisions += int(newest_focus.focus_decision_count)
			spawned_count += 1
		var focuses := _active_focuses(world)
		peak_focuses = maxi(peak_focuses, focuses.size())
		peak_eyes = maxi(peak_eyes, focuses.size() * 8)
		peak_temporary_references = maxi(peak_temporary_references, focuses.size() * 2)
		for focus in focuses:
			var before_stage := int(focus.attack_stage_count)
			focus._process(1.0 / 120.0)
			completed_stages += int(focus.attack_stage_count) - before_stage
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
		"completed_stages": completed_stages,
		"focus_decisions": focus_decisions,
		"peak_effects": peak_effects,
		"peak_focuses": peak_focuses,
		"peak_eyes": peak_eyes,
		"peak_temporary_references": peak_temporary_references,
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
	_check(int(metrics.spawned_count) == 5, "não percorreu cinco ativações coordenadas")
	_check(int(metrics.completed_stages) >= 8, "salvas coordenadas não avançaram sob carga")
	_check(int(metrics.peak_focuses) <= 3, "janelas de foco persistiram além da duração esperada")
	_check(int(metrics.peak_eyes) <= 24, "formações mantiveram mais olhos que o previsto")
	_check(int(metrics.peak_temporary_references) <= 6, "referências temporárias cresceram sem limite")
	_check(int(metrics.peak_effects) <= world.MAX_EFFECTS, "Olho da Legião ultrapassou o teto de efeitos")
	print(
		(
			"LEGION EYE STRESS: 90 inimigos/5 focos; média %.2f ms, p95 %.2f ms; "
			+ "pico %d efeitos/%d focos/%d olhos/%d referências; %d decisões iniciais"
		) % [
			average_ms, p95_ms, int(metrics.peak_effects), int(metrics.peak_focuses),
			int(metrics.peak_eyes), int(metrics.peak_temporary_references), int(metrics.focus_decisions)
		]
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
