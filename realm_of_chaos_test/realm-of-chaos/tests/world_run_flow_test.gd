extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")
const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


class AudioSpy:
	extends Node

	var calls: Array[String] = []
	var music_stage := ""

	func play_hit(critical := false) -> void:
		calls.append("hit:%s" % str(critical))

	func play_evolution() -> void:
		calls.append("evolution")

	func play_player_hurt() -> void:
		calls.append("player_hurt")

	func play_player_revive() -> void:
		calls.append("player_revive")

	func play_dash() -> void:
		calls.append("dash")

	func play_weapon_attack(weapon_id: String) -> void:
		calls.append("weapon:%s" % weapon_id)

	func play_shrine_activate() -> void:
		calls.append("shrine")

	func play_reward() -> void:
		calls.append("reward")

	func play_boss_spawn() -> void:
		calls.append("boss_spawn")

	func set_music_stage(stage_id: String) -> void:
		music_stage = stage_id
		calls.append("music:%s" % stage_id)


func _initialize() -> void:
	var watchdog := create_timer(15.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	push_error("WORLD RUN FLOW: teste excedeu 15 segundos")
	quit(2)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WORLD RUN FLOW: " + message)


func _create_world():
	paused = false
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var spy := AudioSpy.new()
	spy.name = "RunFlowAudioSpy"
	world.add_child(spy)
	world.audio = spy
	return world


func _count_pickups(world, kind: String) -> int:
	var count := 0
	for pickup in world.pickups.get_children():
		if is_instance_valid(pickup) and str(pickup.pickup_kind) == kind:
			count += 1
	return count


func _run() -> void:
	var world = await _create_world()
	var audio_spy = world.audio as AudioSpy

	for method_name in [
		&"_update_hud", &"handle_enemy_death", &"_spawn_reward_chest",
		&"open_reward_chest", &"_on_relic_selected", &"on_enemy_hit",
		&"on_weapon_evolved", &"on_boss_phase_changed", &"on_player_damaged",
		&"on_player_revived", &"on_player_dash", &"on_weapon_fired",
		&"activate_landmark", &"record_damage", &"record_player_damage",
		&"shake_camera", &"_on_level_up_requested", &"_show_next_upgrade",
		&"_present_upgrade_options", &"_on_upgrade_selected",
		&"_advance_upgrade_queue", &"_on_player_died", &"_end_run",
		&"_run_stats_text", &"_weapon_title", &"_restart_run",
		&"_return_to_menu", &"_resume_run"
	]:
		_check(world.has_method(method_name), "API publica ausente: %s" % method_name)

	world.time_survived = 65.0
	world.enemies_killed = 12
	world.essence_earned = 7
	world.last_stage = "I · CREPÚSCULO"
	world.current_event_title = "EVENTO DE TESTE"
	world._update_hud()
	_check(world.hud.timer_label.text == "23:55", "HUD alterou o tempo restante")
	_check("0012" in world.hud.kills_label.text and "007" in world.hud.essence_label.text, "HUD alterou contadores da partida")
	_check("I · CREPÚSCULO" in world.hud.stage_label.text, "HUD perdeu o estágio atual")
	_check(world.hud.world_event_label.text == "EVENTO DE TESTE", "HUD perdeu o evento ativo")
	_check(not world.hud.boss_panel.visible, "HUD mostrou chefe inexistente")

	world.record_damage("chaos_bolt", 72.4, false)
	world.record_damage("hunter_skill", 28.0, true)
	world.record_player_damage(19.2)
	_check(is_equal_approx(float(world.damage_by_source.chaos_bolt), 72.4), "dano por fonte não acumulou")
	_check(is_equal_approx(world.damage_taken, 19.2), "dano recebido não acumulou")
	_check(world._weapon_title("hunter_skill") == "Rajada do Eclipse", "título da habilidade especial mudou")
	_check(world._weapon_title("chaos_bolt") == "Besta do Caos", "título da arma mudou")
	_check(world._weapon_title("unknown_source") == "Unknown Source", "fallback do título mudou")
	var stats: String = world._run_stats_text()
	_check("Dano causado  101" in stats and "Besta do Caos (73)" in stats and "Dano recebido  20" in stats, "resumo estatístico mudou")

	world.accessibility_settings["shake"] = 1.0
	world.accessibility_settings["flash"] = 0.5
	var effects_before: int = world.effects.get_child_count()
	world.on_enemy_hit(world.player.global_position, 30.0, true, true)
	_check(world.effects.get_child_count() == effects_before + 2, "acerto crítico perdeu número ou efeito")
	_check(audio_spy.calls.has("hit:true"), "áudio do crítico não foi solicitado")
	world.on_weapon_evolved("ARMA DE TESTE")
	_check("ARMA DE TESTE" in world.hud.stage_banner.text and audio_spy.calls.has("evolution"), "feedback de evolução mudou")
	world.on_player_damaged()
	_check(audio_spy.calls.has("player_hurt") and world.hud.damage_flash.color.a > 0.0, "feedback de dano no jogador mudou")
	world.on_player_revived()
	_check(audio_spy.calls.has("player_revive") and "FÊNIX" in world.hud.stage_banner.text, "feedback de ressurreição mudou")
	world.on_player_dash(Vector2.RIGHT)
	world.on_weapon_fired("chaos_bolt")
	_check(audio_spy.calls.has("dash") and audio_spy.calls.has("weapon:chaos_bolt"), "feedback de dash ou disparo mudou")

	var tree_landmark: Node
	for landmark in world.landmarks.get_children():
		if str(landmark.landmark_kind) == "tree":
			tree_landmark = landmark
			break
	_check(is_instance_valid(tree_landmark), "santuário da árvore não foi criado")
	if is_instance_valid(tree_landmark):
		var nearby_pickup = world._spawn_pickup(3, world.player.global_position + Vector2(30.0, 0.0), "xp")
		var shrine_count_before: int = world.shrines_activated
		var essence_before_shrine: int = world.essence_earned
		world.activate_landmark(tree_landmark)
		_check(tree_landmark.activated and world.shrines_activated == shrine_count_before + 1, "ativação do santuário mudou")
		_check(world.essence_earned == essence_before_shrine + 4 and nearby_pickup.attracted, "recompensa ou atração do santuário mudou")
		_check(audio_spy.calls.has("shrine") and world.player.blessing_time == 40.0, "feedback ou duração da bênção mudou")
		world.activate_landmark(tree_landmark)
		_check(world.shrines_activated == shrine_count_before + 1, "santuário foi ativado duas vezes")

	world.player.relic_levels.clear()
	var chest = world._spawn_reward_chest(world.player.global_position + Vector2(320.0, 0.0), "GUARDIÃO DE TESTE")
	_check(chest.get_parent() == world.rewards and chest.world == world and chest.source_boss == "GUARDIÃO DE TESTE", "criação do baú mudou")
	world.open_reward_chest(chest)
	_check(paused and world.pending_chest == chest and world.hud.relic_overlay.visible, "abertura do baú não pausou e apresentou relíquias")
	_check(world.hud.relic_options.size() == 3 and audio_spy.calls.has("reward"), "opções ou áudio do baú mudaram")
	var chosen_relic := str(world.hud.relic_options[0].id)
	world._on_relic_selected(chosen_relic)
	_check(int(world.player.relic_levels.get(chosen_relic, 0)) == 1, "relíquia selecionada não foi aplicada")
	_check(not paused and world.pending_chest == null and not world.hud.relic_overlay.visible, "seleção da relíquia não retomou a partida")

	world._on_level_up_requested()
	await process_frame
	_check(paused and world.upgrade_active and world.pending_upgrades == 1, "fila de level up não abriu")
	_check(world.hud.upgrade_overlay.visible and world.hud.upgrade_options.size() == 3, "cartas de level up não foram apresentadas")
	_check(
		not world.hud.has_signal("reroll_requested")
		and not world.hud.has_signal("banish_requested")
		and not world.hud.has_signal("skip_requested"),
		"HUD ainda expõe sinais das ações removidas"
	)
	_check(
		world.hud.get_node_or_null("UpgradeOverlay/Panel/Margin/VBox/ChoiceActions") == null,
		"HUD ainda criou a linha de ações removida"
	)
	var selected_option: Dictionary = world.hud.upgrade_options[0]
	world._on_upgrade_selected(str(selected_option.id), str(selected_option.rarity))
	_check(not world.upgrade_active and world.pending_upgrades == 0, "escolha da carta não concluiu a fila")
	_check(not paused and not world.hud.upgrade_overlay.visible, "seleção da carta não retomou a partida")
	var might_before_stale_selection := int(world.player.passive_levels.might)
	world._on_upgrade_selected("might", "COMUM")
	_check(
		int(world.player.passive_levels.might) == might_before_stale_selection,
		"seleção atrasada aplicou upgrade fora do modal"
	)
	_check(world.pending_upgrades == 0 and not world.upgrade_active, "seleção atrasada corrompeu a fila de upgrades")

	world.pending_upgrades = 1
	world.upgrade_active = true
	world.player.hp = world.player.max_hp * 0.4
	var hp_before_fallback: float = world.player.hp
	var essence_before_fallback: int = world.essence_earned
	paused = true
	var no_upgrade_options: Array[Dictionary] = []
	world._present_upgrade_options(no_upgrade_options)
	_check(world.player.hp > hp_before_fallback and world.essence_earned == essence_before_fallback + 2, "fallback sem upgrades mudou")
	_check(not paused and not world.upgrade_active and world.pending_upgrades == 0, "fallback não concluiu a fila")

	var boss_entry: Dictionary = GameDefs.boss_schedule()[0]
	var boss = world._spawn_scheduled_boss(boss_entry, 0)
	_check(is_instance_valid(boss) and world.active_boss == boss, "mini-chefe de caracterização não foi criado")
	if is_instance_valid(boss):
		world.on_boss_phase_changed(boss, 2)
		_check("FASE 2" in world.hud.boss_label.text and world.active_boss_arena.phase == 2, "mudança de fase do chefe mudou")
		var xp_before_boss: int = _count_pickups(world, "xp")
		var rewards_before_boss: int = world.rewards.get_child_count()
		var bosses_before: int = world.bosses_defeated
		var essence_before_boss: int = world.essence_earned
		world.handle_enemy_death(boss, 120, false, true)
		_check(world.bosses_defeated == bosses_before + 1 and world.active_boss == null, "morte do mini-chefe não limpou o estado")
		_check(world.essence_earned == essence_before_boss + 18, "essência do mini-chefe mudou")
		_check(_count_pickups(world, "xp") >= xp_before_boss + 8, "recompensas de XP do mini-chefe mudaram")
		_check(world.rewards.get_child_count() == rewards_before_boss + 1, "baú do mini-chefe não surgiu")
		_check(audio_spy.music_stage == str(GameDefs.difficulty_data(world.time_survived).id), "música não voltou ao estágio após o chefe")

	paused = true
	world.upgrade_active = false
	world.game_ended = false
	world._resume_run()
	_check(not paused, "retomar partida mudou")

	world.queue_free()
	await process_frame

	var defeat_world = await _create_world()
	defeat_world.time_survived = 184.0
	defeat_world.enemies_killed = 44
	defeat_world.essence_earned = 13
	defeat_world.damage_by_source = {"chaos_bolt": 250.0}
	defeat_world.persistence.write_failed = true
	defeat_world._end_run(false)
	_check(defeat_world.game_ended and paused and defeat_world.hud.end_overlay.visible, "derrota não encerrou e pausou a partida")
	_check(defeat_world.hud.end_title.text == "GAME OVER" and "03:04" in defeat_world.hud.end_summary.text, "tela de derrota mudou")
	_check("NÃO FOI POSSÍVEL SALVAR O PROGRESSO" in defeat_world.hud.end_summary.text, "falha de escrita não apareceu no resumo final")
	defeat_world._end_run(true)
	_check(defeat_world.hud.end_title.text == "GAME OVER", "segunda finalização sobrescreveu o resultado")
	paused = false
	defeat_world.queue_free()
	await process_frame

	var victory_world = await _create_world()
	victory_world.time_survived = victory_world.RUN_DURATION
	victory_world._end_run(true)
	_check(victory_world.game_ended and paused and victory_world.hud.end_title.text == "VITÓRIA!", "vitória não encerrou corretamente")
	_check(victory_world.hud.end_restart_button.text == "PRÓXIMA FASE", "ação da vitória mudou")
	_check("NÃO FOI POSSÍVEL SALVAR O PROGRESSO" not in victory_world.hud.end_summary.text, "resumo normal exibiu aviso de save indevido")
	paused = false
	victory_world.queue_free()
	await process_frame

	if failures.is_empty():
		print("WORLD RUN FLOW OK: HUD, feedback, santuários, baús, upgrades, chefes e fim de partida validados")
		quit(0)
	else:
		quit(1)
