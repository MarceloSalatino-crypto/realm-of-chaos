extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const BASE_COLOR := Color("ff557d")
const EVOLVED_COLOR := Color("df63ff")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func(): push_error("SHADOW DANCE CHARACTERIZATION: timeout"); quit(2))
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SHADOW DANCE CHARACTERIZATION: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _check_angle(actual: float, expected: float, message: String) -> void:
	_check(absf(angle_difference(actual, expected)) <= 0.0001, "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _prepare_player(player: Node, evolved: bool) -> void:
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
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.critical_multiplier = 2.0
	player.projectile_bonus = 0
	player.last_direction = Vector2.RIGHT
	player.attack_direction = Vector2.RIGHT
	player.attack_facing_x = 1.0
	player.attack_facing_time = 0.0
	player.pending_attack_facing_x = 0.0


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await process_frame


func _prepare_target(world: Node, player: Node2D, target: Node2D, offset := Vector2(1200.0, 0.0)) -> void:
	target.dead = false
	target.hp = 1_000_000.0
	target.max_hp = target.hp
	target.global_position = player.global_position + offset
	if not target.is_in_group("enemies"):
		target.add_to_group("enemies")
	world._rebuild_spatial_grid()


func _assert_projectile(
	projectile: Node, damage: float, speed: float, pierce: int,
	radius: float, color: Color, angle: float, style: String, label: String,
	expected_lifetime := 2.2
) -> void:
	projectile.set_physics_process(false)
	_check_close(float(projectile.damage), damage, label + ": dano mudou")
	_check_close(float(projectile.speed), speed, label + ": velocidade mudou")
	_check(int(projectile.pierce) == pierce, label + ": perfuração mudou")
	_check_close(float(projectile.hit_radius), radius, label + ": raio mudou")
	_check_close(float(projectile.knockback), 16.0, label + ": knockback mudou")
	if expected_lifetime >= 0.0:
		_check_close(float(projectile.lifetime), expected_lifetime, label + ": duração mudou")
	_check(Color(projectile.projectile_color).is_equal_approx(color), label + ": cor mudou")
	_check_angle(Vector2(projectile.direction).angle(), angle, label + ": direção mudou")
	_check(str(projectile.source_weapon) == "shadow_blades", label + ": fonte mudou")
	if not style.is_empty():
		_check(str(projectile.projectile_batch_style()) == style, label + ": lote visual mudou")
	_check(not bool(projectile.critical), label + ": crítico apareceu com chance negativa")


func _test_base(world: Node, player: Node, target: Node2D) -> void:
	await _clear_children(world.projectiles)
	await _clear_children(world.effects)
	_prepare_player(player, false)
	_prepare_target(world, player, target)
	player._fire_shadow_blades(6)
	var projectiles: Array[Node] = world.projectiles.get_children()
	_check(projectiles.size() == 8, "Lâminas nível 6 deixaram de criar oito ataques")
	_check_close(player.blades_timer, 1.04, "cooldown base mudou")
	_check(player.attack_facing_time > 0.0, "base deixou de orientar o personagem para o alvo")
	for index in range(projectiles.size()):
		_assert_projectile(
			projectiles[index], 28.0, 760.0, 1, 6.0, BASE_COLOR,
			(float(index) - 3.5) * 0.13, "shadow_small", "base %d" % index
		)
	_check_close(28.0 * 8.0, 224.0, "dano emitido por ciclo da base mudou")
	_check_close(28.0 * 8.0 * 2.0, 448.0, "potencial perfurante da base mudou")


func _test_historical_evolution(world: Node, player: Node, target: Node2D) -> void:
	await _clear_children(world.projectiles)
	await _clear_children(world.effects)
	_prepare_player(player, true)
	_prepare_target(world, player, target)
	player._fire_shadow_blades(6)
	await create_timer(0.30).timeout
	var projectiles: Array[Node] = world.projectiles.get_children()
	projectiles.sort_custom(func(a, b):
		return wrapf(Vector2(a.direction).angle(), 0.0, TAU) < wrapf(Vector2(b.direction).angle(), 0.0, TAU)
	)
	_check(projectiles.size() == 16, "Dança histórica deixou de criar dezesseis ataques")
	_check_close(player.blades_timer, 0.78, "cooldown histórico da evolução mudou")
	_check_close(player.attack_facing_time, 0.0, "evolução histórica passou a travar orientação")
	for index in range(projectiles.size()):
		var expected_angle := TAU * float(index) / 16.0
		_assert_projectile(
			projectiles[index], 45.36, 820.0, 3, 8.0, EVOLVED_COLOR,
			expected_angle, "", "evolução histórica %d" % index, -1.0
		)
	_check_close(45.36 * 16.0, 725.76, "dano emitido por ciclo da evolução mudou")
	_check_close(45.36 * 16.0 * 4.0, 2903.04, "potencial perfurante da evolução mudou")


func _test_bonus_critical_and_no_target(world: Node, player: Node, target: Node2D) -> void:
	await _clear_children(world.projectiles)
	await _clear_children(world.effects)
	_prepare_player(player, true)
	player.projectile_bonus = 2
	player.crit_chance = 1.0
	_prepare_target(world, player, target)
	player._fire_shadow_blades(6)
	await create_timer(0.30).timeout
	_check(world.projectiles.get_child_count() == 18, "bônus +2 deixou de produzir 18 lâminas evoluídas")
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)
		_check(bool(projectile.critical), "crítico garantido deixou lâmina não crítica")
		_check_close(float(projectile.damage), 90.72, "crítico individual histórico mudou")

	await _clear_children(world.projectiles)
	_prepare_player(player, true)
	target.dead = true
	target.remove_from_group("enemies")
	world._rebuild_spatial_grid()
	player._fire_shadow_blades(6)
	_check(world.projectiles.get_child_count() == 0, "evolução disparou sem alvo")
	_check_close(player.blades_timer, 0.78, "tentativa sem alvo mudou o cooldown histórico")


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
	var target = world.spawn_enemy("guardian", false, 1.0)
	target.set_process(false)
	target.set_physics_process(false)

	await _test_base(world, world.player, target)
	await _test_historical_evolution(world, world.player, target)
	await _test_bonus_critical_and_no_target(world, world.player, target)

	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print(
			"SHADOW DANCE CHARACTERIZATION OK: base=8×28/760/pierce1/1.04s; "
			+ "evolução histórica=16×45.36 radial/820/pierce3/0.78s"
		)
	quit(0 if failures.is_empty() else 1)
