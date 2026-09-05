extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const EFFECT_SCRIPT = preload("res://scripts/effect.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("CATACLYSM HAMMER PILOT: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CATACLYSM HAMMER PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(
		is_equal_approx(actual, expected),
		"%s (esperado %.4f, obtido %.4f)" % [message, expected, actual]
	)


func _prepare_player(player, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.rune_hammer = 6
	player.evolved_weapons.rune_hammer = evolved
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.hammer_timer = 0.0
	player.last_direction = Vector2.RIGHT


func _spawn_target(world, position: Vector2, kind := "prowler", force_elite := false) -> Node:
	var enemy = world.spawn_enemy(kind, force_elite, 1.0)
	enemy.global_position = position
	enemy.hp = 10_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.knockback_velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _clear_combat_nodes(world) -> void:
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	for effect in world.effects.get_children():
		effect.queue_free()
	await process_frame
	world._rebuild_spatial_grid()


func _find_largest_generic_effect(world) -> Node:
	var selected: Node = null
	for effect in world.effects.get_children():
		if effect.get_script() != EFFECT_SCRIPT:
			continue
		if not is_instance_valid(selected) or float(effect.max_radius) > float(selected.max_radius):
			selected = effect
	return selected


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
	var base_target = _spawn_target(world, Vector2(250.0, 0.0))
	var base_inside = _spawn_target(world, Vector2(235.0, 170.0))
	var base_outside = _spawn_target(world, Vector2(235.0, 240.0))
	world._rebuild_spatial_grid()
	world.player._slam_rune_hammer(6)
	_check_close(10_000.0 - float(base_target.hp), 92.0, "dano do Martelo base mudou")
	_check_close(10_000.0 - float(base_inside.hp), 92.0, "área do Martelo base encolheu")
	_check_close(10_000.0 - float(base_outside.hp), 0.0, "área do Martelo base cresceu")
	_check_close(world.player.hammer_timer, 2.22, "cooldown do Martelo base mudou")
	_check_close(base_target.knockback_velocity.x, 105.0, "knockback do Martelo base mudou")
	var base_effect = _find_largest_generic_effect(world)
	_check(is_instance_valid(base_effect), "Martelo base não criou efeito")
	if is_instance_valid(base_effect):
		_check_close(base_effect.global_position.x, 235.0, "origem do impacto base mudou")
		_check_close(base_effect.global_position.y, 0.0, "origem vertical do impacto base mudou")
		_check_close(float(base_effect.max_radius), 177.0, "raio visual do Martelo base mudou")
		_check_close(float(base_effect.duration), 0.50, "duração visual do Martelo base mudou")
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	var evolved_target = _spawn_target(world, Vector2(300.0, 0.0))
	var evolved_inside = _spawn_target(world, Vector2(235.0, 225.0))
	var evolved_outside = _spawn_target(world, Vector2(235.0, 290.0))
	var fissure_only = _spawn_target(world, Vector2(600.0, 0.0))
	var fissure_off_axis = _spawn_target(world, Vector2(600.0, 120.0))
	var evolved_elite = _spawn_target(world, Vector2(235.0, -200.0), "brute", true)
	world._rebuild_spatial_grid()
	world.player._slam_rune_hammer(6)
	_check_close(10_000.0 - float(evolved_target.hp), 147.2, "impacto principal não recebeu 80% do dano")
	_check_close(10_000.0 - float(evolved_inside.hp), 147.2, "área principal do Cataclismo encolheu")
	_check_close(10_000.0 - float(evolved_outside.hp), 0.0, "área atual do Cataclismo cresceu")
	_check_close(10_000.0 - float(fissure_only.hp), 0.0, "fissura causou dano antes de avançar")
	_check_close(10_000.0 - float(evolved_elite.hp), 147.2, "impacto principal falhou no elite")
	_check_close(world.player.hammer_timer, 1.6428, "cooldown atual do Cataclismo mudou")
	_check_close(evolved_target.knockback_velocity.x, 185.0, "knockback atual do Cataclismo mudou")
	var rupture = world.effects.get_node_or_null("CataclysmRupture")
	_check(is_instance_valid(rupture), "ruptura do Cataclismo não foi criada")
	if is_instance_valid(rupture):
		rupture.set_process(false)
		var signature: Dictionary = rupture.visual_signature()
		_check_close(float(signature.primary_damage_fraction), 0.80, "fração do impacto mudou")
		_check_close(float(signature.fissure_damage_fraction), 0.20, "fração da fissura mudou")
		_check(int(signature.rupture_count) == 3, "fissura não possui três rupturas")
		_check_close(float(signature.main_radius), 230.0, "raio principal do Cataclismo mudou")
		_check_close(float(signature.fissure_reach), 415.0, "alcance da fissura mudou")
		_check_close(float(signature.duration), 0.58, "duração da ruptura mudou")

	rupture._process(0.11)
	_check_close(10_000.0 - float(evolved_target.hp), 184.0, "impacto + fissura não preservaram dano 184")
	_check_close(evolved_target.knockback_velocity.x, 185.0, "fissura duplicou knockback do impacto")
	_check_close(10_000.0 - float(evolved_inside.hp), 184.0, "alvo fora do eixo perdeu parte do dano histórico")
	_check_close(10_000.0 - float(evolved_elite.hp), 184.0, "elite perdeu parte do dano histórico")
	_check_close(10_000.0 - float(fissure_only.hp), 0.0, "primeira ruptura avançou além do segmento")

	rupture._process(0.10)
	_check_close(10_000.0 - float(evolved_target.hp), 184.0, "segmentos sobrepostos duplicaram dano")
	rupture._process(0.10)
	_check_close(10_000.0 - float(fissure_only.hp), 36.8, "fissura distante aplicou dano incorreto")
	_check_close(fissure_only.knockback_velocity.x, 86.0, "fissura distante aplicou knockback incorreto")
	_check_close(10_000.0 - float(fissure_off_axis.hp), 0.0, "fissura ultrapassou sua largura")
	_check_close(10_000.0 - float(evolved_inside.hp), 184.0, "alvo fora da fissura recebeu dano duplicado")
	_check(int(rupture.rupture_stage_count) == 3, "ruptura não processou os três estágios")
	print(
		"CATACLYSM AFTER: base preservada em 92/raio177/cooldown2.22/knockback105; "
		+ "evoluído=147.2 impacto + 36.8 fissura, total184/raio230/cooldown1.6428/knockback185"
	)

	await _clear_combat_nodes(world)
	_prepare_player(world.player, true)
	var aim_target = _spawn_target(world, Vector2(250.0, 0.0))
	var boss_target = _spawn_target(world, Vector2(335.0, 120.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	world.player._slam_rune_hammer(6)
	_check_close(10_000.0 - float(boss_target.hp), 147.2, "impacto principal falhou no boss")
	_check_close(boss_target.knockback_velocity.length(), 185.0 * 0.34, "resistência de knockback do boss mudou")
	_check(10_000.0 - float(aim_target.hp) > 0.0, "alvo de mira não recebeu impacto")
	var boss_rupture = world.effects.get_node_or_null("CataclysmRupture")
	if is_instance_valid(boss_rupture):
		boss_rupture.set_process(false)
		boss_rupture._process(0.11)
	_check_close(10_000.0 - float(boss_target.hp), 184.0, "boss perdeu parte do dano histórico")
	_check_close(boss_target.knockback_velocity.length(), 185.0 * 0.34, "aftershock duplicou knockback do boss")

	await _clear_combat_nodes(world)
	_prepare_player(world.player, true)
	var dying_target = _spawn_target(world, Vector2(300.0, 0.0))
	dying_target.hp = 170.0
	dying_target.max_hp = 170.0
	world._rebuild_spatial_grid()
	world.player._slam_rune_hammer(6)
	_check(not dying_target.dead, "impacto principal matou antes do tremor planejado")
	_check_close(float(dying_target.hp), 22.8, "vida antes do tremor ficou incorreta")
	var dying_rupture = world.effects.get_node_or_null("CataclysmRupture")
	_check(is_instance_valid(dying_rupture), "ruptura não existe no cenário de morte intermediária")
	# Simula outra fonte eliminando o alvo entre o impacto e a propagação.
	dying_target.dead = true
	dying_target.remove_from_group("enemies")
	var hp_when_removed: float = dying_target.hp
	if is_instance_valid(dying_rupture):
		dying_rupture.set_process(false)
		dying_rupture._process(0.31)
	_check_close(float(dying_target.hp), hp_when_removed, "fissuras voltaram a atingir inimigo morto")

	await _clear_combat_nodes(world)
	_prepare_player(world.player, true)
	var freed_target = _spawn_target(world, Vector2(300.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._slam_rune_hammer(6)
	var freed_rupture = world.effects.get_node_or_null("CataclysmRupture")
	_check(is_instance_valid(freed_rupture), "ruptura não existe no cenário de alvo liberado")
	var freed_target_id := freed_target.get_instance_id()
	freed_target.queue_free()
	await process_frame
	_check(not is_instance_valid(freed_target), "alvo do cenário de lifecycle não foi liberado")
	if is_instance_valid(freed_rupture):
		freed_rupture.set_process(false)
		freed_rupture._process(0.11)
		_check(
			not freed_rupture.primary_hit_targets.has(freed_target_id),
			"aftershock reteve referência a alvo já liberado"
		)

	await _clear_combat_nodes(world)
	for index in range(world.MAX_EFFECTS):
		var cosmetic := Node2D.new()
		cosmetic.name = "Cosmetic%d" % index
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)
	for index in range(world.MAX_PLAYER_PROJECTILES):
		var projectile_placeholder := Node2D.new()
		projectile_placeholder.name = "ProjectileCap%d" % index
		world.projectiles.add_child(projectile_placeholder)
	_prepare_player(world.player, true)
	var saturated_target = _spawn_target(world, Vector2(300.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._slam_rune_hammer(6)
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "Cataclismo prioritário ultrapassou teto visual")
	_check(
		world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES,
		"Cataclismo alterou o teto independente de projéteis"
	)
	var saturated_rupture = world.effects.get_node_or_null("CataclysmRupture")
	_check(is_instance_valid(saturated_rupture), "impacto/fissura desapareceram com 120 efeitos")
	if is_instance_valid(saturated_rupture):
		saturated_rupture.set_process(false)
		saturated_rupture._process(0.31)
	_check_close(10_000.0 - float(saturated_target.hp), 184.0, "saturação impediu dano total do Cataclismo")

	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
