extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	push_error("CRIMSON REAPER PILOT: teste excedeu 20 segundos")
	quit(2)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CRIMSON REAPER PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.4f, obtido %.4f)" % [message, expected, actual])


func _prepare_player(player, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.blood_scythe = 6
	player.evolved_weapons.blood_scythe = evolved
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.life_steal = 0.0
	player.max_hp = 100.0
	player.hp = 50.0
	player.last_direction = Vector2.RIGHT
	player.scythe_timer = 0.0


func _spawn_target(world, offset: Vector2) -> Node:
	var enemy = world.spawn_enemy("prowler", false, 1.0)
	enemy.global_position = world.player.global_position + offset
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _clear_targets(world, targets: Array[Node]) -> void:
	for enemy in targets:
		if is_instance_valid(enemy):
			enemy.queue_free()
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

	_prepare_player(world.player, false)
	var base_targets: Array[Node] = [
		_spawn_target(world, Vector2(170.0, 0.0)),
		_spawn_target(world, Vector2(-180.0, 0.0)),
		_spawn_target(world, Vector2(240.0, 0.0)),
	]
	world._rebuild_spatial_grid()
	var base_projectiles_before: int = world.projectiles.get_child_count()
	world.player._swing_blood_scythe(6)
	_check_close(10000.0 - float(base_targets[0].hp), 58.0, "Foice base perdeu o dano frontal")
	_check_close(10000.0 - float(base_targets[1].hp), 0.0, "Foice base passou a atingir atrás")
	_check_close(10000.0 - float(base_targets[2].hp), 0.0, "Foice base ultrapassou o alcance")
	_check_close(world.player.hp, 50.32, "cura da Foice base mudou")
	_check_close(world.player.scythe_timer, 0.95, "cooldown da Foice base mudou")
	_check(world.projectiles.get_child_count() == base_projectiles_before, "Foice base passou a criar projétil")
	await _clear_targets(world, base_targets)

	_prepare_player(world.player, true)
	var evolved_targets: Array[Node] = [
		_spawn_target(world, Vector2(170.0, 0.0)),
		_spawn_target(world, Vector2(-180.0, 0.0)),
		_spawn_target(world, Vector2(240.0, 0.0)),
		_spawn_target(world, Vector2(280.0, 0.0)),
	]
	world._rebuild_spatial_grid()
	var evolved_projectiles_before: int = world.projectiles.get_child_count()
	world.player._swing_blood_scythe(6)
	for index in range(3):
		_check_close(
			10000.0 - float(evolved_targets[index].hp), 107.3,
			"Ceifadora atual perdeu dano/alcance 360° no alvo %d" % index
		)
	_check_close(10000.0 - float(evolved_targets[3].hp), 0.0, "Ceifadora atual ultrapassou o raio 245")
	_check_close(world.player.hp, 52.25, "cura da Ceifadora atual mudou")
	_check_close(world.player.scythe_timer, 0.684, "cooldown da Ceifadora atual mudou")
	_check(
		world.projectiles.get_child_count() == evolved_projectiles_before + 1,
		"Ceifadora não criou exatamente um crescente"
	)
	var crescent = world.projectiles.get_child(world.projectiles.get_child_count() - 1)
	_check(str(crescent.visual_style) == "crimson_crescent", "projétil perdeu a silhueta de crescente")
	_check(str(crescent.source_weapon) == "blood_scythe", "crescente deixou de pertencer à Foice")
	_check(int(crescent.pierce) == 4, "perfuração inicial do crescente divergiu")
	_check_close(float(crescent.knockback), 72.0, "knockback do crescente divergiu")
	_check_close(float(crescent.lifetime), 0.72, "duração do crescente divergiu")
	var slash = world.effects.get_node_or_null("CrimsonReaperSlash")
	_check(is_instance_valid(slash), "efeito 360° exclusivo não foi criado")
	if is_instance_valid(slash):
		var signature: Dictionary = slash.visual_signature()
		_check(int(signature.blade_count) == 3 and float(signature.radius) == 245.0, "assinatura visual do corte mudou")
	for _frame in range(6):
		await physics_frame
	_check_close(10000.0 - float(evolved_targets[3].hp), 107.3, "crescente não atingiu o alvo fora do corte")
	for index in range(3):
		_check_close(
			10000.0 - float(evolved_targets[index].hp), 107.3,
			"crescente duplicou o dano em alvo já atingido pelo corte %d" % index
		)
	_check_close(world.player.hp, 52.25, "crescente alterou a cura original da Ceifadora")
	print(
		"CRIMSON REAPER AFTER: base preserved; evolved damage=107.3 360deg radius=245 "
		+ "heal=2.25, 3-blade slash, 1 piercing crescent without inner double-hit"
	)

	for effect in world.effects.get_children():
		effect.queue_free()
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
	await process_frame
	for index in range(world.MAX_EFFECTS):
		var cosmetic := Node2D.new()
		cosmetic.name = "Cosmetic%d" % index
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)
	for index in range(world.MAX_PLAYER_PROJECTILES):
		var filler = world.player.bullet_scene.instantiate()
		filler.setup(Vector2.RIGHT, 0.0, 0.0, 999, 4.0, Color("65506e"))
		filler.lifetime = 20.0
		world.add_player_projectile(filler)
	_prepare_player(world.player, true)
	world.player._swing_blood_scythe(6)
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "efeito prioritário ultrapassou o teto visual")
	_check(
		is_instance_valid(world.effects.get_node_or_null("CrimsonReaperSlash")),
		"corte importante desapareceu com 120 efeitos ativos"
	)
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "crescente ultrapassou o teto de projéteis")
	var saturated_crescent_count := 0
	for projectile in world.projectiles.get_children():
		if is_instance_valid(projectile) and str(projectile.get("visual_style")) == "crimson_crescent":
			saturated_crescent_count += 1
	_check(saturated_crescent_count == 1, "crescente desapareceu sob saturação de projéteis")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("CRIMSON REAPER PILOT OK: base preservada, leitura 360°, crescente e prioridade visual validados")
		quit(0)
	else:
		quit(1)
