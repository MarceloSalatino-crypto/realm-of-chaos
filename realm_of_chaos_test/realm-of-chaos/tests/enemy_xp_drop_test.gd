extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const ENEMY_SCENE = preload("res://scenes/enemies/enemy.tscn")
const SIMULATED_RUNS := 240
const COMMON_ENEMIES: Array[String] = [
	"prowler", "bat", "mage", "brute", "ember", "bomber",
	"necromancer", "archer", "assassin", "swarm", "guardian",
]
const BOSS_ENEMIES: Array[String] = [
	"ossuary_colossus", "glacial_archon", "infernal_reaper",
	"void_titan", "chaos_sovereign", "void_knight",
]

var failures: Array[String] = []


class DropEnemy:
	extends Node2D

	var final_boss := false
	var enemy_type := "prowler"
	var hit_radius := 21.0


func _initialize() -> void:
	var watchdog := create_timer(35.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("ENEMY XP DROP: teste excedeu 35 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ENEMY XP DROP: " + message)


func _check_close(actual: float, expected: float, tolerance: float, message: String) -> void:
	_check(
		absf(actual - expected) <= tolerance,
		"%s (esperado %.4f ± %.4f, obtido %.4f)" % [message, expected, tolerance, actual]
	)


func _count_pickups(world: Node, pickup_kind: String) -> int:
	var count := 0
	for pickup in world.pickups.get_children():
		if is_instance_valid(pickup) and str(pickup.pickup_kind) == pickup_kind:
			count += 1
	return count


func _find_pickup(world: Node, pickup_kind: String) -> Node:
	for pickup in world.pickups.get_children():
		if is_instance_valid(pickup) and str(pickup.pickup_kind) == pickup_kind:
			return pickup
	return null


func _clear_pickups(world: Node) -> void:
	for pickup in world.pickups.get_children():
		pickup.queue_free()
	await process_frame


func _levels_from_xp(total_xp: int) -> int:
	var level := 1
	var stored_xp := total_xp
	var needed := 12
	while stored_xp >= needed:
		stored_xp -= needed
		level += 1
		needed = int(round(10.0 + pow(level, 1.34) * 5.2))
	return level


func _legacy_scaled_xp(enemy_id: String, power: float, elite: bool) -> int:
	var value := maxi(1, int(round(float(GameDefs.enemy_data(enemy_id).xp) * sqrt(power))))
	return value * 4 if elite else value


func _new_scaled_xp(enemy_id: String, power: float, elite: bool) -> int:
	var profile := GameDefs.enemy_xp_drop_profile(enemy_id)
	var value := maxi(1, int(round(float(profile.value) * sqrt(power))))
	if elite:
		value = maxi(1, int(round(value * float(profile.elite_value_multiplier))))
	return value


func _empty_totals() -> Dictionary:
	return {
		"total": 0,
		"common": 0,
		"elite": 0,
		"mini_boss": 0,
		"final_boss": 0,
		"ordinary_kills": 0,
		"ordinary_drops": 0,
		"common_kills": 0,
		"common_drops": 0,
		"elite_kills": 0,
		"elite_drops": 0,
		"pickup_count": 0,
	}


func _add_reward(totals: Dictionary, category: String, amount: int, pickup_count: int) -> void:
	totals.total = int(totals.total) + amount
	totals[category] = int(totals[category]) + amount
	totals.pickup_count = int(totals.pickup_count) + pickup_count


func _simulate_run(profile: Resource, run_index: int) -> Dictionary:
	var legacy := _empty_totals()
	var current := _empty_totals()
	var rng := RandomNumberGenerator.new()
	rng.seed = 730_001 + run_index * 7_919
	for minute in range(25):
		var elapsed := float(minute * 60 + 30)
		var difficulty: Dictionary = profile.difficulty_at(elapsed)
		var choices: Array[String] = profile.enemy_choices_at(elapsed)
		var kills_this_minute := 40 + roundi(minute * 2.2)
		for _kill_index in range(kills_this_minute):
			var enemy_id: String = choices[rng.randi_range(0, choices.size() - 1)]
			var elite: bool = rng.randf() < float(difficulty.elite_chance)
			var category := "elite" if elite else "common"
			var legacy_value := _legacy_scaled_xp(enemy_id, float(difficulty.power), elite)
			_add_reward(legacy, category, legacy_value, 1)
			legacy.ordinary_kills = int(legacy.ordinary_kills) + 1
			legacy.ordinary_drops = int(legacy.ordinary_drops) + 1
			legacy[category + "_kills"] = int(legacy[category + "_kills"]) + 1
			legacy[category + "_drops"] = int(legacy[category + "_drops"]) + 1
			var drop_profile := GameDefs.enemy_xp_drop_profile(enemy_id)
			var chance := float(drop_profile.elite_chance if elite else drop_profile.chance)
			current.ordinary_kills = int(current.ordinary_kills) + 1
			current[category + "_kills"] = int(current[category + "_kills"]) + 1
			if rng.randf() < chance:
				var current_value := _new_scaled_xp(enemy_id, float(difficulty.power), elite)
				_add_reward(current, category, current_value, 1)
				current.ordinary_drops = int(current.ordinary_drops) + 1
				current[category + "_drops"] = int(current[category + "_drops"]) + 1
	for boss_entry in profile.boss_schedule:
		var boss_id := str(boss_entry.kind)
		var category := "final_boss" if bool(boss_entry.final) else "mini_boss"
		var legacy_base := int(GameDefs.enemy_data(boss_id).xp)
		var legacy_burst_count := 10 if bool(boss_entry.final) else 7
		var legacy_burst_value := 18 if bool(boss_entry.final) else 12
		_add_reward(
			legacy, category, legacy_base + legacy_burst_count * legacy_burst_value,
			1 + legacy_burst_count
		)
		var drop_profile := GameDefs.enemy_xp_drop_profile(boss_id)
		var current_burst_count := int(drop_profile.burst_count)
		var current_burst_value := int(drop_profile.burst_value)
		_add_reward(
			current, category,
			int(drop_profile.value) + current_burst_count * current_burst_value,
			1 + current_burst_count
		)
	legacy.level = _levels_from_xp(int(legacy.total))
	current.level = _levels_from_xp(int(current.total))
	return {"legacy": legacy, "current": current}


func _average_totals(samples: Array[Dictionary], key: String) -> Dictionary:
	var result := {
		"xp": 0.0,
		"level": 0.0,
		"common": 0.0,
		"elite": 0.0,
		"mini_boss": 0.0,
		"final_boss": 0.0,
		"drop_rate": 0.0,
		"common_drop_rate": 0.0,
		"elite_drop_rate": 0.0,
		"pickups": 0.0,
	}
	for sample in samples:
		var totals: Dictionary = sample[key]
		result.xp += float(totals.total)
		result.level += float(totals.level)
		result.common += float(totals.common)
		result.elite += float(totals.elite)
		result.mini_boss += float(totals.mini_boss)
		result.final_boss += float(totals.final_boss)
		result.drop_rate += float(totals.ordinary_drops) / maxf(1.0, float(totals.ordinary_kills))
		result.common_drop_rate += float(totals.common_drops) / maxf(1.0, float(totals.common_kills))
		result.elite_drop_rate += float(totals.elite_drops) / maxf(1.0, float(totals.elite_kills))
		result.pickups += float(totals.pickup_count)
	for metric in result:
		result[metric] = float(result[metric]) / samples.size()
	return result


func _test_profile_contract(world: Node) -> void:
	var expected := {
		"prowler": [0.60, 5], "bat": [0.50, 4], "mage": [0.62, 8],
		"brute": [0.64, 14], "ember": [0.50, 10], "bomber": [0.70, 10],
		"necromancer": [0.72, 18], "archer": [0.67, 12], "assassin": [0.56, 16],
		"swarm": [0.25, 4], "guardian": [0.80, 20],
	}
	for enemy_id in COMMON_ENEMIES:
		var profile := GameDefs.enemy_xp_drop_profile(enemy_id)
		_check_close(float(profile.chance), float(expected[enemy_id][0]), 0.0001, "chance incorreta para " + enemy_id)
		_check(int(profile.value) == int(expected[enemy_id][1]), "valor de XP incorreto para " + enemy_id)
		_check(float(profile.chance) > 0.0 and float(profile.chance) < 1.0, enemy_id + " ainda possui XP comum garantido")
		var below: Dictionary = world.run_flow.resolve_enemy_xp_drop(enemy_id, int(profile.value), false, false, float(profile.chance) - 0.0001)
		var boundary: Dictionary = world.run_flow.resolve_enemy_xp_drop(enemy_id, int(profile.value), false, false, float(profile.chance))
		_check(bool(below.dropped), enemy_id + " não dropou abaixo do limiar configurado")
		_check(not bool(boundary.dropped), enemy_id + " dropou no limite exclusivo da chance")
		var elite: Dictionary = world.run_flow.resolve_enemy_xp_drop(enemy_id, int(profile.value) * 4, true, false, 1.0)
		_check(bool(elite.dropped), "elite sem XP garantido: " + enemy_id)
	for boss_id in BOSS_ENEMIES:
		var profile := GameDefs.enemy_xp_drop_profile(boss_id)
		var boss_drop: Dictionary = world.run_flow.resolve_enemy_xp_drop(boss_id, int(profile.value), false, true, 1.0)
		_check(bool(profile.guaranteed) and bool(boss_drop.dropped), "boss sem XP garantido: " + boss_id)
		_check(int(profile.value) >= 80, "recompensa base de boss deixou de ser significativa: " + boss_id)
		_check(int(profile.burst_count) > 0 and int(profile.burst_value) > 0, "boss sem explosão visível de XP: " + boss_id)


func _test_enemy_runtime_values(world: Node) -> void:
	for enemy_id in COMMON_ENEMIES:
		var enemy = ENEMY_SCENE.instantiate()
		enemy.setup(enemy_id, 4.0, true, world)
		world.enemies.add_child(enemy)
		await process_frame
		_check(
			int(enemy.xp_value) == _new_scaled_xp(enemy_id, 4.0, true),
			"Enemy não aplicou valor/multiplicador do perfil: " + enemy_id
		)
		enemy.queue_free()
		await process_frame


func _test_runtime_drop_path(world: Node) -> void:
	var enemy := DropEnemy.new()
	enemy.enemy_type = "prowler"
	enemy.global_position = Vector2(850.0, 0.0)
	world.handle_enemy_death(enemy, 5, false, false, 1.0)
	_check(_count_pickups(world, "xp") == 0, "falha de chance criou uma gema falsa")
	world.handle_enemy_death(enemy, 5, false, false, 0.0)
	_check(_count_pickups(world, "xp") == 1, "drop aprovado não criou a gema de XP")
	var pickup := _find_pickup(world, "xp")
	_check(is_instance_valid(pickup), "drop aprovado não pôde ser localizado entre outros pickups")
	if is_instance_valid(pickup):
		_check(int(pickup.value) == 5, "gema recebeu valor diferente do perfil")
		_check(str(pickup.pickup_batch_style()) == "xp_common", "XP comum perdeu o visual verde existente")
	await _clear_pickups(world)

	enemy.enemy_type = "brute"
	world.handle_enemy_death(enemy, 14, false, false, 0.0)
	pickup = _find_pickup(world, "xp")
	_check(is_instance_valid(pickup), "XP alto aprovado não pôde ser localizado entre outros pickups")
	if is_instance_valid(pickup):
		_check(str(pickup.pickup_batch_style()) == "xp_high", "XP alto não utilizou o cristal dourado existente")
	await _clear_pickups(world)
	enemy.free()


func _test_level_up_compatibility(world: Node) -> void:
	var player: Node = world.player
	if player.level_up_requested.is_connected(world._on_level_up_requested):
		player.level_up_requested.disconnect(world._on_level_up_requested)
	player.level = 1
	player.experience = 0
	player.experience_needed = 12
	var emitted := [0]
	player.level_up_requested.connect(func(): emitted[0] += 1)
	player.collect_xp(1500)
	_check(emitted[0] == player.level - 1, "XP agregado e sinais de level-up ficaram inconsistentes")
	var options: Array[Dictionary] = player.get_upgrade_options(3)
	_check(options.size() == 3, "novo XP não alimentou corretamente o sistema de três escolhas")
	var unique_ids: Dictionary = {}
	for option in options:
		unique_ids[str(option.id)] = true
	_check(unique_ids.size() == options.size(), "level-up após novo XP gerou cartas duplicadas")


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_physics_process(false)

	_test_profile_contract(world)
	await _test_enemy_runtime_values(world)
	await _test_runtime_drop_path(world)
	var samples: Array[Dictionary] = []
	for run_index in range(SIMULATED_RUNS):
		samples.append(_simulate_run(world.encounter_profile, run_index))
	var legacy := _average_totals(samples, "legacy")
	var current := _average_totals(samples, "current")
	var xp_ratio := float(current.xp) / maxf(1.0, float(legacy.xp))
	_check(xp_ratio >= 0.90 and xp_ratio <= 1.10, "XP total saiu da faixa de preservação: %.3f" % xp_ratio)
	_check(absf(float(current.level) - float(legacy.level)) <= 2.0, "progressão média divergiu mais de dois níveis")
	_check(float(current.common_drop_rate) < 0.75, "inimigos comuns ainda geram XP quase sempre")
	_check(float(current.common_drop_rate) > 0.35, "drop comum ficou raro demais")
	_check_close(float(current.elite_drop_rate), 1.0, 0.0001, "elites não mantiveram XP garantido")
	_check(float(current.pickups) < float(legacy.pickups) * 0.82, "contagem visual de gemas não caiu materialmente")
	_test_level_up_compatibility(world)

	print(
		"XP RUNS (", SIMULATED_RUNS, " x 25min): legacy=", legacy,
		" current=", current, " ratio=", snappedf(xp_ratio, 0.001)
	)
	world.game_ended = true
	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY XP DROP OK: perfis, chance, valores, elites, bosses, visual e progressão validados")
		quit(0)
	else:
		quit(1)
