extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const EvolutionCatalogScript = preload("res://scripts/evolution_catalog.gd")
const EXPECTED_LEGACY := {
	"chaos_bolt": {"title": "BALISTA ABISSAL", "passive": "critical", "weapon_level": 8, "passive_level": 3},
	"shadow_blades": {"title": "DANÇA DAS SOMBRAS", "passive": "swiftness", "weapon_level": 6, "passive_level": 3},
	"soul_orbit": {"title": "DEVORADOR DE ESPÍRITOS", "passive": "regeneration", "weapon_level": 6, "passive_level": 3},
	"chaos_nova": {"title": "COLAPSO DO VAZIO", "passive": "might", "weapon_level": 6, "passive_level": 3},
	"blood_scythe": {"title": "CEIFADORA CARMESIM", "passive": "vitality", "weapon_level": 6, "passive_level": 3},
	"forbidden_grimoire": {"title": "CÓDICE DO FIM", "passive": "magnet", "weapon_level": 6, "passive_level": 3},
	"rune_hammer": {"title": "MARTELO DO CATACLISMO", "passive": "armor", "weapon_level": 6, "passive_level": 3},
	"storm_relic": {"title": "TEMPESTADE ETERNA", "passive": "haste", "weapon_level": 6, "passive_level": 3},
	"swarm_idol": {"title": "OLHO DA LEGIÃO", "passive": "regeneration", "weapon_level": 6, "passive_level": 3},
}

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	push_error("EVOLUTION CATALOG: teste excedeu 20 segundos")
	quit(2)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("EVOLUTION CATALOG: " + message)


func _max_levels() -> Dictionary:
	var result: Dictionary = {}
	for definition in GameDefs.upgrades():
		result[str(definition.id)] = int(definition.max)
	return result


func _reset_build(player) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	for passive_id in player.passive_levels:
		player.passive_levels[passive_id] = 0


func _set_requirement(player, requirement: Dictionary) -> void:
	var item_id := str(requirement.id)
	match str(requirement.kind):
		"weapon":
			player.weapon_levels[item_id] = int(requirement.level)
		"passive":
			player.passive_levels[item_id] = int(requirement.level)


func _test_current_recipes(player) -> void:
	var recipes := GameDefs.evolution_recipes()
	_check(recipes.size() == 9, "catálogo não possui exatamente as nove receitas legadas")
	_check(GameDefs.evolution_catalog_validation_errors().is_empty(), "catálogo de produção não passou no validador")
	_check(player.WEAPON_IDS == GameDefs.WEAPON_UPGRADE_IDS, "IDs de arma do Player divergiram do catálogo")
	var player_passive_ids: Array[String] = []
	for passive_id in player.passive_levels:
		player_passive_ids.append(str(passive_id))
	player_passive_ids.sort()
	var catalog_passive_ids := GameDefs.PASSIVE_UPGRADE_IDS.duplicate()
	catalog_passive_ids.sort()
	_check(player_passive_ids == catalog_passive_ids, "IDs de passivo do Player divergiram do catálogo")
	for weapon_id in EXPECTED_LEGACY:
		var expected: Dictionary = EXPECTED_LEGACY[weapon_id]
		_check(GameDefs.evolution_data(weapon_id) == expected, "fachada legada mudou: %s" % weapon_id)
		var recipe := GameDefs.evolution_recipe(weapon_id)
		_check(str(recipe.get("title", "")) == str(expected.title), "título genérico divergiu: %s" % weapon_id)
		_check(str(recipe.get("slot_policy", "")) == "upgrade_base", "política de slot mudou: %s" % weapon_id)
		var synergies: Array[Dictionary] = player.progression.synergy_items_for(weapon_id)
		_check(
			synergies.size() == 1
			and str(synergies[0].id) == str(expected.passive)
			and int(synergies[0].required_level) == int(expected.passive_level),
			"HUD perdeu requisito legado: %s" % weapon_id
		)
		_check(
			GameDefs.upgrade_title(str(expected.passive)).to_upper() in player.progression.evolution_hint_for(weapon_id),
			"dica do HUD perdeu o passivo: %s" % weapon_id
		)
	var mutable_copy := GameDefs.evolution_recipe("chaos_bolt")
	mutable_copy.title = "ALTERADO PELO TESTE"
	mutable_copy.requirements[0].level = 1
	_check(
		str(GameDefs.evolution_recipe("chaos_bolt").title) == "BALISTA ABISSAL"
		and int(GameDefs.evolution_recipe("chaos_bolt").requirements[0].level) == 8,
		"consulta expôs o catálogo interno para mutação externa"
	)
	_check(GameDefs.evolution_data("unknown_weapon").is_empty(), "arma desconhecida ganhou evolução")


