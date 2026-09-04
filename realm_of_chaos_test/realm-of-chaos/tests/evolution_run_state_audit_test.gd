extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const LEGION_FOCUS_SCRIPT = preload("res://scripts/legion_focus.gd")
const ORBIT_CYCLES := 80
const ORBIT_TARGETS_PER_CYCLE := 9

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(35.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("EVOLUTION RUN STATE AUDIT: teste excedeu 35 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("EVOLUTION RUN STATE AUDIT: " + message)


func _spawn_target(world: Node, position: Vector2) -> Node:
	var enemy = world.spawn_enemy("prowler", false, 1.0)
	_check(is_instance_valid(enemy), "não foi possível criar alvo")
	if not is_instance_valid(enemy):
		return null
	enemy.global_position = position
	enemy.hp = 10_000_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.knockback_velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _clear_projectiles_and_effects(world: Node) -> void:
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
	for effect in world.effects.get_children():
		effect.queue_free()
	await process_frame


func _find_legion_focus(world: Node) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == LEGION_FOCUS_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _prepare_legion(player: Node) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.swarm_idol = 6
	player.evolved_weapons.swarm_idol = true
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.projectile_bonus = 0
	player.combat.legion_cast_count = 0


func _prepare_orbit(player: Node) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.soul_orbit = 6
	player.evolved_weapons.soul_orbit = true
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.life_steal = 0.0
	player.orbit_angle = 0.0
	player.orbit_hit_times.clear()
	player.combat.reset_soul_devourer_state()


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO

	_prepare_legion(world.player)
	for index in range(12):
		_spawn_target(world, Vector2(160.0 + index * 42.0, float(index % 3) * 18.0))
	world._rebuild_spatial_grid()
	world.player._release_swarm_eyes(6)
	_check(world.player.combat.legion_cast_count == 1, "primeira ativação não avançou para 1")
	_check(_find_legion_focus(world) == null, "primeira ativação criou foco especial")
	await _clear_projectiles_and_effects(world)
	world.player._release_swarm_eyes(6)
	_check(world.player.combat.legion_cast_count == 2, "segunda ativação não avançou para 2")
	_check(_find_legion_focus(world) == null, "segunda ativação criou foco especial")
	await _clear_projectiles_and_effects(world)
	world.player._release_swarm_eyes(6)
	_check(world.player.combat.legion_cast_count == 3, "terceira ativação não avançou para 3")
	_check(is_instance_valid(_find_legion_focus(world)), "terceira ativação não criou o foco especial")
	await _clear_projectiles_and_effects(world)

	# A desevolução não existe no gameplay. O teste apenas documenta que o
	# contador fica suspenso e retoma a cadência se o estado for forçado.
	world.player.evolved_weapons.swarm_idol = false
	world.player._release_swarm_eyes(6)
	_check(world.player.combat.legion_cast_count == 3, "desevolução artificial alterou o contador")
	await _clear_projectiles_and_effects(world)
	world.player.evolved_weapons.swarm_idol = true
	world.player._release_swarm_eyes(6)
	_check(world.player.combat.legion_cast_count == 4, "reevolução artificial não retomou a cadência existente")
	_check(_find_legion_focus(world) == null, "reevolução artificial criou especial fora da terceira cadência")

	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await _clear_projectiles_and_effects(world)
	await process_frame
	_prepare_orbit(world.player)

	for cycle in range(ORBIT_CYCLES):
		for index in range(ORBIT_TARGETS_PER_CYCLE):
			var blade_position := Vector2.RIGHT.rotated(TAU * float(index) / float(ORBIT_TARGETS_PER_CYCLE)) * 170.0
			_spawn_target(world, blade_position)
		world._rebuild_spatial_grid()
		world.player._damage_orbit(6)
		for enemy in world.enemies.get_children():
			enemy.queue_free()
		await process_frame
		world._rebuild_spatial_grid()
		for effect in world.effects.get_children():
			effect.queue_free()
		await process_frame

	_check(world.enemies.get_child_count() == 0, "simulação longa manteve inimigos vivos")
	var expired_time := Time.get_ticks_msec() - 1000
	for enemy_id in world.player.orbit_hit_times:
		world.player.orbit_hit_times[enemy_id] = expired_time
	world.player.combat.next_orbit_hit_history_prune_msec = 0
	var current_target := _spawn_target(world, Vector2(170.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._damage_orbit(6)
	_check(
		world.player.orbit_hit_times.size() == 1,
		"histórico da Órbita manteve IDs expirados depois da janela de recarga (%d entradas)" % world.player.orbit_hit_times.size()
	)
	_check(
		is_instance_valid(current_target)
		and world.player.orbit_hit_times.has(current_target.get_instance_id()),
		"limpeza do histórico removeu o alvo atual da Órbita"
	)
	current_target.queue_free()
	await process_frame

	world.queue_free()
	await process_frame
	var fresh_world = WORLD_SCENE.instantiate()
	root.add_child(fresh_world)
	await process_frame
	fresh_world.suppress_save = true
	fresh_world.audio.enabled = false
	fresh_world.set_process(false)
	fresh_world.set_physics_process(false)
	fresh_world.player.set_process(false)
	fresh_world.player.set_physics_process(false)
	_check(fresh_world.player.combat.legion_cast_count == 0, "novo Player herdou contador da Legião")
	_check(fresh_world.player.orbit_hit_times.is_empty(), "novo Player herdou orbit_hit_times")
	fresh_world.queue_free()
	await process_frame
	if failures.is_empty():
		print("EVOLUTION RUN STATE AUDIT OK: Legião 1/2/3, desevolução defensiva e histórico da Órbita limitado durante a run/retry")
		quit(0)
	else:
		quit(1)
