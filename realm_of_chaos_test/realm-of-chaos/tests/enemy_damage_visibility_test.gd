extends SceneTree

const NORMAL_RANGED_TYPES := ["mage", "archer", "necromancer", "void_knight"]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ENEMY DAMAGE VISIBILITY: " + message)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await process_frame


func _prepare_player(world: Node) -> void:
	world.player.set_physics_process(false)
	world.player.disabled = false
	world.player.dodge_chance = 0.0
	world.player.invulnerability = 0.0
	world.player.hp = world.player.max_hp
	world.player.global_position = Vector2.ZERO


func _test_ranged_contact_feedback(world: Node) -> void:
	for kind in NORMAL_RANGED_TYPES:
		await _clear_children(world.enemies)
		await _clear_children(world.enemy_projectiles)
		_prepare_player(world)
		var enemy = world.spawn_enemy(kind, false, 1.0)
		enemy.player = world.player
		enemy.global_position = Vector2(float(enemy.hit_radius) + 20.0, 0.0)
		enemy.cast_cooldown = 0.0
		enemy.special_cooldown = 999.0
		enemy.damage_cooldown = 0.0
		enemy._physics_process(1.0 / 60.0)
		enemy.set_physics_process(false)
		_check(world.player.hp < world.player.max_hp, "%s deixou de aplicar o dano de contato existente" % kind)
		_check(str(enemy.pending_projectile_attack).is_empty(), "%s misturou pose/disparo ranged com o golpe de contato" % kind)
		var visual_time_value: Variant = enemy.get("contact_attack_visual_time")
		var visual_time := float(visual_time_value) if visual_time_value != null else 0.0
		_check(visual_time > 0.0, "%s causou contato sem feedback visual próprio" % kind)
		_check(world.enemy_projectiles.get_child_count() == 0, "%s criou projétil no mesmo instante do golpe de contato" % kind)


func _test_projectile_waits_for_presentation(world: Node) -> void:
	await _clear_children(world.enemy_projectiles)
	_prepare_player(world)
	var hp_before: float = world.player.hp
	var projectile = world.spawn_enemy_projectile(
		world.player.global_position + Vector2(4.0, 0.0), Vector2.LEFT,
		12.0, 245.0, Color("ff496d"), 8.0, true
	)
	var start_position: Vector2 = projectile.global_position
	for _tick in range(6):
		projectile._physics_process(1.0 / 60.0)
	_check(is_equal_approx(world.player.hp, hp_before), "projétil próximo causou dano antes de qualquer frame de apresentação")
	_check(bool(projectile.get("active")) and bool(projectile.visible), "projétil próximo foi reciclado antes de aparecer")
	_check(projectile.global_position.is_equal_approx(start_position), "projétil avançou antes do primeiro frame e pode atravessar o jogador em FPS baixo")
	_check(projectile.has_method("mark_visual_presented"), "projétil não expõe confirmação explícita de apresentação")
	if projectile.has_method("mark_visual_presented"):
		projectile.mark_visual_presented()
		projectile._physics_process(1.0 / 60.0)
		_check(world.player.hp < hp_before, "projétil apresentado deixou de aplicar o dano original")
		_check(not bool(projectile.get("active")), "projétil apresentado não foi reciclado após acertar")


func _test_batch_layers(world: Node) -> void:
	_check(world.player_projectile_batch_renderer.z_index == world.projectiles.z_index, "batch dos projéteis do jogador não herdou z_index 12")
	_check(world.enemy_projectile_batch_renderer.z_index == world.enemy_projectiles.z_index, "batch dos projéteis inimigos não herdou z_index 11")
	_check(world.pickup_batch_renderer.z_index == world.pickups.z_index, "batch dos pickups não herdou z_index 2")
	_check(world.effect_batch_renderer.z_index == world.effects.z_index, "batch dos efeitos não herdou z_index 14")


func _boss_case_has_direct_damage(kind: String, phase: int, pattern_seed: int) -> bool:
	if kind in ["ossuary_colossus", "void_titan"]:
		return true
	if kind == "glacial_archon":
		return phase >= 2
	if kind == "chaos_sovereign":
		return phase >= 3 or pattern_seed % 2 == 0
	return false


func _boss_case_has_projectiles(kind: String, phase: int, pattern_seed: int) -> bool:
	if kind == "ossuary_colossus":
		return phase >= 2
	if kind in ["glacial_archon", "infernal_reaper", "void_titan"]:
		return true
	if kind == "chaos_sovereign":
		return phase >= 3 or pattern_seed % 2 == 1
	return false


