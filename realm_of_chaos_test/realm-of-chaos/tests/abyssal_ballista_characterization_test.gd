extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const BASE_COLOR := Color("a96cff")
const EVOLVED_COLOR := Color("ffd36b")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	push_error("ABYSSAL BALLISTA CHARACTERIZATION: teste excedeu 20 segundos")
	quit(2)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ABYSSAL BALLISTA CHARACTERIZATION: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _reset_player(player: Node) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.chaos_bolt = 8
	player.equipped_weapon_id = "chaos_bolt"
	player.damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.critical_multiplier = 2.0
	player.projectile_bonus = 0
	player.last_direction = Vector2.RIGHT
	player.attack_direction = Vector2.RIGHT
	player.attack_facing_time = 0.0
	player.pending_attack_facing_x = 0.0


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await process_frame


func _prepare_target(world: Node, player: Node2D, target: Node2D) -> void:
	target.dead = false
	target.hp = 1_000_000.0
	target.max_hp = 1_000_000.0
	target.global_position = player.global_position + Vector2(1200.0, 0.0)
	if not target.is_in_group("enemies"):
		target.add_to_group("enemies")
	world._rebuild_spatial_grid()


func _wait_for_salvo() -> void:
	# A implementação histórica dispara imediatamente. Uma evolução visual pode
	# usar uma formação curta, mas o contrato mecânico deve estar completo aqui.
	await create_timer(0.32).timeout


func _projectiles(world: Node) -> Array:
	return world.projectiles.get_children()


func _assert_projectile(
	projectile: Node, expected_damage: float, expected_speed: float,
	expected_pierce: int, expected_radius: float, expected_color: Color,
	expected_angle: float, label: String
) -> void:
	_check_close(float(projectile.damage), expected_damage, label + ": dano mudou")
	_check_close(float(projectile.speed), expected_speed, label + ": velocidade mudou")
	_check(int(projectile.pierce) == expected_pierce, label + ": perfuração mudou")
	_check_close(float(projectile.hit_radius), expected_radius, label + ": raio mudou")
	_check(Color(projectile.projectile_color).is_equal_approx(expected_color), label + ": cor mecânico-visual mudou")
	_check_close(Vector2(projectile.direction).angle(), expected_angle, label + ": abertura angular mudou")
	_check(str(projectile.source_weapon) == "chaos_bolt", label + ": fonte de dano mudou")


func _test_base(world: Node, player: Node, target: Node2D) -> void:
	await _clear_children(world.projectiles)
	_reset_player(player)
	_prepare_target(world, player, target)
	player._fire_chaos_bolt()
	var spawned := _projectiles(world)
	_check(spawned.size() == 3, "Besta nível 8 deixou de criar 3 projéteis")
	_check_close(player.bolt_timer, 0.32, "intervalo da Besta nível 8 mudou")
	for index in range(spawned.size()):
		_assert_projectile(
			spawned[index], 47.6, 650.0, 2, 13.6, BASE_COLOR,
			(float(index) - 1.0) * 0.12, "Besta projétil %d" % index
		)


func _test_evolved(world: Node, player: Node, target: Node2D) -> void:
	await _clear_children(world.projectiles)
	_reset_player(player)
	player.evolved_weapons.chaos_bolt = true
	_prepare_target(world, player, target)
	player._fire_chaos_bolt()
	await _wait_for_salvo()
	var spawned := _projectiles(world)
	_check(spawned.size() == 5, "Balista nível 8 deixou de criar 5 projéteis")
	_check_close(player.bolt_timer, 0.48, "intervalo da Balista mudou")
	for index in range(spawned.size()):
		_assert_projectile(
			spawned[index], 97.58, 760.0, 8, 14.0, EVOLVED_COLOR,
			(float(index) - 2.0) * 0.09, "Balista projétil %d" % index
		)
	_check_close(97.58 * float(spawned.size()), 487.9, "potencial total sem crítico da Balista mudou")


func _test_projectile_bonus_and_critical(world: Node, player: Node, target: Node2D) -> void:
	await _clear_children(world.projectiles)
	_reset_player(player)
	player.evolved_weapons.chaos_bolt = true
	player.projectile_bonus = 2
	player.crit_chance = 1.0
	_prepare_target(world, player, target)
	player._fire_chaos_bolt()
	await _wait_for_salvo()
	var spawned := _projectiles(world)
	_check(spawned.size() == 7, "bônus +2 deixou de produzir 7 projéteis na Balista")
	for projectile in spawned:
		_check(bool(projectile.critical), "crítico garantido deixou projétil não crítico")
		_check_close(float(projectile.damage), 195.16, "multiplicador crítico individual mudou")


func _test_no_target(world: Node, player: Node, target: Node2D) -> void:
	await _clear_children(world.projectiles)
	await _clear_children(world.effects)
	_reset_player(player)
	player.evolved_weapons.chaos_bolt = true
	target.dead = true
	world._rebuild_spatial_grid()
	player._fire_chaos_bolt()
	await _wait_for_salvo()
	_check(world.projectiles.get_child_count() == 0, "Balista disparou sem alvo válido")
	_check(world.effects.get_child_count() == 0, "Balista criou formação sem alvo válido")
	_check_close(player.bolt_timer, 0.48, "tentativa sem alvo mudou o intervalo histórico")


func _run() -> void:
	var world := WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	var target = world.spawn_enemy("guardian", false, 1.0)
	target.set_process(false)
	target.set_physics_process(false)

	await _test_base(world, world.player, target)
	await _test_evolved(world, world.player, target)
	await _test_projectile_bonus_and_critical(world, world.player, target)
	await _test_no_target(world, world.player, target)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ABYSSAL BALLISTA CHARACTERIZATION OK: Besta e Balista históricas congeladas")
		quit(0)
	else:
		quit(1)
