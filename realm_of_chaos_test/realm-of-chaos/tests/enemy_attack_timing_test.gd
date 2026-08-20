extends SceneTree

const NORMAL_RANGED_TYPES := ["mage", "archer", "necromancer", "void_knight"]
const EXPECTED_COUNTS := {"mage": 1, "archer": 3, "necromancer": 1, "void_knight": 1}
const EXPECTED_COOLDOWNS := {"mage": 2.7, "archer": 1.65, "necromancer": 2.7, "void_knight": 1.65}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ENEMY ATTACK TIMING: " + message)


func _clear_combatants(world: Node) -> void:
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	for projectile in world.enemy_projectiles.get_children():
		projectile.queue_free()
	await process_frame


func _wait_for_release(world: Node, maximum_frames := 20) -> Dictionary:
	var elapsed := 0.0
	var initial_count: int = world.enemy_projectiles.get_child_count()
	for frame_index in range(maximum_frames):
		await physics_frame
		await process_frame
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)
		if world.enemy_projectiles.get_child_count() > initial_count:
			return {"elapsed": elapsed, "frame_index": frame_index + 1}
	return {"elapsed": elapsed, "frame_index": -1}


func _test_normal_attack(world: Node, kind: String) -> void:
	await _clear_combatants(world)
	world.player.global_position = Vector2.ZERO
	var enemy = world.spawn_enemy(kind, false, 1.0)
	enemy.global_position = Vector2(100.0, 0.0)
	enemy.player = world.player
	enemy.cast_cooldown = 0.0
	enemy.special_cooldown = 999.0
	enemy.movement_age = 0.25
	await physics_frame
	await process_frame
	_check(world.enemy_projectiles.get_child_count() == 0, "%s disparou no primeiro frame da pose" % kind)
	_check(enemy.pending_projectile_attack == "normal" and enemy.sprite.frame == 2, "%s nao entrou na pose de preparacao" % kind)
	_check(is_equal_approx(enemy.cast_cooldown, float(EXPECTED_COOLDOWNS[kind])), "%s nao iniciou o cooldown no começo da preparacao" % kind)
	if kind in ["mage", "archer", "necromancer"]:
		_check(enemy.velocity.x > 0.0 and enemy.sprite.flip_h, "%s nao separou a mira para a esquerda do recuo para a direita" % kind)
	else:
		_check(enemy.sprite.flip_h, "%s nao travou a orientacao no alvo durante a preparacao" % kind)
	var locked_direction: Vector2 = enemy.projectile_attack_direction
	world.player.global_position = Vector2(220.0, 0.0)
	var release: Dictionary = await _wait_for_release(world)
	var elapsed := float(release.elapsed)
	_check(int(release.frame_index) > 0 and elapsed >= 0.18 and elapsed <= 0.22, "%s liberou fora da janela de 0,18-0,22s: %.3fs" % [kind, elapsed])
	_check(world.enemy_projectiles.get_child_count() == int(EXPECTED_COUNTS[kind]), "%s criou quantidade incorreta na liberacao" % kind)
	_check(enemy.sprite.frame == 3 and enemy.sprite.flip_h, "%s nao sincronizou projeteis com a pose de liberacao travada" % kind)
	for projectile in world.enemy_projectiles.get_children():
		_check(projectile.direction.dot(locked_direction) > 0.97, "%s recalculou a mira durante a preparacao" % kind)
	var cooldown_after_release: float = enemy.cast_cooldown
	_check(cooldown_after_release < float(EXPECTED_COOLDOWNS[kind]) - 0.18 and cooldown_after_release > float(EXPECTED_COOLDOWNS[kind]) - 0.25, "%s iniciou o cooldown apenas na liberacao" % kind)


func _test_radial_attack(world: Node) -> void:
	await _clear_combatants(world)
	world.player.global_position = Vector2.ZERO
	var enemy = world.spawn_enemy("glacial_archon", false, 1.0)
	enemy.global_position = Vector2(320.0, 0.0)
	enemy.player = world.player
	enemy.cast_cooldown = 999.0
	enemy.special_cooldown = 999.0
	enemy.pending_special = "radial"
	enemy.telegraph_time = 0.001
	enemy.telegraph_duration = 0.78
	await physics_frame
	await process_frame
	_check(world.enemy_projectiles.get_child_count() == 0 and enemy.pending_projectile_attack == "radial", "especial radial criou projeteis antes da preparacao final")
	_check(enemy.sprite.frame == 2 and enemy.sprite.flip_h, "especial radial nao travou a pose de preparacao no alvo")
	var release: Dictionary = await _wait_for_release(world)
	var elapsed := float(release.elapsed)
	_check(int(release.frame_index) > 0 and elapsed >= 0.18 and elapsed <= 0.22, "especial radial liberou fora da janela: %.3fs" % elapsed)
	_check(world.enemy_projectiles.get_child_count() == 12, "especial radial nao preservou os 12 projeteis da fase 1")
	_check(enemy.sprite.frame == 3, "especial radial nao coincidiu com o quadro de liberacao")
	_check(absf(enemy.special_cooldown - (3.08 - elapsed)) <= 0.04, "especial radial alterou seu intervalo de cooldown")


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	world.suppress_save = true
	world.spawn_timer = 9999.0
	world.set_process(false)
	world.player.disabled = true
	world.player.global_position = Vector2.ZERO
	for kind in NORMAL_RANGED_TYPES:
		await _test_normal_attack(world, kind)
	await _test_radial_attack(world)
	for music_player in world.audio.music_players:
		music_player.stop()
		music_player.stream = null
	world.audio.cached_streams.clear()
	current_scene = null
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY ATTACK TIMING OK: preparação, orientação, liberação e cooldowns integrados para todos os ranged e radial")
	quit(0 if failures.is_empty() else 1)
