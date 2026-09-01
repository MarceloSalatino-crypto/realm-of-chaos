extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("CODEX OF THE END GAP: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CODEX OF THE END GAP: " + message)


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


func _run_shared_result(world: Node, starts_critical: bool) -> void:
	var normal := _spawn_target(world, "prowler", false, Vector2(80.0, 0.0))
	var elite := _spawn_target(world, "guardian", true, Vector2(-80.0, 0.0))
	var boss := _spawn_target(world, "ossuary_colossus", false, Vector2(0.0, 80.0))
	world._rebuild_spatial_grid()
	var ritual = world.spawn_codex_ritual(
		Vector2.ZERO, 205.0, 100.0, 1.0 if starts_critical else 0.0, 2.0
	)
	_check(is_instance_valid(ritual), "ritual não foi criado")
	ritual.set_process(false)
	ritual._process(0.25)
	var first_expected := 44.0 if starts_critical else 22.0
	for target in [normal, elite, boss]:
		_check_close(10_000.0 - float(target.hp), first_expected, "primeiro pulso divergiu em %s" % target.enemy_type)
		ritual.critical_chance = 0.0 if starts_critical else 1.0
	ritual._process(0.28)
	var second_expected := 92.0 if starts_critical else 46.0
	for target in [normal, elite, boss]:
		_check_close(10_000.0 - float(target.hp), second_expected, "segundo pulso fez reroll em %s" % target.enemy_type)
	ritual._process(0.32)
	var final_expected := 200.0 if starts_critical else 100.0
	for target in [normal, elite, boss]:
		_check_close(10_000.0 - float(target.hp), final_expected, "implosão fez reroll em %s" % target.enemy_type)
		_check(
			bool(ritual.critical_targets[target.get_instance_id()]) == starts_critical,
			"resultado crítico compartilhado mudou entre estágios"
		)
	_check(int(ritual.visual_signature().damage_stage_count) == 3, "ritual não executou exatamente três estágios")


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

	# Alterar a chance após o primeiro pulso prova que não existem três rolls.
	await _run_shared_result(world, true)
	await _clear_combat(world)
	await _run_shared_result(world, false)

	# Um alvo removido após o primeiro pulso não é retido nem interrompe os demais.
	await _clear_combat(world)
	var removed := _spawn_target(world, "prowler", false, Vector2(80.0, 0.0))
	var survivor := _spawn_target(world, "prowler", false, Vector2(-80.0, 0.0))
	world._rebuild_spatial_grid()
	var ritual = world.spawn_codex_ritual(Vector2.ZERO, 205.0, 100.0, 0.0, 2.0)
	ritual.set_process(false)
	ritual._process(0.25)
	removed.queue_free()
	await process_frame
	world._rebuild_spatial_grid()
	ritual._process(0.60)
	_check(not is_instance_valid(removed), "alvo de teste não foi removido entre pulsos")
	_check_close(10_000.0 - float(survivor.hp), 100.0, "alvo restante não concluiu pulsos e implosão")
	_check(int(ritual.visual_signature().damage_stage_count) == 3, "remoção de alvo interrompeu os estágios restantes")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("CODEX OF THE END GAP OK: crítico compartilhado, não crítico, elite/boss e alvo removido validados")
		quit(0)
	else:
		quit(1)
