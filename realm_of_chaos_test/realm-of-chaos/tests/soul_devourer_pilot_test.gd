extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const RELEASE_SCRIPT := preload("res://scripts/spirit_devourer_release.gd")
const LEVEL := 6
const HISTORICAL_HIT := 48.1
const RESERVED_PER_HIT := 12.025
const CONTINUOUS_HIT := 36.075

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(35.0, true, false, true)
	watchdog.timeout.connect(func(): push_error("SOUL DEVOURER PILOT: timeout"); quit(2))
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SOUL DEVOURER PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await process_frame


func _prepare_player(player: Node, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.soul_orbit = LEVEL
	player.evolved_weapons.soul_orbit = evolved
	player.equipped_weapon_id = "soul_orbit"
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.boss_damage_multiplier = 1.0
	player.life_steal = 0.0
	player.hp = 100.0
	player.max_hp = 125.0
	player.orbit_tick = 0.0
	player.orbit_angle = 0.0
	player.orbit_hit_times.clear()
	player.combat.reset_soul_devourer_state()


func _spawn_target(world: Node, kind: String, position: Vector2, force_elite := false) -> Node:
	var enemy = world.spawn_enemy(kind, force_elite, 1.0)
	_check(is_instance_valid(enemy), "alvo %s não nasceu" % kind)
	if not is_instance_valid(enemy):
		return null
	enemy.global_position = position
	enemy.hp = 10_000.0
	enemy.max_hp = 10_000.0
	enemy.knockback_velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _spawn_ring(world: Node, count: int, radius: float) -> Array[Node]:
	var targets: Array[Node] = []
	for index in range(count):
		var position: Vector2 = world.player.global_position + Vector2.RIGHT.rotated(TAU * index / count) * radius
		var enemy := _spawn_target(world, "prowler", position)
		if is_instance_valid(enemy):
			targets.append(enemy)
	world._rebuild_spatial_grid()
	return targets


func _total_damage(targets: Array[Node]) -> float:
	var total := 0.0
	for target in targets:
		if is_instance_valid(target):
			total += 10_000.0 - float(target.hp)
	return total


func _find_release(world: Node) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == RELEASE_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _allow_orbit_rehit(player: Node, targets: Array[Node]) -> void:
	var old_time := Time.get_ticks_msec() - 500
	for target in targets:
		if is_instance_valid(target):
			player.orbit_hit_times[target.get_instance_id()] = old_time


func _test_base_untouched(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, false)
	var targets := _spawn_ring(world, 5, 120.0)
	world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), 130.0, "dano agregado da base mudou")
	_check_close(world.player.hp, 100.0, "base passou a curar")
	var signature: Dictionary = world.player.combat.soul_devourer_signature()
	_check(int(signature.charges) == 0 and int(signature.release_count) == 0, "base acumulou essência")
	_check(_find_release(world) == null, "base criou liberação do Devorador")


func _test_evolved_release(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, true)
	var targets := _spawn_ring(world, 9, 170.0)
	world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), HISTORICAL_HIT * 9.0, "dano agregado da evolução ganhou/perdeu poder")
	_check_close(world.player.hp, 103.15, "cura histórica por nove acertos mudou")
	var signature: Dictionary = world.player.combat.soul_devourer_signature()
	_check(int(signature.charge_limit) == 6, "limite de cargas não é seis")
	_check_close(float(signature.reserved_damage_ratio), 0.25, "fração reservada divergiu")
	_check(int(signature.max_targets) == 3, "descarga não está limitada a três alvos")
	_check(int(signature.charges) == 0 and int(signature.release_count) == 1, "seis acertos não produziram uma única descarga")
	_check_close(float(signature.stored_damage), 0.0, "dano armazenado não foi consumido")
	_check_close(float(signature.release_cooldown), 0.35, "cooldown máximo da descarga mudou")
	var release := _find_release(world)
	_check(is_instance_valid(release), "feedback crítico da descarga não nasceu")
	if is_instance_valid(release):
		var visual: Dictionary = release.visual_signature()
		_check(int(visual.target_count) == 3, "feedback visual não representa os três alvos")
		_check(int(visual.source_charge_count) == 6, "feedback visual não recebeu seis cargas")
	_check(world.projectiles.get_child_count() == 0, "evolução criou projétil inesperado")

	var damage_before_repeat := _total_damage(targets)
	world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), damage_before_repeat, "trava individual de 430 ms duplicou dano")
	_check(int(world.player.combat.soul_devourer_release_count) == 1, "repetição imediata duplicou a descarga")

	_allow_orbit_rehit(world.player, targets)
	world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets) - damage_before_repeat, HISTORICAL_HIT * 9.0, "cooldown da descarga reduziu o dano orbital histórico")
	_check(int(world.player.combat.soul_essence_charges) == 0, "acumulou cargas durante cooldown")


func _test_frequency_and_no_growth(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, true)
	var target := _spawn_target(world, "prowler", world.player.global_position + Vector2(170.0, 0.0))
	var targets: Array[Node] = [target]
	world._rebuild_spatial_grid()
	for _hit in range(6):
		_allow_orbit_rehit(world.player, targets)
		world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), HISTORICAL_HIT * 6.0, "primeira descarga alterou o dano de seis acertos")
	_check(int(world.player.combat.soul_devourer_release_count) == 1, "seis acertos não geraram exatamente uma descarga")
	for _hit in range(6):
		_allow_orbit_rehit(world.player, targets)
		world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), HISTORICAL_HIT * 12.0, "acertos durante cooldown mudaram o DPS histórico")
	_check(int(world.player.combat.soul_devourer_release_count) == 1, "cooldown permitiu crescimento de descargas")
	world.player.combat.soul_devourer_release_cooldown = 0.0
	for _hit in range(6):
		_allow_orbit_rehit(world.player, targets)
		world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), HISTORICAL_HIT * 18.0, "segunda descarga alterou o dano total")
	_check(int(world.player.combat.soul_devourer_release_count) == 2, "nova janela não liberou exatamente uma segunda descarga")
	_check(int(world.player.combat.soul_essence_charges) == 0, "cargas cresceram após a liberação")


