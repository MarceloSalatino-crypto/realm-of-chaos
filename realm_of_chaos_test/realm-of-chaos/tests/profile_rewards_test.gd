extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROFILE/REWARDS: " + message)


func _run() -> void:
	_check(str(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://scenes/main_menu.tscn", "menu principal não é a cena inicial do projeto")
	_check(GameDefs.characters().size() == 4, "catálogo de caçadores incompleto")
	var expected_starting_weapons := {
		"eclipse_hunter": "chaos_bolt",
		"glacial_oracle": "soul_orbit",
		"crimson_knight": "shadow_blades",
		"void_automaton": "chaos_nova"
	}
	for definition in GameDefs.characters():
		var character_id := str(definition.id)
		_check(
			str(definition.starting_weapon) == str(expected_starting_weapons.get(character_id, "")),
			"arma inicial temática incorreta: %s" % character_id
		)
	_check(GameDefs.relics().size() >= 10, "catálogo de relíquias incompleto")
	_check(GameDefs.achievements().size() >= 6, "catálogo de conquistas incompleto")

	var menu = load("res://scenes/main_menu.tscn").instantiate()
	menu.save_path = "user://profile_rewards_menu_test.cfg"
	root.add_child(menu)
	await process_frame
	_check(is_instance_valid(menu.profile_button), "botão de perfil não foi criado")
	_check(menu.profile_button.text == "PERFIL DO RITUAL", "menu não exibe o botão único de perfil")
	_check(menu.get_node_or_null("Menu/Meta") == null, "atalho antigo de Legado ainda existe no menu")
	_check(menu.get_node("Menu").get_child(1) == menu.profile_button, "Perfil do Ritual não está após Iniciar Ritual")
	menu._show_profile()
	await process_frame
	await process_frame
	_check(is_instance_valid(menu.popup) and menu.popup.scene_file_path == "res://scenes/profile_hub.tscn", "painel unificado de perfil não abriu")
	_check(str(menu.popup.current_tab) == "hunters", "fachada de perfil não abriu Caçadores")
	_check(menu.popup.tab_buttons.size() == 4, "Perfil do Ritual não criou as quatro abas")
	_check(menu.popup.character_grid.get_child_count() == 4, "aba Caçadores não exibe quatro cartões")
	for character_id in expected_starting_weapons:
		_check(menu.popup.find_child("Character_%s" % character_id, true, false) != null, "cartão ausente: %s" % character_id)
	menu.popup.show_tab("achievements")
	await process_frame
	_check(menu.popup.achievement_grid.get_child_count() == GameDefs.achievements().size(), "Conquistas não criou um cartão por conquista")
	menu.popup.show_tab("options")
	await process_frame
	_check(menu.popup.options_grid.get_child_count() == 6, "Opções não reuniu os controles previstos")
	menu._show_meta_progression()
	await process_frame
	await process_frame
	_check(str(menu.popup.current_tab) == "legacy", "fachada antiga de Legado não abre a aba correta")
	_check(menu.popup.legacy_list.get_child_count() == GameDefs.meta_upgrades().size(), "Legado não exibe todas as melhorias")
	menu.queue_free()
	await process_frame

	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	_check(world.landmarks.get_child_count() == 4 and world.landmark_positions.size() == 4, "mapa não criou os quatro santuários")
	_check(world.obstacles.get_child_count() == 24, "mapa não criou obstáculos físicos")
	_check(is_instance_valid(world.map_overlay) and is_instance_valid(world.hud.minimap), "caminhos ou minimapa não foram criados")
	_check(world.hazards.get_child_count() == 18, "perigos do bioma não foram distribuídos")
	var first_hazard = world.hazards.get_child(0)
	var environment: Dictionary = world.get_environment_effect(first_hazard.global_position)
	_check(float(environment.speed) != 1.0 or float(environment.traction) != 1.0 or float(environment.damage) > 0.0, "perigo do bioma não altera a física")
	_check(world.player.character_applied and not world.player.character_id.is_empty(), "caçador selecionado não foi aplicado")
	var active_character: Dictionary = GameDefs.character_data(world.player.character_id)
	var active_starting_weapon := str(active_character.starting_weapon)
	var active_weapon_count := 0
	for weapon_id in world.player.WEAPON_IDS:
		if int(world.player.weapon_levels[weapon_id]) > 0:
			active_weapon_count += 1
	_check(
		active_weapon_count == 1
		and world.player.equipped_weapon_id == active_starting_weapon
		and int(world.player.weapon_levels[active_starting_weapon]) == 1,
		"caçador do perfil não recebeu sua arma inicial exclusiva"
	)
	_check(world.player.movement_acceleration > 0.0 and world.player.movement_deceleration > 0.0, "movimento não usa aceleração natural")
	world.time_survived = 60.0
	var early_types: Dictionary = {}
	for _roll in range(48):
		early_types[world._pick_enemy_type()] = true
	_check(early_types.size() >= 3 and early_types.has("prowler") and (early_types.has("bat") or early_types.has("swarm")), "primeiro minuto ainda não possui variedade suficiente de inimigos")
	_check(InputMap.has_action("dash") and InputMap.has_action("map_toggle"), "controles de esquiva ou minimapa não foram registrados")
	var first_landmark = world.landmarks.get_child(0)
	world.activate_landmark(first_landmark)
	_check(first_landmark.activated and world.shrines_activated == 1, "santuário não foi ativado")
	_check(world.player.blessing_time > 0.0 and world.player.temporary_damage_multiplier > 1.0, "bênção temporária do altar não foi aplicada")
	world.player._start_dash(Vector2.RIGHT, world)
	_check(world.player.dash_cooldown > 0.0 and world.player.dash_duration > 0.0 and world.player.invulnerability > 0.0, "esquiva não concedeu impulso e proteção")

	var chest = world._spawn_reward_chest(world.player.global_position, "GUARDIÃO DE TESTE")
	world.open_reward_chest(chest)
	_check(paused and world.hud.relic_overlay.visible and world.hud.relic_options.size() == 3, "baú não abriu a seleção de relíquias")
	var chosen_id := ""
	for option in world.hud.relic_options:
		if str(option.id) != "phoenix_feather":
			chosen_id = str(option.id)
			break
	_check(not chosen_id.is_empty(), "seleção de relíquia não ofereceu opção segura")
	if not chosen_id.is_empty():
		world._on_relic_selected(chosen_id)
		_check(int(world.player.relic_levels.get(chosen_id, 0)) == 1, "efeito da relíquia não foi aplicado")
	_check(not paused and not world.hud.relic_overlay.visible, "partida não retomou após escolher relíquia")

	var target = world.spawn_enemy("brute", false, 1.0)
	target.global_position = world.player.global_position + Vector2(100.0, 0.0)
	target.take_damage(25.0, Vector2.RIGHT, false, "chaos_bolt")
	_check(float(world.damage_by_source.get("chaos_bolt", 0.0)) > 0.0, "dano por arma não foi registrado")
	_check("Besta do Caos" in world._run_stats_text(), "resumo não identifica a maior fonte de dano")
	world.hud.show_boss_intro("COLOSSO DE TESTE", "MINI-CHEFE", false)
	_check(world.hud.boss_intro.visible, "apresentação cinematográfica do chefe não abriu")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROFILE/REWARDS OK: menu, mapa, esquiva, santuários, baús, relíquias e estatísticas validados")
		quit(0)
	else:
		quit(1)
