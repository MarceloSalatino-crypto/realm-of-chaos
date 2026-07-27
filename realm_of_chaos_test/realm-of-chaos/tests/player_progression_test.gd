extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")
const WORLD_SCENE = preload("res://scenes/world.tscn")
const EXPECTED_RARITY_FINGERPRINT := "RARO,COMUM,COMUM,RARO,RARO,RARO,RARO,RARO,COMUM,COMUM,COMUM,COMUM,COMUM,COMUM,COMUM,LENDÁRIO,RARO,COMUM,COMUM,COMUM,COMUM,COMUM,COMUM,COMUM"
const EXPECTED_OPTION_FINGERPRINT := "critical:COMUM:0:1:1:PASSIVO:COMBINA COM Besta Do Caos|armor:COMUM:0:1:1:PASSIVO:|blood_scythe:COMUM:0:1:1:NOVA ARMA:EVOLUI COM SANGUE ANCESTRAL NV.3|magnet:COMUM:0:1:1:PASSIVO:|haste:RARO:0:1:1:PASSIVO:|vitality:COMUM:0:1:1:PASSIVO:"

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	push_error("PLAYER PROGRESSION: teste excedeu 20 segundos")
	quit(2)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PLAYER PROGRESSION: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _reset_player(player) -> void:
	player.level = 1
	player.experience = 0
	player.experience_needed = 12
	player.weapon_levels.clear()
	player.evolved_weapons.clear()
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels["chaos_bolt"] = 1
	player.equipped_weapon_id = "chaos_bolt"
	for passive_id in player.passive_levels:
		player.passive_levels[passive_id] = 0
	player.relic_levels.clear()
	player.banished_upgrades.clear()
	player.move_speed = 235.0
	player.hp = 125.0
	player.max_hp = 125.0
	player.armor = 0.0
	player.regeneration = 0.0
	player.damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.crit_chance = 0.05
	player.critical_multiplier = 2.0
	player.pickup_radius = 105.0
	player.projectile_bonus = 0
	player.life_steal = 0.0
	player.boss_damage_multiplier = 1.0
	player.dodge_chance = 0.0
	player.revive_charges = 0
	player.character_id = "eclipse_hunter"
	player.character_applied = false
	player.character_color = Color.WHITE
	player.character_skill_name = "RAJADA DO ECLIPSE"
	player.blessing_time = 0.0
	player.blessing_title = ""
	player.temporary_damage_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.temporary_move_multiplier = 1.0
	player.temporary_pickup_multiplier = 1.0
	player.temporary_crit_bonus = 0.0
	player.temporary_armor = 0.0
	player.sprite.modulate = Color.WHITE


func _rarity_fingerprint(player) -> String:
	seed(197701)
	var rarities: Array[String] = []
	for _index in range(24):
		rarities.append(player._roll_rarity())
	return ",".join(rarities)


