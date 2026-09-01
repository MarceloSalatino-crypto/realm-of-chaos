extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const EFFECT_SCRIPT = preload("res://scripts/effect.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("VOID COLLAPSE PILOT: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("VOID COLLAPSE PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(
		is_equal_approx(actual, expected),
		"%s (esperado %.4f, obtido %.4f)" % [message, expected, actual]
	)


func _prepare_player(player, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.chaos_nova = 6
	player.evolved_weapons.chaos_nova = evolved
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.nova_timer = 0.0
	player.last_direction = Vector2.RIGHT


func _spawn_target(world, position: Vector2) -> Node:
	var enemy = world.spawn_enemy("prowler", false, 1.0)
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


func _find_generic_effect(world) -> Node:
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
	var base_center = _spawn_target(world, Vector2(150.0, 0.0))
	var base_inside = _spawn_target(world, Vector2(0.0, 290.0))
	var base_outside = _spawn_target(world, Vector2(0.0, 340.0))
	world._rebuild_spatial_grid()
	world.player._cast_nova(6)
	_check_close(10_000.0 - float(base_center.hp), 79.0, "dano da Nova base mudou")
	_check_close(10_000.0 - float(base_inside.hp), 79.0, "área da Nova base encolheu")
	_check_close(10_000.0 - float(base_outside.hp), 0.0, "área da Nova base cresceu")
	_check_close(world.player.nova_timer, 3.32, "cooldown da Nova base mudou")
	_check(base_center.knockback_velocity.x > 0.0, "Nova base deixou de empurrar para fora")
	var base_effect = _find_generic_effect(world)
	_check(is_instance_valid(base_effect), "Nova base não criou seu efeito")
	if is_instance_valid(base_effect):
		_check_close(float(base_effect.max_radius), 299.0, "raio visual da Nova base mudou")
		_check_close(float(base_effect.duration), 0.55, "duração visual da Nova base mudou")
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	var evolved_center = _spawn_target(world, Vector2(150.0, 0.0))
	var evolved_inside = _spawn_target(world, Vector2(0.0, 420.0))
	var evolved_outside = _spawn_target(world, Vector2(0.0, 470.0))
	world._rebuild_spatial_grid()
	world.player._cast_nova(6)
	_check_close(10_000.0 - float(evolved_center.hp), 0.0, "Colapso causou dano antes da implosão")
	_check_close(world.player.nova_timer, 3.10, "cooldown do Colapso mudou")
	var collapse = world.effects.get_node_or_null("VoidCollapse")
	_check(is_instance_valid(collapse), "formação do Colapso do Vazio não foi criada")
	if is_instance_valid(collapse):
		collapse.set_process(false)
		var initial_signature: Dictionary = collapse.visual_signature()
		_check(int(initial_signature.pull_count) == 3, "Colapso não possui três impulsos de atração")
		_check_close(float(initial_signature.radius), 431.0, "raio do Colapso mudou")
		_check_close(float(initial_signature.duration), 0.88, "duração do Colapso mudou")
		_check_close(float(initial_signature.total_force), 155.0, "força total anterior não foi preservada")

	collapse._process(0.19)
	_check_close(10_000.0 - float(evolved_center.hp), 0.0, "primeira atração causou dano antecipado")
	_check_close(evolved_center.knockback_velocity.x, -18.0, "primeira atração aplicou força incorreta")
	_check_close(evolved_outside.knockback_velocity.length(), 0.0, "atração ultrapassou o raio 431")

	collapse._process(0.18)
	_check_close(evolved_center.knockback_velocity.x, -50.0, "segunda atração aplicou força incorreta")
	_check(evolved_inside.knockback_velocity.y < 0.0, "alvo lateral não foi atraído para o centro")

	collapse._process(0.16)
	_check_close(evolved_center.knockback_velocity.x, -95.0, "terceira atração aplicou força incorreta")
	_check_close(10_000.0 - float(evolved_center.hp), 0.0, "atração causou dano antes da implosão")

	collapse._process(0.16)
	_check_close(10_000.0 - float(evolved_center.hp), 165.9, "implosão não preservou o dano total anterior")
	_check_close(10_000.0 - float(evolved_inside.hp), 165.9, "implosão perdeu alvo dentro da área")
	_check_close(10_000.0 - float(evolved_outside.hp), 0.0, "implosão ultrapassou o raio 431")
	_check_close(evolved_center.knockback_velocity.x, -155.0, "atração total não preservou magnitude 155")
	if is_instance_valid(collapse):
		var final_signature: Dictionary = collapse.visual_signature()
		_check(int(final_signature.pull_stage_count) == 3, "Colapso não processou as três atrações")
		_check(int(final_signature.damage_stage_count) == 1, "Colapso não processou uma única implosão")
	print(
		"VOID COLLAPSE AFTER: base preservada em 79/raio299/cooldown3.32; "
		+ "evoluída=3 atrações + implosão, total165.9/raio431/cooldown3.10/força155"
	)

	await _clear_combat_nodes(world)
	_prepare_player(world.player, true)
	var realtime_target = _spawn_target(world, Vector2(150.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_nova(6)
	await create_timer(0.95, true, false, true).timeout
	await process_frame
	_check_close(10_000.0 - float(realtime_target.hp), 165.9, "timeline real não concluiu a implosão")

	await _clear_combat_nodes(world)
	for index in range(world.MAX_EFFECTS):
		var cosmetic := Node2D.new()
		cosmetic.name = "Cosmetic%d" % index
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)
	_prepare_player(world.player, true)
	var saturated_target = _spawn_target(world, Vector2(150.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_nova(6)
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "Colapso prioritário ultrapassou o teto visual")
	var saturated_collapse = world.effects.get_node_or_null("VoidCollapse")
	_check(is_instance_valid(saturated_collapse), "Colapso desapareceu com 120 efeitos ativos")
	if is_instance_valid(saturated_collapse):
		saturated_collapse.set_process(false)
		saturated_collapse._process(0.69)
	_check_close(10_000.0 - float(saturated_target.hp), 165.9, "saturação visual impediu a implosão")

	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
