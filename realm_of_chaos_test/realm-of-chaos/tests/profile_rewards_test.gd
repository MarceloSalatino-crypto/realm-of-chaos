extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROFILE/REWARDS: " + message)


func _run() -> void:
	_check(GameDefs.characters().size() == 4, "catálogo de caçadores incompleto")
	_check(GameDefs.relics().size() >= 10, "catálogo de relíquias incompleto")
	_check(GameDefs.achievements().size() >= 6, "catálogo de conquistas incompleto")

	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(is_instance_valid(menu.profile_button), "botão de perfil não foi criado")
	menu._show_profile()
	await process_frame
	_check(is_instance_valid(menu.popup) and menu.popup.get_child_count() >= 2, "painel de perfil não abriu")
	menu.queue_free()
	await process_frame

	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	_check(world.hazards.get_child_count() == 18, "perigos do bioma não foram distribuídos")
	var first_hazard = world.hazards.get_child(0)
	var environment: Dictionary = world.get_environment_effect(first_hazard.global_position)
	_check(float(environment.speed) != 1.0 or float(environment.traction) != 1.0 or float(environment.damage) > 0.0, "perigo do bioma não altera a física")
	_check(world.player.character_applied and not world.player.character_id.is_empty(), "caçador selecionado não foi aplicado")
	_check(world.player.movement_acceleration > 0.0 and world.player.movement_deceleration > 0.0, "movimento não usa aceleração natural")

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
		print("PROFILE/REWARDS OK: caçadores, opções, biomas, baús, relíquias e estatísticas validados")
		quit(0)
	else:
		quit(1)