func _test_critical_damage_is_conserved(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, true)
	world.player.crit_chance = 1.0
	var target := _spawn_target(world, "prowler", world.player.global_position + Vector2(170.0, 0.0))
	var targets: Array[Node] = [target]
	world._rebuild_spatial_grid()
	for _hit in range(6):
		_allow_orbit_rehit(world.player, targets)
		world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), HISTORICAL_HIT * 2.0 * 6.0, "redistribuição perdeu ou duplicou o crítico")
	_check(int(world.player.combat.soul_devourer_release_count) == 1, "crítico alterou a quantidade de descargas")
	_check_close(world.player.hp, 102.1, "crítico alterou a cura fixa por acerto")


func _test_elite_boss_and_removed_targets(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, true)
	var normal := _spawn_target(world, "prowler", world.player.global_position + Vector2(100.0, 0.0))
	var elite := _spawn_target(world, "guardian", world.player.global_position + Vector2(0.0, 120.0), true)
	var boss := _spawn_target(world, "ossuary_colossus", world.player.global_position + Vector2(-140.0, 0.0))
	world._rebuild_spatial_grid()
	world.player.combat.soul_essence_charges = 6
	world.player.combat.soul_essence_damage = RESERVED_PER_HIT * 6.0
	_check(world.player.combat.release_soul_essence(170.0), "descarga manual válida falhou")
	_check_close(10_000.0 - float(normal.hp), 24.05, "dano da descarga no inimigo comum divergiu")
	_check_close(10_000.0 - float(elite.hp), 24.05, "dano da descarga no elite divergiu")
	_check_close(10_000.0 - float(boss.hp), 24.05, "dano da descarga no boss divergiu")
	var release := _find_release(world)
	for target in [normal, elite, boss]:
		target.queue_free()
	await process_frame
	if is_instance_valid(release):
		release.set_process(false)
		release._process(0.20)
		_check(not release.is_queued_for_deletion(), "remoção dos alvos invalidou prematuramente o feedback")


func _test_pending_release_recovers_after_target_dies(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, true)
	world.player.combat.soul_essence_charges = 6
	world.player.combat.soul_essence_damage = RESERVED_PER_HIT * 6.0
	_check(not world.player.combat.release_soul_essence(170.0), "descarga sem alvo consumiu a essência")
	_check(int(world.player.combat.soul_essence_charges) == 6, "descarga sem alvo perdeu as cargas")
	_check_close(float(world.player.combat.soul_essence_damage), RESERVED_PER_HIT * 6.0, "descarga sem alvo perdeu dano armazenado")
	var replacement := _spawn_target(world, "prowler", world.player.global_position + Vector2(170.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._damage_orbit(LEVEL)
	_check(int(world.player.combat.soul_devourer_release_count) == 1, "essência pendente não foi liberada quando surgiu um alvo válido")
	_check_close(10_000.0 - float(replacement.hp), RESERVED_PER_HIT * 6.0 + HISTORICAL_HIT, "retomada da descarga alterou o dano total")
	_check(int(world.player.combat.soul_essence_charges) == 0, "retomada da descarga não limpou as cargas")


func _test_saturation(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	await _clear_container(world.projectiles)
	_prepare_player(world.player, true)
	var targets: Array[Node] = []
	for index in range(3):
		var enemy := _spawn_target(world, "prowler", world.player.global_position + Vector2.RIGHT.rotated(TAU * index / 3.0) * 130.0)
		targets.append(enemy)
	world._rebuild_spatial_grid()
	for index in range(world.MAX_EFFECTS):
		var filler := Node2D.new()
		filler.name = "CosmeticEffect%d" % index
		world.effects.add_child(filler)
	for index in range(world.MAX_PLAYER_PROJECTILES):
		var projectile := Node2D.new()
		projectile.name = "ProjectileCap%d" % index
		world.add_player_projectile(projectile)
	world.player.combat.soul_essence_charges = 6
	world.player.combat.soul_essence_damage = RESERVED_PER_HIT * 6.0
	_check(world.player.combat.release_soul_essence(170.0), "mecânica sumiu com orçamento saturado")
	_check_close(_total_damage(targets), RESERVED_PER_HIT * 6.0, "saturação alterou o dano armazenado")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "feedback crítico ultrapassou 120 efeitos")
	_check(is_instance_valid(_find_release(world)), "feedback crítico foi descartado com 120 efeitos")
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "descarga alterou o teto de projéteis")
	_check(int(world.player.combat.soul_essence_charges) == 0, "saturação impediu consumo das cargas")


func _run() -> void:
	var world := WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.spawn_timer = 9999.0
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO

	await _test_base_untouched(world)
	await _test_evolved_release(world)
	await _test_frequency_and_no_growth(world)
	await _test_critical_damage_is_conserved(world)
	await _test_elite_boss_and_removed_targets(world)
	await _test_pending_release_recovers_after_target_dies(world)
	await _test_saturation(world)

	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SOUL DEVOURER PILOT OK: base, redistribuição, limite, frequência, elite/boss e saturação validados")
	quit(0 if failures.is_empty() else 1)
