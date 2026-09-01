extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("CODEX OF THE END PILOT: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CODEX OF THE END PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.4f, obtido %.4f)" % [message, expected, actual])


func _prepare_player(player, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.forbidden_grimoire = 6
	player.evolved_weapons.forbidden_grimoire = evolved
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.grimoire_timer = 0.0
	player.last_direction = Vector2.RIGHT


func _spawn_target(world, position: Vector2) -> Node:
	var enemy = world.spawn_enemy("prowler", false, 1.0)
	enemy.global_position = position
	enemy.hp = 10_000.0
	enemy.max_hp = enemy.hp
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
	var base_center = _spawn_target(world, Vector2(220.0, 0.0))
	var base_inside = _spawn_target(world, Vector2(220.0, 150.0))
	var base_outside = _spawn_target(world, Vector2(220.0, 200.0))
	world._rebuild_spatial_grid()
	world.player._cast_forbidden_grimoire(6)
	_check_close(10_000.0 - float(base_center.hp), 73.0, "dano central do Grimório base mudou")
	_check_close(10_000.0 - float(base_inside.hp), 73.0, "área do Grimório base encolheu")
	_check_close(10_000.0 - float(base_outside.hp), 0.0, "área do Grimório base cresceu")
	_check_close(world.player.grimoire_timer, 1.81, "cooldown do Grimório base mudou")
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	var evolved_center = _spawn_target(world, Vector2(220.0, 0.0))
	var evolved_inside = _spawn_target(world, Vector2(220.0, 200.0))
	var evolved_outside = _spawn_target(world, Vector2(220.0, 240.0))
	world._rebuild_spatial_grid()
	world.player._cast_forbidden_grimoire(6)
	_check_close(10_000.0 - float(evolved_center.hp), 0.0, "Códice ainda aplicou dano antes do primeiro pulso")
	_check_close(world.player.grimoire_timer, 1.3032, "cooldown do Códice mudou")
	var ritual = world.effects.get_node_or_null("CodexRitual")
	_check(is_instance_valid(ritual), "selo ritual do Códice não foi criado")
	if is_instance_valid(ritual):
		ritual.set_process(false)
		var initial_signature: Dictionary = ritual.visual_signature()
		_check(int(initial_signature.pulse_count) == 2, "ritual não possui dois pulsos preparatórios")
		_check_close(float(initial_signature.radius), 205.0, "raio do ritual mudou")
		_check_close(float(initial_signature.duration), 0.96, "duração do ritual mudou")

	ritual._process(0.25)
	_check_close(10_000.0 - float(evolved_center.hp), 132.86 * 0.22, "primeiro pulso aplicou dano incorreto")
	_check(evolved_inside.knockback_velocity.y < 0.0, "primeiro pulso não atraiu o alvo para o centro")
	_check_close(10_000.0 - float(evolved_outside.hp), 0.0, "primeiro pulso ultrapassou o raio 205")

	ritual._process(0.28)
	_check_close(10_000.0 - float(evolved_center.hp), 132.86 * 0.46, "segundo pulso aplicou dano incorreto")
	_check_close(10_000.0 - float(evolved_outside.hp), 0.0, "segundo pulso ultrapassou o raio 205")

	ritual._process(0.32)
	_check_close(10_000.0 - float(evolved_center.hp), 132.86, "implosão não preservou o dano total anterior")
	_check_close(10_000.0 - float(evolved_inside.hp), 132.86, "implosão perdeu alvo dentro da área")
	_check_close(10_000.0 - float(evolved_outside.hp), 0.0, "implosão ultrapassou o raio 205")
	if is_instance_valid(ritual):
		var final_signature: Dictionary = ritual.visual_signature()
		_check(int(final_signature.damage_stage_count) == 3, "ritual não processou dois pulsos e uma implosão")
	print(
		"CODEX AFTER: base preservada em 73/raio158/cooldown1.81; "
		+ "evoluída=2 pulsos + implosão, total132.86/raio205/cooldown1.3032 com atração"
	)

	await _clear_combat_nodes(world)
	_prepare_player(world.player, true)
	var realtime_target = _spawn_target(world, Vector2(220.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_forbidden_grimoire(6)
	await create_timer(1.10, true, false, true).timeout
	await process_frame
	_check_close(10_000.0 - float(realtime_target.hp), 132.86, "timeline real não concluiu os três estágios")

	await _clear_combat_nodes(world)
	for index in range(world.MAX_EFFECTS):
		var cosmetic := Node2D.new()
		cosmetic.name = "Cosmetic%d" % index
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)
	_prepare_player(world.player, true)
	var saturated_target = _spawn_target(world, Vector2(220.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_forbidden_grimoire(6)
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "ritual prioritário ultrapassou o teto visual")
	var saturated_ritual = world.effects.get_node_or_null("CodexRitual")
	_check(is_instance_valid(saturated_ritual), "ritual desapareceu com 120 efeitos ativos")
	if is_instance_valid(saturated_ritual):
		saturated_ritual.set_process(false)
		saturated_ritual._process(0.85)
	_check_close(10_000.0 - float(saturated_target.hp), 132.86, "saturação visual impediu o dano do ritual")

	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