func _option_fingerprint(player) -> String:
	_reset_player(player)
	seed(448921)
	var options: Array[Dictionary] = player.get_upgrade_options(6)
	var signature: Array[String] = []
	for option in options:
		signature.append("%s:%s:%d:%d:%d:%s:%s" % [
			str(option.id), str(option.rarity), int(option.current_level),
			int(option.level), int(option.levels_gained), str(option.category),
			str(option.evolution_hint)
		])
	return "|".join(signature)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_physics_process(false)
	var player = world.player

	for method_name in [
		&"collect_xp", &"get_upgrade_options", &"is_build_complete", &"refresh_build_complete",
		&"_evolution_hint_for",
		&"active_weapon_count", &"banish_upgrade", &"_roll_rarity",
		&"get_upgrade_level", &"apply_upgrade", &"_upgrade_max",
		&"_check_weapon_evolutions", &"apply_meta_bonuses",
		&"apply_landmark_blessing", &"apply_character", &"get_relic_options",
		&"apply_relic", &"all_weapons_evolved", &"relic_summary",
		&"grant_boss_reward", &"weapon_summary", &"effective_damage_multiplier",
		&"effective_cooldown_multiplier", &"effective_crit_chance",
		&"effective_pickup_radius", &"equipped_weapon_title"
	]:
		_check(player.has_method(method_name), "API pública ausente: %s" % method_name)

	_reset_player(player)
	var weapon_levels_ref: Dictionary = player.weapon_levels
	var passive_levels_ref: Dictionary = player.passive_levels
	var evolved_weapons_ref: Dictionary = player.evolved_weapons
	var relic_levels_ref: Dictionary = player.relic_levels
	var banished_upgrades_ref: Dictionary = player.banished_upgrades
	weapon_levels_ref["chaos_bolt"] = 3
	passive_levels_ref["might"] = 2
	evolved_weapons_ref["chaos_bolt"] = true
	relic_levels_ref["phoenix_feather"] = 1
	banished_upgrades_ref["haste"] = true
	_check(int(player.weapon_levels.chaos_bolt) == 3, "weapon_levels deixou de ser acessível por referência")
	_check(int(player.passive_levels.might) == 2, "passive_levels deixou de ser acessível por referência")
	_check(bool(player.evolved_weapons.chaos_bolt), "evolved_weapons deixou de ser acessível por referência")
	_check(int(player.relic_levels.phoenix_feather) == 1, "relic_levels deixou de ser acessível por referência")
	_check(bool(player.banished_upgrades.haste), "banished_upgrades deixou de ser acessível por referência")
	player.weapon_levels["shadow_blades"] = 4
	_check(int(weapon_levels_ref.shadow_blades) == 4, "escrita externa em weapon_levels perdeu identidade")

	_reset_player(player)
	var world_level_callback := Callable(world, "_on_level_up_requested")
	if player.level_up_requested.is_connected(world_level_callback):
		player.level_up_requested.disconnect(world_level_callback)
	var emitted_levels := [0]
	player.level_up_requested.connect(func(): emitted_levels[0] += 1)
	player.collect_xp(40)
	_check(player.level == 3 and player.experience == 5 and player.experience_needed == 33, "progressão de múltiplos níveis mudou")
	_check(int(emitted_levels[0]) == 2, "sinal de level up não foi emitido uma vez por nível")

	var rarity_fingerprint := _rarity_fingerprint(player)
	var option_fingerprint := _option_fingerprint(player)
	print("PLAYER RARITY FINGERPRINT: " + rarity_fingerprint)
	print("PLAYER OPTION FINGERPRINT: " + option_fingerprint)
	if not EXPECTED_RARITY_FINGERPRINT.is_empty():
		_check(rarity_fingerprint == EXPECTED_RARITY_FINGERPRINT, "sequência determinística de raridades mudou")
	if not EXPECTED_OPTION_FINGERPRINT.is_empty():
		_check(option_fingerprint == EXPECTED_OPTION_FINGERPRINT, "conteúdo determinístico das opções mudou")

	_reset_player(player)
	var initial_options: Array[Dictionary] = player.get_upgrade_options(6)
	_check(initial_options.size() == 6, "quantidade de opções solicitada mudou")
	for option in initial_options:
		_check(option.has_all(["id", "level", "current_level", "levels_gained", "rarity", "category", "evolution_hint"]), "opção perdeu campos públicos")
		_check(str(option.rarity) in ["COMUM", "RARO", "LENDÁRIO"], "opção recebeu raridade inválida")
		_check(int(option.levels_gained) >= 1 and int(option.levels_gained) <= 2, "ganho de níveis da opção mudou")
	player.banish_upgrade("might")
	var options_without_might: Array[Dictionary] = player.get_upgrade_options(GameDefs.upgrades().size())
	for option in options_without_might:
		_check(str(option.id) != "might", "upgrade banido voltou às opções")

	_reset_player(player)
	for index in range(player.MAX_WEAPONS):
		player.weapon_levels[player.WEAPON_IDS[index]] = 1
	_check(player.active_weapon_count() == player.MAX_WEAPONS, "contagem do limite de armas mudou")
	var capped_options: Array[Dictionary] = player.get_upgrade_options(GameDefs.upgrades().size())
	for option in capped_options:
		var option_id := str(option.id)
		if player.weapon_levels.has(option_id):
			_check(int(player.weapon_levels[option_id]) > 0, "nova arma apareceu após atingir o limite")

	_reset_player(player)
	_check(player.get_upgrade_level("chaos_bolt") == 1 and player.get_upgrade_level("might") == 0, "consulta de nível mudou")
	for definition in GameDefs.upgrades():
		_check(player._upgrade_max(str(definition.id)) == int(definition.max), "limite divergiu do catálogo: %s" % str(definition.id))
	_check(player._upgrade_max("desconhecido") == 8, "fallback de limite mudou")
	player.apply_upgrade("might", "COMUM")
	_check(int(player.passive_levels.might) == 1, "upgrade passivo não avançou")
	_check_close(player.damage_multiplier, 1.15, "fórmula comum de Poder Profano mudou")
	player.apply_upgrade("soul_orbit", "LENDÁRIO")
	_check(int(player.weapon_levels.soul_orbit) == 2, "upgrade lendário de arma não avançou dois níveis")

	_reset_player(player)
	_check("OLHAR FATAL NV.3" in player._evolution_hint_for("chaos_bolt"), "dica de evolução da arma mudou")
	player.weapon_levels.chaos_nova = 3
	_check("Cajado Da Nova" in player._evolution_hint_for("might"), "sinergia do passivo mudou")
	player.weapon_levels.chaos_bolt = 8
	player.passive_levels.critical = 3
	var effects_before_evolution: int = world.effects.get_child_count()
	player._check_weapon_evolutions()
	_check(bool(player.evolved_weapons.chaos_bolt), "evolução válida não foi reconhecida")
	_check("BALISTA ABISSAL" in world.hud.stage_banner.text, "evolução não notificou o World")
	var effects_after_evolution: int = world.effects.get_child_count()
	player._check_weapon_evolutions()
	_check(world.effects.get_child_count() == effects_after_evolution and effects_after_evolution > effects_before_evolution, "evolução foi notificada mais de uma vez")

	_reset_player(player)
	player.apply_meta_bonuses({"power": 2, "vitality": 1, "speed": 1, "fortune": 1})
	_check_close(player.damage_multiplier, 1.10, "meta bônus de poder mudou")
	_check_close(player.max_hp, 135.0, "meta bônus de vitalidade mudou")
	_check_close(player.hp, 135.0, "meta bônus não restaurou vida")
	_check_close(player.move_speed, 242.05, "meta bônus de velocidade mudou")
	_check_close(player.crit_chance, 0.065, "meta bônus de fortuna mudou")

	var character_expectations := {
		"eclipse_hunter": [1.08, 125.0, 0.0, 1.0, 0.0],
		"glacial_oracle": [1.0, 125.0, 3.0, 0.90, 0.0],
		"crimson_knight": [1.0, 160.0, 0.0, 1.0, 0.004],
		"void_automaton": [1.18, 110.0, 0.0, 1.0, 0.0]
	}
	for character_id in character_expectations:
		_reset_player(player)
		var expected: Array = character_expectations[character_id]
		player.apply_character(character_id)
		var definition: Dictionary = GameDefs.character_data(character_id)
		_check(player.character_applied and player.character_id == character_id, "personagem não foi aplicado: %s" % character_id)
		_check(player.character_skill_name == str(definition.skill), "habilidade do personagem mudou: %s" % character_id)
		_check(player.sprite.modulate.is_equal_approx(Color(definition.color)), "cor do personagem mudou: %s" % character_id)
		_check_close(player.damage_multiplier, float(expected[0]), "dano do personagem mudou: %s" % character_id)
		_check_close(player.max_hp, float(expected[1]), "vida do personagem mudou: %s" % character_id)
		_check_close(player.armor, float(expected[2]), "armadura do personagem mudou: %s" % character_id)
		_check_close(player.cooldown_multiplier, float(expected[3]), "cooldown do personagem mudou: %s" % character_id)
		_check_close(player.life_steal, float(expected[4]), "roubo de vida do personagem mudou: %s" % character_id)
		_check_close(player.hp, player.max_hp, "personagem não iniciou com vida cheia: %s" % character_id)
	var character_before_repeat: String = player.character_id
	player.apply_character("eclipse_hunter")
	_check(player.character_id == character_before_repeat, "aplicação repetida substituiu o personagem")

	_reset_player(player)
	player.hp = 50.0
	_check(player.apply_landmark_blessing("altar", 40.0) == "FÚRIA RUBRA", "nome da bênção do altar mudou")
	_check_close(player.blessing_time, 40.0, "duração da bênção mudou")
	_check_close(player.temporary_damage_multiplier, 1.32, "bônus do altar mudou")
	_check_close(player.hp, 81.25, "cura do altar mudou")
	_reset_player(player)
	player.apply_landmark_blessing("obelisk", 32.0)
	_check_close(player.temporary_cooldown_multiplier, 0.72, "bônus do obelisco mudou")
	_check_close(player.temporary_crit_bonus, 0.12, "crítico do obelisco mudou")
	_reset_player(player)
	player.hp = 50.0
	player.apply_landmark_blessing("tree")
	_check_close(player.temporary_move_multiplier, 1.24, "movimento da árvore mudou")
	_check_close(player.temporary_pickup_multiplier, 2.6, "ímã da árvore mudou")
	_check_close(player.hp, 65.0, "cura da árvore mudou")
	_reset_player(player)
	player.apply_landmark_blessing("portal")
	_check_close(player.temporary_armor, 7.0, "armadura do portal mudou")
	_check_close(player.temporary_move_multiplier, 1.12, "movimento do portal mudou")
	player.damage_multiplier = 1.5
	player.cooldown_multiplier = 0.8
	player.crit_chance = 0.2
	player.pickup_radius = 120.0
	_check_close(player.effective_damage_multiplier(), 1.5, "getter efetivo de dano mudou")
	_check_close(player.effective_cooldown_multiplier(), 0.8, "getter efetivo de cooldown mudou")
	_check_close(player.effective_crit_chance(), 0.2, "getter efetivo de crítico mudou")
	_check_close(player.effective_pickup_radius(), 120.0, "getter efetivo de coleta mudou")

	var relic_ids: Array[String] = []
	for definition in GameDefs.relics():
		relic_ids.append(str(definition.id))
	_reset_player(player)
	var relic_options: Array[Dictionary] = player.get_relic_options(GameDefs.relics().size())
	_check(relic_options.size() == GameDefs.relics().size(), "catálogo inicial de relíquias mudou")
	for relic_id in relic_ids:
		_reset_player(player)
		player.apply_relic(relic_id)
		_check(int(player.relic_levels.get(relic_id, 0)) == 1, "nível da relíquia não avançou: %s" % relic_id)
		match relic_id:
			"glass_cannon":
				_check_close(player.damage_multiplier, 1.30, "dano do Canhão de Vidro mudou")
				_check_close(player.max_hp, 110.0, "penalidade do Canhão de Vidro mudou")
			"blood_fang":
				_check_close(player.life_steal, 0.0045, "Presa Sangrenta mudou")
			"storm_crown":
				_check(player.projectile_bonus == 1, "projétil da Coroa da Tempestade mudou")
				_check_close(player.damage_multiplier, 1.08, "dano da Coroa da Tempestade mudou")
			"void_boots":
				_check_close(player.move_speed, 263.2, "velocidade das Botas do Vazio mudou")
				_check_close(player.dodge_chance, 0.06, "esquiva das Botas do Vazio mudou")
			"magnet_core":
				_check_close(player.pickup_radius, 162.75, "alcance do Núcleo Magnético mudou")
				_check_close(player.move_speed, 253.8, "velocidade do Núcleo Magnético mudou")
			"boss_hunter":
				_check_close(player.boss_damage_multiplier, 1.25, "Selo do Caçador mudou")
			"phoenix_feather":
				_check(player.revive_charges == 1, "Pluma da Fênix mudou")
			"chrono_shard":
				_check_close(player.cooldown_multiplier, 0.88, "Fragmento Cronal mudou")
			"iron_heart":
				_check_close(player.max_hp, 155.0, "vida do Coração de Ferro mudou")
				_check_close(player.armor, 2.0, "armadura do Coração de Ferro mudou")
			"soul_lens":
				_check_close(player.crit_chance, 0.15, "crítico da Lente das Almas mudou")
				_check_close(player.critical_multiplier, 2.20, "multiplicador da Lente das Almas mudou")

	_reset_player(player)
	player.apply_relic("phoenix_feather")
	var options_after_unique: Array[Dictionary] = player.get_relic_options(GameDefs.relics().size())
	for option in options_after_unique:
		_check(str(option.id) != "phoenix_feather", "relíquia no máximo voltou às opções")
	player.relic_levels["glass_cannon"] = 2
	var relic_text: String = player.relic_summary()
	_check("Canhão De Vidro 2" in relic_text and "Pluma Da Fênix 1" in relic_text, "resumo de relíquias mudou")

	_reset_player(player)
	for index in range(player.MAX_WEAPONS):
		var weapon_id: String = player.WEAPON_IDS[index]
		player.weapon_levels[weapon_id] = 1
		player.evolved_weapons[weapon_id] = true
	_check(player.all_weapons_evolved(), "seis armas evoluídas não foram reconhecidas")
	player.evolved_weapons[player.WEAPON_IDS[0]] = false
	_check(not player.all_weapons_evolved(), "build parcialmente evoluída foi aceita")
	player.evolved_weapons[player.WEAPON_IDS[0]] = true
	var weapon_text: String = player.weapon_summary()
	_check("\n" in weapon_text and "BALISTA" in weapon_text, "resumo expandido das armas mudou")

	_reset_player(player)
	player.hp = 10.0
	player.grant_boss_reward(false)
	_check_close(player.damage_multiplier, 1.045, "dano da recompensa de mini-chefe mudou")
	_check_close(player.max_hp, 130.0, "vida da recompensa de mini-chefe mudou")
	_check_close(player.hp, 33.4, "cura da recompensa de mini-chefe mudou")
	_reset_player(player)
	player.hp = 10.0
	player.grant_boss_reward(true)
	_check_close(player.damage_multiplier, 1.08, "dano da recompensa final mudou")
	_check_close(player.max_hp, 137.0, "vida da recompensa final mudou")
	_check_close(player.hp, 57.95, "cura da recompensa final mudou")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER PROGRESSION OK: campos públicos, XP, upgrades, evoluções, personagens, bênçãos, relíquias e resumos validados")
		quit(0)
	else:
		quit(1)
