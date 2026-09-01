extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const SEQUENCE_SCRIPT := preload("res://scripts/shadow_dance_sequence.gd")

var failures: Array[String] = []


class DummyEnemy:
	extends Node2D
	var dead := false
	var hit_radius := 12.0
	var damage_taken := 0.0
	var elite := false
	var boss := false

	func take_damage(amount: float, _knockback := Vector2.ZERO, _critical := false, _source := "") -> void:
		damage_taken += amount


func _initialize() -> void:
	var watchdog := create_timer(30.0, true, false, true)
	watchdog.timeout.connect(func(): push_error("SHADOW DANCE PILOT: timeout"); quit(2))
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SHADOW DANCE PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _prepare_player(player: Node, evolved: bool, crit_chance := -1.0, projectile_bonus := 0) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.shadow_blades = 6
	player.evolved_weapons.shadow_blades = evolved
	player.equipped_weapon_id = "shadow_blades"
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = crit_chance
	player.temporary_crit_bonus = 0.0
	player.critical_multiplier = 2.0
	player.projectile_bonus = projectile_bonus
	player.last_direction = Vector2.RIGHT
	player.attack_facing_time = 0.0
	player.pending_attack_facing_x = 0.0


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await process_frame


func _reset_world(world: Node) -> void:
	await _clear_container(world.projectiles)
	await _clear_container(world.effects)
	await _clear_container(world.enemies)


func _spawn_dummy(world: Node, position: Vector2, elite := false, boss := false) -> DummyEnemy:
	var enemy := DummyEnemy.new()
	enemy.elite = elite
	enemy.boss = boss
	enemy.add_to_group("enemies")
	world.enemies.add_child(enemy)
	enemy.global_position = position
	return enemy


func _find_sequence(world: Node) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == SEQUENCE_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _freeze_projectiles(world: Node) -> void:
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)


func _step_sequence(sequence: Node, delta: float) -> void:
	sequence.set_process(false)
	sequence._process(delta)


func _shadow_projectiles(world: Node) -> Array[Node]:
	var result: Array[Node] = []
	for projectile in world.projectiles.get_children():
		if str(projectile.get("source_weapon")) == "shadow_blades":
			result.append(projectile)
	return result


