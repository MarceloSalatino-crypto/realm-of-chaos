extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("CRIMSON REAPER GAP: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CRIMSON REAPER GAP: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) <= 0.02, "%s (esperado %.3f, obtido %.3f)" % [message, expected, actual])


func _spawn_target(world: Node, kind: String, elite: bool, position: Vector2) -> Node:
	var enemy = world.spawn_enemy(kind, elite, 1.0)
	_check(is_instance_valid(enemy), "não foi possível criar alvo %s" % kind)
	if not is_instance_valid(enemy):
		return null
	enemy.global_position = position
	enemy.hp = 10_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.knockback_velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


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
	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	world.player.weapon_levels.blood_scythe = 6
	world.player.evolved_weapons.blood_scythe = true
	world.player.damage_multiplier = 1.0
	world.player.temporary_damage_multiplier = 1.0
	world.player.cooldown_multiplier = 1.0
	world.player.temporary_cooldown_multiplier = 1.0
	world.player.crit_chance = 1.0
	world.player.temporary_crit_bonus = 0.0
	world.player.critical_multiplier = 2.0
	world.player.boss_damage_multiplier = 1.0
	world.player.last_direction = Vector2.RIGHT

	var normal := _spawn_target(world, "prowler", false, Vector2(150.0, 0.0))
	var elite := _spawn_target(world, "guardian", true, Vector2(-175.0, 0.0))
	var boss := _spawn_target(world, "ossuary_colossus", false, Vector2(0.0, 185.0))
	var crescent_target := _spawn_target(world, "prowler", false, Vector2(290.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._swing_blood_scythe(6)

	for target in [normal, elite, boss]:
		_check_close(10_000.0 - float(target.hp), 214.6, "corte crítico foi aplicado incorretamente em %s" % target.enemy_type)
	_check_close(normal.knockback_velocity.length(), 72.0, "knockback do inimigo normal mudou")
	_check_close(elite.knockback_velocity.length(), 72.0, "resposta de knockback da elite mudou")
	_check_close(boss.knockback_velocity.length(), 24.48, "resistência de knockback do boss mudou")
	_check_close(10_000.0 - float(crescent_target.hp), 0.0, "crescente atingiu antes de percorrer sua trajetória")

	var crescent: Node = null
	for projectile in world.projectiles.get_children():
		if str(projectile.get("visual_style")) == "crimson_crescent":
			crescent = projectile
			break
	_check(is_instance_valid(crescent), "crescente crítico não foi criado")
	if is_instance_valid(crescent):
		_check(bool(crescent.critical), "crescente não preservou o crítico garantido")
		_check_close(float(crescent.damage), 214.6, "multiplicador crítico do crescente mudou")
		for target in [normal, elite, boss]:
			_check(crescent.hit_targets.has(target.get_instance_id()), "crescente não ignorou alvo já atingido pelo corte")

	for _frame in range(10):
		await physics_frame
	_check_close(10_000.0 - float(crescent_target.hp), 214.6, "crescente crítico não atingiu exatamente uma vez")
	for target in [normal, elite, boss]:
		_check_close(10_000.0 - float(target.hp), 214.6, "crescente duplicou o corte inicial em %s" % target.enemy_type)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("CRIMSON REAPER GAP OK: crítico, normal/elite/boss, knockback e crescente sem duplicação validados")
		quit(0)
	else:
		quit(1)
