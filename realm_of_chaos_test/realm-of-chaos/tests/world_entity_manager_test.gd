extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const ENEMY_PROJECTILE_SCENE = preload("res://scenes/enemies/enemy_projectile.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WORLD ENTITY MANAGER: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.4f, obtido %.4f)" % [message, expected, actual])


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _pickup_count(parent: Node, kind: String) -> int:
	var count := 0
	for pickup in parent.get_children():
		if str(pickup.get("pickup_kind")) == kind:
			count += 1
	return count


func _pickup_value(parent: Node, kind: String) -> int:
	var total := 0
	for pickup in parent.get_children():
		if str(pickup.get("pickup_kind")) == kind:
			total += int(pickup.get("value"))
	return total


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)

	for method_name in [
		&"spawn_enemy", &"spawn_enemy_near", &"enemy_population_cap", &"remaining_enemy_capacity",
		&"has_enemy_capacity", &"get_spawn_position", &"add_player_projectile",
		&"spawn_enemy_projectile", &"recycle_enemy_projectile", &"add_enemy_projectile",
		&"_spawn_pickup", &"spawn_effect", &"_effect_visual_quality",
		&"spawn_weapon_flash", &"spawn_lightning", &"spawn_damage_number"
	]:
		_check(world.has_method(method_name), "API publica ausente: %s" % method_name)

	seed(8123)
	world.time_survived = 600.0
	var player_position: Vector2 = world.player.global_position
	var elite = world.spawn_enemy("guardian", true, 3.25)
	_check(is_instance_valid(elite) and elite.get_parent() == world.enemies, "inimigo nao foi registrado no container")
	_check(elite.enemy_type == "guardian" and elite.elite, "tipo ou elite forcado nao foi preservado")
	_check_close(elite.power, 3.25, "power_override do inimigo mudou")
	_check(elite.world == world, "referencia do World nao foi vinculada ao inimigo")
	var elite_distance: float = elite.global_position.distance_to(player_position)
	_check(elite_distance >= 609.9 and elite_distance <= 760.1, "inimigo comum saiu do anel de spawn")
	var boss = world.spawn_enemy("ossuary_colossus", false, 2.50)
	_check(is_instance_valid(boss) and boss.boss and not boss.elite, "chefe direto foi configurado incorretamente")
	_check_close(boss.power, 2.50, "power_override do chefe mudou")
	var boss_distance: float = boss.global_position.distance_to(player_position)
	_check(boss_distance >= 579.9 and boss_distance <= 670.1, "chefe saiu do anel de spawn")
	var nearby_enemy = world.spawn_enemy_near("prowler", player_position, 54.0, 92.0, false, 1.0)
	_check(is_instance_valid(nearby_enemy), "spawn local seguro nao criou inimigo em area livre")
	if is_instance_valid(nearby_enemy):
		var nearby_distance: float = nearby_enemy.global_position.distance_to(player_position)
		_check(nearby_distance >= 53.9 and nearby_distance <= 92.1, "spawn local saiu do anel solicitado")
		_check(world._spawn_position_is_clear(nearby_enemy.global_position), "spawn local ignorou obstaculo ou santuário")
	world.game_ended = true
	_check(world.spawn_enemy("prowler") == null, "spawn de inimigo ignorou game_ended")
	world.game_ended = false

	_check(world._effect_visual_quality(40.0, 0.20) == 2, "qualidade leve de efeito mudou")
	world.spawn_effect(Vector2(30.0, 40.0), Color("aa66ff"), 72.0, 0.42, true)
	_check(world.effects.get_child_count() == 1, "efeito comum nao foi criado")
	var effect = world.effects.get_child(0)
	_check(effect.global_position == Vector2(30.0, 40.0), "posicao do efeito mudou")
	_check(effect.effect_color == Color("aa66ff") and effect.filled, "cor ou preenchimento do efeito mudou")
	_check_close(effect.max_radius, 72.0, "raio do efeito mudou")
	_check_close(effect.duration, 0.42, "duracao do efeito mudou")
	_check(effect.visual_quality == 2, "qualidade configurada no efeito mudou")
	_clear_children(world.effects)
	for _index in range(world.EFFECT_MEDIUM_LOAD):
		world.effects.add_child(Node2D.new())
	_check(world._effect_visual_quality(40.0, 0.20) == 1, "carga media nao reduziu qualidade para 1")
	while world.effects.get_child_count() < world.EFFECT_HIGH_LOAD:
		world.effects.add_child(Node2D.new())
	_check(world._effect_visual_quality(40.0, 0.20) == 0, "carga alta nao reduziu qualidade para 0")
	_check(world._effect_visual_quality(140.0, 0.20) == 1, "efeito grande perdeu legibilidade intermediaria")
	_check(world._effect_visual_quality(40.0, 0.50) == 1, "efeito longo perdeu legibilidade intermediaria")
	_clear_children(world.effects)

	world.spawn_weapon_flash(Vector2(80.0, 90.0), 3, 0.4, 0.5, 0.6, Color("ff6688"))
	_check(world.effects.get_child_count() == 1, "flash de arma nao foi criado")
	var flash = world.effects.get_child(0)
	_check(flash.global_position == Vector2(80.0, 90.0) and flash.frame == 3 and flash.hframes == 5, "configuracao do flash mudou")
	_check(flash.modulate == Color("ff6688"), "tint do flash mudou")
	_clear_children(world.effects)
	var lightning_points := PackedVector2Array([Vector2.ZERO, Vector2(40.0, 10.0), Vector2(80.0, -5.0)])
	world.spawn_lightning(lightning_points, Color("66eeff"))
	_check(world.effects.get_child_count() == 1, "relampago nao foi criado")
	var lightning = world.effects.get_child(0)
	_check(lightning.points == lightning_points and lightning.color == Color("66eeff"), "pontos ou cor do relampago mudaram")
	_check(lightning.visual_quality == 2, "qualidade leve do relampago mudou")
	_clear_children(world.effects)
	world.spawn_damage_number(Vector2(120.0, 130.0), 17.2, true, false, "")
	_check(world.effects.get_child_count() == 1, "numero de dano nao foi criado")
	var damage_number = world.effects.get_child(0)
	_check("18" in damage_number.text and damage_number.z_index == 60, "texto ou camada do dano critico mudou")
	_clear_children(world.effects)
	while world.effects.get_child_count() < world.MAX_EFFECTS:
		world.effects.add_child(Node2D.new())
	var effects_at_cap: int = world.effects.get_child_count()
	world.spawn_effect(Vector2.ZERO, Color.WHITE, 20.0)
	world.spawn_weapon_flash(Vector2.ZERO, 0, 0.0, 1.0)
	world.spawn_lightning(lightning_points)
	world.spawn_damage_number(Vector2.ZERO, 1.0)
	_check(world.effects.get_child_count() == effects_at_cap, "orçamento de efeitos foi ultrapassado")
	_clear_children(world.effects)

	var oldest_player_projectile := Node2D.new()
	oldest_player_projectile.name = "OldestPlayerProjectile"
	world.add_player_projectile(oldest_player_projectile)
	var second_player_projectile := Node2D.new()
	second_player_projectile.name = "SecondPlayerProjectile"
	world.add_player_projectile(second_player_projectile)
	while world.projectiles.get_child_count() < world.MAX_PLAYER_PROJECTILES:
		world.add_player_projectile(Node2D.new())
	world.add_player_projectile(Node2D.new())
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "limite de projeteis do jogador foi ultrapassado")
	_check(oldest_player_projectile.get_parent() == null and oldest_player_projectile.is_queued_for_deletion(), "projetil mais antigo do jogador nao foi removido")
	_check(world.projectiles.get_child(0) == second_player_projectile, "ordem dos projeteis restantes mudou")

	var first_enemy_projectile = world.spawn_enemy_projectile(
		Vector2(12.0, 34.0), Vector2.RIGHT, 15.0, 245.0, Color("e95779"), 11.0, true
	)
	_check(first_enemy_projectile.get_parent() == world.enemy_projectiles and first_enemy_projectile.active, "projetil inimigo nao foi ativado")
	_check(first_enemy_projectile.owner_world == world and first_enemy_projectile.target_player == world.player, "runtime do projetil inimigo nao foi vinculado")
	_check(first_enemy_projectile.global_position == Vector2(12.0, 34.0), "posicao do projetil inimigo mudou")
	_check(first_enemy_projectile.direction == Vector2.RIGHT and first_enemy_projectile.uses_danger_style, "direcao ou silhueta perigosa mudou")
	_check_close(first_enemy_projectile.damage, 15.0, "dano configurado no projetil mudou")
	first_enemy_projectile.prepare_for_pool()
	world.recycle_enemy_projectile(first_enemy_projectile)
	_check(first_enemy_projectile.get_parent() == world.enemy_projectile_pool, "projetil inativo nao entrou no pool")
	_check(not first_enemy_projectile.active and not first_enemy_projectile.visible and not first_enemy_projectile.is_physics_processing(), "estado inativo do pool mudou")
	var reused_projectile = world.spawn_enemy_projectile(
		Vector2(50.0, 60.0), Vector2.DOWN, 22.0, 310.0, Color("7755ff"), 7.0, false
	)
	_check(reused_projectile == first_enemy_projectile, "pool nao reutilizou o projetil disponivel")
	_check(reused_projectile.active and reused_projectile.visible and reused_projectile.is_physics_processing(), "projetil reutilizado nao foi reativado")
	_check(reused_projectile.direction == Vector2.DOWN and reused_projectile.global_position == Vector2(50.0, 60.0), "setup reutilizado manteve estado antigo")

	var external_projectile = ENEMY_PROJECTILE_SCENE.instantiate()
	world.add_enemy_projectile(external_projectile)
	_check(external_projectile.get_parent() == world.enemy_projectiles, "API compativel nao registrou projetil externo")
	_check(external_projectile.owner_world == world and external_projectile.target_player == world.player and external_projectile.active, "API compativel nao vinculou runtime")
	while world.enemy_projectiles.get_child_count() < world.MAX_ENEMY_PROJECTILES:
		world.spawn_enemy_projectile(Vector2.ZERO, Vector2.LEFT, 1.0, 100.0, Color.WHITE, 4.0)
	var oldest_enemy_projectile = world.enemy_projectiles.get_child(0)
	var reused_oldest = world.spawn_enemy_projectile(Vector2(90.0, 100.0), Vector2.UP, 30.0, 400.0, Color.RED, 13.0, true)
	_check(world.enemy_projectiles.get_child_count() == world.MAX_ENEMY_PROJECTILES, "teto de projeteis inimigos foi ultrapassado")
	_check(reused_oldest == oldest_enemy_projectile and world.enemy_projectiles.get_child(-1) == oldest_enemy_projectile, "teto nao reutilizou o projetil mais antigo")
	_check(reused_oldest.direction == Vector2.UP and reused_oldest.damage == 30.0, "projetil mais antigo nao recebeu o novo setup")

	var pool_candidates: Array[Node] = []
	for index in range(world.ENEMY_PROJECTILE_POOL_LIMIT + 1):
		pool_candidates.append(world.enemy_projectiles.get_child(index))
	for index in range(pool_candidates.size()):
		var projectile = pool_candidates[index]
		projectile.prepare_for_pool()
		world.recycle_enemy_projectile(projectile)
		if index < world.ENEMY_PROJECTILE_POOL_LIMIT:
			_check(projectile.get_parent() == world.enemy_projectile_pool, "projetil nao foi movido ao pool dentro do limite")
	var overflow_projectile = pool_candidates[-1]
	_check(world.enemy_projectile_pool.get_child_count() == world.ENEMY_PROJECTILE_POOL_LIMIT, "pool ultrapassou o limite de 160")
	_check(overflow_projectile.is_queued_for_deletion(), "excedente do pool nao foi descartado")
	var pool_count_before_reuse: int = world.enemy_projectile_pool.get_child_count()
	var active_count_before_reuse: int = world.enemy_projectiles.get_child_count()
	var projectile_from_full_pool = world.spawn_enemy_projectile(Vector2.ZERO, Vector2.RIGHT, 4.0, 180.0, Color.WHITE, 5.0)
	_check(projectile_from_full_pool.get_parent() == world.enemy_projectiles and projectile_from_full_pool.active, "pool cheio nao devolveu projetil ativo")
	_check(world.enemy_projectile_pool.get_child_count() == pool_count_before_reuse - 1, "reuso nao retirou uma voz do pool")
	_check(world.enemy_projectiles.get_child_count() == active_count_before_reuse + 1, "reuso nao devolveu projetil ao container ativo")

	var first_pickup = world._spawn_pickup(3, Vector2(1800.0, 1800.0), "xp")
	_check(first_pickup.get_parent() == world.pickups and first_pickup.value == 3 and first_pickup.pickup_kind == "xp", "pickup de XP foi configurado incorretamente")
	_check(first_pickup.global_position == Vector2(1800.0, 1800.0), "posicao do pickup mudou")
	var notifier = first_pickup.get_node_or_null("VisibleOnScreenNotifier2D")
	_check(notifier is VisibleOnScreenNotifier2D, "pickup perdeu VisibleOnScreenNotifier2D")
	if notifier is VisibleOnScreenNotifier2D:
		_check(notifier.rect == Rect2(-18.0, -18.0, 36.0, 36.0), "retangulo do notifier mudou")
		_check(notifier.screen_entered.is_connected(Callable(first_pickup, "_on_screen_entered")), "screen_entered nao esta conectado")
		_check(notifier.screen_exited.is_connected(Callable(first_pickup, "_on_screen_exited")), "screen_exited nao esta conectado")
	first_pickup._refresh_visual_load()
	_check_close(first_pickup.redraw_interval, 1.0 / 30.0, "pickup leve nao usa 30 Hz")
	while world.pickups.get_child_count() < 160:
		world._spawn_pickup(1, Vector2(2000.0, 2000.0), "xp")
	first_pickup._refresh_visual_load()
	_check_close(first_pickup.redraw_interval, 1.0 / 20.0, "pickup em carga media nao usa 20 Hz")
	while world.pickups.get_child_count() < 360:
		world._spawn_pickup(1, Vector2(2100.0, 2100.0), "xp")
	first_pickup._refresh_visual_load()
	_check_close(first_pickup.redraw_interval, 1.0 / 15.0, "pickup em carga alta nao usa 15 Hz")
	while world.pickups.get_child_count() < world.MAX_PICKUPS:
		world._spawn_pickup(1, Vector2(2200.0, 2200.0), "xp")
	world.pickup_merge_cursor = 117
	var merge_target = world.pickups.get_child(117)
	merge_target.value = 60
	var merged_pickup = world._spawn_pickup(5, Vector2.ZERO, "xp")
	_check(world.pickups.get_child_count() == world.MAX_PICKUPS, "pickup excedente nao foi fundido no teto")
	_check(merged_pickup == merge_target and merge_target.value == 65, "fusao perdeu XP ou escolheu alvo incorreto")
	_check(merge_target.attracted and world.pickup_merge_cursor == 118, "fusao nao atualizou atracao ou cursor")
	var xp_before_health := _pickup_value(world.pickups, "xp")
	var health_pickup = world._spawn_pickup(24, Vector2(2300.0, 2300.0), "heal")
	_check(world.pickups.get_child_count() == world.MAX_PICKUPS, "cura ultrapassou o teto global preenchido por XP")
	_check(_pickup_count(world.pickups, "heal") == 1, "cura nao ocupou a vaga liberada pela consolidacao de XP")
	_check(_pickup_value(world.pickups, "xp") == xp_before_health, "consolidacao para cura perdeu XP")
	_check(health_pickup.pickup_kind == "heal" and health_pickup.has_node("VisibleOnScreenNotifier2D"), "pickup de vida perdeu tipo ou notifier")

	_clear_children(world.pickups)
	var oldest_common_heal = world._spawn_pickup(24, Vector2(2400.0, 2400.0), "heal")
	var second_common_heal = world._spawn_pickup(24, Vector2(2410.0, 2400.0), "heal")
	while world.pickups.get_child_count() < world.MAX_PICKUPS:
		world._spawn_pickup(60, Vector2(2420.0, 2400.0), "heal")
	var discarded_common_heal = world._spawn_pickup(20, Vector2(2430.0, 2400.0), "heal")
	_check(discarded_common_heal == null, "cura nova substituiu uma cura mais valiosa")
	_check(world.pickups.get_child_count() == world.MAX_PICKUPS, "cura descartada alterou o teto global")
	var boss_heal = world._spawn_pickup(60, Vector2(2440.0, 2400.0), "heal")
	_check(world.pickups.get_child_count() == world.MAX_PICKUPS, "cura de boss ultrapassou o teto global")
	_check(boss_heal != null and boss_heal.get_parent() == world.pickups, "cura de boss nao substituiu cura comum")
	_check(oldest_common_heal.get_parent() == null and oldest_common_heal.is_queued_for_deletion(), "cura menos valiosa e mais antiga nao foi substituida")
	_check(second_common_heal.get_parent() == world.pickups, "desempate de antiguidade removeu a cura comum errada")

	var third_common_heal = world.pickups.get_child(1)
	third_common_heal.value = 24
	var xp_from_full_heals = world._spawn_pickup(7, Vector2(2450.0, 2400.0), "xp")
	_check(world.pickups.get_child_count() == world.MAX_PICKUPS, "XP ultrapassou o teto preenchido apenas por curas")
	_check(xp_from_full_heals != null and xp_from_full_heals.pickup_kind == "xp" and xp_from_full_heals.value == 7, "XP foi descartado no teto de curas")
	_check(second_common_heal.get_parent() == null and second_common_heal.is_queued_for_deletion(), "XP nao substituiu a cura menos valiosa e mais antiga")
	_check(third_common_heal.get_parent() == world.pickups, "desempate de antiguidade do XP removeu a cura errada")
	_check(_pickup_count(world.pickups, "xp") == 1 and _pickup_count(world.pickups, "heal") == world.MAX_PICKUPS - 1, "composicao do teto global ficou incorreta")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD ENTITY MANAGER OK: inimigos, limites, pool, pickups/notifiers e efeitos validados")
		quit(0)
	else:
		quit(1)
