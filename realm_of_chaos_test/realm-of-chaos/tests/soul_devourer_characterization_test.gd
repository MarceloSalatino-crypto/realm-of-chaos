extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const LEVEL := 6

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(25.0, true, false, true)
	watchdog.timeout.connect(func(): push_error("SOUL DEVOURER CHARACTERIZATION: timeout"); quit(2))
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SOUL DEVOURER CHARACTERIZATION: " + message)


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


func _spawn_ring_targets(world: Node, count: int, radius: float) -> Array[Node]:
	var targets: Array[Node] = []
	for index in range(count):
		var enemy = world.spawn_enemy("prowler", false, 1.0)
		_check(is_instance_valid(enemy), "alvo orbital %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		enemy.global_position = world.player.global_position + Vector2.RIGHT.rotated(TAU * index / count) * radius
		enemy.hp = 10_000.0
		enemy.max_hp = 10_000.0
		enemy.knockback_velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
		targets.append(enemy)
	world._rebuild_spatial_grid()
	return targets


func _assert_target_hits(targets: Array[Node], expected_damage: float, expected_knockback: float, label: String) -> void:
	for index in range(targets.size()):
		var target := targets[index]
		_check_close(10_000.0 - float(target.hp), expected_damage, "%s: dano do alvo %d mudou" % [label, index])
		_check_close(Vector2(target.knockback_velocity).length(), expected_knockback, "%s: knockback do alvo %d mudou" % [label, index])


func _total_damage(targets: Array[Node]) -> float:
	var total := 0.0
	for target in targets:
		total += 10_000.0 - float(target.hp)
	return total


func _test_base(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, false)
	var targets := _spawn_ring_targets(world, 5, 120.0)
	world.player._damage_orbit(LEVEL)
	_check_close(world.player.orbit_tick, 0.10, "frequência de verificação da Órbita base mudou")
	_check(world.player.orbit_hit_times.size() == 5, "Órbita base deixou de registrar cinco lâminas/alvos")
	_assert_target_hits(targets, 26.0, 8.0, "Órbita base")
	_check_close(world.player.hp, 100.0, "Órbita base passou a curar")
	world.player._damage_orbit(LEVEL)
	_assert_target_hits(targets, 26.0, 8.0, "trava de 430 ms da Órbita base")
	_check(world.projectiles.get_child_count() == 0, "Órbita base passou a criar projéteis")

	world.player.orbit_angle = 0.0
	world.player.orbit_tick = 999.0
	world.player.combat.update_weapons(0.5)
	_check_close(world.player.orbit_angle, 1.38, "velocidade angular da Órbita base mudou")


func _test_historical_evolution(world: Node) -> void:
	await _clear_container(world.enemies)
	await _clear_container(world.effects)
	_prepare_player(world.player, true)
	var targets := _spawn_ring_targets(world, 9, 170.0)
	world.player._damage_orbit(LEVEL)
	_check_close(world.player.orbit_tick, 0.10, "frequência de verificação do Devorador histórico mudou")
	_check(world.player.orbit_hit_times.size() == 9, "Devorador histórico deixou de registrar nove lâminas/alvos")
	_check_close(_total_damage(targets), 432.9, "potencial agregado histórico de nove acertos mudou")
	for index in range(targets.size()):
		_check_close(Vector2(targets[index].knockback_velocity).length(), 18.0, "Devorador: knockback do alvo %d mudou" % index)
	_check_close(world.player.hp, 103.15, "cura histórica de 0,35 por acerto mudou")
	var damage_before_repeat := _total_damage(targets)
	world.player._damage_orbit(LEVEL)
	_check_close(_total_damage(targets), damage_before_repeat, "trava de 430 ms do Devorador mudou")
	_check(world.projectiles.get_child_count() == 0, "Devorador histórico passou a criar projéteis")

	world.player.orbit_angle = 0.0
	world.player.orbit_tick = 999.0
	world.player.combat.update_weapons(0.5)
	_check_close(world.player.orbit_angle, 1.38, "velocidade angular do Devorador histórico mudou")


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

	await _test_base(world)
	await _test_historical_evolution(world)

	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SOUL DEVOURER CHARACTERIZATION OK: base 5×120/26 e evolução histórica 9×170/48,1 congeladas")
	quit(0 if failures.is_empty() else 1)
