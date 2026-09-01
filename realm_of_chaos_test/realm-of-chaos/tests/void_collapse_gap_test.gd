extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("VOID COLLAPSE GAP: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("VOID COLLAPSE GAP: " + message)


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


func _clear_combat(world: Node) -> void:
	for enemy in world.enemies.get_children():
		enemy.queue_free()
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
	world.set_physics_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.boss_damage_multiplier = 1.0

	# Crítico ocorre somente na implosão e a redução de atração é exclusiva do boss.
	var normal := _spawn_target(world, "prowler", false, Vector2(100.0, 0.0))
	var elite := _spawn_target(world, "guardian", true, Vector2(-100.0, 0.0))
	var boss := _spawn_target(world, "ossuary_colossus", false, Vector2(0.0, 100.0))
	world._rebuild_spatial_grid()
	var collapse = world.spawn_void_collapse(Vector2.ZERO, 431.0, 100.0, 1.0, 2.0)
	_check(is_instance_valid(collapse), "Colapso não foi criado")
	collapse.set_process(false)
	collapse._process(0.18)
	_check_close(10_000.0 - float(normal.hp), 0.0, "atração causou dano crítico antecipado")
	_check_close(normal.knockback_velocity.length(), 18.0, "atração do inimigo normal mudou")
	_check_close(elite.knockback_velocity.length(), 18.0, "elite recebeu redução de atração reservada ao boss")
	_check_close(boss.knockback_velocity.length(), 6.12, "boss não recebeu atração reduzida de 34%")
	collapse._process(0.51)
	for target in [normal, elite, boss]:
		_check_close(10_000.0 - float(target.hp), 200.0, "implosão crítica não aplicou exatamente uma vez em %s" % target.enemy_type)
	var hp_after_implosion := float(normal.hp)
	collapse._process(0.01)
	_check_close(float(normal.hp), hp_after_implosion, "implosão crítica foi repetida")
	_check(int(collapse.visual_signature().damage_stage_count) == 1, "contador registrou mais de uma implosão")

	# Um alvo removido entre atração e implosão não deixa referência inválida.
	await _clear_combat(world)
	var removed := _spawn_target(world, "prowler", false, Vector2(100.0, 0.0))
	var survivor := _spawn_target(world, "prowler", false, Vector2(-100.0, 0.0))
	world._rebuild_spatial_grid()
	collapse = world.spawn_void_collapse(Vector2.ZERO, 431.0, 100.0, 0.0, 2.0)
	collapse.set_process(false)
	collapse._process(0.37)
	removed.queue_free()
	await process_frame
	world._rebuild_spatial_grid()
	collapse._process(0.32)
	_check(not is_instance_valid(removed), "alvo de teste não foi removido antes da implosão")
	_check_close(10_000.0 - float(survivor.hp), 100.0, "alvos restantes deixaram de receber a implosão")
	_check(int(collapse.visual_signature().damage_stage_count) == 1, "remoção de alvo duplicou ou cancelou a implosão")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("VOID COLLAPSE GAP OK: crítico único, resistência do boss e alvo removido validados")
		quit(0)
	else:
		quit(1)
