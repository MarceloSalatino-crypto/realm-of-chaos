extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const HOMING_EYE_SCRIPT = preload("res://scripts/homing_eye.gd")
const LEGION_FOCUS_SCRIPT = preload("res://scripts/legion_focus.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("LEGION EYE PILOT: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("LEGION EYE PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(
		is_equal_approx(actual, expected),
		"%s (esperado %.4f, obtido %.4f)" % [message, expected, actual]
	)


func _prepare_player(player, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.swarm_idol = 6
	player.evolved_weapons.swarm_idol = evolved
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.critical_multiplier = 2.0
	player.boss_damage_multiplier = 1.0
	player.swarm_timer = 0.0
	player.combat.legion_cast_count = 0


func _spawn_target(world, position: Vector2, kind := "prowler", elite := false) -> Node:
	var enemy = world.spawn_enemy(kind, elite, 1.0)
	enemy.global_position = position
	enemy.hp = 10_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.knockback_velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _eyes(world) -> Array[Node]:
	var result: Array[Node] = []
	for projectile in world.projectiles.get_children():
		if projectile.get_script() == HOMING_EYE_SCRIPT:
			result.append(projectile)
	return result


func _freeze_eyes(world) -> Array[Node]:
	var result := _eyes(world)
	for eye in result:
		eye.set_physics_process(false)
	return result


func _find_legion_focus(world) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == LEGION_FOCUS_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _clear_combat_nodes(world) -> void:
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
	for effect in world.effects.get_children():
		effect.queue_free()
	await process_frame
	world._rebuild_spatial_grid()


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO

	_prepare_player(world.player, false)
	for index in range(10):
		_spawn_target(world, Vector2(180.0 + index * 38.0, 30.0 * float(index % 2)))
	world._rebuild_spatial_grid()
	var base_candidates: Array[Node] = world.get_enemies_near(world.player.global_position, 900.0)
	world.player._release_swarm_eyes(6)
	var base_eyes := _freeze_eyes(world)
	_check(base_eyes.size() == 5, "Ídolo base deixou de criar cinco olhos no nível 6")
	_check_close(world.player.swarm_timer, 1.74, "cooldown base mudou")
	for index in range(base_eyes.size()):
		var eye: Node = base_eyes[index]
		_check_close(float(eye.damage), 48.0, "dano base mudou no olho %d" % index)
		_check_close(float(eye.speed), 350.0, "velocidade base mudou no olho %d" % index)
		_check_close(float(eye.lifetime), 4.0, "duração base mudou no olho %d" % index)
		_check_close(eye.global_position.distance_to(Vector2.ZERO), 28.0, "raio inicial base mudou")
		_check(eye.target == base_candidates[index], "ordem/seleção base mudou no olho %d" % index)
		_check(eye.sprite != null and eye.sprite.frame == 4, "sprite base do olho mudou")
		_check(eye.sprite.modulate == Color("d9a2ff"), "cor base do olho mudou")
	_check(
		world.player_projectile_batch_renderer._entries.is_empty(),
		"olhos base passaram a usar batching sem caracterização"
	)
	var base_hit_target: Node = base_eyes[0].target
	base_eyes[0].global_position = base_hit_target.global_position
	base_eyes[0]._physics_process(0.0)
	_check_close(10_000.0 - float(base_hit_target.hp), 48.0, "dano real do Ídolo base mudou")
	_check_close(base_hit_target.knockback_velocity.length(), 18.0, "impulso real do Ídolo base mudou")
	await _clear_combat_nodes(world)

	_prepare_player(world.player, false)
	world.player._release_swarm_eyes(6)
	_check(_eyes(world).is_empty(), "Ídolo base criou olhos sem inimigos")
	_check_close(world.player.swarm_timer, 1.74, "tentativa sem alvo mudou o cooldown base")

	_prepare_player(world.player, true)
	for index in range(12):
		_spawn_target(world, Vector2(160.0 + index * 42.0, 22.0 * float(index % 3)))
	world._rebuild_spatial_grid()
	var evolved_candidates: Array[Node] = world.get_enemies_near(world.player.global_position, 900.0)
	world.player._release_swarm_eyes(6)
	var evolved_eyes := _freeze_eyes(world)
	_check(evolved_eyes.size() == 8, "Olho da Legião atual deixou de criar oito olhos")
	_check_close(world.player.swarm_timer, 1.218, "cooldown evoluído atual mudou")
	for index in range(evolved_eyes.size()):
		var eye: Node = evolved_eyes[index]
		_check_close(float(eye.damage), 80.64, "dano evoluído atual mudou no olho %d" % index)
		_check_close(float(eye.speed), 430.0, "velocidade evoluída atual mudou no olho %d" % index)
		_check_close(float(eye.lifetime), 4.0, "duração evoluída atual mudou")
		_check(eye.target == evolved_candidates[index], "seleção evoluída atual mudou no olho %d" % index)
		_check(eye.sprite.modulate == Color("d9a2ff"), "evolução atual ganhou visual não caracterizado")
	_check(
		world.player_projectile_batch_renderer._entries.is_empty(),
		"olhos evoluídos atuais deixaram de ser Nodes/Sprites independentes"
	)
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	world.player.crit_chance = 1.0
	var boss = _spawn_target(world, Vector2(220.0, 0.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var boss_eyes := _freeze_eyes(world)
	_check(boss_eyes.size() == 8, "alvo único/boss mudou a quantidade atual")
	var first_boss_eye: Node = boss_eyes[0]
	_check(bool(first_boss_eye.critical), "crítico evoluído atual não foi preservado")
	first_boss_eye.global_position = boss.global_position
	first_boss_eye._physics_process(0.0)
	_check_close(10_000.0 - float(boss.hp), 161.28, "dano crítico atual no boss mudou")
	_check_close(boss.knockback_velocity.length(), 18.0 * 0.34, "resistência do boss ao impulso mudou")
	await _clear_combat_nodes(world)

	# As duas primeiras ativações evoluídas continuam sendo as oito entidades históricas.
	await _clear_combat_nodes(world)
	_prepare_player(world.player, true)
	for index in range(10):
		_spawn_target(world, Vector2(160.0 + index * 46.0, 20.0 * float(index % 2)))
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	_check(_freeze_eyes(world).size() == 8, "primeiro disparo evoluído deixou de ser a rajada normal")
	await _clear_combat_nodes(world)
	for index in range(10):
		_spawn_target(world, Vector2(160.0 + index * 46.0, 20.0 * float(index % 2)))
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	_check(_freeze_eyes(world).size() == 8, "segundo disparo evoluído deixou de ser a rajada normal")
	_check(not is_instance_valid(_find_legion_focus(world)), "foco ativou antes do terceiro disparo")
	await _clear_combat_nodes(world)

	# No terceiro disparo uma decisão central prioriza boss, depois elite, depois distância.
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	var nearest_common = _spawn_target(world, Vector2(145.0, 0.0))
	var priority_elite = _spawn_target(world, Vector2(275.0, 0.0), "guardian", true)
	var priority_boss = _spawn_target(world, Vector2(520.0, 0.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	_check(_eyes(world).is_empty(), "janela de foco também criou olhos independentes")
	var focus = _find_legion_focus(world)
	_check(is_instance_valid(focus), "terceiro disparo não criou o foco coordenado")
	if is_instance_valid(focus):
		focus.set_process(false)
		var signature: Dictionary = focus.visual_signature()
		_check(int(signature.eye_count) == 8, "formação coordenada não manteve oito olhos")
		_check_close(float(signature.focus_range), 900.0, "alcance do foco mudou")
		_check_close(float(signature.eye_knockback), 18.0, "impulso por olho mudou")
		_check_close(float(signature.mark_time), 0.10, "tempo da marca mudou")
		_check_close(float(signature.first_strike_time), 0.34, "primeiro ataque coordenado mudou")
		_check_close(float(signature.second_strike_time), 0.50, "segundo ataque coordenado mudou")
		_check_close(float(signature.redistribute_time), 0.58, "redistribuição mudou")
		_check_close(float(signature.duration), 0.78, "duração da janela mudou")
		_check(focus.current_focus_target() == priority_boss, "boss não recebeu prioridade sobre elite/comum")
		focus._process(0.33)
		_check_close(10_000.0 - float(priority_boss.hp), 0.0, "foco causou dano antes do ataque visual")
		focus._process(0.011)
		_check_close(10_000.0 - float(priority_boss.hp), 322.56, "primeira salva não aplicou quatro olhos")
		focus._process(0.16)
		_check_close(10_000.0 - float(priority_boss.hp), 645.12, "duas salvas não preservaram oito olhos")
		_check_close(priority_boss.knockback_velocity.length(), 8.0 * 18.0 * 0.34, "resistência de boss ao impulso não foi preservada")
		_check_close(10_000.0 - float(priority_elite.hp), 0.0, "foco vazou dano para a elite")
		_check_close(10_000.0 - float(nearest_common.hp), 0.0, "foco vazou dano para o alvo comum")
		signature = focus.visual_signature()
		_check(int(signature.attack_stage_count) == 2, "foco não concluiu exatamente duas salvas")
		_check(int(signature.successful_wave_count) == 2, "contagem de salvas bem-sucedidas incorreta")
		_check(int(signature.hit_count) == 8, "foco não registrou oito impactos")
		_check(int(signature.focus_decision_count) == 1, "foco fez mais de uma busca sem perder o alvo")
		var formation_distance: float = focus.eye_positions[0].distance_to(Vector2.ZERO)
		focus._process(0.10)
		_check_close(10_000.0 - float(priority_boss.hp), 645.12, "foco repetiu dano depois das duas salvas")
		focus._process(0.04)
		_check(
			focus.eye_positions[0].distance_to(Vector2.ZERO) < formation_distance,
			"olhos não começaram a se redistribuir para o jogador"
		)
		focus._process(0.15)
		_check(focus.is_queued_for_deletion(), "janela de foco não terminou após 0.78s")
	await _clear_combat_nodes(world)

	# Críticos continuam sendo rolados por olho e preservam exatamente o total anterior.
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	world.player.crit_chance = 1.0
	var critical_boss = _spawn_target(world, Vector2(260.0, 0.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var critical_focus = _find_legion_focus(world)
	_check(is_instance_valid(critical_focus), "foco crítico não foi criado")
	if is_instance_valid(critical_focus):
		critical_focus.set_process(false)
		critical_focus._process(0.51)
	_check_close(10_000.0 - float(critical_boss.hp), 1290.24, "oito críticos não preservaram o dano histórico")
	await _clear_combat_nodes(world)

	# Alvo morto antes da primeira salva: uma única nova decisão transfere o foco.
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	var dead_priority = _spawn_target(world, Vector2(260.0, 0.0), "ossuary_colossus")
	var dead_replacement = _spawn_target(world, Vector2(340.0, 0.0), "guardian", true)
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var dead_focus = _find_legion_focus(world)
	dead_priority.dead = true
	dead_priority.remove_from_group("enemies")
	if is_instance_valid(dead_focus):
		dead_focus.set_process(false)
		dead_focus._process(0.35)
		_check(dead_focus.current_focus_target() == dead_replacement, "foco não trocou alvo morto")
		_check_close(10_000.0 - float(dead_replacement.hp), 322.56, "alvo substituto não recebeu a primeira salva")
		var dead_signature: Dictionary = dead_focus.visual_signature()
		_check(int(dead_signature.retarget_count) == 1, "alvo morto gerou número incorreto de retargets")
		_check(int(dead_signature.focus_decision_count) == 2, "alvo morto não fez exatamente uma nova busca")
	await _clear_combat_nodes(world)

	# Alvo removido entre salvas: a segunda salva encontra um substituto sem referência inválida.
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	var removed_priority = _spawn_target(world, Vector2(260.0, 0.0), "ossuary_colossus")
	var removed_replacement = _spawn_target(world, Vector2(350.0, 0.0), "guardian", true)
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var removed_focus = _find_legion_focus(world)
	if is_instance_valid(removed_focus):
		removed_focus.set_process(false)
		removed_focus._process(0.35)
		_check_close(10_000.0 - float(removed_priority.hp), 322.56, "primeira salva no alvo removido mudou")
		removed_priority.queue_free()
		await process_frame
		world._rebuild_spatial_grid()
		removed_focus._process(0.16)
		_check(removed_focus.current_focus_target() == removed_replacement, "foco manteve referência liberada")
		_check_close(10_000.0 - float(removed_replacement.hp), 322.56, "segunda salva não migrou para o substituto")
	await _clear_combat_nodes(world)

	# Alvo vivo que sai dos 900px também força uma única troca central.
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	var distant_priority = _spawn_target(world, Vector2(260.0, 0.0), "ossuary_colossus")
	var distant_replacement = _spawn_target(world, Vector2(330.0, 0.0), "guardian", true)
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var distant_focus = _find_legion_focus(world)
	distant_priority.global_position = Vector2(1200.0, 0.0)
	world._rebuild_spatial_grid()
	if is_instance_valid(distant_focus):
		distant_focus.set_process(false)
		distant_focus._process(0.35)
		_check(distant_focus.current_focus_target() == distant_replacement, "foco não abandonou alvo fora do alcance")
		_check_close(10_000.0 - float(distant_replacement.hp), 322.56, "troca por alcance perdeu a salva")
	await _clear_combat_nodes(world)

	# Se o alvo morrer dentro da primeira salva, impactos restantes não duplicam dano.
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	var fragile_priority = _spawn_target(world, Vector2(240.0, 0.0), "ossuary_colossus")
	fragile_priority.hp = 100.0
	fragile_priority.max_hp = 100.0
	var wave_replacement = _spawn_target(world, Vector2(330.0, 0.0), "guardian", true)
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var interrupted_focus = _find_legion_focus(world)
	if is_instance_valid(interrupted_focus):
		interrupted_focus.set_process(false)
		interrupted_focus._process(0.35)
		_check(bool(fragile_priority.dead), "alvo frágil não morreu durante a primeira salva")
		interrupted_focus._process(0.16)
		_check(interrupted_focus.current_focus_target() == wave_replacement, "segunda salva não buscou alvo após morte no meio do ataque")
		_check_close(10_000.0 - float(wave_replacement.hp), 322.56, "segunda salva após morte não manteve quatro impactos")
		_check(int(interrupted_focus.visual_signature().hit_count) == 6, "morte no meio da salva duplicou ou perdeu impactos")
	await _clear_combat_nodes(world)

	# Sem substituto, as duas salvas são canceladas sem dano, loop ou erro.
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	var lone_priority = _spawn_target(world, Vector2(260.0, 0.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var lone_focus = _find_legion_focus(world)
	lone_priority.dead = true
	lone_priority.remove_from_group("enemies")
	world._rebuild_spatial_grid()
	if is_instance_valid(lone_focus):
		lone_focus.set_process(false)
		lone_focus._process(0.51)
		var lone_signature: Dictionary = lone_focus.visual_signature()
		_check(int(lone_signature.cancelled_wave_count) == 2, "salvas sem alvo não foram canceladas")
		_check(int(lone_signature.hit_count) == 0, "foco sem alvo causou dano")
		_check(int(lone_signature.focus_decision_count) == 3, "cada salva cancelada não fez uma única decisão central")
	await _clear_combat_nodes(world)

	# Saturação: o visual crítico substitui cosmético, não aumenta os tetos e preserva o dano.
	for index in range(world.MAX_EFFECTS):
		var cosmetic := Node2D.new()
		cosmetic.name = "LegionCosmetic%d" % index
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)
	for index in range(world.MAX_PLAYER_PROJECTILES):
		var projectile_placeholder := Node2D.new()
		projectile_placeholder.name = "LegionProjectileCap%d" % index
		world.projectiles.add_child(projectile_placeholder)
	_prepare_player(world.player, true)
	world.player.combat.legion_cast_count = 2
	var saturated_target = _spawn_target(world, Vector2(220.0, 0.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	var saturated_focus = _find_legion_focus(world)
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "foco ultrapassou 120 efeitos")
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "foco alterou o teto de 360 projéteis")
	_check(is_instance_valid(saturated_focus), "visual essencial sumiu com 120 efeitos")
	if is_instance_valid(saturated_focus):
		saturated_focus.set_process(false)
		saturated_focus._process(0.51)
	_check_close(10_000.0 - float(saturated_target.hp), 645.12, "saturação impediu o dano coordenado")

	print(
		"LEGION EYE AFTER: base intacta=5 olhos/48 dano/350 velocidade/1.74s; "
		+ "evoluída normal=8 olhos/80.64 dano/430 velocidade/1.218s; "
		+ "cada 3ª ativação=foco central 4+4, 645.12 dano potencial, 900 alcance, 0.78s"
	)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
