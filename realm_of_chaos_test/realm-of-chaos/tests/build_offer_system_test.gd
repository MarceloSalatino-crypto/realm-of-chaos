extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const SIMULATED_RUNS := 160
const LEVELS_PER_RUN := 42

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(30.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("BUILD OFFER SYSTEM: teste excedeu 30 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("BUILD OFFER SYSTEM: " + message)


func _reset_build(player: Node, run_seed: int) -> void:
	player.level = 1
	player.weapon_levels.clear()
	player.evolved_weapons.clear()
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.chaos_bolt = 1
	player.equipped_weapon_id = "chaos_bolt"
	for passive_id in player.passive_levels:
		player.passive_levels[passive_id] = 0
	player.banished_upgrades.clear()
	player.progression.set_offer_weight_overrides({})
	player.set_upgrade_run_seed(run_seed)
	player.refresh_build_complete()


func _ids(options: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for option in options:
		result.append(str(option.id))
	return result


func _signature(options: Array[Dictionary]) -> String:
	var ids := _ids(options)
	ids.sort()
	return "|".join(ids)


func _sequence(player: Node, run_seed: int, rolls: int) -> Array[String]:
	_reset_build(player, run_seed)
	var result: Array[String] = []
	for level_index in range(rolls):
		player.level = level_index + 2
		var options: Array[Dictionary] = player.get_upgrade_options(3)
		var option_parts: Array[String] = []
		for option in options:
			option_parts.append("%s:%s" % [str(option.id), str(option.rarity)])
		result.append(",".join(option_parts))
	return result


func _catalog_definition(upgrade_id: String) -> Dictionary:
	for definition in GameDefs.upgrades():
		if str(definition.id) == upgrade_id:
			return definition
	return {}


func _set_level_from_option(player: Node, option: Dictionary) -> bool:
	var upgrade_id := str(option.id)
	var was_owned: bool = player.get_upgrade_level(upgrade_id) > 0
	if player.weapon_levels.has(upgrade_id):
		player.weapon_levels[upgrade_id] = int(option.level)
	else:
		player.passive_levels[upgrade_id] = int(option.level)
	player.refresh_build_complete()
	return was_owned


func _run_characterization(player: Node) -> Dictionary:
	var total_weapons := 0.0
	var total_passives := 0.0
	var total_new_choices := 0
	var total_upgrade_choices := 0
	var build_frequencies: Dictionary = {}
	var offer_frequencies: Dictionary = {}
	for run_index in range(SIMULATED_RUNS):
		var run_seed := 810_000 + run_index * 97
		_reset_build(player, run_seed)
		var decision_rng := RandomNumberGenerator.new()
		decision_rng.seed = run_seed ^ 0x51A7
		for level_index in range(LEVELS_PER_RUN):
			player.level = level_index + 2
			var options: Array[Dictionary] = player.get_upgrade_options(3)
			if options.is_empty():
				break
			for option in options:
				var option_id := str(option.id)
				offer_frequencies[option_id] = int(offer_frequencies.get(option_id, 0)) + 1
			var chosen: Dictionary = options[decision_rng.randi_range(0, options.size() - 1)]
			if _set_level_from_option(player, chosen):
				total_upgrade_choices += 1
			else:
				total_new_choices += 1
		var owned_ids: Array[String] = []
		for weapon_id in player.WEAPON_IDS:
			if int(player.weapon_levels.get(weapon_id, 0)) > 0:
				owned_ids.append(weapon_id)
		for passive_id in player.passive_levels:
			if int(player.passive_levels.get(passive_id, 0)) > 0:
				owned_ids.append(str(passive_id))
		owned_ids.sort()
		var build_signature := "|".join(owned_ids)
		build_frequencies[build_signature] = int(build_frequencies.get(build_signature, 0)) + 1
		total_weapons += player.active_weapon_count()
		total_passives += player.active_passive_count()
	var most_common_build_count := 0
	for occurrence in build_frequencies.values():
		most_common_build_count = maxi(most_common_build_count, int(occurrence))
	return {
		"average_weapons": total_weapons / SIMULATED_RUNS,
		"average_passives": total_passives / SIMULATED_RUNS,
		"unique_builds": build_frequencies.size(),
		"most_common_build_rate": float(most_common_build_count) / SIMULATED_RUNS,
		"new_choices": total_new_choices,
		"upgrade_choices": total_upgrade_choices,
		"offer_frequencies": offer_frequencies,
	}


func _run_legacy_characterization(player: Node) -> Dictionary:
	var total_weapons := 0.0
	var total_passives := 0.0
	var build_frequencies: Dictionary = {}
	for run_index in range(SIMULATED_RUNS):
		var weapon_levels: Dictionary = {}
		var passive_levels: Dictionary = {}
		for weapon_id in player.WEAPON_IDS:
			weapon_levels[weapon_id] = 0
		weapon_levels.chaos_bolt = 1
		for passive_id in player.passive_levels:
			passive_levels[str(passive_id)] = 0
		var offer_rng := RandomNumberGenerator.new()
		offer_rng.seed = 810_000 + run_index * 97
		var decision_rng := RandomNumberGenerator.new()
		decision_rng.seed = offer_rng.seed ^ 0x51A7
		for _level_index in range(LEVELS_PER_RUN):
			var active_weapons := 0
			for weapon_id in weapon_levels:
				if int(weapon_levels[weapon_id]) > 0:
					active_weapons += 1
			var pool: Array[Dictionary] = []
			for definition in GameDefs.upgrades():
				var upgrade_id := str(definition.id)
				var current_level := int(weapon_levels.get(upgrade_id, passive_levels.get(upgrade_id, 0)))
				if current_level >= int(definition.max):
					continue
				if weapon_levels.has(upgrade_id) and current_level <= 0 and active_weapons >= player.MAX_WEAPONS:
					continue
				pool.append(definition)
			if pool.is_empty():
				break
			var trio: Array[Dictionary] = []
			while not pool.is_empty() and trio.size() < 3:
				trio.append(pool.pop_at(offer_rng.randi_range(0, pool.size() - 1)))
			var chosen: Dictionary = trio[decision_rng.randi_range(0, trio.size() - 1)]
			var chosen_id := str(chosen.id)
			var current_level := int(weapon_levels.get(chosen_id, passive_levels.get(chosen_id, 0)))
			var level_gain := 2 if offer_rng.randf() < 0.08 else 1
			var new_level := mini(int(chosen.max), current_level + level_gain)
			if weapon_levels.has(chosen_id):
				weapon_levels[chosen_id] = new_level
			else:
				passive_levels[chosen_id] = new_level
		var owned_ids: Array[String] = []
		for weapon_id in weapon_levels:
			if int(weapon_levels[weapon_id]) > 0:
				owned_ids.append(str(weapon_id))
				total_weapons += 1.0
		for passive_id in passive_levels:
			if int(passive_levels[passive_id]) > 0:
				owned_ids.append(str(passive_id))
				total_passives += 1.0
		owned_ids.sort()
		var signature := "|".join(owned_ids)
		build_frequencies[signature] = int(build_frequencies.get(signature, 0)) + 1
	var most_common_build_count := 0
	for occurrence in build_frequencies.values():
		most_common_build_count = maxi(most_common_build_count, int(occurrence))
	return {
		"average_weapons": total_weapons / SIMULATED_RUNS,
		"average_passives": total_passives / SIMULATED_RUNS,
		"unique_builds": build_frequencies.size(),
		"most_common_build_rate": float(most_common_build_count) / SIMULATED_RUNS,
	}


func _test_weight_infrastructure(player: Node) -> void:
	var low_weight_count := 0
	var standard_weight_count := 0
	for sample_index in range(700):
		_reset_build(player, 430_000 + sample_index)
		player.progression.set_offer_weight_overrides({
			"blood_scythe": 0.12,
			"rune_hammer": 1.0,
		})
		var options: Array[Dictionary] = player.get_upgrade_options(3)
		for option in options:
			if str(option.id) == "blood_scythe":
				low_weight_count += 1
			elif str(option.id) == "rune_hammer":
				standard_weight_count += 1
	_check(
		low_weight_count * 2 < standard_weight_count,
		"peso individual baixo não reduziu materialmente a frequência (%d vs %d)" % [low_weight_count, standard_weight_count]
	)
	print("BUILD WEIGHT SAMPLE: low=", low_weight_count, " standard=", standard_weight_count)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_physics_process(false)
	var player: Node = world.player

	_check(player.MAX_WEAPONS == 6, "limite de armas não é seis")
	_check(player.MAX_PASSIVES == 6, "limite de passivos não é seis")
	for definition in GameDefs.upgrades():
		_check(definition.has("offer_weight") and float(definition.offer_weight) >= 0.0, "item sem peso orientado por dados: %s" % str(definition.id))
		_check(definition.has("offer_tier"), "item sem categoria de oferta: %s" % str(definition.id))

	_reset_build(player, 1001)
	var previous_signature := ""
	var first_offer: Array[Dictionary] = []
	for roll_index in range(80):
		player.level = roll_index + 2
		var options: Array[Dictionary] = player.get_upgrade_options(3)
		_check(options.size() == 3, "level-up não retornou três cartas")
		var ids := _ids(options)
		var unique_ids: Dictionary = {}
		for upgrade_id in ids:
			unique_ids[upgrade_id] = true
		_check(unique_ids.size() == ids.size(), "trio contém carta duplicada: %s" % ",".join(ids))
		var current_signature := _signature(options)
		if not previous_signature.is_empty():
			_check(current_signature != previous_signature, "trio consecutivo foi repetido: " + current_signature)
		previous_signature = current_signature
		if roll_index == 0:
			first_offer = options

	var first_unselected_id := str(first_offer[0].id)
	var returned_later := false
	for _roll_index in range(36):
		var later_options: Array[Dictionary] = player.get_upgrade_options(3)
		if first_unselected_id in _ids(later_options):
			returned_later = true
			break
	_check(returned_later, "item não escolhido nunca voltou após a janela de recência")

	_reset_build(player, 2077)
	var fresh_definition := _catalog_definition("chaos_bolt")
	var fresh_weight: float = player.progression._candidate_offer_weight(fresh_definition)
	var relevant_offer: Array[Dictionary] = player.get_upgrade_options(3)
	_check("chaos_bolt" in _ids(relevant_offer) or "critical" in _ids(relevant_offer), "trio inicial não contém opção relevante à arma inicial")
	var recently_shown_id := str(relevant_offer[0].id)
	var recently_shown_definition := _catalog_definition(recently_shown_id)
	player.reset_upgrade_offer_history()
	var baseline_weight: float = player.progression._candidate_offer_weight(recently_shown_definition)
	player.set_upgrade_run_seed(2077)
	player.get_upgrade_options(3)
	var penalized_weight: float = player.progression._candidate_offer_weight(recently_shown_definition)
	_check(penalized_weight < baseline_weight, "carta recém-mostrada não recebeu penalidade temporária")
	_check(fresh_weight > 0.0, "peso-base de opção válida ficou zerado")

	var sequence_a := _sequence(player, 991_337, 18)
	var sequence_b := _sequence(player, 991_337, 18)
	var sequence_c := _sequence(player, 991_338, 18)
	_check(sequence_a == sequence_b, "mesma seed não reproduziu escolhas e raridades")
	_check(sequence_a != sequence_c, "seeds diferentes produziram a mesma sequência")

	_reset_build(player, 5511)
	for index in range(player.MAX_WEAPONS):
		player.weapon_levels[player.WEAPON_IDS[index]] = 1
	var passive_ids: Array[String] = []
	for passive_id in player.passive_levels:
		passive_ids.append(str(passive_id))
	for index in range(player.MAX_PASSIVES):
		player.passive_levels[passive_ids[index]] = 1
	var owned_before: Dictionary = {}
	for weapon_id in player.WEAPON_IDS:
		if int(player.weapon_levels[weapon_id]) > 0:
			owned_before[weapon_id] = true
	for passive_id in player.passive_levels:
		if int(player.passive_levels[passive_id]) > 0:
			owned_before[str(passive_id)] = true
	for _roll_index in range(20):
		var capped_options: Array[Dictionary] = player.get_upgrade_options(3)
		for option in capped_options:
			_check(owned_before.has(str(option.id)), "slots completos ofereceram item novo: %s" % str(option.id))
	for weapon_id in player.WEAPON_IDS:
		if not owned_before.has(weapon_id):
			player.apply_upgrade(weapon_id, "LENDÁRIO")
	for passive_id in player.passive_levels:
		if not owned_before.has(str(passive_id)):
			player.apply_upgrade(str(passive_id), "LENDÁRIO")
	_check(player.active_weapon_count() == 6 and player.active_passive_count() == 6, "aplicação direta permitiu adquirir tudo")
	_check(player.active_weapon_count() + player.active_passive_count() == 12, "build ultrapassou doze slots de itens")

	_test_weight_infrastructure(player)
	var characterization := _run_characterization(player)
	var legacy_characterization := _run_legacy_characterization(player)
	print(
		"BUILD CHARACTERIZATION: runs=", SIMULATED_RUNS,
		" avg_weapons=", "%.2f" % float(characterization.average_weapons),
		" avg_passives=", "%.2f" % float(characterization.average_passives),
		" unique_builds=", int(characterization.unique_builds),
		" top_build_rate=", "%.2f%%" % (float(characterization.most_common_build_rate) * 100.0),
		" new_choices=", int(characterization.new_choices),
		" upgrades=", int(characterization.upgrade_choices)
	)
	print(
		"LEGACY BUILD MODEL: runs=", SIMULATED_RUNS,
		" avg_weapons=", "%.2f" % float(legacy_characterization.average_weapons),
		" avg_passives=", "%.2f" % float(legacy_characterization.average_passives),
		" unique_builds=", int(legacy_characterization.unique_builds),
		" top_build_rate=", "%.2f%%" % (float(legacy_characterization.most_common_build_rate) * 100.0)
	)
	_check(float(characterization.average_weapons) <= 6.0, "simulações excederam seis armas")
	_check(float(characterization.average_passives) <= 6.0, "simulações excederam seis passivos")
	_check(int(characterization.unique_builds) >= int(SIMULATED_RUNS * 0.70), "variedade entre builds ficou baixa")
	_check(float(characterization.most_common_build_rate) <= 0.05, "uma build dominou as runs simuladas")
	_check(int(characterization.new_choices) > 0 and int(characterization.upgrade_choices) > int(characterization.new_choices), "progressão não combinou descoberta e fortalecimento")
	_check(float(legacy_characterization.average_passives) > 6.0, "modelo legado não reproduziu aquisição excessiva de passivos")
	_check(int(characterization.unique_builds) > int(legacy_characterization.unique_builds), "novo sorteio não superou a variedade do modelo legado")

	# As receitas e seus requisitos são caracterizados aqui; sua lógica detalhada
	# continua coberta por player_progression_test e upgrade_rarity_test.
	_check(GameDefs.evolution_data("chaos_bolt") == {"title": "BALISTA ABISSAL", "passive": "critical", "weapon_level": 8, "passive_level": 3}, "receita existente da Besta foi alterada")
	_check(GameDefs.evolution_data("swarm_idol") == {"title": "OLHO DA LEGIÃO", "passive": "regeneration", "weapon_level": 6, "passive_level": 3}, "receita existente do Ídolo foi alterada")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("BUILD OFFER SYSTEM OK: slots, RNG, recência, variedade, pesos e evoluções preservados")
		quit(0)
	else:
		quit(1)