func _test_requirement_order_and_slots(player) -> void:
	for recipe in GameDefs.evolution_recipes():
		var base_weapon := str(recipe.base_weapon)
		_reset_build(player)
		for requirement_value in recipe.requirements:
			var requirement := Dictionary(requirement_value)
			if str(requirement.kind) != "weapon" or str(requirement.id) != base_weapon:
				_set_requirement(player, requirement)
		player._check_weapon_evolutions()
		_check(not bool(player.evolved_weapons[base_weapon]), "evoluiu sem arma-base: %s" % base_weapon)
		for requirement_value in recipe.requirements:
			var requirement := Dictionary(requirement_value)
			if str(requirement.kind) == "weapon" and str(requirement.id) == base_weapon:
				_set_requirement(player, requirement)
		var weapons_before: int = player.active_weapon_count()
		var passives_before: int = player.active_passive_count()
		player._check_weapon_evolutions()
		_check(bool(player.evolved_weapons[base_weapon]), "ordem passivo→arma não evoluiu: %s" % base_weapon)
		_check(
			player.active_weapon_count() == weapons_before and player.active_passive_count() == passives_before,
			"evolução alterou ocupação dos slots: %s" % base_weapon
		)

		_reset_build(player)
		for requirement_value in recipe.requirements:
			var requirement := Dictionary(requirement_value)
			if str(requirement.kind) == "weapon" and str(requirement.id) == base_weapon:
				_set_requirement(player, requirement)
		player._check_weapon_evolutions()
		_check(not bool(player.evolved_weapons[base_weapon]), "evoluiu sem requisito complementar: %s" % base_weapon)
		for requirement_value in recipe.requirements:
			var requirement := Dictionary(requirement_value)
			if str(requirement.kind) != "weapon" or str(requirement.id) != base_weapon:
				_set_requirement(player, requirement)
		player._check_weapon_evolutions()
		_check(bool(player.evolved_weapons[base_weapon]), "ordem arma→passivo não evoluiu: %s" % base_weapon)


func _test_future_weapon_pair_support() -> void:
	var future_recipe := {
		"id": "future_weapon_pair",
		"title": "RECEITA SINTÉTICA",
		"base_weapon": "chaos_bolt",
		"slot_policy": "upgrade_base",
		"requirements": [
			{"kind": "weapon", "id": "chaos_bolt", "level": 8},
			{"kind": "weapon", "id": "shadow_blades", "level": 6},
		],
	}
	var errors := EvolutionCatalogScript.validation_errors(
		[future_recipe], GameDefs.WEAPON_UPGRADE_IDS, GameDefs.PASSIVE_UPGRADE_IDS, _max_levels()
	)
	_check(errors.is_empty(), "arquitetura rejeitou receita sintética arma+arma: %s" % "; ".join(errors))
	_check(
		EvolutionCatalogScript.requirements_met(
			future_recipe,
			{"chaos_bolt": 8, "shadow_blades": 6},
			{}
		),
		"avaliador não reconheceu requisitos arma+arma completos"
	)
	_check(
		not EvolutionCatalogScript.requirements_met(
			future_recipe,
			{"chaos_bolt": 8, "shadow_blades": 5},
			{}
		),
		"avaliador aceitou arma parceira abaixo do requisito"
	)


func _test_validator_rejects_invalid_catalogs() -> void:
	var max_levels := _max_levels()
	var valid_recipe: Dictionary = EvolutionCatalogScript.recipes()[0]
	var cases: Array[Dictionary] = []
	var duplicate_id := valid_recipe.duplicate(true)
	duplicate_id.base_weapon = "shadow_blades"
	duplicate_id.requirements = [
		{"kind": "weapon", "id": "shadow_blades", "level": 6},
		{"kind": "passive", "id": "swiftness", "level": 3},
	]
	cases.append({"recipes": [valid_recipe, duplicate_id], "needle": "duplicado"})
	var duplicate_base := valid_recipe.duplicate(true)
	duplicate_base.id = "other_id"
	cases.append({"recipes": [valid_recipe, duplicate_base], "needle": "mais de uma receita"})
	var unknown_base := valid_recipe.duplicate(true)
	unknown_base.base_weapon = "missing_weapon"
	cases.append({"recipes": [unknown_base], "needle": "arma-base inexistente"})
	var invalid_slot := valid_recipe.duplicate(true)
	invalid_slot.slot_policy = "consume_both"
	cases.append({"recipes": [invalid_slot], "needle": "política de slot inválida"})
	var invalid_kind := valid_recipe.duplicate(true)
	invalid_kind.requirements[1].kind = "relic"
	cases.append({"recipes": [invalid_kind], "needle": "tipo de requisito inválido"})
	var unknown_item := valid_recipe.duplicate(true)
	unknown_item.requirements[1].id = "missing_passive"
	cases.append({"recipes": [unknown_item], "needle": "inexistente"})
	var invalid_level := valid_recipe.duplicate(true)
	invalid_level.requirements[1].level = 0
	cases.append({"recipes": [invalid_level], "needle": "nível inválido"})
	var excessive_level := valid_recipe.duplicate(true)
	excessive_level.requirements[1].level = 99
	cases.append({"recipes": [excessive_level], "needle": "acima do máximo"})
	var missing_base_requirement := valid_recipe.duplicate(true)
	missing_base_requirement.requirements.remove_at(0)
	cases.append({"recipes": [missing_base_requirement], "needle": "não exige a própria arma-base"})
	var repeated_requirement := valid_recipe.duplicate(true)
	repeated_requirement.requirements.append(repeated_requirement.requirements[1].duplicate(true))
	cases.append({"recipes": [repeated_requirement], "needle": "repete o requisito"})
	for case in cases:
		var errors := EvolutionCatalogScript.validation_errors(
			case.recipes, GameDefs.WEAPON_UPGRADE_IDS, GameDefs.PASSIVE_UPGRADE_IDS, max_levels
		)
		_check(
			errors.any(func(message: String): return str(case.needle) in message),
			"validador não detectou caso inválido: %s (%s)" % [str(case.needle), "; ".join(errors)]
		)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_physics_process(false)
	_test_current_recipes(world.player)
	_test_requirement_order_and_slots(world.player)
	_test_future_weapon_pair_support()
	_test_validator_rejects_invalid_catalogs()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("EVOLUTION CATALOG OK: 9 receitas, fachada legada, requisitos, slots, HUD e arma+arma futura validados")
		quit(0)
	else:
		quit(1)
