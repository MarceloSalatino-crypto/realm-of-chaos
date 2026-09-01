extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const LIGHTNING_EFFECT_SCRIPT = preload("res://scripts/lightning_effect.gd")
const ETERNAL_STORM_SCRIPT = preload("res://scripts/eternal_storm.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("ETERNAL STORM PILOT: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ETERNAL STORM PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(
		is_equal_approx(actual, expected),
		"%s (esperado %.4f, obtido %.4f)" % [message, expected, actual]
	)


func _prepare_player(player, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.storm_relic = 6
	player.evolved_weapons.storm_relic = evolved
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.critical_multiplier = 2.0
	player.boss_damage_multiplier = 1.0
	player.storm_timer = 0.0


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


func _spawn_line(world, count: int, first_distance := 80.0, spacing := 48.0) -> Array[Node]:
	var targets: Array[Node] = []
	for index in range(count):
		targets.append(_spawn_target(world, Vector2(first_distance + spacing * index, 0.0)))
	world._rebuild_spatial_grid()
	return targets


func _find_lightning(world) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == LIGHTNING_EFFECT_SCRIPT:
			return effect
	return null


func _find_eternal_storm(world) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == ETERNAL_STORM_SCRIPT:
			return effect
	return null


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
	var base_targets := _spawn_line(world, 9)
	world.player._cast_storm_chain(6)
	for index in range(base_targets.size()):
		_check_close(
			10_000.0 - float(base_targets[index].hp), 39.0 if index < 8 else 0.0,
			"seleção/dano base mudou no alvo %d" % index
		)
	_check_close(world.player.storm_timer, 1.09, "cooldown base mudou")
	var base_lightning = _find_lightning(world)
	_check(is_instance_valid(base_lightning), "Relíquia base não criou relâmpago")
	if is_instance_valid(base_lightning):
		_check(base_lightning.points.size() == 9, "Relíquia base não manteve oito alvos")
		_check(base_lightning.color == Color("68eaff"), "cor base mudou")
		_check_close(float(base_lightning.duration), 0.24, "duração visual base mudou")
		_check(base_lightning.points[0].is_equal_approx(Vector2.ZERO), "cadeia base não começa no jogador")
		for index in range(8):
			_check(
				base_lightning.points[index + 1].is_equal_approx(base_targets[index].global_position),
				"ordem de seleção base mudou no salto %d" % index
			)
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	var evolved_targets := _spawn_line(world, 12)
	world.player._cast_storm_chain(6)
	for index in range(evolved_targets.size()):
		_check_close(
			10_000.0 - float(evolved_targets[index].hp), 43.602 if index < 11 else 0.0,
			"descarga principal/seleção evoluída incorreta no alvo %d" % index
		)
	_check_close(world.player.storm_timer, 0.7085, "cooldown evoluído mudou")
	_check(not is_instance_valid(_find_lightning(world)), "ramo evoluído ainda criou o relâmpago base")
	var evolved_storm = _find_eternal_storm(world)
	_check(is_instance_valid(evolved_storm), "Tempestade Eterna não criou sua rede elétrica")
	if is_instance_valid(evolved_storm):
		evolved_storm.set_process(false)
		var signature: Dictionary = evolved_storm.visual_signature()
		_check_close(float(signature.main_damage_fraction), 0.65, "fração da descarga principal mudou")
		_check_close(float(signature.echo_damage_fraction), 0.35, "fração do eco mudou")
		_check_close(float(signature.echo_delay), 0.16, "intervalo do eco mudou")
		_check_close(float(signature.duration), 0.44, "duração visual evoluída mudou")
		_check(int(signature.target_count) == 11, "Tempestade Eterna não manteve onze alvos")
		_check(int(signature.main_point_count) == 12, "rede principal perdeu pontos")
		_check(int(signature.echo_point_count) == 12, "eco não retorna até a origem")
		evolved_storm._process(0.15)
		for index in range(11):
			_check_close(
				10_000.0 - float(evolved_targets[index].hp), 43.602,
				"eco aconteceu antes de 0.16s no alvo %d" % index
			)
		evolved_storm._process(0.011)
		for index in range(11):
			_check_close(
				10_000.0 - float(evolved_targets[index].hp), 67.08,
				"descarga + eco não preservaram 67.08 no alvo %d" % index
			)
		_check(int(evolved_storm.echo_stage_count) == 1, "eco não ocorreu exatamente uma vez")
		evolved_storm._process(0.10)
		for index in range(11):
			_check_close(
				10_000.0 - float(evolved_targets[index].hp), 67.08,
				"eco repetiu dano no alvo %d" % index
			)
	await _clear_combat_nodes(world)

	_prepare_player(world.player, false)
	var inside_range = _spawn_target(world, Vector2(719.0, 0.0))
	var outside_range = _spawn_target(world, Vector2(721.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_storm_chain(6)
	_check_close(10_000.0 - float(inside_range.hp), 39.0, "alcance base encolheu")
	_check_close(10_000.0 - float(outside_range.hp), 0.0, "alcance base cresceu")
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	world.player.crit_chance = 1.0
	var critical_target = _spawn_target(world, Vector2(180.0, 0.0))
	var elite_target = _spawn_target(world, Vector2(240.0, 0.0), "guardian", true)
	var boss_target = _spawn_target(world, Vector2(300.0, 0.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	world.player._cast_storm_chain(6)
	_check_close(10_000.0 - float(critical_target.hp), 87.204, "fração crítica inicial mudou")
	_check_close(10_000.0 - float(elite_target.hp), 87.204, "fração inicial em elite mudou")
	_check_close(10_000.0 - float(boss_target.hp), 87.204, "fração inicial em boss mudou")
	var critical_storm = _find_eternal_storm(world)
	_check(is_instance_valid(critical_storm), "rede crítica não foi criada")
	if is_instance_valid(critical_storm):
		critical_storm.set_process(false)
		critical_storm._process(0.17)
	_check_close(10_000.0 - float(critical_target.hp), 134.16, "crítico total evoluído mudou")
	_check_close(10_000.0 - float(elite_target.hp), 134.16, "dano total em elite mudou")
	_check_close(10_000.0 - float(boss_target.hp), 134.16, "dano total em boss mudou")
	_check_close(critical_target.knockback_velocity.length(), 0.0, "Relíquia passou a causar knockback")
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	var single_target = _spawn_target(world, Vector2(220.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_storm_chain(6)
	var single_storm = _find_eternal_storm(world)
	_check(is_instance_valid(single_storm), "Tempestade falhou contra alvo único")
	if is_instance_valid(single_storm):
		single_storm.set_process(false)
		_check(int(single_storm.visual_signature().target_count) == 1, "alvo único criou saltos extras")
		single_storm._process(0.17)
	_check_close(10_000.0 - float(single_target.hp), 67.08, "alvo único não preservou dano total")
	await _clear_combat_nodes(world)

	_prepare_player(world.player, true)
	var dead_between_stages = _spawn_target(world, Vector2(180.0, 0.0))
	var removed_between_stages = _spawn_target(world, Vector2(240.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_storm_chain(6)
	var interrupted_storm = _find_eternal_storm(world)
	_check(is_instance_valid(interrupted_storm), "rede não existe no cenário de remoção")
	var dead_hp_after_main: float = dead_between_stages.hp
	dead_between_stages.dead = true
	dead_between_stages.remove_from_group("enemies")
	removed_between_stages.queue_free()
	await process_frame
	if is_instance_valid(interrupted_storm):
		interrupted_storm.set_process(false)
		interrupted_storm._process(0.17)
	_check_close(float(dead_between_stages.hp), dead_hp_after_main, "eco atingiu inimigo morto")
	_check(int(interrupted_storm.echo_stage_count) == 1, "remoção de alvo impediu o eco único")
	await _clear_combat_nodes(world)

	for index in range(world.MAX_EFFECTS):
		var cosmetic := Node2D.new()
		cosmetic.name = "StormCosmetic%d" % index
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)
	for index in range(world.MAX_PLAYER_PROJECTILES):
		var projectile_placeholder := Node2D.new()
		projectile_placeholder.name = "StormProjectileCap%d" % index
		world.projectiles.add_child(projectile_placeholder)
	_prepare_player(world.player, true)
	var saturated_target = _spawn_target(world, Vector2(200.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._cast_storm_chain(6)
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "Tempestade ultrapassou 120 efeitos")
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "Tempestade alterou 360 projéteis")
	var saturated_storm = _find_eternal_storm(world)
	_check(is_instance_valid(saturated_storm), "rede elétrica desapareceu com 120 efeitos")
	if is_instance_valid(saturated_storm):
		saturated_storm.set_process(false)
		saturated_storm._process(0.17)
	_check_close(10_000.0 - float(saturated_target.hp), 67.08, "saturação impediu dano total")

	print(
		"ETERNAL STORM BEFORE: base=39 dano/8 alvos/720 alcance/1.09s; "
		+ "AFTER: evoluída=43.602 descarga + 23.478 eco em 0.16s = 67.08; "
		+ "11 alvos/720 alcance/0.7085s, uma rede batched de 0.44s"
	)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
