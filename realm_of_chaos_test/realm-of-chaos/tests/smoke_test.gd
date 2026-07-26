extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE TEST: " + message)


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false

	_check(is_instance_valid(world.player), "player não foi instanciado")
	_check(world.decorations.get_child_count() == 310, "mundo procedural incompleto")
	_check(world.hud != null, "HUD não foi instanciado")
	var starting_weapon_count := 0
	for weapon_id in world.player.WEAPON_IDS:
		if int(world.player.weapon_levels[weapon_id]) > 0:
			starting_weapon_count += 1
	_check(starting_weapon_count == 1 and world.player.equipped_weapon_id in world.player.WEAPON_IDS, "arma inicial não foi sorteada corretamente")
	_check(world.player.sprite.texture != null, "a aparência da arma sorteada não foi aplicada ao jogador")
	_check(world.player.sprite.hframes == 4 and world.player.sprite.vframes == 2, "jogador não usa a folha de animação 4x2")
	_check(is_equal_approx(world.RUN_DURATION, 1500.0), "partida não está configurada para 25 minutos")
	_check(world.BOSS_TIMES.size() == 5 and is_equal_approx(world.BOSS_TIMES[-1], 1500.0), "agenda de chefes incompleta")
	var boss_schedule := GameDefs.boss_schedule()
	_check(boss_schedule.size() == 5, "sequência de mini-chefes e chefe final incompleta")
	_check(float(boss_schedule[0].time) == 300.0 and float(boss_schedule[1].time) == 600.0 and float(boss_schedule[2].time) == 900.0 and float(boss_schedule[3].time) == 1200.0 and float(boss_schedule[4].time) == 1500.0, "chefes não estão agendados em 5, 10, 15, 20 e 25 minutos")
	_check(str(boss_schedule[4].kind) == "chaos_sovereign" and bool(boss_schedule[4].final), "Soberano do Caos não é o chefe final")
	var normal := GameDefs.difficulty_data(0.0)
	var hard := GameDefs.difficulty_data(300.0)
	var chaos := GameDefs.difficulty_data(600.0)
	var inferno := GameDefs.difficulty_data(900.0)
	_check(normal.id == "normal" and hard.id == "hard" and chaos.id == "chaos" and inferno.id == "inferno", "transições de dificuldade incorretas")
	_check(float(normal.interval) > float(hard.interval) and float(hard.interval) > float(chaos.interval) and float(chaos.interval) > float(inferno.interval), "spawn não acelera entre as fases")
	_check(int(normal.batch) < int(hard.batch) and int(hard.batch) < int(chaos.batch) and int(chaos.batch) < int(inferno.batch), "volume das hordas não cresce entre as fases")
	_check(float(normal.power) < float(hard.power) and float(hard.power) < float(chaos.power) and float(chaos.power) < float(inferno.power), "poder inimigo não cresce entre as fases")

	for kind in ["prowler", "bat", "mage", "brute", "ember", "bomber", "necromancer", "archer", "assassin", "swarm", "guardian"]:
		var enemy = world.spawn_enemy(kind)
		_check(enemy != null, "falha ao criar inimigo: " + kind)
		if enemy:
			enemy.global_position = world.player.global_position + Vector2(280, 0)
	await process_frame
	_check(world.enemies.get_child_count() >= 11, "diretor não manteve o bestiário expandido ativo")
	world._rebuild_spatial_grid()
	_check(world.get_enemies_near(world.player.global_position, 400.0).size() >= 11, "índice espacial não encontrou a horda próxima")
	_check(world.get_nearest_enemy(world.player.global_position) != null, "busca espacial não encontrou o alvo mais próximo")
	var animated_enemy = world.spawn_enemy("bat")
	animated_enemy.global_position = world.player.global_position + Vector2(310, 0)
	var initial_sprite_position: Vector2 = animated_enemy.sprite.position
	for _frame in range(6):
		await process_frame
	_check(not animated_enemy.sprite.position.is_equal_approx(initial_sprite_position), "inimigo permaneceu visualmente estático")
	animated_enemy.animation_clock = 0.0
	animated_enemy.attack_pulse = 0.0
	animated_enemy.cast_pulse = 0.0
	animated_enemy._animate_sprite(0.15)
	_check(animated_enemy.sprite.hframes == 4 and animated_enemy.sprite.frame == 1, "asas ou braços inimigos permaneceram estáticos")

	var target = world.spawn_enemy("prowler")
	target.global_position = world.player.global_position + Vector2(90, 0)
	target.attack_pulse = 1.0
	target._animate_sprite(0.01)
	_check(target.sprite.frame >= 2, "inimigo não exibiu o quadro de preparação do golpe")
	world.player.weapon_levels.chaos_bolt = maxi(1, int(world.player.weapon_levels.chaos_bolt))
	world.player._fire_chaos_bolt()
	_check(world.player.attack_flash > 0.0 and world.player.attack_recoil > 0.0, "jogador não reagiu visualmente ao ataque")
	world.player._animate_character(0.01, Vector2.RIGHT, false)
	_check(world.player.sprite.frame_coords.y == 1, "jogador não exibiu a sequência visual da arma ao atacar")
	await process_frame
	_check(world.projectiles.get_child_count() > 0, "arma principal não criou projétil")

	var kills_before: int = world.enemies_killed
	target.take_damage(99999.0)
	await process_frame
	_check(world.enemies_killed == kills_before + 1, "morte não incrementou contador")
	_check(world.pickups.get_child_count() > 0, "morte não gerou cristal de experiência")

	var old_damage: float = world.player.damage_multiplier
	world.player.apply_upgrade("might", "COMUM")
	_check(world.player.damage_multiplier > old_damage, "upgrade passivo não foi aplicado")
	world.player.apply_upgrade("soul_orbit", "RARO")
	_check(world.player.weapon_levels.soul_orbit > 0, "arma desbloqueável não foi aplicada")
	world.player.weapon_levels.chaos_bolt = 8
	world.player.passive_levels.critical = 3
	world.player._check_weapon_evolutions()
	_check(world.player.evolved_weapons.chaos_bolt, "Balista Abissal não evoluiu com a combinação correta")
	_check("BALISTA" in world.player.weapon_summary(), "HUD não identifica a arma evoluída")
	_check(world.player.get_upgrade_options(3).size() == 3, "seleção de upgrades incompleta")
	world._on_level_up_requested()
	await process_frame
	_check(world.upgrade_active and world.hud.upgrade_overlay.visible, "fluxo visual de level-up não abriu")
	world._on_upgrade_selected("magnet", "COMUM")
	_check(not paused and not world.hud.upgrade_overlay.visible, "fluxo de level-up não retomou a partida")
	var old_pickup_radius: float = world.player.pickup_radius
	world._trigger_world_event("soul_storm")
	_check(world.current_event == "soul_storm" and world.player.pickup_radius > old_pickup_radius, "evento Tempestade de Almas não foi aplicado")
	world._end_world_event()
	_check(is_equal_approx(world.player.pickup_radius, old_pickup_radius), "bônus temporário do evento não foi removido")
	var old_meta_damage: float = world.player.damage_multiplier
	world.player.apply_meta_bonuses({"power": 2, "vitality": 1, "speed": 1, "fortune": 1})
	_check(world.player.damage_multiplier > old_meta_damage and world.player.max_hp >= 135.0, "metaprogressão não aplicou bônus permanentes")

	for index in range(boss_schedule.size()):
		var scheduled_boss = world._spawn_scheduled_boss(boss_schedule[index], index)
		_check(scheduled_boss != null and scheduled_boss.boss and scheduled_boss.sprite.hframes == 4, "falha ao criar chefe agendado: " + str(boss_schedule[index].kind))
		if scheduled_boss:
			scheduled_boss.set_physics_process(false)
	_check(world.boss_spawn_log.size() == 5 and world.final_boss_spawned, "diretor não registrou os cinco confrontos")
	var final_boss = world.active_boss
	_check(final_boss.final_boss and final_boss.enemy_type == "chaos_sovereign", "chefe dos 25 minutos não foi marcado como final")
	final_boss.hp = final_boss.max_hp * 0.30
	final_boss._update_boss_phase()
	_check(final_boss.boss_phase == 3, "chefe final não entrou na terceira fase")
	var colossus = world.enemies.get_children().filter(func(candidate): return candidate.enemy_type == "ossuary_colossus")[0]
	colossus._begin_special("slam", 0.8)
	_check(colossus.pending_special == "slam" and colossus.telegraph_time > 0.0 and colossus.sprite.frame <= 3, "mini-chefe não sinalizou o ataque")

	world.hud.show_end_screen(false, 742.0, 99, 12)
	_check(world.hud.end_overlay.visible and world.hud.end_title.text == "GAME OVER", "tela de derrota não abriu")
	_check("12:22" in world.hud.end_summary.text and "99" in world.hud.end_summary.text, "resumo da derrota não mostra tempo e eliminações")
	world.hud.end_overlay.hide()
	world.hud.show_end_screen(true, 1500.0, 321, 28)
	_check(world.hud.end_title.text == "VITÓRIA!" and "25:00" in world.hud.end_summary.text and world.hud.get_node("EndOverlay/Panel/Margin/VBox/Restart").text == "PRÓXIMA FASE", "tela de vitória do chefe final incorreta")
	_check(world.hud.get_node("EndOverlay/Panel/Margin/VBox/Restart") != null and world.hud.get_node("EndOverlay/Panel/Margin/VBox/Menu") != null, "telas finais sem reiniciar ou menu")
	world.hud.end_overlay.hide()
	world.player.disabled = false
	world.player.invulnerability = 0.0
	world.player.dodge_chance = 0.0
	world.player.revive_charges = 0
	world.player.hp = 1.0
	world.player.take_damage(9999.0, Vector2.RIGHT)
	_check(world.player.death_started, "animação de morte do jogador não iniciou")
	await create_timer(1.0, true, false, true).timeout
	_check(world.game_ended and paused and world.hud.end_title.text == "GAME OVER", "morte do jogador não encerrou a partida")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("SMOKE TEST OK: horda expandida, evoluções, eventos, metaprogressão, mini-chefes e chefe final validados")
		quit(0)
	else:
		print("SMOKE TEST FALHOU: %d problema(s)" % failures.size())
		quit(1)