func _test_base_untouched(world: Node) -> void:
	await _reset_world(world)
	_prepare_player(world.player, false)
	_spawn_dummy(world, world.player.global_position + Vector2(1200.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._fire_shadow_blades(6)
	_freeze_projectiles(world)
	_check(world.projectiles.get_child_count() == 8, "base deixou de criar oito lâminas imediatamente")
	_check(_find_sequence(world) == null, "base criou sequência exclusiva da evolução")
	_check_close(world.player.blades_timer, 1.04, "cooldown base mudou")
	for projectile in world.projectiles.get_children():
		_check_close(float(projectile.damage), 28.0, "dano base mudou")
		_check(str(projectile.projectile_batch_style()) == "shadow_small", "visual base mudou")


func _test_two_wave_sequence(world: Node) -> void:
	await _reset_world(world)
	_prepare_player(world.player, true)
	var target := _spawn_dummy(world, world.player.global_position + Vector2(800.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._fire_shadow_blades(6)
	var sequence := _find_sequence(world)
	_check(is_instance_valid(sequence), "evolução não criou a sequência coordenada")
	_check(world.projectiles.get_child_count() == 4, "primeiro passo da saída não contém quatro lâminas")
	_check_close(world.player.blades_timer, 0.78, "cooldown evoluído mudou")
	if not is_instance_valid(sequence):
		return
	sequence.set_process(false)
	_freeze_projectiles(world)
	var signature: Dictionary = sequence.visual_signature()
	_check(int(signature.entry_count) == 16, "sequência não preservou os 16 ataques históricos")
	_check(int(signature.outbound_count) == 8 and int(signature.return_count) == 8, "divisão 8+8 mudou")
	_check(bool(signature.outbound_released) and not bool(signature.second_outbound_released), "ordem inicial das cadências mudou")
	_step_sequence(sequence, 0.06)
	_check(world.projectiles.get_child_count() == 4, "segundo passo da saída saiu antes de 0,07s")
	_step_sequence(sequence, 0.02)
	_check(world.projectiles.get_child_count() == 8, "saída não completou oito lâminas")
	_step_sequence(sequence, 0.11)
	_check(world.projectiles.get_child_count() == 8, "retorno saiu antes de 0,20s")
	_step_sequence(sequence, 0.02)
	_check(world.projectiles.get_child_count() == 12, "primeiro retorno não adicionou quatro sombras")
	_step_sequence(sequence, 0.07)
	_freeze_projectiles(world)
	_check(world.projectiles.get_child_count() == 16, "retorno não completou os 16 ataques")
	signature = sequence.visual_signature()
	_check(bool(signature.return_released) and int(signature.released_projectile_count) == 16, "contador da sequência não registrou os 16 ataques")
	var return_count := 0
	var total_damage := 0.0
	for projectile in _shadow_projectiles(world):
		total_damage += float(projectile.damage)
		_check_close(float(projectile.speed), 820.0, "velocidade evoluída mudou")
		_check(int(projectile.pierce) == 3, "perfuração evoluída mudou")
		_check_close(float(projectile.hit_radius), 8.0, "raio evoluído mudou")
		_check_close(float(projectile.knockback), 16.0, "knockback evoluído mudou")
		_check_close(float(projectile.lifetime), 2.2, "tempo de vida evoluído mudou")
		if str(projectile.visual_style) == "shadow_return":
			return_count += 1
	_check(return_count == 8, "segunda cadência não contém oito sombras de retorno")
	_check_close(total_damage, 725.76, "dano agregado sem crítico mudou")
	_check_close(total_damage / 0.78, 930.46155, "DPS emitido aproximado mudou")
	target.dead = true
	target.remove_from_group("enemies")
	_step_sequence(sequence, 0.36)
	_check(sequence.is_queued_for_deletion(), "sequência não encerrou o estado visual após 0,64s")


func _test_critical_bonus_and_target_lifecycle(world: Node) -> void:
	await _reset_world(world)
	_prepare_player(world.player, true, 1.0, 2)
	var target := _spawn_dummy(world, world.player.global_position + Vector2(720.0, 0.0), true, false)
	world._rebuild_spatial_grid()
	world.player._fire_shadow_blades(6)
	var sequence := _find_sequence(world)
	_check(is_instance_valid(sequence), "sequência crítica não nasceu")
	if not is_instance_valid(sequence):
		return
	sequence.set_process(false)
	_freeze_projectiles(world)
	_check(world.projectiles.get_child_count() == 5, "bônus +2 não dividiu o primeiro passo em cinco")
	target.dead = true
	target.remove_from_group("enemies")
	target.queue_free()
	_step_sequence(sequence, 0.28)
	_freeze_projectiles(world)
	var projectiles := _shadow_projectiles(world)
	_check(projectiles.size() == 18, "alvo removido interrompeu indevidamente a sequência")
	for projectile in projectiles:
		_check(bool(projectile.critical), "crítico garantido não foi preservado em uma etapa")
		_check_close(float(projectile.damage), 90.72, "crítico foi aplicado mais ou menos de uma vez")
	_check(int(sequence.visual_signature().cancelled_wave_count) == 0, "remoção do alvo cancelou sequência que não depende dele")


func _test_target_state_does_not_break_return(world: Node) -> void:
	for lifecycle_case in ["dead", "out_of_range"]:
		await _reset_world(world)
		_prepare_player(world.player, true)
		var target := _spawn_dummy(world, world.player.global_position + Vector2(720.0, 0.0))
		world._rebuild_spatial_grid()
		world.player._fire_shadow_blades(6)
		var sequence := _find_sequence(world)
		_check(is_instance_valid(sequence), "sequência ausente no caso de alvo %s" % lifecycle_case)
		if not is_instance_valid(sequence):
			continue
		sequence.set_process(false)
		_freeze_projectiles(world)
		if lifecycle_case == "dead":
			target.dead = true
		else:
			target.global_position = Vector2(9000.0, 9000.0)
			world._rebuild_spatial_grid()
		_step_sequence(sequence, 0.28)
		_freeze_projectiles(world)
		_check(
			_shadow_projectiles(world).size() == 16,
			"alvo %s interrompeu o retorno independente" % lifecycle_case
		)
		_check(
			int(sequence.visual_signature().cancelled_wave_count) == 0,
			"alvo %s cancelou uma cadência" % lifecycle_case
		)


func _test_damage_against_enemy_classes(world: Node) -> void:
	await _reset_world(world)
	_prepare_player(world.player, true)
	var normal := _spawn_dummy(world, Vector2(260.0, 0.0))
	var elite := _spawn_dummy(world, Vector2(330.0, 0.0), true, false)
	var boss := _spawn_dummy(world, Vector2(400.0, 0.0), false, true)
	world._rebuild_spatial_grid()
	world.player._fire_shadow_blades(6)
	var sequence := _find_sequence(world)
	_check(is_instance_valid(sequence), "sequência ausente no teste de classes")
	if not is_instance_valid(sequence):
		return
	sequence.set_process(false)
	_freeze_projectiles(world)
	var projectile: Node = world.projectiles.get_child(0)
	for enemy in [normal, elite, boss]:
		projectile.global_position = enemy.global_position
		projectile._physics_process(0.0)
	_check_close(normal.damage_taken, 45.36, "inimigo normal não recebeu dano")
	_check_close(elite.damage_taken, 45.36, "elite não recebeu dano")
	_check_close(boss.damage_taken, 45.36, "boss não recebeu dano")
	_check(int(projectile.pierce) == 0, "perfuração não registrou três classes atingidas")


func _test_no_target_and_saturation(world: Node) -> void:
	await _reset_world(world)
	_prepare_player(world.player, true)
	world._rebuild_spatial_grid()
	world.player._fire_shadow_blades(6)
	_check(_find_sequence(world) == null, "sequência nasceu sem alvo")
	_check(world.projectiles.get_child_count() == 0, "evolução disparou sem alvo")
	_check_close(world.player.blades_timer, 0.78, "tentativa sem alvo mudou o cooldown")

	_spawn_dummy(world, world.player.global_position + Vector2(700.0, 0.0))
	world._rebuild_spatial_grid()
	for index in range(world.MAX_EFFECTS):
		var filler := Node2D.new()
		filler.name = "CosmeticEffect%d" % index
		world.effects.add_child(filler)
	for index in range(world.MAX_PLAYER_PROJECTILES):
		var filler := Node2D.new()
		filler.name = "ProjectileCap%d" % index
		world.projectiles.add_child(filler)
	world.player._fire_shadow_blades(6)
	var sequence := _find_sequence(world)
	_check(is_instance_valid(sequence), "sequência crítica sumiu com 120 efeitos")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "sequência ultrapassou o teto de efeitos")
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "primeira cadência ultrapassou o teto de projéteis")
	if not is_instance_valid(sequence):
		return
	sequence.set_process(false)
	_step_sequence(sequence, 0.28)
	_freeze_projectiles(world)
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "retorno ultrapassou o teto de projéteis")
	_check(_shadow_projectiles(world).size() == 16, "teto cheio descartou parte da mecânica principal")


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
	await _test_two_wave_sequence(world)
	await _test_critical_bonus_and_target_lifecycle(world)
	await _test_target_state_does_not_break_return(world)
	await _test_damage_against_enemy_classes(world)
	await _test_no_target_and_saturation(world)

	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print(
			"SHADOW DANCE PILOT OK: base intacta; evolução=8 saída + 8 retorno em 0.20s, "
			+ "16×45.36=725.76 por ciclo/0.78s, crítico e saturação preservados"
		)
	quit(0 if failures.is_empty() else 1)