func _test_all_boss_attack_patterns(world: Node) -> void:
	var cases: Array[Dictionary] = []
	for phase in range(1, 4):
		for kind in ["ossuary_colossus", "glacial_archon", "infernal_reaper", "void_titan"]:
			cases.append({"kind": kind, "phase": phase, "pattern_seed": 0})
	for phase in range(1, 3):
		cases.append({"kind": "chaos_sovereign", "phase": phase, "pattern_seed": 0})
		cases.append({"kind": "chaos_sovereign", "phase": phase, "pattern_seed": 1})
	cases.append({"kind": "chaos_sovereign", "phase": 3, "pattern_seed": 0})

	for entry in cases:
		await _clear_children(world.enemies)
		await _clear_children(world.enemy_projectiles)
		await _clear_children(world.effects)
		_prepare_player(world)
		var kind := str(entry.kind)
		var phase := int(entry.phase)
		var pattern_seed := int(entry.pattern_seed)
		var boss = world.spawn_enemy(kind, false, 1.0)
		boss.set_physics_process(false)
		boss.player = world.player
		boss.global_position = Vector2(80.0, 0.0)
		boss.boss_phase = phase
		boss.boss_pattern_index = pattern_seed
		boss.special_cooldown = 0.0
		boss.pending_special = ""
		boss._try_begin_special(80.0)
		var case_name := "%s fase %d padrão %d" % [kind, phase, pattern_seed]
		_check(not boss.pending_special.is_empty() and boss.telegraph_time > 0.0, "%s não apresentou telegraph antes do padrão" % case_name)
		boss.telegraph_time = 0.0
		var hp_before: float = world.player.hp
		boss._execute_special(Vector2.LEFT)
		var expects_damage := _boss_case_has_direct_damage(kind, phase, pattern_seed)
		var expects_projectiles := _boss_case_has_projectiles(kind, phase, pattern_seed)
		if expects_damage:
			_check(world.player.hp < hp_before, "%s perdeu o dano direto original" % case_name)
			_check(_critical_effect_count(world) >= 1, "%s causou dano direto sem efeito crítico" % case_name)
		else:
			_check(is_equal_approx(world.player.hp, hp_before), "%s ganhou dano direto que não existia" % case_name)
		if expects_projectiles:
			_check(boss.pending_projectile_attack == "radial", "%s não preparou seus projéteis visíveis" % case_name)
			boss._update_projectile_attack(boss.PROJECTILE_PREPARE_DURATION + 0.001)
			_check(world.enemy_projectiles.get_child_count() > 0, "%s não criou projéteis na liberação" % case_name)
			for projectile in world.enemy_projectiles.get_children():
				_check(not bool(projectile.get("visual_presented")), "%s marcou projétil como apresentado antes do frame visual" % case_name)
		else:
			_check(boss.pending_projectile_attack.is_empty(), "%s criou projéteis fora do padrão original" % case_name)


func _fill_effect_budget(world: Node) -> void:
	await _clear_children(world.effects)
	while world.effects.get_child_count() < world.MAX_EFFECTS:
		var cosmetic := Node2D.new()
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)


func _critical_effect_count(world: Node) -> int:
	var count := 0
	for effect in world.effects.get_children():
		if bool(effect.get_meta("combat_critical_visual", false)):
			count += 1
	return count


func _test_dangerous_effect_priority(world: Node) -> void:
	await _fill_effect_budget(world)
	_prepare_player(world)
	var boss = world.spawn_enemy("ossuary_colossus", false, 1.0)
	boss.set_physics_process(false)
	boss.player = world.player
	boss.global_position = Vector2(80.0, 0.0)
	var hp_before: float = world.player.hp
	boss._ground_slam(165.0, 0.82)
	_check(world.player.hp < hp_before, "slam deixou de aplicar o dano existente")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "slam prioritário alterou o teto de 120 efeitos")
	_check(_critical_effect_count(world) == 1, "slam causou dano sem substituir um efeito cosmético por seu visual")

	await _clear_children(world.enemies)
	_prepare_player(world)
	var bomber = world.spawn_enemy("bomber", false, 1.0)
	bomber.set_physics_process(false)
	bomber.player = world.player
	bomber.global_position = Vector2(75.0, 0.0)
	hp_before = world.player.hp
	bomber.take_damage(bomber.max_hp + 1.0, Vector2.ZERO, false, "visibility_test")
	_check(world.player.hp < hp_before, "explosão de morte do Bomber deixou de aplicar o dano existente")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "explosão prioritária alterou o teto de 120 efeitos")
	_check(_critical_effect_count(world) >= 2, "explosão de morte do Bomber ocorreu sem visual prioritário")


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	world.suppress_save = true
	world.spawn_timer = 9999.0
	world.set_process(false)
	await _test_ranged_contact_feedback(world)
	await _test_projectile_waits_for_presentation(world)
	_test_batch_layers(world)
	await _test_all_boss_attack_patterns(world)
	await _test_dangerous_effect_priority(world)

	for music_player in world.audio.music_players:
		music_player.stop()
		music_player.stream = null
	world.audio.cached_streams.clear()
	current_scene = null
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY DAMAGE VISIBILITY OK: contato ranged, apresentação, layers e prioridade visual validados")
	quit(0 if failures.is_empty() else 1)
